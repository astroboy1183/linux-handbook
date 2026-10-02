# Bash Scripting Cheat Sheet

Quick reference for writing bash scripts: a safe template, variables,
expansions, tests, control flow, functions, arrays, option parsing, and
redirection. Chapters: all of [Level 2](../chapters/02-scripting/index.md),
especially [Error handling](../chapters/02-scripting/04-error-handling.md)
and [Arguments and getopts](../chapters/02-scripting/05-arguments-getopts.md).

## Script template

```bash
#!/usr/bin/env bash
#
# backup.sh - archive a directory, with logging, cleanup, and a dry-run mode.
set -euo pipefail

SCRIPT_NAME="${0##*/}"
readonly SCRIPT_NAME

log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "$SCRIPT_NAME" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [-n] [-v] [-o DIR] SOURCE
  -n       dry run: show what would happen
  -v       verbose output
  -o DIR   output directory (default: /tmp)
  -h       show this help
EOF
}

tmpdir=""
cleanup() {
    local rc=$?
    if [[ -n "$tmpdir" ]]; then rm -rf -- "$tmpdir"; fi
    exit "$rc"
}
trap cleanup EXIT
trap 'log "interrupted"; exit 130' INT TERM

dry_run=false
verbose=false
outdir=/tmp

while getopts ":nvo:h" opt; do
    case "$opt" in
        n) dry_run=true ;;
        v) verbose=true ;;
        o) outdir="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG needs an argument" ;;
        \?) usage >&2; die "unknown option: -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))

(( $# == 1 )) || { usage >&2; exit 2; }
src="$1"
[[ -d "$src" ]] || die "not a directory: $src"

tmpdir="$(mktemp -d)"
if $verbose; then log "src=$src outdir=$outdir dry_run=$dry_run"; fi

if $dry_run; then
    log "would archive $src into $outdir"
else
    tar -czf "$outdir/backup-$(date +%F).tar.gz" -C "$src" .
    log "done"
fi
```

| Line | Why it's there |
|---|---|
| `#!/usr/bin/env bash` | **Shebang**: run with the first `bash` found in `PATH` |
| `set -e` | Exit when a command fails (with exceptions: inside `if`, `&&`, `||`) |
| `set -u` | Treat unset variables as errors (catches typos) |
| `set -o pipefail` | A pipeline fails if **any** command in it fails, not just the last |
| `trap cleanup EXIT` | Always run `cleanup` when the script ends, for any reason |
| `log ... >&2` | Messages go to stderr, so stdout stays clean for data |

Check every script with `shellcheck script.sh`. Debug with `bash -x
script.sh`, or `set -x` / `set +x` around a section.

## Variables and quoting

```bash
name="alex"                  # no spaces around =
echo "Hello, $name"          # double quotes: variables expand
echo 'Cost: $5'              # single quotes: nothing expands
echo "${name}_backup"        # braces separate the name from text
today="$(date +%F)"          # command substitution
count=$((count + 1))         # arithmetic
readonly MAX=10              # constant
export PGHOST=db.internal    # pass to child processes
local tmp="x"                # inside a function: local scope
```

!!! warning "Common mistake: unquoted variables"
    Always write `"$var"`, not `$var`. Unquoted, the value is split on spaces
    and expanded as a glob, so a file named `my report.txt` becomes two
    arguments. Use `"$@"` (quoted) to pass all arguments through unchanged.

## Parameter expansion

With `f=/home/alex/data/report.final.csv`:

| Expansion | Result | What it does |
|---|---|---|
| `${f}` | `/home/alex/data/report.final.csv` | Value |
| `${#f}` | `32` | Length |
| `${f##*/}` | `report.final.csv` | Remove longest prefix matching `*/` (basename) |
| `${f%/*}` | `/home/alex/data` | Remove shortest suffix matching `/*` (dirname) |
| `${f%.*}` | `/home/alex/data/report.final` | Remove shortest suffix: strip extension |
| `${f%%.*}` | `/home/alex/data/report` | Remove longest suffix |
| `${f##*.}` | `csv` | Extension |
| `${f/report/summary}` | `/home/alex/data/summary.final.csv` | Replace first match |
| `${f//a/A}` | `/home/Alex/dAtA/report.finAl.csv` | Replace all matches |
| `${f:6:4}` | `alex` | Substring: offset 6, length 4 |
| `${f: -3}` | `csv` | Last 3 characters (note the space) |
| `${var:-default}` | `default` if unset or empty | Use a default |
| `${var:=default}` | Same, and assigns it | Set a default |
| `${var:?message}` | Exits with `message` if unset or empty | Require a value |
| `${var:+alt}` | `alt` if set and non-empty, else empty | Use alternate |
| `${name^^}` / `${name,,}` | `ALEX` / `alex` | Upper / lower case |
| `${name^}` | `Alex` | Capitalize first letter |

## Test operators

Use `[[ ... ]]` in bash scripts. It handles empty variables safely and
supports `&&`, `||`, `==` patterns, and `=~` regexes.

| Strings | True if | Numbers | True if |
|---|---|---|---|
| `-z "$s"` | `s` is empty | `$a -eq $b` | Equal |
| `-n "$s"` | `s` is not empty | `$a -ne $b` | Not equal |
| `"$a" == "$b"` | Equal | `$a -lt $b` | Less than |
| `"$a" != "$b"` | Not equal | `$a -le $b` | Less or equal |
| `"$a" == b*` | Matches glob (unquoted right side) | `$a -gt $b` | Greater than |
| `"$a" =~ ^[0-9]+$` | Matches regex (unquoted) | `$a -ge $b` | Greater or equal |
| `"$a" < "$b"` | Sorts before | `(( a > b ))` | Arithmetic test, C-style |

| Files | True if | Files | True if |
|---|---|---|---|
| `-e f` | Exists | `-r f` | Readable by you |
| `-f f` | Regular file | `-w f` | Writable by you |
| `-d f` | Directory | `-x f` | Executable by you |
| `-L f` | Symbolic link | `-s f` | Exists and not empty |
| `f1 -nt f2` | f1 newer than f2 | `f1 -ot f2` | f1 older than f2 |

Combine with `&&`, `||`, and `!` inside `[[ ]]`. Regex capture groups land in
`BASH_REMATCH`:

```bash
if [[ "$date" =~ ^([0-9]{4})-([0-9]{2})$ ]]; then
    echo "year=${BASH_REMATCH[1]} month=${BASH_REMATCH[2]}"
fi
```

## Conditionals

```bash
if [[ -f "$config" ]]; then
    source "$config"
elif [[ -n "${CONFIG_URL:-}" ]]; then
    curl -fsS "$CONFIG_URL" -o "$config"
else
    die "no config"
fi

if grep -q 'ERROR' app.log; then echo "errors found"; fi   # test a command's exit status

[[ -d "$dir" ]] || mkdir -p "$dir"                          # short form

case "$1" in
    start|up)   start_app ;;
    stop)       stop_app ;;
    *.tar.gz)   extract "$1" ;;
    *)          usage; exit 2 ;;
esac
```

## Loops

```bash
for f in *.csv; do                     # over files (quote "$f" inside!)
    echo "processing $f"
done

for i in {1..5}; do echo "$i"; done    # brace range
for ((i = 0; i < 10; i++)); do echo "$i"; done   # C-style

for host in "${hosts[@]}"; do ping -c1 "$host"; done   # over an array

while IFS= read -r line; do            # read a file line by line, safely
    echo "> $line"
done < input.txt

while IFS=, read -r name city age; do  # split CSV fields
    echo "$name is $age"
done < <(tail -n +2 people.csv)

until curl -fs http://localhost:8080/health; do sleep 2; done   # retry until success

break      # leave the loop
continue   # skip to the next iteration
```

## Functions

```bash
greet() {
    local name="${1:?name required}"   # local variable, required argument
    local greeting="${2:-Hello}"        # optional, with default
    printf '%s, %s!\n' "$greeting" "$name"
}

greet alex           # Hello, alex!
msg="$(greet bob Hi)"   # capture output

is_root() { [[ $EUID -eq 0 ]]; }   # the last command's status is the return value
if is_root; then echo "running as root"; fi

fail() { return 3; }   # return sets the exit status (0–255), not a value
```

## Arrays

```bash
files=(a.txt "b c.txt" d.txt)      # indexed array
files+=(e.txt)                     # append
echo "${files[0]}"                 # first element
echo "${files[-1]}"                # last element
echo "${#files[@]}"                # number of elements
echo "${!files[@]}"                # indexes: 0 1 2 3
for f in "${files[@]}"; do echo "$f"; done   # iterate, always quoted
echo "${files[@]:1:2}"             # slice: 2 elements from index 1
unset 'files[1]'                   # remove one element
mapfile -t lines < input.txt       # read a file into an array, one line each

declare -A port=([http]=80 [https]=443)   # associative array (dictionary)
port[ssh]=22
echo "${port[https]}"              # 443
for k in "${!port[@]}"; do echo "$k=${port[$k]}"; done   # keys (unordered)
[[ -v port[ssh] ]] && echo "has ssh"
```

## getopts template

```bash
verbose=false
output=""
while getopts ":vo:h" opt; do      # leading ":" = handle errors yourself
    case "$opt" in                 # "o:" = -o takes an argument
        v) verbose=true ;;
        o) output="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "-$OPTARG needs an argument" >&2; exit 2 ;;
        \?) echo "unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))              # now "$@" holds the remaining arguments
```

`getopts` handles short options only (`-v -o out` or `-vo out`). For long
options like `--verbose`, parse with a `while`/`case` loop over `"$1"` and
`shift`.

## Redirection

| Syntax | What it does |
|---|---|
| `cmd > file` | stdout to file (overwrite) |
| `cmd >> file` | stdout to file (append) |
| `cmd 2> file` | stderr to file |
| `cmd > file 2>&1` | stdout **and** stderr to file (order matters) |
| `cmd &> file` | Same, bash shorthand |
| `cmd 2>/dev/null` | Discard errors |
| `cmd < file` | stdin from file |
| `cmd1 | cmd2` | stdout of cmd1 into stdin of cmd2 |
| `cmd1 |& cmd2` | stdout and stderr into cmd2 |
| `cmd | tee file` | Show output **and** save it |
| `cmd <<EOF ... EOF` | **Here-document**: multi-line stdin (`<<'EOF'` disables expansion) |
| `cmd <<< "$var"` | **Here-string**: a string as stdin |
| `diff <(cmd1) <(cmd2)` | **Process substitution**: command output as a file |
| `exec > >(tee -a log.txt) 2>&1` | Send the rest of the script's output to a log too |
| `>&2 echo "msg"` | Print to stderr |

## Special variables

| Variable | Meaning |
|---|---|
| `$0` | Script name as invoked |
| `$1` … `$9`, `${10}` | Positional arguments |
| `$#` | Number of arguments |
| `"$@"` | All arguments, each as a separate word (use this) |
| `"$*"` | All arguments joined into one string |
| `$?` | Exit status of the last command (0 = success) |
| `$$` | PID of the current shell |
| `$!` | PID of the last background job |
| `$_` | Last argument of the previous command |
| `$-` | Current shell option flags |
| `$EUID` / `$UID` | Effective / real user ID (0 = root) |
| `$RANDOM` | Random integer 0–32767 |
| `$LINENO` | Current line number (useful in error messages) |
| `$SECONDS` | Seconds since the shell started |
| `$PIPESTATUS` | Array of exit statuses from the last pipeline |
| `$IFS` | Characters used for word splitting (default: space, tab, newline) |
| `$BASH_SOURCE` | Path of the current script file (works when sourced) |

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | General error |
| `2` | Misuse: bad arguments (convention) |
| `126` | Command found but not executable |
| `127` | Command not found |
| `128+N` | Killed by signal N (130 = ++ctrl+c++, 137 = `SIGKILL`, 143 = `SIGTERM`) |
