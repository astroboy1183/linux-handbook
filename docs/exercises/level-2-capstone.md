# Level 2 capstone: a backup script

> **Level 2 · Capstone** · ⏱️ 3–6 hours · Prerequisites: all of [Level 2: Shell scripting](../chapters/02-scripting/index.md)

Build `backup.sh`, a real tool you'll keep using: it archives a directory into a timestamped `.tar.gz`, keeps only the newest N archives, logs what it does, supports a dry-run mode, and passes ShellCheck with no warnings. It pulls together every chapter in Level 2.

## The scenario

Alex keeps work in `~/projects`: ETL code, SQL, notebooks, and a small web app. There's an external drive mounted at `/mnt/backup`. Alex wants one command, safe to run by hand or from a scheduler, that:

- makes a compressed snapshot of `~/projects` on the drive,
- never fills the drive, because old snapshots get cleaned up automatically,
- explains exactly what it did, or *would* do, and when,
- refuses clearly, instead of guessing, when something is wrong.

In Level 4 you'll run this script nightly with a systemd timer. Build it well now.

## Requirements

### Command line

```text
backup.sh -s SOURCE -d DEST [-k KEEP] [-n] [-v] [-h]
```

| Option | Required | Meaning |
| --- | --- | --- |
| `-s SOURCE` | yes | Directory to back up |
| `-d DEST` | yes | Directory to store archives in. Create it if it doesn't exist |
| `-k KEEP` | no | How many archives of SOURCE to keep, at least 1. Default: 7 |
| `-n` | no | Dry run: log what would happen, create and delete nothing |
| `-v` | no | Verbose: extra detail (debug lines) in the log |
| `-h` | no | Print usage to stdout and exit 0 |

Parse options with `getopts` in silent mode.

### Behavior

1. **Validate everything before doing anything.**
    - `-s` and `-d` are both given.
    - `KEEP` is a whole number ≥ 1 (and `08` means 8).
    - SOURCE exists, is a directory, and is readable.
    - DEST is not SOURCE itself and not inside SOURCE, or the backup would contain itself.
    - DEST, if it exists, is a directory and is writable.
    - Usage errors (bad options, missing or invalid values) print a message and a hint to **stderr** and exit **2**. Runtime failures exit **1**.
2. **Create the archive.**
    - Name: `<name>-YYYYmmdd-HHMMSS.tar.gz`, where `<name>` is SOURCE's base name (for example `projects-20261002-110930.tar.gz`).
    - The archive must contain the SOURCE directory itself as its top-level folder, not absolute paths. `tar -tzf` should show `projects/...`, not `home/alex/projects/...`.
    - A failed or interrupted run must **never** leave a file that looks like a valid backup. Write to a temporary name in DEST and rename it into place only when it's complete.
3. **Rotate old archives.**
    - After a successful archive, delete the oldest archives *of this SOURCE* in DEST so that exactly KEEP remain.
    - Never touch any other file in DEST: other sources' archives, notes, anything that doesn't match your naming pattern exactly.
4. **Log.**
    - Every log line has a timestamp and a level, for example `2026-10-02 11:09:30 [INFO ] created projects-20261002-110930.tar.gz (123KiB)`.
    - Logs go to **stderr**. `-v` adds `DEBUG` lines.
    - Log at least: what is being backed up and where, the archive created and its size, each deleted archive, and the total run time.
5. **Dry run (`-n`).**
    - Performs all validation.
    - Logs the archive it would create and each archive it would delete, computing rotation as if the new archive existed.
    - Creates, modifies, and deletes nothing, not even DEST.
6. **Clean up on failure.**
    - Use `set -euo pipefail` and a `trap ... EXIT` cleanup.
    - On any failure, including ++ctrl+c++ and `kill`, the temporary archive is removed and the exit status is non-zero.
7. **Quality.**
    - `shellcheck backup.sh` prints **nothing**. Install it with `sudo apt install shellcheck` if you haven't.
    - Works with SOURCE and DEST paths containing spaces.
    - Has a header comment, a `usage` function, and uses functions with `local` variables.

## Acceptance criteria

Tick each one off with a real test in a scratch directory. Don't point it at anything you care about until every box is ticked.

- [ ] `./backup.sh -h` prints usage to stdout and exits 0.
- [ ] `./backup.sh` with no options exits 2 with a message on stderr.
- [ ] `-k 0`, `-k abc`, an unknown option like `-x`, and `-s` with no value each exit 2.
- [ ] A missing SOURCE, or a SOURCE that is a file, exits 1 with a clear message.
- [ ] `-d` pointing inside SOURCE is refused before anything is created.
- [ ] `-n` with a DEST that doesn't exist logs "would create" and leaves no DEST behind.
- [ ] A normal run creates exactly one `NAME-YYYYmmdd-HHMMSS.tar.gz` in DEST.
- [ ] `gzip -t` passes on the archive, and `tar -tzf` lists `NAME/...` paths.
- [ ] With five older archives present and `-k 3`, the dry run names exactly the three oldest as "would delete," and the real run then leaves exactly 3 archives of SOURCE: the newest ones.
- [ ] Unrelated files in DEST (`notes.txt`, `other-20260101-000000.tar.gz`) survive every run.
- [ ] Pressing ++ctrl+c++ during a large backup leaves no temporary or partial archive, and the exit status is 130.
- [ ] A file in SOURCE that you can't read (`chmod 000`) makes the run fail with exit 1, and leaves no partial archive.
- [ ] Every log line has a timestamp and a level, and nothing but the help text goes to stdout.
- [ ] Paths with spaces work for both SOURCE and DEST.
- [ ] `shellcheck backup.sh` prints nothing.
- [ ] `bash -n backup.sh` passes.

### Stretch goals

Optional, but each one teaches something:

- [ ] `-l LOGFILE`: also append log lines to a file.
- [ ] A lock so two runs can't write to the same DEST at once (`flock`). The second run should exit 1 with "already running."
- [ ] Treat tar's exit status 1 ("file changed as we read it") as a warning, and 2 as a failure.
- [ ] Make ++ctrl+c++ and `kill` take effect immediately, even in the middle of a long `tar` (hint 6).
- [ ] An automated test script that runs your acceptance checks in a temporary sandbox and prints PASS/FAIL.

## Hints

Try each part yourself first. Open a hint only when you're stuck.

??? tip "Hint 1: Structure"

    Build it in stages, running ShellCheck after each:

    1. Skeleton: shebang, header, `set -euo pipefail`, defaults, `usage`, `main "$@"`.
    2. `parse_args` with `getopts ":s:d:k:nvh"` and `shift $((OPTIND - 1))`.
    3. `validate`: every check, with `usage_error` (exit 2) and `die` (exit 1) helpers.
    4. Logging: `log LEVEL message`, with `info`, `warn`, `debug`, and `die` built on it.
    5. `create_archive`, then `rotate`, then the dry-run branches, then traps.

    Keep each function small. `main` should read like the list above.

??? tip "Hint 2: Archive paths and names"

    `tar -czf ARCHIVE -C PARENT BASENAME` changes into `PARENT` before adding `BASENAME`, so the archive contains `projects/...`. Get the parts with `dirname -- "$src"` and `basename -- "$src"`, after normalizing SOURCE with `realpath -- "$src"`, so `.` or `~/projects/` work too.

    For the timestamp without running `date`: `printf -v stamp '%(%Y%m%d-%H%M%S)T' -1`. This format sorts alphabetically in time order, which makes rotation easy.

    If SOURCE's name can contain odd characters, sanitize it for the archive name: `name=${name//[^A-Za-z0-9._-]/_}`.

??? tip "Hint 3: Never leave a fake backup"

    ```bash
    tmp_archive=$(mktemp -- "$dest/.$archive.XXXXXX")
    tar -czf "$tmp_archive" ...
    gzip -t -- "$tmp_archive"
    mv -- "$tmp_archive" "$dest/$archive"
    tmp_archive=""
    ```

    Put the temp file **in DEST**, not `/tmp`, so `mv` is an atomic rename on the same filesystem. The leading dot keeps it out of your rotation pattern. In the `EXIT` trap, delete `$tmp_archive` if it's set. Clear the variable after the `mv` so a successful run doesn't try to delete it.

??? tip "Hint 4: Rotation"

    List only *your* archives, safely, oldest first:

    ```bash
    mapfile -d '' -t backups < <(
        find "$dest" -maxdepth 1 -type f \
            -name "$name-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].tar.gz" \
            -print0 | sort -z
    )
    ```

    Then `excess=$(( ${#backups[@]} - keep ))`, and delete `backups[0]` through `backups[excess-1]` if `excess > 0`. In dry-run mode the new archive doesn't exist yet, so add 1 to the count before computing `excess`.

    Why not `ls -t | tail`? `ls` output breaks on unusual names, and modification times can be changed by copying. Your timestamped names are the source of truth.

??? tip "Hint 5: Dry run"

    Decide at each state-changing step: `mkdir`, `tar`, `mv`, and `rm`. A simple pattern:

    ```bash
    if (( dry_run )); then
        info "[dry run] would delete old backup ${f##*/}"
    else
        rm -f -- "$f"
        info "deleted old backup ${f##*/}"
    fi
    ```

    Don't create DEST, take a lock, or write temp files in dry-run mode. Then test: `find DEST` before and after a dry run must be identical.

??? tip "Hint 6: Traps that work during a long tar"

    ```bash
    trap cleanup EXIT
    trap 'on_signal INT 130' INT
    trap 'on_signal TERM 143' TERM
    ```

    where `on_signal` logs and calls `exit "$2"`, which fires `cleanup`.

    There's a catch. Bash runs a trap only **after the current foreground command finishes**. A `kill` sent to your script during a 10-minute `tar` is handled 10 minutes later. The fix is to run `tar` in the background and `wait` for it, because `wait` *is* interrupted by signals:

    ```bash
    tar -czf "$tmp_archive" -C "$parent" -- "$base" &
    child_pid=$!
    wait "$child_pid" || status=$?
    child_pid=""
    ```

    In `cleanup`, if `child_pid` is set, `kill` it and `wait` for it before deleting the temp file.

??? tip "Hint 7: Common ShellCheck complaints you may meet"

    - **SC2086/SC2046**: quote every expansion.
    - **SC2155**: `local x=$(cmd)` → `local x; x=$(cmd)`.
    - **SC2015**: `A && B || C` → use `if`.
    - **SC2064**: use single quotes in `trap` strings.
    - **SC2162**: `read -r`.
    - **SC2034**: a variable you set but never use. Usually a typo.

    Look up any other code at `https://www.shellcheck.net/wiki/SC####`.

## Solution

Finished, or truly stuck? Compare with the [reference solution](solutions/level-2-capstone.md). It includes the full script, a section-by-section explanation, and a test plan. Your version doesn't need to match. It needs to pass every acceptance criterion.
