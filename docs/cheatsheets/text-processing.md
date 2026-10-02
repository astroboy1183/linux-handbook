# Text Processing Cheat Sheet

Quick reference for searching, slicing, transforming, and summarizing text
with pipelines. Chapters:
[Pipes and redirection](../chapters/01-command-line/04-pipes-and-redirection.md),
[Text processing](../chapters/01-command-line/05-text-processing.md).

The examples use a web server log, `access.log`:

```text
192.168.1.10 - - [02/Oct/2026:09:14:01 +0000] "GET /index.html HTTP/1.1" 200 512
192.168.1.11 - - [02/Oct/2026:09:15:22 +0000] "GET /api/users HTTP/1.1" 500 87
10.0.0.5 - - [02/Oct/2026:10:22:47 +0000] "GET /missing HTTP/1.1" 404 0
```

Split on spaces, field `$1` is the IP, `$4` the timestamp, `$7` the path,
`$9` the status code, and `$10` the response size.

## grep: find lines

| Command | What it does |
|---|---|
| `grep 'error' app.log` | Lines containing `error` |
| `grep -i 'error' app.log` | Case-insensitive |
| `grep -v 'DEBUG' app.log` | Lines that do **not** match |
| `grep -c ' 500 ' access.log` | Count matching lines |
| `grep -n 'TODO' *.py` | Show line numbers |
| `grep -w 'id' file` | Whole words only (not `width`) |
| `grep -o 'user=[a-z]*' app.log` | Print only the matched part |
| `grep -E '(GET|POST) /api' access.log` | Extended regex: `+`, `?`, `|`, `()`, `{}` work unescaped |
| `grep -F '[ERROR]' app.log` | Fixed string: no regex, brackets are literal |
| `grep -P '\d{3} \d+$' access.log` | Perl regex (`\d`, lookarounds) |
| `grep -r 'api_key' ~/projects` | Search recursively |
| `grep -rl 'api_key' .` | Only list matching file names |
| `grep -r --include='*.py' 'import os' .` | Recurse, only in matching files |
| `grep -A 3 -B 1 'Traceback' app.log` | 3 lines after, 1 before each match (`-C 2`: both) |
| `grep -q 'ok' f && echo yes` | Quiet: exit status only, for scripts |
| `grep -e '-v' file` | Pattern starting with `-` |

## cut, sort, uniq, wc, head, tail

| Command | What it does |
|---|---|
| `cut -d, -f2 data.csv` | Field 2, comma-delimited |
| `cut -d, -f1,3 data.csv` | Fields 1 and 3 |
| `cut -d: -f1 /etc/passwd` | All usernames |
| `cut -c1-10 file` | Characters 1–10 of each line |
| `sort file` | Sort alphabetically |
| `sort -n` / `sort -h` | Numeric / human sizes (`2K`, `1G`) |
| `sort -r` | Reverse |
| `sort -u` | Sort and drop duplicates |
| `sort -t, -k3,3n data.csv` | By field 3 only, numeric, comma-separated |
| `sort -k2,2 -k1,1n` | By field 2, then field 1 numerically |
| `uniq` | Collapse **adjacent** duplicate lines (sort first) |
| `uniq -c` | Prefix each line with its count |
| `uniq -d` / `uniq -u` | Only duplicated / only unique lines |
| `wc -l` / `-w` / `-c` | Count lines / words / bytes |
| `head -n 5` / `tail -n 5` | First / last 5 lines |
| `tail -n +2` | From line 2 onward (skip header) |
| `tail -f app.log` | Follow new lines |

## tr: translate characters

| Command | What it does |
|---|---|
| `tr 'a-z' 'A-Z'` | Uppercase |
| `tr -d '\r'` | Delete carriage returns (fix Windows line endings) |
| `tr -s ' '` | Squeeze runs of spaces into one |
| `tr ',' '\t'` | Commas to tabs |
| `tr -dc '[:alnum:]\n'` | Delete everything except letters, digits, newlines |
| `tr '\n' ' '` | Join all lines into one |

## sed: stream editor

| Command | What it does |
|---|---|
| `sed 's/old/new/' f` | Replace the first match on each line |
| `sed 's/old/new/g' f` | Replace all matches |
| `sed 's/old/new/gI' f` | All matches, case-insensitive (GNU) |
| `sed 's#/usr/local#/opt#g' f` | Use another delimiter for paths |
| `sed -E 's/([0-9]+)-([0-9]+)/\2-\1/' f` | Extended regex with capture groups |
| `sed -n '10,20p' f` | Print only lines 10–20 |
| `sed -n '/START/,/END/p' f` | Print from a START line to an END line |
| `sed '/^#/d' f` | Delete comment lines |
| `sed '/^\s*$/d' f` | Delete blank lines |
| `sed 's/[[:space:]]*$//' f` | Strip trailing whitespace |
| `sed '1d' f` | Delete the first line (header) |
| `sed '3i\new line' f` | Insert a line before line 3 |
| `sed '/pattern/a\new line' f` | Append a line after each match |
| `sed -i 's/8080/9090/' app.conf` | Edit the file **in place** |
| `sed -i.bak 's/8080/9090/' app.conf` | In place, keeping `app.conf.bak` |

!!! tip "Preview before `-i`"
    Run the `sed` command without `-i` first and check the output (or pipe it
    to `diff -u app.conf -`). Then add `-i`.

## awk: fields and calculations

awk splits each line into fields `$1`, `$2`, … (`$0` is the whole line,
`$NF` the last field). `NR` is the line number, `NF` the number of fields.
The pattern `{ action }` runs the action on lines matching the pattern.

| Command | What it does |
|---|---|
| `awk '{print $1}' access.log` | Print field 1 |
| `awk '{print $1, $9}' access.log` | Fields 1 and 9, space-separated |
| `awk -F, '{print $2}' data.csv` | Set the input separator |
| `awk -F, -v OFS='\t' '{print $1,$3}' data.csv` | Set the output separator |
| `awk '$9 >= 500' access.log` | Lines where field 9 ≥ 500 |
| `awk '$9 == 404 {print $7}' access.log` | Paths that returned 404 |
| `awk '/ERROR/ {n++} END {print n}' app.log` | Count matching lines |
| `awk '{s += $10} END {print s}' access.log` | Sum a column |
| `awk '{s += $1} END {print s/NR}' nums.txt` | Average |
| `awk 'NR > 1' data.csv` | Skip the header |
| `awk 'length > 120' file` | Lines longer than 120 characters |
| `awk '{print NR": "$0}' file` | Number the lines |
| `awk -F, '{sum[$2] += $3} END {for (k in sum) print k, sum[k]}' data.csv` | Group by column 2, sum column 3 |
| `awk '!seen[$0]++' file` | Remove duplicates, keeping order (no sort needed) |
| `awk '{printf "%-15s %6d\n", $1, $10}' access.log` | Formatted columns |

## xargs: turn input into arguments

| Command | What it does |
|---|---|
| `find . -name '*.tmp' | xargs rm` | Run `rm` with the found names as arguments |
| `find . -name '*.tmp' -print0 | xargs -0 rm` | Safe with spaces and newlines in names |
| `cat urls.txt | xargs -n 1 curl -sO` | One argument per command |
| `ls *.csv | xargs -I{} cp {} {}.bak` | Place the argument anywhere with `{}` |
| `cat hosts.txt | xargs -P 4 -I{} ping -c1 {}` | Run 4 in parallel |
| `xargs -r` | Don't run at all if input is empty |

## Other handy tools

| Command | What it does |
|---|---|
| `paste -d, a.txt b.txt` | Join files side by side |
| `paste -sd, file` | Join all lines with commas |
| `column -t -s, data.csv` | Align a CSV into columns |
| `comm -12 a.txt b.txt` | Lines in both sorted files (`-23`: only in a) |
| `diff -u a b` | Unified diff |
| `tee out.txt` | Write to a file **and** pass along the pipe |
| `nl -ba file` | Number all lines |
| `tac file` | Print lines in reverse order |
| `rev` | Reverse each line's characters |
| `split -l 100000 big.csv part_` | Split into 100,000-line chunks |

## Regular expression quick reference

**BRE** (basic) is the default for `grep` and `sed`. **ERE** (extended) is
enabled with `grep -E` or `sed -E`, and is what you usually want.

| Pattern | Matches | BRE form (if different) |
|---|---|---|
| `.` | Any single character | |
| `^` / `$` | Start / end of line | |
| `[abc]` | One of a, b, c | |
| `[^abc]` | Any character except a, b, c | |
| `[a-z0-9]` | A range | |
| `*` | Previous item 0 or more times | |
| `+` | 1 or more | `\+` |
| `?` | 0 or 1 | `\?` |
| `{3}` / `{2,5}` / `{2,}` | Exactly 3 / 2 to 5 / 2 or more | `\{3\}` |
| `(abc)` | Group (and capture, for `\1` in sed) | `\(abc\)` |
| `a|b` | a or b | `a\|b` (GNU) |
| `\.` | A literal dot (escape special characters) | |
| `\b` / `\<` `\>` | Word boundary / word start, end (GNU) | |
| `\s` / `\S` | Whitespace / non-whitespace (GNU) | |
| `\w` / `\W` | Word character `[A-Za-z0-9_]` / not (GNU) | |
| `\d` | A digit: **only** with `grep -P`. Use `[0-9]` elsewhere | |

| POSIX class | Same as |
|---|---|
| `[[:digit:]]` | `[0-9]` |
| `[[:alpha:]]` | Letters |
| `[[:alnum:]]` | Letters and digits |
| `[[:space:]]` | Space, tab, newline, and other whitespace |
| `[[:upper:]]` / `[[:lower:]]` | Upper / lower case |
| `[[:punct:]]` | Punctuation |

!!! warning "Common mistake: quoting"
    Always put regexes in **single quotes**. Without quotes, the shell
    expands `*`, `?`, `[...]`, and `$` before `grep` ever sees them.

## jq: JSON basics

```json
{"users":[{"name":"ana","age":31,"tags":["admin","dev"]},{"name":"bo","age":25,"tags":[]}],"count":2}
```

| Command | Output |
|---|---|
| `jq . users.json` | Pretty-printed JSON |
| `jq '.count' users.json` | `2` |
| `jq '.users[0].name' users.json` | `"ana"` |
| `jq -r '.users[].name' users.json` | `ana` and `bo` on separate lines (`-r`: raw, no quotes) |
| `jq '.users | length' users.json` | `2` |
| `jq '.users[] | select(.age > 30) | .name' users.json` | `"ana"` |
| `jq -r '.users[] | [.name, .age] | @csv' users.json` | `"ana",31` |
| `jq -r '.users[] | "\(.name)\t\(.age)"' users.json` | Tab-separated text |
| `jq -c '.users | map({name, age})' users.json` | Compact output (`-c`), new objects |
| `jq '[.users[].age] | add' users.json` | `56` |
| `jq '.users | sort_by(.age) | .[0].name' users.json` | `"bo"` |
| `jq 'keys' users.json` | `["count", "users"]` |
| `jq -n --arg u alex '{user: $u}'` | Build JSON safely from shell variables |
| `curl -s https://api.github.com/repos/torvalds/linux | jq '.stargazers_count'` | Query an API |

## 15 classic one-liners

```bash
# 1. Top 10 client IPs in a web log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -n 10

# 2. Count of each HTTP status code
awk '{print $9}' access.log | sort | uniq -c | sort -rn

# 3. Requests per hour
awk '{split($4, t, ":"); print t[2]}' access.log | sort | uniq -c

# 4. All 5xx errors
awk '$9 >= 500' access.log

# 5. Most requested paths
awk '{print $7}' access.log | sort | uniq -c | sort -rn | head

# 6. Total bytes served
awk '{s += $10} END {print s}' access.log

# 7. Unique IPv4 addresses anywhere in a file
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' access.log | sort -u

# 8. Ten most common words in a text
tr -cs '[:alpha:]' '\n' < book.txt | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn | head

# 9. Strip comments and blank lines from a config file
grep -vE '^\s*(#|$)' /etc/ssh/sshd_config

# 10. Count rows per value of CSV column 2 (skipping the header)
tail -n +2 data.csv | cut -d, -f2 | sort | uniq -c | sort -rn

# 11. Remove duplicate lines but keep the original order
awk '!seen[$0]++' list.txt

# 12. Find which files contain a string, then count matches per file
grep -rc 'TODO' --include='*.py' . | grep -v ':0$' | sort -t: -k2,2nr

# 13. Replace a string in every matching file (preview first without -i)
grep -rl 'old.example.com' conf/ | xargs sed -i 's/old\.example\.com/new.example.com/g'

# 14. Lines in a.txt that are not in b.txt
comm -23 <(sort a.txt) <(sort b.txt)

# 15. Watch the error count in a log, refreshed every 5 seconds
watch -n 5 "grep -c ERROR /var/log/app.log"
```
