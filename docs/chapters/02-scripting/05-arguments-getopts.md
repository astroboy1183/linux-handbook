# Arguments and getopts

> **Level 2 · Chapter 5** · ⏱️ ~45 min read · Prerequisites: [Error handling](04-error-handling.md)

Real tools take arguments and options: `ls -la /etc`, `grep -i -n error app.log`. This chapter covers how a script receives its arguments, how to parse short options properly with `getopts`, how to support `--long-options` by hand, how to validate everything before doing any work, and when a config file or environment variable is a better fit than a flag.

## Why it matters

Alex's log-search script started as `./logsearch.sh app.log`. Then a teammate wanted warnings instead of errors, so Alex added a second argument: `./logsearch.sh app.log WARN`. Then a limit: `./logsearch.sh app.log WARN 20`. Then case-insensitive matching: `./logsearch.sh app.log WARN 20 yes`.

Nobody can remember what the fourth positional argument means. Someone passes `20 WARN` in the wrong order and the script silently searches for the level "20." And searching two files is impossible, because the second position is already taken.

With options, it reads `./logsearch.sh -l WARN -n 20 -i app.log other.log`. The order doesn't matter, every value is labeled, defaults fill the gaps, `-h` explains everything, and a typo like `-q` produces a clear error instead of a silent wrong answer. That is what users expect of any Linux command, and this chapter shows how to give it to them.

## Concepts

### Arguments, options, and operands

When you run `grep -i -m 5 error app.log`, the shell splits the line into words and passes them to `grep` as its **arguments** (also called **parameters**). By convention, Linux tools divide arguments into:

- **Options** (also called **flags** or **switches**) start with `-`. They change *how* the command behaves. `-i` is a **boolean option**: it's either there or not. `-m 5` is an **option with an argument** (also called an option value).
- **Operands** (also called **positional arguments**) are the things the command works *on*: `error` and `app.log`.
- **`--`**, on its own, means "end of options." Everything after it is an operand, even if it starts with a dash. That's how you `grep` for the text `-v`, or `rm` a file named `-rf`.

The POSIX conventions for short options, which `getopts` implements for you:

| Convention | Example | Equivalent to |
| --- | --- | --- |
| Single-letter options after one dash | `-v` | |
| Boolean flags can be bundled | `-iv` | `-i -v` |
| An option's argument can be separate or attached | `-n 5`, `-n5` | |
| A bundle can end with an option that takes an argument | `-vn 5` | `-v -n 5` |
| Options come before operands | `cmd -v file` | |
| `--` ends options | `cmd -- -file` | |

GNU tools also accept **long options** like `--max-count=5` or `--max-count 5`, and allow options after operands. `getopts` doesn't support long options. You'll write that parsing by hand later in this chapter.

### Positional parameters: `$0`, `$1`...`$9`, `${10}`, `$#`

Inside a script, the arguments are the **positional parameters**:

| Parameter | Meaning |
| --- | --- |
| `$0` | How the script was called: `./backup.sh`, `backup`, or `/home/alex/bin/backup` |
| `$1` to `$9` | The first nine arguments |
| `${10}`, `${11}`, ... | Further arguments. Braces are **required**: `$10` means `$1` followed by `0` |
| `$#` | The number of arguments (not counting `$0`) |
| `"$@"` | All arguments, each as a separate word (Chapter 2) |
| `"$*"` | All arguments joined into one string |

`$0` is whatever path was used to start the script, so it varies between runs. `${0##*/}` gives just the file name, which is good for messages. To find the directory the script *lives in* (to load a file next to it), use `${BASH_SOURCE[0]}`:

```bash
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
```

This changes into the script's directory in a subshell and prints the absolute path, so it works no matter where you call the script from.

### `shift`

**`shift`** drops `$1` and moves every other parameter down by one: `$2` becomes `$1`, `$3` becomes `$2`, and `$#` goes down by one. `shift N` drops N parameters at once. If there are fewer than N, `shift N` fails (status 1) and changes nothing.

`shift` is how you consume arguments one at a time in a loop, `while (( $# > 0 )); do ...; shift; done`, and how you drop the options once `getopts` has parsed them.

### `usage()` functions

Every script that takes arguments should have a **`usage` function** that prints a short help text. Call it for `-h`, and for any argument error. The convention:

- `-h` (and `--help`) prints usage to **stdout** and exits **0**. The user asked for it, and they might pipe it into `less`.
- A usage *error* prints the error, plus usage or a hint, to **stderr** and exits **2**.

The usual way to write a multi-line help text is a **here-document** (heredoc). `cat <<EOF` feeds every following line to `cat`'s standard input, up to a line containing only `EOF`. Variables inside it are expanded. Writing `<<'EOF'`, with the delimiter quoted, turns expansion off. The delimiter word is up to you: `USAGE`, `EOF`, `END`.

A good usage text shows the synopsis line in the standard notation: `[optional]`, `REQUIRED`, `...` for "one or more", and `a|b` for alternatives. Then it lists one line per option with its default, followed by an example.

### `getopts`: the built-in option parser

**`getopts`** is a bash builtin that parses short options one at a time. It's called in a `while` loop:

```bash
while getopts "OPTSTRING" opt; do
    case $opt in
        ...
    esac
done
shift $((OPTIND - 1))
```

**The optstring** lists the option letters the script accepts. A letter followed by `:` takes an argument:

```text
"l:n:ivh"
 │  │ │││
 │  │ ││└── -h   flag
 │  │ │└─── -v   flag
 │  │ └──── -i   flag
 │  └────── -n   takes an argument (n:)
 └───────── -l   takes an argument (l:)
```

**Each call to `getopts`:**

1. Looks at the next option in the arguments.
2. Puts the option letter in the variable you named (here `opt`).
3. If the option takes an argument, puts that argument in **`OPTARG`**.
4. Updates **`OPTIND`**, the index of the next argument to examine. It starts at 1.
5. Returns 0 (true), so the loop continues.

When it reaches the first operand (a word not starting with `-`), or `--`, or the end of the arguments, `getopts` returns 1 and the loop ends. At that point `OPTIND` points at the first operand, so **`shift $((OPTIND - 1))`** removes all the options and leaves only the operands in `"$@"`.

```text
./logsearch.sh -l WARN -i -n 20 app.log other.log
               $1 $2   $3 $4 $5 $6      $7

after the loop: OPTIND=6    shift 5    →   $1=app.log  $2=other.log
```

`getopts` stops at the first operand. `cmd file -v` treats `-v` as a second operand, not an option. This is the POSIX behavior. GNU tools reorder arguments, `getopts` doesn't.

### Error handling in `getopts`: normal vs silent mode

`getopts` has two error-reporting modes.

**Normal mode** (the default): on an unknown option or a missing argument, `getopts` prints its own error message, such as `./g1.sh: illegal option -- x`, sets `opt` to `?`, and unsets `OPTARG`. You can't tell which error happened.

**Silent mode**, chosen by starting the optstring with a colon (`":l:n:ivh"`): `getopts` prints nothing and tells you exactly what went wrong, so you can write your own messages:

| Situation | `opt` is set to | `OPTARG` is set to |
| --- | --- | --- |
| Valid option | the letter | its argument, if it takes one |
| Unknown option `-x` | `?` | `x` (the offending letter) |
| Missing argument for `-n` | `:` | `n` (the option missing its argument) |

In the `case`, write the unknown-option branch as `\?)` with the backslash. An unescaped `?` is a glob pattern that matches **any** single character, so it would catch every option.

Use silent mode. It gives you control over the wording, lets you add a "Try -h" hint, and lets you choose the exit code.

!!! warning "Common mistake: an option value that looks like an option"
    With `-o -v`, `getopts` takes `-v` as the **argument** of `-o`, because `-o` requires one and `-v` is the next word. That's standard behavior (GNU tools do the same), and validation is what protects you. If an output file name starts with `-`, reject it or at least warn.

!!! tip "`getopts` inside functions"
    `OPTIND` is a global variable. If a function uses `getopts` and is called twice, the second call starts where the first left off and parses nothing. Declare `local OPTIND opt` at the top of any function that uses `getopts`.

### Long options by hand

`getopts` only handles single-letter options. For `--level WARN`, `--level=WARN`, and `--help`, the standard approach is a `while` loop over `$1` with a `case`, shifting as you go:

```bash
while (( $# > 0 )); do
    case $1 in
        -l|--level)  level=$2; shift 2 ;;     # value in the next word
        --level=*)   level=${1#*=}; shift ;;  # value after the '='
        -v|--verbose) verbose=1; shift ;;
        --)          shift; break ;;          # end of options
        -?*)         die "unknown option: $1" ;;
        *)           break ;;                 # first operand
    esac
done
```

Pieces to notice:

- Each option with a value needs two branches: one for `--opt value` (consume two words with `shift 2`) and one for `--opt=value` (strip up to `=` with `${1#*=}`).
- Before `shift 2`, check that a value exists: `(( $# >= 2 )) || die "$1 requires an argument"`. Otherwise `$2` is unset, `set -u` kills the script with a confusing message, and `shift 2` fails.
- `-?*` matches a dash followed by at least one character, so any unknown option is caught. A lone `-`, which conventionally means "stdin," falls through to the operand branch.
- This simple loop doesn't support bundled short flags (`-iv`) or attached values (`-n5`). Those need more branches. If you need all of that, use the `getopt` program (see the tip below) or switch to Python's `argparse` (Chapter 6).

!!! tip "`getopt` (no s) from util-linux"
    Mint also ships **`getopt`**, an external program from util-linux (`getopt --version`). It understands long options, bundling, and options after operands, and rewrites the arguments into a normalized form for a simple `case` loop. It's powerful but less portable (macOS ships a different, older `getopt`), and the `eval set --` idiom it requires is easy to get wrong. This handbook uses `getopts` for short options and a hand-written loop when long options are needed.

### Validating input

Parse first, validate second, and only then do any work. Never start deleting, copying, or loading before every input is checked. A typo found halfway through a run leaves a half-done mess.

What to check:

| Check | How |
| --- | --- |
| Required argument present | `(( $# >= 1 )) || die "..."`, or `${var:?msg}` |
| No unexpected extra arguments | `(( $# == 0 )) || die "unexpected argument '$1'"` |
| Integer | `[[ $n =~ ^[0-9]+$ ]]` (non-negative), `^-?[0-9]+$` (signed) |
| Range | `(( n >= 1 && n <= 100 ))`, *after* the integer check |
| One of a fixed set | `case $level in DEBUG|INFO|WARN|ERROR) ;; *) die ...;; esac` |
| A name with safe characters | `[[ $name =~ ^[a-z][a-z0-9_-]*$ ]]` |
| Input file is readable | `[[ -f $f && -r $f ]]` |
| Output directory is writable | `[[ -d $d && -w $d ]]` |
| Not dangerous | `[[ $dest != / ]]`, and `$src` and `$dest` aren't the same path |

Normalize before validating where it helps: `level=${level^^}` accepts `warn` as well as `WARN`.

Why check integers with a regex instead of just using them in `(( ))`? Arithmetic treats an unknown word as a variable name, and an unset variable is 0. So `-n ten` would silently mean "0." Worse, arithmetic *evaluates* what it's given, so input like `a[$(cmd)]` can execute commands in some contexts. Validate first, then do the arithmetic.

### Defaults

Set defaults **before** parsing, in one visible block near the top of the script, so options simply overwrite them. Document each default in `usage`. For values that depend on the environment, use parameter expansion: `name=${USER:-friend}`, `output_dir=${XDG_DATA_HOME:-$HOME/.local/share}/myapp`.

### Config files and environment variables as alternatives

Options are perfect for things that change from run to run. For settings that rarely change (a server name, a retention count, an API endpoint), retyping a flag every time is tedious and error-prone. There are two alternatives:

- **Environment variables** are good for per-machine or per-session settings, secrets injected by a scheduler, and overriding behavior in tests: `LOGSEARCH_LEVEL=INFO ./logsearch.sh`. Prefix them with the tool's name to avoid clashes.
- **Config files** are good for many settings, or settings a team shares. Conventional locations are `~/.config/TOOL/config` or `~/.config/TOOL.conf` for per-user settings (the XDG convention) and `/etc/TOOL.conf` for system-wide ones.

The standard precedence, from weakest to strongest, is:

```mermaid
flowchart LR
    A["Built-in defaults"] --> B["System config<br/>/etc/tool.conf"] --> C["User config<br/>~/.config/tool.conf"] --> D["Environment<br/>TOOL_LEVEL=..."] --> E["Command-line<br/>options"]
```

Each layer overrides the one before it, so the most specific, most deliberate choice wins.

!!! danger "Don't `source` config files you don't fully control"
    The tempting way to read a `KEY=value` config is `source ~/.config/tool.conf`. But `source` *executes* the file as bash. A line like `output=$(rm -rf ~)` would run. If the config file is writable by anyone else, or you'd run the script as root with a user's config, that's a privilege escalation. **Parse** config files line by line and accept only known keys, as shown in the examples below.

## Commands and examples

### Positional parameters

```bash
#!/usr/bin/env bash
# params.sh - show the positional parameters
echo "\$0 = $0"
echo "\$# = $#"
echo "\$1 = ${1-<unset>}"
echo "\$2 = ${2-<unset>}"
echo "\$10 = $10   (that's \$1 followed by 0)"
echo "\${10} = ${10-<unset>}"
echo "all: $*"
```

```bash
./params.sh a b c d e f g h i j
```

```text
$0 = ./params.sh
$# = 10
$1 = a
$2 = b
$10 = a0   (that's $1 followed by 0)
${10} = j
all: a b c d e f g h i j
```

```bash
bash params.sh "first arg"
```

```text
$0 = params.sh
$# = 1
$1 = first arg
$2 = <unset>
$10 = first arg0   (that's $1 followed by 0)
${10} = <unset>
all: first arg
```

`$0` changed with how the script was launched. The quoted `"first arg"` is one parameter.

### `shift`

```bash
#!/usr/bin/env bash
echo "start: $# args: $*"
shift
echo "after shift:   $# args: $*"
shift 2
echo "after shift 2: $# args: $*"
shift 5 || echo "shift 5 failed (only $# left), nothing changed"
echo "end: $# args: $*"
```

```bash
./shift.sh one two three four five
```

```text
start: 5 args: one two three four five
after shift:   4 args: two three four five
after shift 2: 2 args: four five
shift 5 failed (only 2 left), nothing changed
end: 2 args: four five
```

The standard loop that processes every argument:

```bash
while (( $# > 0 )); do
    echo "processing: $1"
    shift
done
```

```text
processing: a b
processing: c
```

(That's the output for `./loop-shift.sh "a b" c`.)

### Finding the script's own directory

```bash
#!/usr/bin/env bash
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
echo "script lives in: $script_dir"
echo "called as: $0, name only: ${0##*/}"
```

```bash
cd /
/home/alex/scripts/scriptdir.sh
```

```text
script lives in: /home/alex/scripts
called as: /home/alex/scripts/scriptdir.sh, name only: scriptdir.sh
```

Use `"$script_dir/lib.sh"` or `"$script_dir/templates/"` to reach files shipped next to the script.

### `getopts` step by step

This script prints what `getopts` sets on each iteration:

```bash
#!/usr/bin/env bash
# g1.sh - getopts in its default (noisy) mode
verbose=0 output=""
while getopts "vo:" opt; do
    echo "  opt=$opt OPTARG=${OPTARG-<unset>} OPTIND=$OPTIND"
    case $opt in
        v) verbose=1 ;;
        o) output=$OPTARG ;;
        *) echo "  (bad option, opt is '?')" ;;
    esac
done
shift $((OPTIND - 1))
echo "verbose=$verbose output=$output remaining: $*"
```

Separate options, then bundled options:

```bash
./g1.sh -v -o out.csv data.csv
./g1.sh -vo out.csv a b
```

```text
  opt=v OPTARG=<unset> OPTIND=2
  opt=o OPTARG=out.csv OPTIND=4
verbose=1 output=out.csv remaining: data.csv
  opt=v OPTARG=<unset> OPTIND=1
  opt=o OPTARG=out.csv OPTIND=3
verbose=1 output=out.csv remaining: a b
```

In the first run, `OPTIND` jumps from 2 to 4 because `-o` consumed its argument. In the bundled run, `OPTIND` stays at 1 after `-v`, because `getopts` is still inside the word `-vo`. In both cases, `shift $((OPTIND - 1))` leaves exactly the operands.

An attached value, and stopping at the first operand:

```bash
./g1.sh -oout.csv
./g1.sh data.csv -v
./g1.sh -v -- -o notanoption
```

```text
  opt=o OPTARG=out.csv OPTIND=2
verbose=0 output=out.csv remaining:
verbose=0 output= remaining: data.csv -v
  opt=v OPTARG=<unset> OPTIND=2
verbose=1 output= remaining: -o notanoption
```

`data.csv -v`: parsing stopped at `data.csv`, so `-v` became an operand. After `--`, `-o` is an operand too.

Errors in the default mode:

```bash
./g1.sh -x
./g1.sh -o
```

```text
./g1.sh: illegal option -- x
  opt=? OPTARG=<unset> OPTIND=2
  (bad option, opt is '?')
verbose=0 output= remaining:
./g1.sh: option requires an argument -- o
  opt=? OPTARG=<unset> OPTIND=2
  (bad option, opt is '?')
verbose=0 output= remaining:
```

`getopts` printed its own messages, both errors look the same to your code (`opt=?`), and the script carried on as if nothing had happened.

### Silent mode

```bash
#!/usr/bin/env bash
# g2.sh - getopts in silent mode (leading colon)
while getopts ":vo:" opt; do
    case $opt in
        v) echo "verbose on" ;;
        o) echo "output: $OPTARG" ;;
        :) echo "error: -$OPTARG requires an argument" >&2; exit 2 ;;
        \?) echo "error: unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
echo "operands: $*"
```

```bash
./g2.sh -x; echo "exit=$?"
./g2.sh -o; echo "exit=$?"
./g2.sh -v -o report.csv in1 in2
./g2.sh -o -v
```

```text
error: unknown option -x
exit=2
error: -o requires an argument
exit=2
verbose on
output: report.csv
operands: in1 in2
output: -v
operands:
```

Now each error is distinct, and the messages are yours. The last run shows the "value that looks like an option" behavior: `-v` became the output file name.

### A complete `getopts` script

This is the pattern to copy: header, `usage`, `die`, defaults, parsing, validation, and only then the work.

```bash
#!/usr/bin/env bash
#
# logsearch.sh - show log lines at a given level from one or more log files.
#
set -euo pipefail

readonly PROG=${0##*/}

usage() {
    cat <<USAGE
Usage: $PROG [-l LEVEL] [-n MAX] [-i] [-v] [-h] FILE...

Show lines at LEVEL from each FILE.

Options:
  -l LEVEL   DEBUG, INFO, WARN, or ERROR (default: ERROR)
  -n MAX     show at most MAX matching lines per file (default: all)
  -i         match the level case-insensitively
  -v         verbose: print which file is being searched
  -h         show this help and exit

Example:
  $PROG -l WARN -n 20 /var/log/app/*.log
USAGE
}

die() {
    printf '%s: %s\n' "$PROG" "$*" >&2
    printf "Try '%s -h' for more information.\n" "$PROG" >&2
    exit 2
}

# ---- Defaults ------------------------------------------------------------
level=ERROR
max=0            # 0 = no limit
ignore_case=0
verbose=0

# ---- Parse options -------------------------------------------------------
while getopts ":l:n:ivh" opt; do
    case $opt in
        l) level=$OPTARG ;;
        n) max=$OPTARG ;;
        i) ignore_case=1 ;;
        v) verbose=1 ;;
        h) usage; exit 0 ;;
        :) die "option -$OPTARG requires an argument" ;;
        \?) die "unknown option -$OPTARG" ;;
    esac
done
shift $((OPTIND - 1))

# ---- Validate ------------------------------------------------------------
level=${level^^}
case $level in
    DEBUG|INFO|WARN|ERROR) ;;
    *) die "invalid level '$level' (use DEBUG, INFO, WARN, or ERROR)" ;;
esac
[[ $max =~ ^[0-9]+$ ]] || die "-n needs a non-negative integer, got '$max'"
(( $# > 0 )) || die "no log files given"
for f in "$@"; do
    [[ -r $f ]] || die "cannot read '$f'"
done

# ---- Work ----------------------------------------------------------------
grep_opts=(-E)
(( ignore_case )) && grep_opts+=(-i)
(( max > 0 )) && grep_opts+=(-m "$max")

for f in "$@"; do
    (( verbose )) && printf '== %s ==\n' "$f" >&2
    grep "${grep_opts[@]}" -- " $level " "$f" || true
done
```

With this `app.log`:

```text
2026-10-01 10:00:01 INFO  api: service started on :8080
2026-10-01 10:00:05 ERROR db: connection refused (host=db1)
2026-10-01 10:00:09 WARN  api: slow request /orders 2.1s
2026-10-01 10:01:13 ERROR db: connection refused (host=db1)
2026-10-01 10:02:00 INFO  api: heartbeat
2026-10-01 10:02:30 error worker: job 4411 failed
```

Normal use:

```bash
./logsearch.sh app.log
./logsearch.sh -l warn app.log
./logsearch.sh -i app.log
```

```text
2026-10-01 10:00:05 ERROR db: connection refused (host=db1)
2026-10-01 10:01:13 ERROR db: connection refused (host=db1)
2026-10-01 10:00:09 WARN  api: slow request /orders 2.1s
2026-10-01 10:00:05 ERROR db: connection refused (host=db1)
2026-10-01 10:01:13 ERROR db: connection refused (host=db1)
2026-10-01 10:02:30 error worker: job 4411 failed
```

The default level is ERROR. `-l warn` was normalized to `WARN`. `-i` also found the lowercase `error` line.

Several files with a limit and verbose output (the `==` headers go to stderr):

```bash
./logsearch.sh -i -n 2 -v app.log app2.log
```

```text
== app.log ==
2026-10-01 10:00:05 ERROR db: connection refused (host=db1)
2026-10-01 10:01:13 ERROR db: connection refused (host=db1)
== app2.log ==
2026-10-01 10:00:05 ERROR db: connection refused (host=db1)
2026-10-01 10:01:13 ERROR db: connection refused (host=db1)
```

Every kind of bad input, caught before any work starts:

```bash
./logsearch.sh -l FATAL app.log; echo "exit=$?"
./logsearch.sh -n ten app.log; echo "exit=$?"
./logsearch.sh -q app.log; echo "exit=$?"
./logsearch.sh -l; echo "exit=$?"
./logsearch.sh; echo "exit=$?"
./logsearch.sh nope.log; echo "exit=$?"
```

```text
logsearch.sh: invalid level 'FATAL' (use DEBUG, INFO, WARN, or ERROR)
Try 'logsearch.sh -h' for more information.
exit=2
logsearch.sh: -n needs a non-negative integer, got 'ten'
Try 'logsearch.sh -h' for more information.
exit=2
logsearch.sh: unknown option -q
Try 'logsearch.sh -h' for more information.
exit=2
logsearch.sh: option -l requires an argument
Try 'logsearch.sh -h' for more information.
exit=2
logsearch.sh: no log files given
Try 'logsearch.sh -h' for more information.
exit=2
logsearch.sh: cannot read 'nope.log'
Try 'logsearch.sh -h' for more information.
exit=2
```

And help, which goes to stdout with exit 0:

```bash
./logsearch.sh -h; echo "exit=$?"
```

```text
Usage: logsearch.sh [-l LEVEL] [-n MAX] [-i] [-v] [-h] FILE...

Show lines at LEVEL from each FILE.

Options:
  -l LEVEL   DEBUG, INFO, WARN, or ERROR (default: ERROR)
  -n MAX     show at most MAX matching lines per file (default: all)
  -i         match the level case-insensitively
  -v         verbose: print which file is being searched
  -h         show this help and exit

Example:
  logsearch.sh -l WARN -n 20 /var/log/app/*.log
exit=0
```

Design notes:

- `grep_opts` is an **array** of options built up conditionally (Chapter 2). It's expanded with `"${grep_opts[@]}"`, so each option stays a separate word.
- `--` before the pattern protects against patterns that start with a dash.
- `|| true` after `grep`: "no match in this file" (status 1) is normal here and must not trigger `set -e`.
- Spaces around `" $level "` stop `INFO` from matching a message like `INFORMATION`.

### Long options by hand

```bash
#!/usr/bin/env bash
# longopts.sh - parse short AND long options by hand with while/case.
set -euo pipefail

die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit 2; }

level=ERROR max=0 ignore_case=0 verbose=0 output=""

while (( $# > 0 )); do
    case $1 in
        -l|--level)
            (( $# >= 2 )) || die "$1 requires an argument"
            level=$2; shift 2 ;;
        --level=*)
            level=${1#*=}; shift ;;
        -n|--max)
            (( $# >= 2 )) || die "$1 requires an argument"
            max=$2; shift 2 ;;
        --max=*)
            max=${1#*=}; shift ;;
        -o|--output)
            (( $# >= 2 )) || die "$1 requires an argument"
            output=$2; shift 2 ;;
        --output=*)
            output=${1#*=}; shift ;;
        -i|--ignore-case)
            ignore_case=1; shift ;;
        -v|--verbose)
            verbose=1; shift ;;
        -h|--help)
            echo "usage: ${0##*/} [--level L] [--max N] [--output F] [-i] [-v] FILE..."
            exit 0 ;;
        --)
            shift; break ;;            # everything after -- is a file
        -?*)
            die "unknown option: $1" ;;
        *)
            break ;;                   # first non-option: stop parsing
    esac
done

echo "level=$level max=$max output=${output:-<stdout>} ignore_case=$ignore_case verbose=$verbose"
echo "files ($#): $*"
```

```bash
./longopts.sh --level WARN --max=5 -v app.log app2.log
./longopts.sh -l INFO --output=report.txt --ignore-case -- -weird-name.log
./longopts.sh --max; echo "exit=$?"
./longopts.sh --colour app.log; echo "exit=$?"
./longopts.sh -iv app.log; echo "exit=$?"
```

```text
level=WARN max=5 output=<stdout> ignore_case=0 verbose=1
files (2): app.log app2.log
level=INFO max=0 output=report.txt ignore_case=1 verbose=0
files (1): -weird-name.log
longopts.sh: --max requires an argument
exit=2
longopts.sh: unknown option: --colour
exit=2
longopts.sh: unknown option: -iv
exit=2
```

Both `--max=5` and `--level WARN` forms work, and `--` protected a file name beginning with a dash. The last line shows the limitation: bundled short flags aren't supported by this simple loop. That's a fair trade for a short script. Document it in `usage`.

For comparison, `getopt` (util-linux) normalizes everything for you. Save this as `gnu-getopt.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
parsed=$(getopt -o l:n:iv --long level:,max:,ignore-case,verbose -n "${0##*/}" -- "$@") || exit 2
eval set -- "$parsed"
echo "normalized: $*"
```

```bash
./gnu-getopt.sh -vi --level=WARN app.log -n 3
```

```text
normalized: -v -i --level WARN -n 3 -- app.log
```

The bundle was split, `--level=WARN` became two words, the option after the operand was moved forward, and `--` was inserted before the operands. A simple `case` loop can then process the result. The `eval` is safe here only because `getopt` quotes its output for exactly this purpose.

### Config file plus environment plus options

A layered settings loader that **parses** the config file instead of sourcing it:

```bash
#!/usr/bin/env bash
# config-demo.sh - layered settings: defaults < config file < env < options
set -euo pipefail

# 1. Built-in defaults
level=ERROR
max=0

# 2. Config file (KEY=value lines), parsed, never sourced
load_config() {
    local file=$1 key value lineno=0
    [[ -r $file ]] || return 0               # a missing config file is fine
    while IFS='=' read -r key value || [[ -n $key ]]; do
        (( ++lineno ))
        key=${key//[[:space:]]/}             # strip all whitespace from the key
        value=${value#"${value%%[![:space:]]*}"}   # trim leading spaces
        value=${value%"${value##*[![:space:]]}"}   # trim trailing spaces
        [[ -z $key || $key == \#* ]] && continue   # blank line or comment
        case $key in
            level) level=$value ;;
            max)   max=$value ;;
            *) echo "warning: $file:$lineno: unknown key '$key' ignored" >&2 ;;
        esac
    done < "$file"
}
load_config "${LOGSEARCH_CONFIG:-$HOME/.config/logsearch.conf}"

# 3. Environment variables override the config file
level=${LOGSEARCH_LEVEL:-$level}
max=${LOGSEARCH_MAX:-$max}

# 4. Command-line options override everything
while getopts ":l:n:" opt; do
    case $opt in
        l) level=$OPTARG ;;
        n) max=$OPTARG ;;
        *) echo "usage: ${0##*/} [-l LEVEL] [-n MAX]" >&2; exit 2 ;;
    esac
done

echo "level=$level max=$max"
```

A config file with a comment, extra spaces, an unknown key, and a malicious line:

```ini
# logsearch.conf - defaults for logsearch
level = WARN
max=50
# unknown keys are rejected
colour = always
output=$(rm -rf ~)
```

```bash
./config-demo.sh
LOGSEARCH_CONFIG=logsearch.conf ./config-demo.sh
LOGSEARCH_CONFIG=logsearch.conf LOGSEARCH_LEVEL=INFO ./config-demo.sh 2>/dev/null
LOGSEARCH_CONFIG=logsearch.conf LOGSEARCH_LEVEL=INFO ./config-demo.sh -l DEBUG -n 5 2>/dev/null
```

```text
level=ERROR max=0
warning: logsearch.conf:5: unknown key 'colour' ignored
warning: logsearch.conf:6: unknown key 'output' ignored
level=WARN max=50
level=INFO max=50
level=DEBUG max=5
```

Each layer overrode the previous one. The `$(rm -rf ~)` line was just text to the parser, so it was rejected as an unknown key and never executed. Had the script used `source logsearch.conf`, it would have run.

The two trimming lines are worth understanding. `${value%%[![:space:]]*}` is "everything from the first non-space character onward, removed," which leaves just the leading spaces. The outer `${value#"..."}` then strips exactly those spaces from the front. The trailing-space line mirrors it. That's pure bash, with no `sed` call per line.

## Exercises

### Exercise 1: Greet with options (easy)

Write `greet.sh` with `-n NAME` (default: `$USER`), `-u` (uppercase the greeting), and `-h` (help). Use `getopts` in silent mode. Reject unknown options, a missing `-n` value, and any leftover operands with exit status 2.

??? success "Solution"

    ```bash
    #!/usr/bin/env bash
    # greet.sh - greet someone, politely or loudly.
    set -euo pipefail

    usage() {
        echo "Usage: ${0##*/} [-n NAME] [-u] [-h]"
        echo "  -n NAME  who to greet (default: \$USER)"
        echo "  -u       SHOUT (uppercase)"
        echo "  -h       show this help"
    }

    name=${USER:-friend}
    upper=0
    while getopts ":n:uh" opt; do
        case $opt in
            n) name=$OPTARG ;;
            u) upper=1 ;;
            h) usage; exit 0 ;;
            :) echo "error: -$OPTARG needs a value" >&2; usage >&2; exit 2 ;;
            \?) echo "error: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
        esac
    done
    shift $((OPTIND - 1))
    (( $# == 0 )) || { echo "error: unexpected argument '$1'" >&2; exit 2; }

    msg="Hello, $name!"
    (( upper )) && msg=${msg^^}
    echo "$msg"
    ```

    ```bash
    ./greet.sh; ./greet.sh -n Sam -u; ./greet.sh -un Kim
    ./greet.sh extra; echo "exit=$?"
    ```

    ```text
    Hello, alex!
    HELLO, SAM!
    HELLO, KIM!
    error: unexpected argument 'extra'
    exit=2
    ```

    `-un Kim` works because `getopts` handles bundles. `${msg^^}` uppercases in pure bash.

### Exercise 2: Sum with shift (easy)

Write `sum.sh INT...` that adds up all its arguments using a `while (( $# > 0 ))` / `shift` loop. Reject anything that isn't an integer (negative numbers allowed). Make sure `08` counts as 8, not as an octal error.

??? success "Solution"

    ```bash
    #!/usr/bin/env bash
    # sum.sh - add up integer arguments.
    set -euo pipefail
    (( $# > 0 )) || { echo "usage: ${0##*/} INT..." >&2; exit 2; }
    total=0
    while (( $# > 0 )); do
        n=$1
        [[ $n =~ ^-?[0-9]+$ ]] || { echo "not an integer: '$n'" >&2; exit 2; }
        if [[ $n == -* ]]; then
            n=$(( -10#${n#-} ))      # 10# forces base 10, so "08" is 8, not octal
        else
            n=$(( 10#$n ))
        fi
        total=$(( total + n ))
        shift
    done
    echo "$total"
    ```

    ```bash
    ./sum.sh 1 2 3; ./sum.sh 10 -4 08; ./sum.sh 1 x; echo "exit=$?"
    ```

    ```text
    6
    14
    not an integer: 'x'
    exit=2
    ```

    `10#` must come right before the digits, so the sign is handled separately.

### Exercise 3: Extend `logsearch.sh` (medium)

Add two options to the complete `logsearch.sh` example: `-c` prints only a count of matching lines per file (as `file:count`), and `-o OUTPUT` writes results to a file instead of stdout. Validate that OUTPUT isn't a directory and can be written. Update `usage`.

??? success "Solution"

    The changes:

    ```text
    # usage line and option list
    Usage: $PROG [-l LEVEL] [-n MAX] [-i] [-c] [-o OUTPUT] [-v] [-h] FILE...
      -c         print only a count of matching lines per file
      -o OUTPUT  write results to OUTPUT instead of standard output

    # defaults
    count_only=0
    output=""

    # optstring and case branches
    while getopts ":l:n:icvo:h" opt; do
            c) count_only=1 ;;
            o) output=$OPTARG ;;

    # validation, after the file checks
    if [[ -n $output ]]; then
        [[ -d $output ]] && die "-o: '$output' is a directory"
        exec > "$output" || die "-o: cannot write '$output'"
    fi

    # building grep options
    (( count_only )) && grep_opts+=(-c -H)
    ```

    ```bash
    ./logsearch.sh -c -i app.log app2.log
    ./logsearch.sh -l WARN -o warn.txt app.log && cat warn.txt
    ./logsearch.sh -o . app.log; echo "exit=$?"
    ```

    ```text
    app.log:3
    app2.log:3
    2026-10-01 10:00:09 WARN  api: slow request /orders 2.1s
    logsearch.sh: -o: '.' is a directory
    Try 'logsearch.sh -h' for more information.
    exit=2
    ```

    `exec > "$output"` with no command redirects the *rest of the script's* stdout to the file. Stderr, where errors and `-v` headers go, still reaches the terminal. `grep -c -H` prints `file:count`.

### Exercise 4: Long options for `greet.sh` (medium)

Rewrite Exercise 1's parsing as a `while`/`case` loop so it also accepts `--name NAME`, `--name=NAME`, `--upper`, and `--help`, and treats `--` as end of options. A missing value must produce a clear error, not an "unbound variable" crash.

??? success "Solution"

    ```bash
    #!/usr/bin/env bash
    # greet-long.sh - greet.sh with long options too.
    set -euo pipefail

    usage() {
        echo "Usage: ${0##*/} [-n|--name NAME] [-u|--upper] [-h|--help]"
    }
    bad() { echo "error: $*" >&2; usage >&2; exit 2; }

    name=${USER:-friend}
    upper=0
    while (( $# > 0 )); do
        case $1 in
            -n|--name)
                (( $# >= 2 )) || bad "$1 needs a value"
                name=$2; shift 2 ;;
            --name=*)
                name=${1#*=}; shift ;;
            -u|--upper)
                upper=1; shift ;;
            -h|--help)
                usage; exit 0 ;;
            --)
                shift; break ;;
            -*)
                bad "unknown option $1" ;;
            *)
                break ;;
        esac
    done
    (( $# == 0 )) || bad "unexpected argument '$1'"

    msg="Hello, $name!"
    (( upper )) && msg=${msg^^}
    echo "$msg"
    ```

    ```bash
    ./greet-long.sh --name "Alex Doe"
    ./greet-long.sh --name=Sam --upper
    ./greet-long.sh --name; echo "exit=$?"
    ```

    ```text
    Hello, Alex Doe!
    HELLO, SAM!
    error: --name needs a value
    Usage: greet-long.sh [-n|--name NAME] [-u|--upper] [-h|--help]
    exit=2
    ```

    The `(( $# >= 2 ))` check runs before `$2` is touched, so `set -u` never fires.

### Exercise 5: Project skeleton generator (hard)

Write `mkproject.sh [-t TYPE] [-d DIR] [-f] [-n] [-h] NAME` that creates `DIR/NAME/` with a `README.md`, a `tests/` folder, and a starter script (`NAME.sh` for type `bash`, or `NAME.py` with dashes turned into underscores for type `python`). Validate: exactly one NAME matching `^[a-z][a-z0-9_-]*$`; TYPE is bash or python; DIR is a writable directory; refuse if `DIR/NAME` exists unless `-f` (and even then, never overwrite existing files). `-n` is a dry run that prints what would be created.

??? success "Solution"

    ```bash
    #!/usr/bin/env bash
    #
    # mkproject.sh - create a small project skeleton.
    #
    set -euo pipefail

    readonly PROG=${0##*/}

    usage() {
        cat <<USAGE
    Usage: $PROG [-t TYPE] [-d DIR] [-f] [-n] [-h] NAME

    Create DIR/NAME with a starter layout.

      -t TYPE  bash or python (default: bash)
      -d DIR   parent directory (default: current directory)
      -f       allow NAME to exist already (files are not overwritten)
      -n       dry run: show what would be created
      -h       show this help
    USAGE
    }
    die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 2; }

    type=bash parent=. force=0 dry_run=0
    while getopts ":t:d:fnh" opt; do
        case $opt in
            t) type=$OPTARG ;;
            d) parent=$OPTARG ;;
            f) force=1 ;;
            n) dry_run=1 ;;
            h) usage; exit 0 ;;
            :) die "-$OPTARG requires an argument" ;;
            \?) die "unknown option -$OPTARG" ;;
        esac
    done
    shift $((OPTIND - 1))

    (( $# == 1 )) || { usage >&2; exit 2; }
    name=$1
    [[ $name =~ ^[a-z][a-z0-9_-]*$ ]] || die "invalid name '$name' (lowercase letters, digits, - and _)"
    case $type in bash|python) ;; *) die "unknown type '$type'" ;; esac
    [[ -d $parent && -w $parent ]] || die "parent '$parent' is not a writable directory"
    target=$parent/$name
    if [[ -e $target ]] && (( ! force )); then
        die "'$target' already exists (use -f to add missing files)"
    fi

    run() {
        if (( dry_run )); then printf 'would: %s\n' "$*"; else "$@"; fi
    }
    # write_file PATH CONTENT - create PATH unless it already exists
    write_file() {
        if [[ -e $1 ]]; then echo "skip: $1 exists"; return 0; fi
        if (( dry_run )); then echo "would: write $1"; else printf '%s\n' "$2" > "$1"; fi
    }

    run mkdir -p -- "$target/tests"
    write_file "$target/README.md" "# $name"
    case $type in
        bash)   write_file "$target/$name.sh" $'#!/usr/bin/env bash\nset -euo pipefail' ;;
        python) write_file "$target/${name//-/_}.py" $'def main():\n    pass\n\nif __name__ == "__main__":\n    main()' ;;
    esac
    echo "done: $target ($type)"
    ```

    ```bash
    ./mkproject.sh -n -t python etl-jobs
    ./mkproject.sh -t python etl-jobs && find etl-jobs | sort
    ./mkproject.sh etl-jobs; echo "exit=$?"
    ./mkproject.sh -f -t python etl-jobs
    ./mkproject.sh "Bad Name"; echo "exit=$?"
    ```

    ```text
    would: mkdir -p -- ./etl-jobs/tests
    would: write ./etl-jobs/README.md
    would: write ./etl-jobs/etl_jobs.py
    done: ./etl-jobs (python)
    done: ./etl-jobs (python)
    etl-jobs
    etl-jobs/etl_jobs.py
    etl-jobs/README.md
    etl-jobs/tests
    mkproject.sh: './etl-jobs' already exists (use -f to add missing files)
    exit=2
    skip: ./etl-jobs/README.md exists
    skip: ./etl-jobs/etl_jobs.py exists
    done: ./etl-jobs (python)
    mkproject.sh: invalid name 'Bad Name' (lowercase letters, digits, - and _)
    exit=2
    ```

    All validation happens before the first `mkdir`. The name regex also blocks path tricks like `../x` or `/etc`. `$'...'` (ANSI-C quoting) puts real newlines into the file contents.

## Check yourself

1. What's the difference between `$10` and `${10}`?

    ??? note "Answer"

        `$10` is `$1` followed by a literal `0`. `${10}` is the tenth positional parameter. Braces are required for parameters above 9.

2. In the optstring `":a:bc:"`, what does each colon mean?

    ??? note "Answer"

        The leading colon selects silent error mode. The colon after `a` means `-a` takes an argument, and likewise after `c`. `-b` is a flag with no argument.

3. After the `getopts` loop, why do you run `shift $((OPTIND - 1))`?

    ??? note "Answer"

        `OPTIND` is the index of the first argument `getopts` didn't consume, the first operand. Shifting by `OPTIND - 1` removes all parsed options, so `"$@"` holds just the operands, starting at `$1`.

4. In silent mode, how do you tell "unknown option" from "missing argument," and which option caused it?

    ??? note "Answer"

        Unknown option: `opt` is `?` and `OPTARG` holds the unknown letter. Missing argument: `opt` is `:` and `OPTARG` holds the option letter that needed a value. Match `?` as `\?)` in `case`, since a bare `?` is a glob that matches any single character.

5. Why should `-h` exit 0 and print to stdout, while a bad option exits 2 and prints to stderr?

    ??? note "Answer"

        Asking for help is a successful request; its output is the result, which a user may pipe into `less`. A bad option is a usage error: the message is a diagnostic (stderr) and the non-zero status tells callers and scripts the command didn't run.

6. Why validate `-n` with a regex instead of just using `(( n > 0 ))`?

    ??? note "Answer"

        Arithmetic treats non-numeric words as variable names (often 0), so bad input is silently accepted with a wrong value, and arithmetic evaluation of untrusted text can even run commands in some contexts. A regex check rejects anything that isn't digits before any arithmetic happens.

7. What precedence order should defaults, config files, environment variables, and command-line options follow, and why?

    ??? note "Answer"

        Defaults < system config < user config < environment variables < command-line options. Each layer is more specific and more deliberate than the one before, so the most explicit choice (what you typed for this run) wins.

8. Why is `source config.conf` dangerous, and what's the alternative?

    ??? note "Answer"

        `source` executes the file as bash, so any command in it (like `$(rm -rf ~)`) runs with the script's privileges. Parse the file instead: read `KEY=value` lines with `while IFS='=' read -r key value`, skip comments, and accept only known keys via `case`.

## Key takeaways

- `$1`...`$9`, `${10}`, `$#`, and `"$@"` hold the arguments. `shift` consumes them. `${0##*/}` names the script, and `${BASH_SOURCE[0]}` locates it.
- Use `getopts` in silent mode (`":..."`), with `:)` and `\?)` branches and `shift $((OPTIND - 1))` afterward.
- For long options, loop over `$1` with `case`, handle both `--opt value` and `--opt=value`, and check `$#` before reading `$2`.
- Set defaults first, parse second, validate everything third, and only then do the work.
- `-h` prints usage to stdout and exits 0. Usage errors go to stderr with exit 2 and a hint.
- Use environment variables and parsed (never sourced) config files for settings that rarely change. The command line always wins.

## Next

Continue with [Bash or Python?](06-bash-vs-python.md), where you'll learn when a script has outgrown bash and how to move it to Python.
