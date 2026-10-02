# Level 2 capstone: reference solution

> **Level 2 · Capstone solution** · Exercise: [Level 2 capstone](../level-2-capstone.md)

This is one complete, working answer to the backup-script capstone. Read it *after* you've built your own. Your script doesn't need to look like this, but it must pass the same tests. The script is also saved in the repository as `scripts/backup.sh`.

!!! warning "Test in a scratch directory first"
    This script deletes old archives. Run every test below on throwaway directories (for example under `~/scratch`) before you point it at real data or a real backup drive.

## The script

```bash
#!/usr/bin/env bash
#
# backup.sh - Create timestamped .tar.gz backups of a directory and keep
#             only the newest N of them.
#
# Usage:   backup.sh -s SOURCE -d DEST [-k KEEP] [-l LOGFILE] [-n] [-v] [-h]
# Example: backup.sh -s ~/projects -d /mnt/backup/projects -k 14 -v
#
# Exit codes:
#   0  success
#   1  runtime failure (tar failed, cannot write, another run in progress, ...)
#   2  usage error (bad or missing options)
#
# Requires: bash 4.3+, GNU tar, gzip, flock (util-linux), coreutils.
# Level 2 capstone reference solution - The Linux Handbook.

set -Eeuo pipefail

# ---- Constants ------------------------------------------------------------
PROG=${0##*/}
readonly PROG
readonly DEFAULT_KEEP=7

# ---- Settings (changed by options) ----------------------------------------
src=""
dest=""
keep=$DEFAULT_KEEP
log_file=""
dry_run=0
verbose=0

# ---- State ----------------------------------------------------------------
name=""             # archive name prefix, derived from SOURCE
tmp_archive=""      # partial archive for the EXIT trap to delete on failure
child_pid=""        # PID of a running tar, for the EXIT trap to stop
start_ts=$SECONDS

# ---- Logging --------------------------------------------------------------
# log LEVEL MESSAGE... : timestamped line to stderr (and to the log file).
log() {
    local level=$1 line
    shift
    printf -v line '%(%Y-%m-%d %H:%M:%S)T [%-5s] %s' -1 "$level" "$*"
    printf '%s\n' "$line" >&2
    if [[ -n $log_file ]]; then
        printf '%s\n' "$line" >> "$log_file"
    fi
}
info()  { log INFO "$@"; }
warn()  { log WARN "$@"; }
debug() { if (( verbose )); then log DEBUG "$@"; fi; }
die()   { log ERROR "$@"; exit 1; }

usage() {
    cat <<EOF
Usage: $PROG -s SOURCE -d DEST [-k KEEP] [-l LOGFILE] [-n] [-v] [-h]

Create DEST/<name>-YYYYmmdd-HHMMSS.tar.gz from the directory SOURCE,
then delete the oldest backups of SOURCE so that only KEEP remain.

Options:
  -s SOURCE   directory to back up (required)
  -d DEST     directory to store backups in; created if missing (required)
  -k KEEP     number of backups to keep, at least 1 (default: $DEFAULT_KEEP)
  -l LOGFILE  also append log lines to LOGFILE
  -n          dry run: report what would happen, change nothing
  -v          verbose: extra detail in the log
  -h          show this help and exit

Examples:
  $PROG -s ~/projects -d /mnt/backup/projects
  $PROG -s /srv/data -d /mnt/backup/data -k 30 -l /var/tmp/backup.log -v
  $PROG -s ~/projects -d /mnt/backup/projects -n
EOF
}

# usage_error MESSAGE : complain about the command line and exit 2.
usage_error() {
    printf '%s: %s\n' "$PROG" "$*" >&2
    printf "Try '%s -h' for more information.\n" "$PROG" >&2
    exit 2
}

# ---- Traps ----------------------------------------------------------------
cleanup() {
    local status=$?
    if [[ -n $child_pid ]]; then
        kill -TERM "$child_pid" 2>/dev/null || true
        wait "$child_pid" 2>/dev/null || true
    fi
    if [[ -n $tmp_archive && -e $tmp_archive ]]; then
        rm -f -- "$tmp_archive"
        warn "removed incomplete archive $tmp_archive"
    fi
    # Status 2 is a usage error, already explained; don't call it a failed backup.
    if (( status != 0 && status != 2 )); then
        log ERROR "backup FAILED (exit status $status)"
    fi
}

on_signal() {
    warn "received SIG$1, stopping"
    exit "$2"          # runs the EXIT trap, which cleans up
}

on_error() {
    log ERROR "command failed (status $1) at line $2: $3"
}

trap cleanup EXIT
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

# ---- Helpers --------------------------------------------------------------
# human BYTES : print a size like 1.5MiB using numfmt.
human() {
    numfmt --to=iec-i --suffix=B -- "$1"
}

# ---- Option parsing -------------------------------------------------------
parse_args() {
    local opt
    while getopts ":s:d:k:l:nvh" opt; do
        case $opt in
            s) src=$OPTARG ;;
            d) dest=$OPTARG ;;
            k) keep=$OPTARG ;;
            l) log_file=$OPTARG ;;
            n) dry_run=1 ;;
            v) verbose=1 ;;
            h) usage; exit 0 ;;
            :) usage_error "option -$OPTARG requires an argument" ;;
            \?) usage_error "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))
    (( $# == 0 )) || usage_error "unexpected argument '$1'"
}

# ---- Validation -----------------------------------------------------------
validate() {
    [[ -n $src ]]  || usage_error "-s SOURCE is required"
    [[ -n $dest ]] || usage_error "-d DEST is required"
    if [[ ! $keep =~ ^[0-9]+$ ]] || (( 10#$keep < 1 )); then
        usage_error "-k must be a whole number of at least 1, got '$keep'"
    fi
    keep=$(( 10#$keep ))     # 10# so that "08" means 8, not invalid octal

    if [[ -n $log_file ]]; then
        touch -- "$log_file" 2>/dev/null || usage_error "cannot write log file '$log_file'"
    fi

    [[ -e $src ]] || die "source '$src' does not exist"
    [[ -d $src ]] || die "source '$src' is not a directory"
    [[ -r $src && -x $src ]] || die "source '$src' is not readable"
    src=$(realpath -- "$src")
    [[ $src != / ]] || die "refusing to back up the whole filesystem (/)"

    if [[ -e $dest && ! -d $dest ]]; then
        die "destination '$dest' exists but is not a directory"
    fi
    # realpath -m works even if DEST does not exist yet.
    dest=$(realpath -m -- "$dest")
    if [[ $dest == "$src" || $dest == "$src"/* ]]; then
        die "destination '$dest' is inside the source; the backup would include itself"
    fi
}

# ---- Steps ----------------------------------------------------------------
prepare_dest() {
    if [[ ! -d $dest ]]; then
        if (( dry_run )); then
            info "[dry run] would create directory $dest"
            return 0
        fi
        mkdir -p -- "$dest" || die "cannot create destination '$dest'"
        info "created destination $dest"
    fi
    [[ -w $dest ]] || die "destination '$dest' is not writable"
}

# Only one backup may write to a destination at a time. The kernel releases
# a flock automatically when the process exits, even after kill -9.
take_lock() {
    if (( dry_run )); then
        debug "[dry run] not taking the lock"
        return 0
    fi
    local lock_file=$dest/.backup.lock
    exec 9>>"$lock_file" || die "cannot open lock file $lock_file"
    flock -n 9 || die "another backup is already running in $dest"
    debug "acquired lock $lock_file"
}

create_archive() {
    local parent base stamp archive final status src_bytes size cmd
    parent=$(dirname -- "$src")
    base=$(basename -- "$src")
    printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
    archive=$name-$stamp.tar.gz
    final=$dest/$archive

    # Size estimate for the log only; unreadable files make du complain,
    # and tar will report those properly below.
    src_bytes=$(du -sb -- "$src" 2>/dev/null | cut -f1) || true
    info "backing up $src ($(human "${src_bytes:-0}")) to $final"

    if (( dry_run )); then
        printf -v cmd '%q ' tar -czf "$final" -C "$parent" -- "$base"
        info "[dry run] would run: ${cmd% }"
        return 0
    fi
    [[ ! -e $final ]] || die "$final already exists; refusing to overwrite"

    # Write to a hidden temp file in DEST, then rename into place, so a
    # half-written archive never carries a real backup name.
    tmp_archive=$(mktemp -- "$dest/.$archive.XXXXXX")
    debug "writing to temporary file $tmp_archive"

    # tar runs in the background and we wait for it: bash runs a signal
    # trap only between commands, but 'wait' can be interrupted, so
    # Ctrl+C or kill takes effect at once instead of after tar finishes.
    status=0
    tar -czf "$tmp_archive" -C "$parent" -- "$base" &
    child_pid=$!
    wait "$child_pid" || status=$?
    child_pid=""
    case $status in
        0) ;;
        1) warn "tar reported files that changed while being read; archive kept" ;;
        *) die "tar failed with status $status" ;;
    esac

    gzip -t -- "$tmp_archive" || die "archive failed gzip integrity test"
    debug "integrity check passed"

    mv -- "$tmp_archive" "$final"
    tmp_archive=""
    size=$(stat -c %s -- "$final")
    info "created $archive ($(human "$size"))"
}

rotate() {
    local -a backups=()
    local count excess i

    if [[ ! -d $dest ]]; then
        debug "no existing backups to rotate"
        return 0
    fi

    # Our names sort chronologically, so plain sort puts the oldest first.
    # The pattern only matches files this script created for this source.
    mapfile -d '' -t backups < <(
        find "$dest" -maxdepth 1 -type f \
            -name "$name-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].tar.gz" \
            -print0 | sort -z
    )
    count=${#backups[@]}
    debug "found $count backup(s) of '$name' in $dest, keeping $keep"

    if (( dry_run )); then
        # The dry run did not create a new archive; pretend it did.
        (( ++count ))
    fi
    excess=$(( count - keep ))
    if (( excess <= 0 )); then
        info "rotation: $count backup(s), limit $keep, nothing to delete"
        return 0
    fi

    for (( i = 0; i < excess; i++ )); do
        if (( dry_run )); then
            info "[dry run] would delete old backup ${backups[i]##*/}"
        else
            rm -f -- "${backups[i]}"
            info "deleted old backup ${backups[i]##*/}"
        fi
    done
}

# ---- Main -----------------------------------------------------------------
main() {
    parse_args "$@"
    validate

    # Archive names start with the source directory's name, with anything
    # other than letters, digits, dot, dash, and underscore replaced by _.
    name=$(basename -- "$src")
    name=${name//[^A-Za-z0-9._-]/_}

    if (( dry_run )); then
        info "DRY RUN: nothing will be created or deleted"
    fi
    debug "source=$src dest=$dest keep=$keep name=$name"

    prepare_dest
    take_lock
    create_archive
    rotate

    info "done in $(( SECONDS - start_ts ))s"
}

main "$@"
```

## How it works, section by section

### Header and strict mode

The header says what the script does, how to call it, what the exit codes mean, and what it needs. `set -Eeuo pipefail` turns on everything from [Error handling](../../chapters/02-scripting/04-error-handling.md):

- `-e`: stop on an unhandled failure.
- `-u`: stop on an unset variable. That catches typos like `$dset`.
- `-o pipefail`: a pipeline fails if any part fails.
- `-E`: the `ERR` trap also fires inside functions. Almost all the work happens in functions, so without `-E` the `ERR` trap would never fire.

`PROG=${0##*/}` is then made `readonly` on its own line. `readonly PROG=${0##*/}` would also work here, but splitting declaration and assignment is the habit that avoids SC2155 when the value comes from a command substitution.

### Settings and state

All settings start with their defaults in one block, and options overwrite them. Three **state** variables exist for the traps:

- `tmp_archive`: the path of a half-written archive. The `EXIT` trap deletes it if it's set.
- `child_pid`: the PID of a running `tar`. The `EXIT` trap stops it.
- `start_ts`: the value of bash's `SECONDS` counter at startup, for the "done in Ns" line.

`name` is declared here too, even though `main` fills it in, so every global the script uses is visible at the top.

### Logging

`log` builds one line with `printf -v` and bash's built-in time format `%(...)T` (no `date` process per line), then writes it to stderr and, if `-l` was given, appends it to the log file. `info`, `warn`, `debug`, and `die` are one-line wrappers.

Two details from Chapter 4 matter here:

- `debug` uses `if (( verbose ))` rather than `(( verbose )) && log ...`. The `&&` form returns status 1 when verbose is off. As the last command of a function, that would make the *function* fail, and `set -e` would kill the script silently.
- Everything goes to stderr. The script's only stdout output is the help text, so `./backup.sh ... > something` can never mix logs into data.

`usage_error` is separate from `die`. A command-line mistake gets the conventional exit status 2 and a "Try -h" hint, while a runtime failure gets status 1 and a timestamped log line.

### Traps

```bash
trap cleanup EXIT
trap 'on_signal INT 130' INT
trap 'on_signal TERM 143' TERM
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
```

- **`cleanup` (EXIT)** runs however the script ends. It first stops a running `tar` (`kill`, then `wait` so the process has really exited), then deletes the partial archive, then logs a FAILED line for any non-zero status except 2, since a usage error isn't a failed backup.
- **`on_signal` (INT, TERM)** logs the signal and calls `exit` with 128 + the signal number. That `exit` fires the `EXIT` trap, so cleanup lives in exactly one place.
- **`on_error` (ERR)** names the exact command and line that failed unexpectedly. Commands guarded with `|| die` don't trigger it, because they're "tested." It catches the failures you didn't anticipate. The trap string is in single quotes so `$?`, `$LINENO`, and `$BASH_COMMAND` are expanded when the trap fires, not when it's defined.

The signal traps are installed before any work starts, so there's no window in which a ++ctrl+c++ could leave a mess.

### Option parsing

`parse_args` is a textbook silent-mode `getopts` loop from [Arguments and getopts](../../chapters/02-scripting/05-arguments-getopts.md):

- The leading `:` in `":s:d:k:l:nvh"` selects silent mode, so the script writes its own messages.
- `:)` handles "option needs a value" and `\?)` handles "unknown option," both through `usage_error`.
- After `shift $((OPTIND - 1))`, any leftover word is an error. This tool takes no operands, so a stray argument is almost certainly a mistake, like a forgotten `-s`.

`opt` is declared `local`. `OPTIND` doesn't need to be, because `parse_args` runs exactly once.

### Validation

`validate` checks everything before a single file is touched:

- Required options are present.
- `KEEP` is digits only and at least 1. The regex runs before any arithmetic (so `-k 'a[$(cmd)]'` can't be evaluated), and `10#` forces base 10 so that `08` is 8 rather than an octal error.
- The log file is writable, checked with `touch`, so a bad `-l` fails up front instead of halfway through.
- SOURCE exists, is a directory, and is readable and searchable (`-r` and `-x`). It's then normalized with `realpath`, so `.`, `../x`, `~/projects/`, and symlinks all become one canonical absolute path. Backing up `/` is refused outright.
- DEST, if it exists, must be a directory. `realpath -m` canonicalizes it even when it doesn't exist yet.
- **DEST must not be SOURCE or inside SOURCE.** `[[ $dest == "$src"/* ]]` is a pattern match on canonical paths. The quotes around `$src` make it literal, so a source path containing `*` or `[` can't act as a pattern. Without this check, each backup would include all previous backups, and the archives would grow without limit.

### Preparing DEST and the lock

`prepare_dest` creates DEST if needed (or only says it would, in a dry run) and checks it's writable.

`take_lock` opens `DEST/.backup.lock` on file descriptor 9 and takes an exclusive, non-blocking `flock`. A second run against the same DEST fails immediately with "another backup is already running." The kernel releases the lock when the process exits for any reason, even `kill -9`, so there's never a stale lock to clean up. That's the advantage over the `mkdir` lock from Chapter 4. A dry run skips the lock, because it must not create files.

### Creating the archive

`create_archive` follows the "write to temp, verify, rename" pattern:

1. **Name.** `printf -v stamp '%(%Y%m%d-%H%M%S)T' -1` gives a timestamp that sorts alphabetically in time order.
2. **Size estimate.** `du -sb` for the log. Its errors are discarded and `|| true` keeps an unreadable file from killing the script *here*. `tar` will report that problem properly in a moment.
3. **Dry run.** Log the exact `tar` command (built with `printf %q`, so paths with spaces are shown unambiguously) and return.
4. **Refuse to overwrite** an archive with the same name. Two runs in the same second would collide, and the lock makes that very unlikely, but it costs one line.
5. **Temp file in DEST.** `mktemp -- "$dest/.$archive.XXXXXX"` makes a hidden, uniquely named file with mode 600. Being in DEST means the final `mv` is an atomic rename on one filesystem. Being hidden (a leading `.`) means it never matches the rotation pattern.
6. **Run tar in the background and `wait`.** Bash runs signal traps only between commands. With `tar` in the foreground, a `kill` sent during a 10-minute archive would only be handled after `tar` finished. `wait` is interruptible, so the trap fires at once, and `cleanup` stops `tar`. (A ++ctrl+c++ typed in the terminal reaches `tar` too, but a `kill PID` or a scheduler's stop request only reaches the script.)
7. **Interpret tar's exit status.** GNU tar uses 1 for "some files changed while being read." The archive is still usable, so that's a warning. 2 or more is fatal.
8. **Verify** with `gzip -t`, which reads the whole archive and checks its CRC. This catches truncation, for example from a full disk.
9. **Publish** with `mv`, then clear `tmp_archive` so the `EXIT` trap doesn't touch the finished file.

The final archive keeps mode 600 from `mktemp`. Backups often contain secrets (`.env` files, keys, database dumps), so only the owner should be able to read them.

### Rotation

`rotate` lists **only this script's archives for this source**, using a `find -name` pattern with exactly eight digits, a dash, six digits, and `.tar.gz`. A file such as `projects-old.tar.gz`, `notes.txt`, or another source's `other-20260101-000000.tar.gz` can never match.

`-print0 | sort -z` and `mapfile -d ''` make the list safe for any file name (Chapter 2), and because the names embed the timestamp, sorting by name sorts by age. The script deliberately ignores modification times, which `cp` or a restore can change.

In a dry run, no new archive was created, so the count gets `+1` before computing `excess`. The dry run then predicts exactly what a real run would delete.

### `main`

`main` reads like a table of contents: parse, validate, derive the archive name, prepare DEST, lock, archive, rotate, report. The archive name prefix is SOURCE's base name with anything unusual replaced by `_`, so `My Docs (2026)` becomes `My_Docs__2026_-20261002-110658.tar.gz`. That's a name that is safe in a glob pattern and in any tool.

The only top-level command is `main "$@"` on the last line, so bash has read the entire file before anything runs (Chapter 1's style template).

## Sample runs

Paths are shown as Alex would see them, with SOURCE `~/projects` and DEST `~/backups`.

### Dry run before the first backup

```bash
./backup.sh -s ~/projects -d ~/backups -n
```

```text
2026-10-02 11:09:30 [INFO ] DRY RUN: nothing will be created or deleted
2026-10-02 11:09:30 [INFO ] [dry run] would create directory /home/alex/backups
2026-10-02 11:09:30 [INFO ] backing up /home/alex/projects (820KiB) to /home/alex/backups/projects-20261002-110930.tar.gz
2026-10-02 11:09:30 [INFO ] [dry run] would run: tar -czf /home/alex/backups/projects-20261002-110930.tar.gz -C /home/alex -- projects
2026-10-02 11:09:30 [INFO ] done in 0s
```

`~/backups` still doesn't exist afterward.

### First real run, verbose, with a log file

```bash
./backup.sh -s ~/projects -d ~/backups -k 3 -v -l ~/backup.log
```

```text
2026-10-02 11:09:30 [DEBUG] source=/home/alex/projects dest=/home/alex/backups keep=3 name=projects
2026-10-02 11:09:30 [INFO ] created destination /home/alex/backups
2026-10-02 11:09:30 [DEBUG] acquired lock /home/alex/backups/.backup.lock
2026-10-02 11:09:30 [INFO ] backing up /home/alex/projects (820KiB) to /home/alex/backups/projects-20261002-110930.tar.gz
2026-10-02 11:09:30 [DEBUG] writing to temporary file /home/alex/backups/.projects-20261002-110930.tar.gz.eClw9s
2026-10-02 11:09:30 [DEBUG] integrity check passed
2026-10-02 11:09:30 [INFO ] created projects-20261002-110930.tar.gz (123KiB)
2026-10-02 11:09:30 [DEBUG] found 1 backup(s) of 'projects' in /home/alex/backups, keeping 3
2026-10-02 11:09:30 [INFO ] rotation: 1 backup(s), limit 3, nothing to delete
2026-10-02 11:09:30 [INFO ] done in 0s
```

```bash
ls -l ~/backups
tar -tzf ~/backups/projects-20261002-110930.tar.gz
```

```text
total 124
-rw------- 1 alex alex 125289 Oct  2 11:09 projects-20261002-110930.tar.gz
projects/
projects/etl/
projects/etl/orders.csv
projects/etl/sql/
projects/etl/sql/daily.sql
projects/web app/
projects/web app/index.html
```

The archive is private (mode 600), and its paths start at `projects/`. (`ls -l` doesn't show the hidden `.backup.lock` file.) The same lines are in `~/backup.log`.

### Rotation

With five older archives already in `~/backups`:

```bash
ls -A ~/backups
```

```text
.backup.lock
projects-20260927-020000.tar.gz
projects-20260928-020000.tar.gz
projects-20260929-020000.tar.gz
projects-20260930-020000.tar.gz
projects-20261001-020000.tar.gz
projects-20261002-110930.tar.gz
```

Preview first:

```bash
./backup.sh -s ~/projects -d ~/backups -k 3 -n
```

```text
2026-10-02 11:09:35 [INFO ] DRY RUN: nothing will be created or deleted
2026-10-02 11:09:35 [INFO ] backing up /home/alex/projects (820KiB) to /home/alex/backups/projects-20261002-110935.tar.gz
2026-10-02 11:09:35 [INFO ] [dry run] would run: tar -czf /home/alex/backups/projects-20261002-110935.tar.gz -C /home/alex -- projects
2026-10-02 11:09:35 [INFO ] [dry run] would delete old backup projects-20260927-020000.tar.gz
2026-10-02 11:09:35 [INFO ] [dry run] would delete old backup projects-20260928-020000.tar.gz
2026-10-02 11:09:35 [INFO ] [dry run] would delete old backup projects-20260929-020000.tar.gz
2026-10-02 11:09:35 [INFO ] [dry run] would delete old backup projects-20260930-020000.tar.gz
2026-10-02 11:09:35 [INFO ] done in 0s
```

Then for real:

```bash
./backup.sh -s ~/projects -d ~/backups -k 3
ls -A ~/backups
```

```text
2026-10-02 11:09:36 [INFO ] backing up /home/alex/projects (820KiB) to /home/alex/backups/projects-20261002-110936.tar.gz
2026-10-02 11:09:36 [INFO ] created projects-20261002-110936.tar.gz (123KiB)
2026-10-02 11:09:36 [INFO ] deleted old backup projects-20260927-020000.tar.gz
2026-10-02 11:09:36 [INFO ] deleted old backup projects-20260928-020000.tar.gz
2026-10-02 11:09:36 [INFO ] deleted old backup projects-20260929-020000.tar.gz
2026-10-02 11:09:36 [INFO ] deleted old backup projects-20260930-020000.tar.gz
2026-10-02 11:09:36 [INFO ] done in 0s
.backup.lock
projects-20261001-020000.tar.gz
projects-20261002-110930.tar.gz
projects-20261002-110936.tar.gz
```

Six archives plus the new one is seven. Keeping three means deleting the four oldest, exactly as the dry run predicted.

### Failures

Command-line mistakes exit 2:

```bash
./backup.sh -s ~/projects -d ~/backups -k 0; echo "exit=$?"
./backup.sh -x; echo "exit=$?"
```

```text
backup.sh: -k must be a whole number of at least 1, got '0'
Try 'backup.sh -h' for more information.
exit=2
backup.sh: unknown option -x
Try 'backup.sh -h' for more information.
exit=2
```

A destination inside the source is refused before anything is created:

```bash
./backup.sh -s ~/projects -d ~/projects/backups; echo "exit=$?"
```

```text
2026-10-02 11:06:17 [ERROR] destination '/home/alex/projects/backups' is inside the source; the backup would include itself
2026-10-02 11:06:17 [ERROR] backup FAILED (exit status 1)
exit=1
```

An unreadable file makes `tar` fail, and the partial archive is removed:

```bash
chmod 000 ~/src2/private.key
./backup.sh -s ~/src2 -d ~/backups2; echo "exit=$?"
```

```text
2026-10-02 11:06:58 [INFO ] created destination /home/alex/backups2
2026-10-02 11:06:58 [INFO ] backing up /home/alex/src2 (10B) to /home/alex/backups2/src2-20261002-110658.tar.gz
tar: src2/private.key: Cannot open: Permission denied
tar: Exiting with failure status due to previous errors
2026-10-02 11:06:58 [ERROR] tar failed with status 2
2026-10-02 11:06:58 [WARN ] removed incomplete archive /home/alex/backups2/.src2-20261002-110658.tar.gz.Idjaho
2026-10-02 11:06:58 [ERROR] backup FAILED (exit status 1)
exit=1
```

A `kill` (SIGTERM) in the middle of archiving 300 MiB. The script stopped within milliseconds instead of waiting for `tar`:

```text
2026-10-02 11:08:06 [INFO ] created destination /home/alex/bigbackups
2026-10-02 11:08:06 [INFO ] backing up /home/alex/big (300MiB) to /home/alex/bigbackups/big-20261002-110806.tar.gz
2026-10-02 11:08:08 [WARN ] received SIGTERM, stopping
2026-10-02 11:08:08 [WARN ] removed incomplete archive /home/alex/bigbackups/.big-20261002-110806.tar.gz.IYzgKo
2026-10-02 11:08:08 [ERROR] backup FAILED (exit status 143)
```

++ctrl+c++ gives the same result with `received SIGINT` and exit status 130.

Two runs at once against the same destination:

```text
[second] 2026-10-02 11:07:23 [ERROR] another backup is already running in /home/alex/bigbackups
[second] 2026-10-02 11:07:23 [ERROR] backup FAILED (exit status 1)
[first]  2026-10-02 11:07:22 [INFO ] backing up /home/alex/big (300MiB) to /home/alex/bigbackups/big-20261002-110722.tar.gz
[first]  2026-10-02 11:07:38 [INFO ] created big-20261002-110722.tar.gz (301MiB)
[first]  2026-10-02 11:07:38 [INFO ] rotation: 1 backup(s), limit 7, nothing to delete
[first]  2026-10-02 11:07:38 [INFO ] done in 16s
```

A file that changed while `tar` was reading it is a warning, not a failure:

```text
tar: big/blob.bin: file changed as we read it
2026-10-02 11:08:34 [WARN ] tar reported files that changed while being read; archive kept
2026-10-02 11:08:36 [INFO ] created big-20261002-110820.tar.gz (301MiB)
```

And an unexpected failure (here, `mv` failing on a broken disk) is caught by the `ERR` trap, which names the exact line:

```text
mv: cannot move: Input/output error
2026-10-02 11:08:58 [ERROR] command failed (status 1) at line 238: mv -- "$tmp_archive" "$final"
2026-10-02 11:08:58 [WARN ] removed incomplete archive /home/alex/backups3/.projects-20261002-110858.tar.gz.hTeuDG
2026-10-02 11:08:58 [ERROR] backup FAILED (exit status 1)
```

## Test plan

### Static checks

```bash
bash -n backup.sh && echo "syntax OK"
shellcheck backup.sh && echo "shellcheck clean"
```

```text
syntax OK
shellcheck clean
```

### Manual tests

Run these in a scratch directory with a small `src/` folder (include a file name with a space) and an empty `out/` path.

| # | Test | Command | Expected |
| --- | --- | --- | --- |
| 1 | Help | `./backup.sh -h; echo $?` | Usage on stdout, `0` |
| 2 | No options | `./backup.sh; echo $?` | Message on stderr, `2` |
| 3 | Bad KEEP | `-k 0`, `-k abc` | Exit `2` |
| 4 | KEEP with leading zero | `-k 08 -n` | Accepted, treated as 8 |
| 5 | Unknown option / missing value | `-x`, `-s` alone | Exit `2` |
| 6 | Missing or non-directory source | `-s nope`, `-s file.txt` | Exit `1`, clear message |
| 7 | DEST inside SOURCE | `-s src -d src/out` | Exit `1`, nothing created |
| 8 | Dry run, new DEST | `-s src -d out -n`, then `ls out` | Logs "would create", `out` doesn't exist |
| 9 | First backup | `-s src -d out` | One `src-YYYYmmdd-HHMMSS.tar.gz`, mode 600 |
| 10 | Archive contents | `gzip -t out/*.tar.gz; tar -tzf out/*.tar.gz` | Passes; paths start with `src/` |
| 11 | Rotation preview | Add 5 fake older archives, `-k 3 -n` | "would delete" the right files; nothing changes |
| 12 | Rotation | `-k 3` | Exactly 3 archives of `src` remain, the newest |
| 13 | Unrelated files | Add `notes.txt`, `other-20200101-000000.tar.gz` | Untouched by every run |
| 14 | Unreadable file | `chmod 000 src/secret` | Exit `1`, no temp files left |
| 15 | Ctrl+C mid-run | Large source, press ++ctrl+c++ | Exit `130`, no temp files left, no `tar` still running |
| 16 | kill mid-run | `kill PID` from another terminal | Exit `143` within a second, no temp files left |
| 17 | Concurrent runs | Start two against the same DEST | Second exits `1` "already running" |
| 18 | Spaces in paths | `-s "My Docs" -d "Back Ups"` | Works; archive named `My_Docs-...` |
| 19 | Log file | `-l run.log` | Same lines in the file as on stderr |
| 20 | Stdout is clean | `./backup.sh -s src -d out 2>/dev/null` | Prints nothing |

For test 15, make a large source quickly with `head -c 300M /dev/urandom > big/blob.bin`. Random data doesn't compress, so `tar` takes several seconds. Delete it afterward.

### Automated tests

The fastest way to retest after every change is a small harness that runs the checks in a throwaway sandbox:

```bash
#!/usr/bin/env bash
# test-backup.sh - quick automated checks for backup.sh, run in a sandbox.
set -uo pipefail

script=$(realpath -- "${1:-./backup.sh}")
sandbox=$(mktemp -d)
trap 'rm -rf -- "$sandbox"' EXIT
cd "$sandbox" || exit 1

pass=0 fail=0
check() {                       # check DESCRIPTION EXPECTED_STATUS COMMAND...
    local desc=$1 want=$2 got
    shift 2
    "$@" >/dev/null 2>&1
    got=$?
    if (( got == want )); then
        (( ++pass )); printf 'PASS  %s\n' "$desc"
    else
        (( ++fail )); printf 'FAIL  %s (wanted %d, got %d)\n' "$desc" "$want" "$got"
    fi
}
count() { find "$1" -maxdepth 1 -name 'src-*.tar.gz' 2>/dev/null | wc -l; }

mkdir -p src/sub && echo "hello" > src/sub/a.txt && echo "id,amount" > "src/b c.csv"

check "help exits 0"                 0 "$script" -h
check "no options is a usage error"  2 "$script"
check "unknown option"               2 "$script" -s src -d out -x
check "keep must be >= 1"            2 "$script" -s src -d out -k 0
check "keep must be a number"        2 "$script" -s src -d out -k many
check "missing source fails"         1 "$script" -s nope -d out
check "dest inside source refused"   1 "$script" -s src -d src/backups
check "dry run succeeds"             0 "$script" -s src -d out -n
check "dry run created nothing"      1 test -e out
check "real run succeeds"            0 "$script" -s src -d out -k 2
check "one archive exists"           0 test "$(count out)" -eq 1
check "archive is a valid gzip"      0 gzip -t out/src-*.tar.gz
check "archive contains the files"   0 bash -c 'tar -tzf out/src-*.tar.gz | grep -q "src/b c.csv"'

# Fake three older backups, then rotate down to 2.
for d in 20200101 20200102 20200103; do touch "out/src-$d-000000.tar.gz"; done
touch out/unrelated.txt out/other-20200101-000000.tar.gz
sleep 1
check "second run succeeds"          0 "$script" -s src -d out -k 2
check "rotation kept exactly 2"      0 test "$(count out)" -eq 2
check "oldest fakes deleted"         1 test -e out/src-20200101-000000.tar.gz
check "unrelated files untouched"    0 test -e out/unrelated.txt -a -e out/other-20200101-000000.tar.gz
check "no temp files left"           0 test -z "$(find out -name '.src-*')"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
```

```bash
./test-backup.sh ./backup.sh
```

```text
PASS  help exits 0
PASS  no options is a usage error
PASS  unknown option
PASS  keep must be >= 1
PASS  keep must be a number
PASS  missing source fails
PASS  dest inside source refused
PASS  dry run succeeds
PASS  dry run created nothing
PASS  real run succeeds
PASS  one archive exists
PASS  archive is a valid gzip
PASS  archive contains the files
PASS  second run succeeds
PASS  rotation kept exactly 2
PASS  oldest fakes deleted
PASS  unrelated files untouched
PASS  no temp files left

18 passed, 0 failed
```

The harness itself uses `set -uo pipefail` *without* `-e`, on purpose: a test runner must keep going after a failed check so it can report them all.

## Where this goes next

- **Level 4, [Scheduling tasks](../../chapters/04-sysadmin/02-scheduling.md):** run `backup.sh` nightly from a systemd timer, with its stderr landing in the journal.
- **Level 4, [Disks and backups](../../chapters/04-sysadmin/06-disks-and-backups.md):** mount a real backup drive, and compare this approach with incremental tools like `rsync --link-dest`.
- **[Bash or Python?](../../chapters/02-scripting/06-bash-vs-python.md):** if you add S3 uploads, encryption, or email reports, revisit that chapter's checklist. This script is near the size where Python starts to pay off.
