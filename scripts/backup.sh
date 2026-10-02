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
