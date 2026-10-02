# Text processing

> **Level 1 · Chapter 5** · ⏱️ ~60 min read · Prerequisites: [Pipes and redirection](04-pipes-and-redirection.md), [Globbing and expansion](02-globbing-and-expansion.md)

Linux stores logs, configs, and data exports as plain text, and ships a toolbox for slicing it: `grep` to select lines, `cut` and `awk` to pick fields, `sort` and `uniq` to count, `tr` and `sed` to transform, and `xargs` to turn text into commands. This chapter teaches each tool in depth, plus regular expressions, using a web server log and a CSV file as running examples.

## Why it matters

At 9:05 on Monday, Alex's manager asks: "The shop felt slow last night. Were there errors? Which endpoints? How many customers were hit?"

The access log on the web server is 2 GB. The server has no spreadsheet, no notebook, and nobody wants to copy 2 GB to a laptop. Alex connects over SSH and types:

```bash
awk '$9 >= 500 {print $7}' access.log | sort | uniq -c | sort -rn | head
```

```text
    417 /api/orders
     95 /api/cart
     12 /api/products
```

Four seconds later, Alex knows that server errors hit three API endpoints, mostly `/api/orders`. Two more one-liners give the time window and the number of distinct customers affected. The answer goes back before the stand-up meeting starts.

None of these tools is impressive on its own. `sort` sorts. `uniq` collapses repeated lines. The power comes from knowing each one well enough to snap them together without thinking. That fluency is what this chapter builds, and it is what the [Level 1 capstone](../../exercises/level-1-capstone.md) tests.

## Concepts

### Text as a universal interface

Most Unix tools agree on a simple data model:

- A **record** is a line, ending in a newline character.
- A **field** is a piece of a line, separated from the next by a **delimiter**: a comma in CSV, a tab in TSV, a colon in `/etc/passwd`, whitespace in most logs.

Because every tool reads and writes lines, any tool's output can be any other tool's input. A tool that reads text from stdin (or from files named as arguments), transforms it, and writes text to stdout is called a **filter**. `grep`, `sort`, `uniq`, `cut`, `tr`, `sed`, and `awk` are all filters.

A typical pipeline narrows the data step by step:

```mermaid
flowchart LR
    A["access.log<br/>all lines"] -->|"grep ' 404 '"| B["only 404 lines"]
    B -->|"awk '{print $7}'"| C["only the paths"]
    C -->|sort| D["paths, grouped"]
    D -->|"uniq -c"| E["count per path"]
    E -->|"sort -rn"| F["biggest first"]
    F -->|head| G["top 10"]
```

Build pipelines one stage at a time. Run the first command, look at the output, add the next stage, look again. Add `| head` while you experiment so you do not flood your terminal.

### Which tool for which job

| Job | Tool | Example |
|---|---|---|
| Keep or drop lines matching a pattern | `grep` | `grep ' 500 ' access.log` |
| Extract columns with a simple, single-character delimiter | `cut` | `cut -d, -f3 sales.csv` |
| Order lines | `sort` | `sort -t, -k5,5n sales.csv` |
| Collapse or count adjacent duplicates | `uniq` | `sort | uniq -c` |
| Replace, delete, or squeeze single characters | `tr` | `tr ',' '\t'` |
| Count lines, words, bytes | `wc` | `wc -l` |
| Edit lines: substitute, delete, print ranges | `sed` | `sed 's/http:/https:/g'` |
| Fields plus logic: filter, compute, aggregate, format | `awk` | `awk '{sum += $10} END {print sum}'` |
| Turn lines of input into command arguments | `xargs` | `xargs -0 rm` |
| Join files side by side, or lines into one | `paste` | `paste -sd,` |
| Align columns for reading | `column` | `column -t -s,` |
| Compare sorted lists / show differences | `comm`, `diff` | `comm -12 a b` |

A rule of thumb: reach for `grep`, `cut`, `sort`, and `uniq` first; switch to `awk` as soon as you need a condition on a specific field, arithmetic, or more than one output column in a custom order.

### The running examples

**`access.log`** is in the **nginx combined log format**, the default format for the nginx and Apache web servers. Each line is one HTTP request:

```text
192.0.2.10 - - [21/Sep/2026:10:05:30 +0000] "POST /login HTTP/1.1" 401 58 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
```

| Part | Example | Meaning |
|---|---|---|
| Client IP | `192.0.2.10` | Who made the request |
| Identity, user | `- -` | Almost always `-` |
| Time | `[21/Sep/2026:10:05:30 +0000]` | When, with time zone offset |
| Request | `"POST /login HTTP/1.1"` | Method, path, protocol |
| Status | `401` | HTTP status code: 2xx OK, 3xx redirect/cached, 4xx client error, 5xx server error |
| Bytes | `58` | Size of the response body |
| Referer | `"https://shop.example.com/login"` | Page the visitor came from |
| User agent | `"Mozilla/5.0 (X11; ...) Firefox/125.0"` | Browser or bot |

When a tool splits this line on whitespace, the fields are numbered like this. Memorize `$1`, `$4`, `$7`, `$9`, and `$10`; you will use them constantly:

```text
$1           $2 $3 $4                     $5      $6     $7     $8         $9  $10 $11                               $12 ...
192.0.2.10   -  -  [21/Sep/2026:10:05:30  +0000]  "POST  /login  HTTP/1.1"  401 58  "https://shop.example.com/login"  "Mozilla/5.0 ...
```

The user agent contains spaces, so it spans a varying number of whitespace fields. You will see how to handle that with `awk -F'"'`.

**`sales.csv`** is a small export of orders, with a header line:

```text
order_id,date,region,product,qty,unit_price
1001,2026-09-01,north,laptop,1,899.00
```

### Regular expressions: a primer

A **regular expression** (regex) is a pattern that describes a set of strings. `grep`, `sed`, and `awk` all use them. Unlike globs (chapter 2), a regex matches **anywhere** in a line unless you anchor it, and its symbols mean different things.

The building blocks:

| Regex | Matches | Example | Matches in... |
|---|---|---|---|
| `abc` | The literal text | `POST` | `"POST /login` |
| `.` | Any one character | `1.99` | `1x99`, `1.99` |
| `[abc]` | One character from the set | `[45]04` | `404`, `504` |
| `[^abc]` | One character **not** in the set | `[^ ]*` | a run of non-spaces |
| `[a-z]`, `[0-9]` | One character in a range | `[0-9][0-9][0-9]` | `401` |
| `[[:digit:]]`, `[[:alpha:]]`, `[[:space:]]` | Named classes (locale-safe) | `[[:digit:]]+` | `2026` |
| `^` | Start of line | `^192` | lines **starting** with 192 |
| `$` | End of line | `\.csv$` | lines **ending** in .csv |
| `*` | Zero or more of the previous item | `ab*c` | `ac`, `abc`, `abbbc` |
| `+` | One or more of the previous item (ERE) | `[0-9]+` | `7`, `42`, `2026` |
| `?` | Zero or one of the previous item (ERE) | `https?` | `http`, `https` |
| `{n}`, `{n,m}` | Exactly n, or n to m, of the previous item (ERE) | `[0-9]{3}` | `404` |
| `(...)` | Group items into one unit (ERE) | `(ab)+` | `ab`, `abab` |
| `a|b` | Either alternative (ERE) | `GET|POST` | `GET` or `POST` |
| `\` | Make the next special character literal | `\.` | a real dot |
| `\b` or `\<`, `\>` | Word boundary (GNU extension) | `\b500\b` | `500` but not `5004` |

Three ideas cause most regex bugs:

1. **`.` is not a dot.** `192.0.2.1` matches `192x0y2z1` and `19200021`. Write `192\.0\.2\.1` when you mean dots.
2. **`*` means "zero or more of the previous item"**, not "anything". The glob `*` is the regex `.*`.
3. **Matching is greedy and leftmost.** The regex engine finds the **leftmost** position where a match can start, then extends it as far as possible. `h.*s` in `the cats chase mice` matches `he cats chas`, not `he cats`. To stop at the first `s`, exclude it: `h[^s]*s`.

#### Basic vs extended regular expressions

There are two regex dialects in the classic tools:

- **BRE** (basic regular expressions): the default for `grep` and `sed`. Only `.`, `*`, `[]`, `^`, `$`, and `\` are special. To use `+`, `?`, `{}`, `()`, and `|`, you must write them with a backslash: `\+`, `\?`, `\{3\}`, `\(...\)`, `\|`. (That backslash form is a GNU extension.)
- **ERE** (extended regular expressions): `grep -E`, `sed -E`, and always in `awk`. `+`, `?`, `{}`, `()`, and `|` are special without backslashes.

| Meaning | BRE (`grep`, `sed`) | ERE (`grep -E`, `sed -E`, `awk`) |
|---|---|---|
| One or more digits | `[0-9]\+` | `[0-9]+` |
| 500 or 502 | `50\(0\|2\)` | `50(0|2)` |
| Exactly 3 digits | `[0-9]\{3\}` | `[0-9]{3}` |
| Literal `+` | `+` | `\+` |

Use ERE (`-E`) whenever your pattern needs grouping, alternation, or repetition counts. It is easier to read. You may see `egrep` in old scripts; it means `grep -E` and is deprecated.

!!! tip "Always single-quote regexes"
    A regex is full of characters the shell cares about: `*`, `?`, `[`, `$`, `|`, `(`. Wrap every regex in single quotes so bash passes it through untouched (chapter 2).

## Commands and examples

Create the practice files. Paste this whole block:

```bash
mkdir -p ~/practice/text && cd ~/practice/text

cat > access.log <<'EOF'
192.0.2.10 - - [21/Sep/2026:09:58:02 +0000] "GET / HTTP/1.1" 200 5320 "-" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:09:58:03 +0000] "GET /static/css/main.css HTTP/1.1" 200 18342 "https://shop.example.com/" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
198.51.100.7 - - [21/Sep/2026:09:59:41 +0000] "GET /products HTTP/1.1" 200 7211 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
198.51.100.7 - - [21/Sep/2026:10:00:15 +0000] "GET /products/42 HTTP/1.1" 200 9876 "https://shop.example.com/products" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
203.0.113.5 - - [21/Sep/2026:10:02:11 +0000] "GET /wp-login.php HTTP/1.1" 404 162 "-" "Mozilla/5.0 zgrab/0.x"
203.0.113.5 - - [21/Sep/2026:10:02:12 +0000] "GET /.env HTTP/1.1" 404 162 "-" "Mozilla/5.0 zgrab/0.x"
192.0.2.10 - - [21/Sep/2026:10:05:30 +0000] "POST /login HTTP/1.1" 401 58 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:10:05:44 +0000] "POST /login HTTP/1.1" 200 412 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:10:06:02 +0000] "POST /api/cart HTTP/1.1" 200 734 "https://shop.example.com/products/42" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
198.51.100.7 - - [21/Sep/2026:10:12:09 +0000] "GET /search?q=usb+cable HTTP/1.1" 200 5004 "https://shop.example.com/" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
203.0.113.5 - - [21/Sep/2026:10:15:40 +0000] "GET /admin HTTP/1.1" 404 162 "-" "Mozilla/5.0 zgrab/0.x"
192.0.2.33 - - [21/Sep/2026:10:31:18 +0000] "GET /api/orders HTTP/1.1" 500 189 "-" "python-requests/2.31.0"
192.0.2.33 - - [21/Sep/2026:10:31:20 +0000] "GET /api/orders HTTP/1.1" 500 189 "-" "python-requests/2.31.0"
192.0.2.33 - - [21/Sep/2026:10:31:25 +0000] "GET /api/orders HTTP/1.1" 200 2245 "-" "python-requests/2.31.0"
198.51.100.7 - - [21/Sep/2026:10:47:51 +0000] "POST /api/orders HTTP/1.1" 502 157 "https://shop.example.com/cart" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
192.0.2.10 - - [21/Sep/2026:11:02:07 +0000] "GET /products/7 HTTP/1.1" 200 8455 "https://shop.example.com/products" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
198.51.100.7 - - [21/Sep/2026:11:03:33 +0000] "GET /products/42 HTTP/1.1" 304 0 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
192.0.2.33 - - [21/Sep/2026:11:04:59 +0000] "GET /api/products?page=2 HTTP/1.1" 200 1893 "-" "python-requests/2.31.0"
EOF

cat > sales.csv <<'EOF'
order_id,date,region,product,qty,unit_price
1001,2026-09-01,north,laptop,1,899.00
1002,2026-09-01,south,mouse,3,19.99
1003,2026-09-02,east,monitor,2,229.50
1004,2026-09-02,north,keyboard,1,49.00
1005,2026-09-03,west,laptop,2,899.00
1006,2026-09-03,south,monitor,1,229.50
1007,2026-09-04,east,mouse,5,19.99
1008,2026-09-04,north,webcam,1,64.00
1009,2026-09-05,west,keyboard,4,49.00
1010,2026-09-05,south,laptop,1,949.00
1011,2026-09-06,east,webcam,2,64.00
1012,2026-09-06,north,mouse,2,19.99
EOF

wc -l access.log sales.csv
```

```text
  18 access.log
  13 sales.csv
  31 total
```

The log is short so you can check every answer by eye. The [capstone](../../exercises/level-1-capstone.md) gives you a 5,000-line version.

### grep: select lines

`grep` (from the old editor command `g/re/p`: globally search for a regular expression and print) prints every line that matches a pattern:

```bash
grep 'POST' access.log
```

```text
192.0.2.10 - - [21/Sep/2026:10:05:30 +0000] "POST /login HTTP/1.1" 401 58 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:10:05:44 +0000] "POST /login HTTP/1.1" 200 412 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:10:06:02 +0000] "POST /api/cart HTTP/1.1" 200 734 "https://shop.example.com/products/42" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
198.51.100.7 - - [21/Sep/2026:10:47:51 +0000] "POST /api/orders HTTP/1.1" 502 157 "https://shop.example.com/cart" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
```

On Mint, `grep` is aliased to `grep --color=auto`, so the matched text is highlighted in your terminal.

#### Counting, inverting, ignoring case

```bash
grep -c ' 404 ' access.log
grep -i 'IPHONE' access.log | wc -l
grep -v 'zgrab' access.log | wc -l
```

```text
3
5
15
```

- `-c` (count) prints the number of matching **lines**, not the number of matches.
- `-i` (ignore case) matches `iPhone`, `IPHONE`, and `iphone`.
- `-v` (invert) prints lines that do **not** match. Here: everything except the scanner's requests.

#### Line numbers and whole words

Searching for the status `500` naively finds an extra line:

```bash
grep -n '500' access.log
```

```text
10:198.51.100.7 - - [21/Sep/2026:10:12:09 +0000] "GET /search?q=usb+cable HTTP/1.1" 200 5004 "https://shop.example.com/" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
12:192.0.2.33 - - [21/Sep/2026:10:31:18 +0000] "GET /api/orders HTTP/1.1" 500 189 "-" "python-requests/2.31.0"
13:192.0.2.33 - - [21/Sep/2026:10:31:20 +0000] "GET /api/orders HTTP/1.1" 500 189 "-" "python-requests/2.31.0"
```

`-n` prefixes each line with its line number. Line 10 matched because its byte count is `5004`. `-w` (word) only matches the pattern as a whole word, with non-word characters (anything but letters, digits, and underscore) or the line edge on both sides:

```bash
grep -c -w '500' access.log
```

```text
2
```

Even more precise is to match the field with its surrounding spaces, `' 500 '`, or to test the status field directly with `awk '$9 == 500'`, which you will see shortly.

#### Printing only the match

`-o` (only matching) prints each match on its own line, instead of the whole line. Combined with a regex, it extracts data:

```bash
grep -o '/products/[0-9]*' access.log
```

```text
/products/42
/products/42
/products/7
/products/42
```

```bash
grep -E -o '"(GET|POST) [^ ]+' access.log | sort | uniq -c | sort -rn | head -4
```

```text
      3 "GET /api/orders
      2 "POST /login
      2 "GET /products/42
      1 "POST /api/orders
```

The ERE `"(GET|POST) [^ ]+` reads: a double quote, then `GET` or `POST`, then a space, then one or more non-space characters (the path).

Here is the "leftmost match" rule biting. You want the time of each request:

```bash
grep -E -o '[0-9]{2}:[0-9]{2}:[0-9]{2}' access.log | head -2
```

```text
26:09:58
26:09:58
```

The first place where "two digits, colon, two digits, colon, two digits" can match is inside `2026:09:58:02`, starting at the `26` of the year. Anchor the pattern on something unambiguous, here the colon before the hour and the space after the seconds:

```bash
grep -E -o ':[0-9]{2}:[0-9]{2}:[0-9]{2} ' access.log | head -2
```

```text
:09:58:02 
:09:58:03 
```

#### Extended regexes and alternation

```bash
grep -E '" (4|5)[0-9]{2} ' access.log | wc -l
grep -E 'Firefox|Safari' access.log | wc -l
```

```text
7
11
```

The first counts every 4xx and 5xx response: a closing quote, a space, a 4 or 5, two more digits, a space. That is the status field and nothing else.

#### Fixed strings

`-F` (fixed strings) treats the pattern as plain text, with no regex meaning at all. It is faster, and it saves you from escaping dots, brackets, and stars:

```bash
grep -c '.' sales.csv
grep -c -F '.' sales.csv
```

```text
13
12
```

As a regex, `.` matches any character, so every non-empty line matches. As a fixed string, it matches only lines containing a real dot. The header has none.

#### Context: -A, -B, -C

When you find an error, you usually want the lines around it. `-A n` prints n lines **after** each match, `-B n` **before**, and `-C n` both:

```bash
grep -A1 ' 401 ' access.log
```

```text
192.0.2.10 - - [21/Sep/2026:10:05:30 +0000] "POST /login HTTP/1.1" 401 58 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:10:05:44 +0000] "POST /login HTTP/1.1" 200 412 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
```

A failed login followed 14 seconds later by a successful one from the same IP: a mistyped password, not an attack. In application logs, `grep -A20 'Traceback'` is the standard way to see a whole Python stack trace. When groups of context lines are not adjacent, grep separates them with a `--` line.

#### Searching many files: -r, -l, --include

`-r` (recursive) searches every file under a directory. `-l` (files with matches) prints only file names. `--include` limits the search to names matching a glob:

```bash
mkdir -p logs/2026 && cp access.log logs/2026/shop.log && echo "nothing here" > logs/notes.txt
grep -r -c 'zgrab' logs
grep -rl --include='*.log' 'zgrab' .
```

```text
logs/2026/shop.log:3
logs/notes.txt:0
./access.log
./logs/2026/shop.log
```

With several files, `grep` prefixes each line with the file name. `-h` hides the names; `-H` forces them.

#### Exit status and -q

`grep` exits with 0 if it found a match, 1 if not, and 2 on an error such as a missing file. `-q` (quiet) prints nothing, which makes `grep` a test you can use in `if` statements and with `&&`:

```bash
grep -q 'wp-login' access.log && echo "scanner detected"
```

```text
scanner detected
```

| Flag | Meaning |
|---|---|
| `-i` | Ignore case |
| `-v` | Invert: print non-matching lines |
| `-c` | Count matching lines |
| `-n` | Show line numbers |
| `-w` | Match whole words only |
| `-o` | Print only the matched part |
| `-E` | Extended regex (ERE) |
| `-F` | Fixed string, no regex |
| `-r` | Recurse into directories |
| `-l` | Print names of files with matches |
| `-A n`, `-B n`, `-C n` | Context lines after, before, both |
| `-q` | Quiet: exit status only |

### cut: select columns

`cut` extracts fields by delimiter, or characters by position. `-d` sets the delimiter (one character) and `-f` lists the fields:

```bash
cut -d, -f3,4 sales.csv | head -4
```

```text
region,product
north,laptop
south,mouse
east,monitor
```

Field lists accept ranges: `-f2-4` (fields 2 to 4), `-f3-` (field 3 to the end), `-f-2` (fields 1 and 2). The output keeps the original delimiter.

On the access log, the delimiter is a space:

```bash
cut -d' ' -f1,9 access.log | head -4
```

```text
192.0.2.10 200
192.0.2.10 200
198.51.100.7 200
198.51.100.7 200
```

`-c` selects characters by position, which suits fixed-width data. For example, the month of each order:

```bash
tail -n +2 sales.csv | cut -d, -f2 | cut -c1-7 | sort -u
```

```text
2026-09
```

!!! warning "Common mistake"
    Using `cut -d' '` on output that has **runs** of spaces, like `ls -l` or `ps`. `cut` treats every single space as a delimiter, so two spaces in a row create an empty field and the numbering shifts. Use `awk '{print $5}'`, which splits on runs of whitespace, or squeeze the spaces first with `tr -s ' '`. Likewise, `cut` does not understand CSV quoting: a field like `"Smith, John"` will be split at its comma.

### sort: order lines

`sort` sorts lines alphabetically by default, using your locale's rules:

```bash
printf '10\n9\n100\n25\n' > nums.txt
sort nums.txt
```

```text
10
100
25
9
```

That is text order: `1` sorts before `2` and `9`, character by character. `-n` (numeric) compares the numbers:

```bash
sort -n nums.txt
sort -rn nums.txt
```

```text
9
10
25
100
100
25
10
9
```

`-r` reverses the order. `-rn` (numeric, biggest first) is so common in pipelines that you will type it without thinking.

#### Sorting by a field: -t and -k

`-t` sets the field separator, and `-k` picks the **key** (the field to sort by). Write keys as `-kSTART,END`: `-k5,5` means "field 5 only". A bare `-k5` means "from field 5 to the end of the line", which is rarely what you want. Modifiers like `n` and `r` can be attached to a key:

```bash
tail -n +2 sales.csv | sort -t, -k5,5n
```

```text
1001,2026-09-01,north,laptop,1,899.00
1004,2026-09-02,north,keyboard,1,49.00
1006,2026-09-03,south,monitor,1,229.50
1008,2026-09-04,north,webcam,1,64.00
1010,2026-09-05,south,laptop,1,949.00
1003,2026-09-02,east,monitor,2,229.50
1005,2026-09-03,west,laptop,2,899.00
1011,2026-09-06,east,webcam,2,64.00
1012,2026-09-06,north,mouse,2,19.99
1002,2026-09-01,south,mouse,3,19.99
1009,2026-09-05,west,keyboard,4,49.00
1007,2026-09-04,east,mouse,5,19.99
```

`tail -n +2` dropped the header first, so it would not be sorted into the data. Lines with equal keys fall back to comparing the whole line, which is why the `qty=1` rows come out in order-ID order.

Several keys break ties in order. Sort by region alphabetically, then by quantity, biggest first:

```bash
tail -n +2 sales.csv | sort -t, -k3,3 -k5,5nr
```

```text
1007,2026-09-04,east,mouse,5,19.99
1003,2026-09-02,east,monitor,2,229.50
1011,2026-09-06,east,webcam,2,64.00
1012,2026-09-06,north,mouse,2,19.99
1001,2026-09-01,north,laptop,1,899.00
1004,2026-09-02,north,keyboard,1,49.00
1008,2026-09-04,north,webcam,1,64.00
1002,2026-09-01,south,mouse,3,19.99
1006,2026-09-03,south,monitor,1,229.50
1010,2026-09-05,south,laptop,1,949.00
1009,2026-09-05,west,keyboard,4,49.00
1005,2026-09-03,west,laptop,2,899.00
```

Without `-t`, `sort` splits fields at the transition from non-blank to blank characters, which works for space-separated output like `uniq -c`.

#### Human sizes, unique lines

`-h` (human numeric) understands size suffixes like `K`, `M`, and `G`, as printed by `du -h` and `ls -lh`:

```bash
printf '120M\tlogs\n4.0K\tnotes\n1.5G\tbackups\n980K\tphotos\n' > sizes.txt
sort -h sizes.txt
```

```text
4.0K	notes
980K	photos
120M	logs
1.5G	backups
```

With `-n`, the same file would sort `1.5G` first, because `-n` stops reading at the first non-digit and sees 1.5. `du -h ~ | sort -hr | head` is the classic "what is eating my disk?" pipeline.

`-u` (unique) outputs only the first of each run of equal lines, after sorting:

```bash
tail -n +2 sales.csv | cut -d, -f3 | sort -u
```

```text
east
north
south
west
```

| Flag | Meaning |
|---|---|
| `-n` | Numeric comparison |
| `-h` | Human sizes (`2K`, `1G`) |
| `-r` | Reverse |
| `-t c` | Field separator |
| `-k a,b` | Sort by fields a through b (add `n`, `r`, `h` per key) |
| `-u` | Output only unique lines |
| `-o file` | Write output to file, safe even if file is also the input |
| `-s` | Stable: keep the original order of equal lines |

!!! info "Locale and sort order"
    `sort` follows your language settings, which mostly ignore case and punctuation when comparing. For byte-by-byte order (fast, and identical on every machine), prefix the command with `LC_ALL=C`: `LC_ALL=C sort file`. This matters for `comm` and `join`, which require both inputs to be sorted the same way.

### uniq: collapse duplicates

`uniq` removes **adjacent** duplicate lines. It compares each line only with the line just before it. That is why it almost always follows `sort`:

```bash
cut -d' ' -f1 access.log | uniq -c
```

```text
      2 192.0.2.10
      2 198.51.100.7
      2 203.0.113.5
      3 192.0.2.10
      1 198.51.100.7
      1 203.0.113.5
      3 192.0.2.33
      1 198.51.100.7
      1 192.0.2.10
      1 198.51.100.7
      1 192.0.2.33
```

`uniq -c` (count) counted **runs**, so `192.0.2.10` appears three times. Sort first, so that identical lines become adjacent:

```bash
cut -d' ' -f1 access.log | sort | uniq -c
```

```text
      6 192.0.2.10
      4 192.0.2.33
      5 198.51.100.7
      3 203.0.113.5
```

Why does `uniq` work this way? Because it only needs to remember one line, it uses constant memory and can process an endless stream. Making the duplicates adjacent is `sort`'s job.

Other useful flags: `-d` prints only lines that are duplicated, `-u` prints only lines that occur once, and `-i` ignores case.

### The frequency-count idiom

Put the last two sections together and you have the most useful pipeline in this chapter:

```bash
cut -d' ' -f1 access.log | sort | uniq -c | sort -rn | head
```

```text
      6 192.0.2.10
      5 198.51.100.7
      4 192.0.2.33
      3 203.0.113.5
```

Read it as: extract the thing you want to count, group identical values, count each group, put the biggest counts first, keep the top ten. Swap the first stage to count anything:

```bash
cut -d' ' -f9 access.log | sort | uniq -c | sort -rn      # status codes
```

```text
     10 200
      3 404
      2 500
      1 502
      1 401
      1 304
```

You will use this idiom in nearly every question of the capstone.

### tr: translate characters

`tr` (translate) works on single **characters**, not words or fields. It reads only stdin; it never takes a file name. Its basic form maps each character in the first set to the matching character in the second:

```bash
head -n 3 sales.csv | tr ',' '\t'
```

```text
order_id	date	region	product	qty	unit_price
1001	2026-09-01	north	laptop	1	899.00
1002	2026-09-01	south	mouse	3	19.99
```

Ranges and classes work as sets:

```bash
echo "Hello World" | tr 'a-z' 'A-Z'
echo "Hello World" | tr '[:lower:]' '[:upper:]'
```

```text
HELLO WORLD
HELLO WORLD
```

Three flags cover most other uses:

- `-d` (delete) removes every character in the set. `tr -d '\r'` converts Windows line endings to Linux ones, a fix you will need for CSVs exported from Excel.
- `-s` (squeeze) collapses runs of a repeated character into one.
- `-c` (complement) inverts the set: "every character **not** listed".

```bash
echo "too    many     spaces" | tr -s ' '
echo "phone: +1 (555) 010-7788" | tr -cd '0-9\n'
echo "$PATH" | tr ':' '\n'
```

```text
too many spaces
15550107788
/home/alex/.local/bin
/usr/local/sbin
/usr/local/bin
/usr/sbin
/usr/bin
/sbin
/bin
/usr/games
/usr/local/games
/snap/bin
```

`tr -cd '0-9\n'` deletes everything except digits and newlines. Turning `:` into newlines makes `$PATH` readable, one directory per line.

### wc in pipelines

`wc -l` at the end of a pipeline answers "how many?":

```bash
grep -v '" 200 ' access.log | wc -l
cut -d' ' -f1 access.log | sort -u | wc -l
```

```text
8
4
```

Eight requests were not plain 200 responses, from four distinct IPs overall. `sort -u | wc -l` is the standard "count distinct values" pattern.

### sed: the stream editor

`sed` (stream editor) applies editing commands to each line as it streams past. It does not open the file in an editor; it reads, edits in memory, and prints. Its most used command by far is **substitute**:

```text
s/regex/replacement/flags
```

```bash
sed 's/north/NORTH/' sales.csv | head -3
```

```text
order_id,date,region,product,qty,unit_price
1001,2026-09-01,NORTH,laptop,1,899.00
1002,2026-09-01,south,mouse,3,19.99
```

`sed` printed every line, changed or not. The original file is untouched.

#### Substitution flags

By default, `s` replaces only the **first** match on each line. The `g` (global) flag replaces all of them:

```bash
echo 'aaa bbb aaa' | sed 's/aaa/x/'
echo 'aaa bbb aaa' | sed 's/aaa/x/g'
echo 'one,two,three,four' | sed 's/,/;/2'
echo 'Error ERROR error' | sed 's/error/X/Ig'
```

```text
x bbb aaa
x bbb x
one,two;three,four
X X X
```

A number replaces only that occurrence (here the second comma). `I` makes the match case-insensitive (a GNU extension).

#### Other delimiters, and & for the match

The `/` after `s` can be any character. When your pattern contains slashes, such as URLs or paths, pick another delimiter instead of escaping every `/`:

```bash
sed 's#https://shop.example.com#SHOP#g' access.log | sed -n '2p'
```

```text
192.0.2.10 - - [21/Sep/2026:09:58:03 +0000] "GET /static/css/main.css HTTP/1.1" 200 18342 "SHOP/" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
```

In the replacement, `&` stands for the whole matched text:

```bash
echo 'error: disk full' | sed 's/error/[&]/'
```

```text
[error]: disk full
```

#### Capture groups and back-references

With `-E`, parentheses capture parts of the match, and `\1`, `\2`, ... in the replacement insert them. Reorder the log's date from `21/Sep/2026:` to `2026-Sep-21 `:

```bash
sed -E 's/\[([0-9]{2})\/([A-Za-z]{3})\/([0-9]{4}):/[\3-\2-\1 /' access.log | head -1
```

```text
192.0.2.10 - - [2026-Sep-21 09:58:02 +0000] "GET / HTTP/1.1" 200 5320 "-" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
```

The regex captures the day, month, and year into groups 1, 2, and 3, and the replacement writes them back in a new order. The `[` and `/` characters are escaped because they are special (a bracket expression and the `s` delimiter).

#### Addresses: choosing which lines to edit

Any `sed` command can be prefixed with an **address** that limits it to certain lines:

| Address | Lines |
|---|---|
| `3` | Line 3 |
| `$` | The last line |
| `2,5` | Lines 2 through 5 |
| `/regex/` | Lines matching the regex |
| `/start/,/end/` | From a line matching `start` through the next line matching `end` |
| `1!` | Every line **except** line 1 (`!` negates any address) |

```bash
sed '1d' sales.csv | head -2
sed '/zgrab/d' access.log | wc -l
```

```text
1001,2026-09-01,north,laptop,1,899.00
1002,2026-09-01,south,mouse,3,19.99
15
```

`d` deletes the addressed lines. `1d` drops the header (like `tail -n +2`); `/zgrab/d` drops every scanner line (like `grep -v zgrab`).

A classic clean-up for config files deletes comments and blank lines. `-e` adds several commands, or you can separate them with `;`:

```bash
printf '# comment\n\nport=80\n  # indented comment\nhost=a\n' | sed -e '/^[[:space:]]*#/d' -e '/^$/d'
```

```text
port=80
host=a
```

#### Printing selected lines: -n and p

`-n` turns off sed's automatic printing. Then only lines you explicitly print with `p` appear. This turns `sed` into a precise line selector:

```bash
sed -n '3,5p' sales.csv
sed -n '$p' sales.csv
```

```text
1002,2026-09-01,south,mouse,3,19.99
1003,2026-09-02,east,monitor,2,229.50
1004,2026-09-02,north,keyboard,1,49.00
1012,2026-09-06,north,mouse,2,19.99
```

A range between two regexes is great for extracting a time window from a log:

```bash
sed -n '/10:05/,/10:12/p' access.log
```

```text
192.0.2.10 - - [21/Sep/2026:10:05:30 +0000] "POST /login HTTP/1.1" 401 58 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:10:05:44 +0000] "POST /login HTTP/1.1" 200 412 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
192.0.2.10 - - [21/Sep/2026:10:06:02 +0000] "POST /api/cart HTTP/1.1" 200 734 "https://shop.example.com/products/42" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
198.51.100.7 - - [21/Sep/2026:10:12:09 +0000] "GET /search?q=usb+cable HTTP/1.1" 200 5004 "https://shop.example.com/" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
```

Two more small commands: `=` prints the line number, and `q` quits. `sed -n '/ 50[0-9] /='` lists the line numbers of server errors, and `sed '3q'` behaves like `head -n 3`.

#### Editing files in place: -i

`-i` (in place) writes the result back to the file instead of printing it. Give it a suffix, and `sed` keeps a backup of the original. Use a scratch config file:

```bash
printf '# app.conf\nlisten_port=8080\nlog_level=info\nmax_workers=4\n' > app.conf
sed -i.bak 's/^log_level=.*/log_level=debug/' app.conf
ls app.conf*
diff app.conf.bak app.conf
```

```text
app.conf  app.conf.bak
3c3
< log_level=info
---
> log_level=debug
```

`-i.bak` means "edit in place, save the original as `app.conf.bak`". Note there is no space between `-i` and `.bak`. Under the hood, `sed -i` writes to a temporary file and renames it over the original, so it is not affected by the truncation trap from chapter 4.

!!! warning "Common mistake"
    Running `sed -i` with an untested expression on an important file. Always run the same command **without** `-i` first and read the output. When you use `-i`, add a backup suffix until you are confident. Also watch the flag order: `sed -iE '...'` does **not** mean `-i -E`. It means "in place, with backup suffix `E`", and your ERE pattern is then read as a BRE. Write `sed -E -i.bak '...'` instead.

### awk: fields, logic, and aggregation

`awk` (named after its creators Aho, Weinberger, and Kernighan) is a small programming language designed for exactly this kind of data. An awk program is a list of **pattern { action }** rules. For each input line, awk splits it into fields and runs every rule whose pattern is true:

```text
awk 'pattern { action }' file
```

- If the pattern is missing, the action runs for every line.
- If the action is missing, the default action is `{ print }` (print the whole line).

Inside the program:

| Name | Meaning |
|---|---|
| `$0` | The whole line |
| `$1`, `$2`, ... | Fields 1, 2, ... (split on runs of whitespace by default) |
| `$NF` | The last field (`NF` is the **number of fields**) |
| `NR` | The current line number (**number of records** so far) |
| `FS` | Input field separator (set with `-F`) |
| `OFS` | Output field separator (default: one space) |

On Mint, `awk` is **mawk**, a fast implementation. Everything in this chapter also works in **gawk** (GNU awk), which you can install for extra features.

#### Printing fields

```bash
awk '{print $1, $9}' access.log | head -3
awk '{print NR, NF}' access.log | head -3
```

```text
192.0.2.10 200
192.0.2.10 200
198.51.100.7 200
1 16
2 16
3 18
```

The comma in `print $1, $9` inserts the output separator (a space). Without the comma, `print $1 $9` would glue the values together.

Notice that line 3 has 18 fields while lines 1 and 2 have 16. The user agent contains a different number of spaces, so `$NF` and anything after field 11 is unreliable. Fields 1 through 10 are stable, which is all most questions need.

#### Choosing a field separator: -F

`-F` sets the field separator. For CSV:

```bash
awk -F, '{print $3}' sales.csv | head -3
```

```text
region
north
south
```

For the user agent, split on the double-quote character instead. The quoted parts of the log line then become fields 2 (request), 4 (referer), and 6 (user agent):

```bash
awk -F'"' '{print $6}' access.log | sort | uniq -c | sort -rn
```

```text
      6 Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0
      5 Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1
      4 python-requests/2.31.0
      3 Mozilla/5.0 zgrab/0.x
```

#### Patterns: filtering by field

A pattern can be any expression. Comparisons on fields are where awk beats grep:

```bash
awk '$9 >= 400' access.log
```

```text
203.0.113.5 - - [21/Sep/2026:10:02:11 +0000] "GET /wp-login.php HTTP/1.1" 404 162 "-" "Mozilla/5.0 zgrab/0.x"
203.0.113.5 - - [21/Sep/2026:10:02:12 +0000] "GET /.env HTTP/1.1" 404 162 "-" "Mozilla/5.0 zgrab/0.x"
192.0.2.10 - - [21/Sep/2026:10:05:30 +0000] "POST /login HTTP/1.1" 401 58 "https://shop.example.com/login" "Mozilla/5.0 (X11; Linux x86_64) Firefox/125.0"
203.0.113.5 - - [21/Sep/2026:10:15:40 +0000] "GET /admin HTTP/1.1" 404 162 "-" "Mozilla/5.0 zgrab/0.x"
192.0.2.33 - - [21/Sep/2026:10:31:18 +0000] "GET /api/orders HTTP/1.1" 500 189 "-" "python-requests/2.31.0"
192.0.2.33 - - [21/Sep/2026:10:31:20 +0000] "GET /api/orders HTTP/1.1" 500 189 "-" "python-requests/2.31.0"
198.51.100.7 - - [21/Sep/2026:10:47:51 +0000] "POST /api/orders HTTP/1.1" 502 157 "https://shop.example.com/cart" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4) Safari/604.1"
```

That is "every error response", tested on the status field alone, with no risk of matching a byte count. Combine conditions with `&&` (and), `||` (or), and `!` (not). `==` compares, and string values need double quotes:

```bash
awk '$1 == "192.0.2.33" && $9 != 200 {print $4, $9}' access.log
awk -F, 'NR > 1 && $3 == "north"' sales.csv
```

```text
[21/Sep/2026:10:31:18 500
[21/Sep/2026:10:31:20 500
1001,2026-09-01,north,laptop,1,899.00
1004,2026-09-02,north,keyboard,1,49.00
1008,2026-09-04,north,webcam,1,64.00
1012,2026-09-06,north,mouse,2,19.99
```

`NR > 1` skips the CSV header. `~` tests a field against a regex (and `!~` is "does not match"):

```bash
awk '$7 ~ /^\/api\// {print $6, $7, $9}' access.log
```

```text
"POST /api/cart 200
"GET /api/orders 500
"GET /api/orders 500
"GET /api/orders 200
"POST /api/orders 502
"GET /api/products?page=2 200
```

#### BEGIN, END, and variables

`BEGIN { ... }` runs once before any input is read; `END { ... }` runs once after the last line. Variables need no declaration and start as zero (or the empty string):

```bash
awk -F, 'NR > 1 {total += $5 * $6} END {print total}' sales.csv
```

```text
4971.4
```

For each data line, add quantity times price to `total`. At the end, print it. That is "total revenue" in one line.

`printf` gives you control over the format, using the same codes as C and Python's `%` formatting: `%s` string, `%d` integer, `%.2f` number with two decimals, `%-10s` left-aligned in 10 characters, `%8d` right-aligned in 8. Unlike `print`, `printf` adds no newline, so end with `\n`:

```bash
awk -F, 'NR > 1 {total += $5 * $6} END {printf "Total revenue: %.2f\n", total}' sales.csv
awk '$9 >= 400 {err++} END {printf "%d of %d requests failed (%.1f%%)\n", err, NR, 100 * err / NR}' access.log
```

```text
Total revenue: 4971.40
7 of 18 requests failed (38.9%)
```

In the `END` block, `NR` holds the total line count. `%%` prints a literal percent sign.

#### Associative arrays: counting and summing by key

An awk **array** is indexed by strings, not just numbers. That makes it a dictionary (a hash map): `count["192.0.2.10"]++` adds one to the counter for that key, creating it at zero the first time. Combined with `END` and `for (key in array)`, you get "group by" in one line.

Count requests per IP (the same answer as `sort | uniq -c`, without sorting first):

```bash
awk '{count[$1]++} END {for (ip in count) print count[ip], ip}' access.log | sort -rn
```

```text
6 192.0.2.10
5 198.51.100.7
4 192.0.2.33
3 203.0.113.5
```

Sum bytes per IP, formatted as a table:

```bash
awk '{bytes[$1] += $10} END {for (ip in bytes) printf "%-15s %8d\n", ip, bytes[ip]}' access.log | sort -k2,2nr
```

```text
192.0.2.10         33321
198.51.100.7       22248
192.0.2.33          4516
203.0.113.5          486
```

Revenue per region from the CSV, with a header from `BEGIN`:

```bash
awk -F, 'BEGIN {printf "%-8s %10s\n", "region", "revenue"}
         NR > 1 {rev[$3] += $5 * $6}
         END {for (r in rev) printf "%-8s %10.2f\n", r, rev[r]}' sales.csv
```

```text
region      revenue
north       1051.98
west        1994.00
south       1238.47
east         686.95
```

An awk program can span several lines inside the quotes, which helps readability.

!!! warning "Common mistake"
    Expecting `for (key in array)` to visit keys in a sorted or insertion order. The order is unspecified and differs between mawk and gawk. Pipe the output to `sort` when order matters.

Two more array idioms are worth memorizing:

```bash
awk -F, 'NR > 1 && !seen[$3]++ {print $3}' sales.csv     # first occurrence of each value, in input order
```

```text
north
south
east
west
```

`!seen[$3]++` is true only the first time a value appears: the counter is 0 (false, negated to true), then it is incremented. Unlike `sort -u`, this keeps the original order.

```bash
awk '{h = substr($4, 14, 2); total[h]++; if ($9 >= 400) err[h]++}
     END {for (h in total) printf "%s:00 %3d requests %3d errors %5.1f%%\n", h, total[h], err[h], 100 * err[h] / total[h]}' access.log | sort
```

```text
09:00   3 requests   0 errors   0.0%
10:00  12 requests   7 errors  58.3%
11:00   3 requests   0 errors   0.0%
```

`substr(s, start, length)` extracts part of a string. In `[21/Sep/2026:10:05:30`, the hour starts at character 14. `if` works like in other languages. This one program produces an hourly error report.

#### More awk tools

| Feature | Example | What it does |
|---|---|---|
| `-v name=value` | `awk -v limit=5000 '$10 > limit'` | Pass a shell value into awk safely |
| `split(s, arr, sep)` | `split($4, t, ":"); print t[2]` | Split a string into an array, returns the count |
| `length(s)` | `length($7) > 30` | String length |
| `tolower(s)`, `toupper(s)` | `tolower($3)` | Change case |
| `next` | `NR == 1 {next}` | Skip to the next line |
| Assigning a field | `{$2 = "X"; print}` | Rebuilds `$0` using `OFS` |
| `OFS` | `-v OFS=,` or `BEGIN {OFS="\t"}` | Separator between printed fields |

Assigning to a field rebuilds the line. Add a revenue column to the CSV:

```bash
awk -F, -v OFS=, 'NR > 1 {$7 = $5 * $6} 1' sales.csv | head -3
```

```text
order_id,date,region,product,qty,unit_price
1001,2026-09-01,north,laptop,1,899.00,899
1002,2026-09-01,south,mouse,3,19.99,59.97
```

The lone `1` at the end is a pattern that is always true, with no action, so awk prints every line. It is a common awk shorthand.

### xargs: turn lines into arguments

Some commands read data from stdin (`grep`, `sort`, `wc`). Others only take **arguments**: `rm`, `mkdir`, `cp`, `chmod`. You cannot pipe a list of file names into `rm`, because `rm` ignores stdin. `xargs` bridges the gap: it reads items from stdin and runs a command with those items as arguments.

```bash
printf 'a\nb\nc\n' | xargs echo
```

```text
a b c
```

`xargs` collected the three lines and ran `echo a b c`, once. It packs as many arguments into each command as the system allows, so it runs few processes. (If stdin is empty, GNU `xargs` still runs the command once with no arguments; `-r` prevents that.)

#### Controlling batches: -n

`-n N` uses at most N arguments per command:

```bash
printf 'a\nb\nc\nd\ne\n' | xargs -n 2 echo
```

```text
a b
c d
e
```

#### Placing the argument: -I

`-I {}` runs the command once **per input line**, replacing `{}` with the line. Use it when the argument is not at the end, or appears more than once:

```bash
printf 'north\nsouth\n' | xargs -I {} echo "region: {}"
```

```text
region: north
region: south
```

```bash
cut -d' ' -f1 access.log | sort -u | xargs -I {} sh -c 'echo "{} $(grep -c "^{} " access.log)"'
```

```text
192.0.2.10 6
192.0.2.33 4
198.51.100.7 5
203.0.113.5 3
```

That runs one `grep -c` per IP. (The `awk` array is faster for this, but the pattern of "for each item, run a command" is what matters.)

#### Spaces in file names: -0 with find -print0

By default, `xargs` splits input on **any whitespace**. File names with spaces break:

```bash
mkdir -p reports && touch "reports/q3 summary.txt" reports/jan.txt reports/feb.txt
find reports -name "*.txt" | xargs ls -l
```

```text
ls: cannot access 'reports/q3': No such file or directory
ls: cannot access 'summary.txt': No such file or directory
-rw-rw-r-- 1 alex alex 0 Sep 21 10:41 reports/feb.txt
-rw-rw-r-- 1 alex alex 0 Sep 21 10:41 reports/jan.txt
```

The fix is to separate items with the **NUL** character (byte value zero), which can never appear in a file name. `find -print0` emits NUL-separated names, and `xargs -0` reads them:

```bash
find reports -name "*.txt" -print0 | xargs -0 ls -l
```

```text
-rw-rw-r-- 1 alex alex 0 Sep 21 10:41 reports/feb.txt
-rw-rw-r-- 1 alex alex 0 Sep 21 10:41 reports/jan.txt
-rw-rw-r-- 1 alex alex 0 Sep 21 10:41 'reports/q3 summary.txt'
```

Make `find ... -print0 | xargs -0 ...` a habit whenever file names come from `find`. [Finding files](06-finding-files.md) covers `find` in depth.

#### Seeing and parallelizing: -t and -P

`-t` prints each command before running it (great for checking). `-P N` runs up to N commands at once:

```bash
time (printf '1\n1\n1\n1\n' | xargs -n 1 sleep)
time (printf '1\n1\n1\n1\n' | xargs -n 1 -P 4 sleep)
```

```text
real	0m4.011s
...
real	0m1.007s
...
```

Four one-second sleeps take four seconds in sequence and one second in parallel. `-P` is a quick way to compress many files at once (`find . -name '*.csv' -print0 | xargs -0 -n 1 -P 4 gzip`) or download a list of URLs.

!!! danger "⚠️ VM only"
    Combining `xargs` with `rm`, `chmod`, or `chown` acts on every name it receives, with no confirmation. Practice destructive `xargs` pipelines on throwaway files in `~/practice`, and run `xargs -t echo` (or `xargs echo rm`) first to see the commands. Never point them at system paths on your main machine; do that only in your VM.

### paste: merge lines side by side

`paste` joins files line by line, with a tab between them by default. Create two lists of usernames:

```bash
printf 'alex\nbianca\ncarlos\ndana\n' > monday.txt
printf 'alex\ncarlos\nemma\nfarid\n' > tuesday.txt
paste monday.txt tuesday.txt
paste -d, monday.txt tuesday.txt
```

```text
alex	alex
bianca	carlos
carlos	emma
dana	farid
alex,alex
bianca,carlos
carlos,emma
dana,farid
```

`-s` (serial) joins all lines of one file into a single line. With `-d`, that turns a column into a comma-separated list:

```bash
paste -sd, monday.txt
cut -d' ' -f10 access.log | paste -sd+ | bc
```

```text
alex,bianca,carlos,dana
60571
```

The second line builds the expression `5320+18342+...` and hands it to `bc`, a calculator, to sum all response sizes.

### column: align for humans

`column -t` (table) aligns whitespace-separated columns. `-s` sets the input separator:

```bash
column -t -s, sales.csv | head -4
```

```text
order_id  date        region  product   qty  unit_price
1001      2026-09-01  north   laptop    1    899.00
1002      2026-09-01  south   mouse     3    19.99
1003      2026-09-02  east    monitor   2    229.50
```

Use `column -t` at the end of a pipeline whose output a person will read. Do not use it in the middle of a pipeline, because the padding changes the data.

### comm and diff: compare files

`comm` compares two **sorted** files and prints three columns: lines only in the first, lines only in the second, and lines in both:

```bash
comm monday.txt tuesday.txt
```

```text
		alex
bianca
		carlos
dana
	emma
	farid
```

The columns are separated by tabs. `-1`, `-2`, and `-3` hide columns, so you usually use it as a set operation:

```bash
comm -12 monday.txt tuesday.txt    # in both (intersection)
comm -23 monday.txt tuesday.txt    # only Monday
comm -13 monday.txt tuesday.txt    # only Tuesday
```

```text
alex
carlos
bianca
dana
emma
farid
```

If the inputs are not sorted, `comm` gives wrong answers and warns `comm: file 1 is not in sorted order`. With process substitution, you can sort on the fly: `comm -12 <(sort a.txt) <(sort b.txt)`.

`diff` shows how to turn one file into another. Its default output lists changes with line numbers:

```bash
diff monday.txt tuesday.txt
```

```text
2d1
< bianca
4c3,4
< dana
---
> emma
> farid
```

Read it as instructions: `2d1` means "delete line 2 of the first file (to line up with line 1 of the second)". `4c3,4` means "change line 4 of the first into lines 3-4 of the second". `<` lines come from the first file, `>` from the second.

`diff -u` gives the **unified** format, which is what `git diff` and code review tools show:

```bash
diff -u app.conf.bak app.conf
```

```text
--- app.conf.bak	2026-09-21 10:41:38.067423538 +0000
+++ app.conf	2026-09-21 10:41:38.069723231 +0000
@@ -1,4 +1,4 @@
 # app.conf
 listen_port=8080
-log_level=info
+log_level=debug
 max_workers=4
```

Lines starting with `-` were removed, `+` were added, and a space means unchanged context. `@@ -1,4 +1,4 @@` says the hunk covers 4 lines starting at line 1 in both files. `diff` exits with 0 if the files are the same, 1 if they differ.

### Modern alternatives

The classic tools are everywhere, including minimal servers and containers, which is why you learn them first. A few modern tools are worth knowing:

=== "ripgrep (rg)"

    `rg` is a much faster recursive grep. It searches the current directory by default, skips files listed in `.gitignore` and hidden files, and uses ERE-style syntax. Install it with `sudo apt install ripgrep`.

    ```bash
    rg 'zgrab'                 # like grep -rn 'zgrab' . but faster, respecting .gitignore
    rg -c ' 50[0-9] ' logs/    # count per file
    rg -t py 'import pandas'   # only Python files
    ```

=== "jq"

    Many modern services log **JSON** (one JSON object per line), which `cut` and `awk` handle badly. `jq` is a processor for JSON. Install it with `sudo apt install jq`.

    ```bash
    printf '%s\n' '{"ts":"2026-09-21T10:31:18Z","path":"/api/orders","status":500}' \
                  '{"ts":"2026-09-21T10:31:25Z","path":"/api/orders","status":200}' > events.jsonl
    jq -r 'select(.status >= 500) | "\(.ts) \(.status) \(.path)"' events.jsonl
    ```

    ```text
    2026-09-21T10:31:18Z 500 /api/orders
    ```

    `select(...)` filters objects, and `"\(.field)"` builds a string from fields. `jq` output can feed straight into `sort | uniq -c`.

For CSV files with quoted fields, tools like `csvkit` or `miller` (`mlr`) parse CSV correctly where `cut -d,` cannot. Install them when you need them; the pipeline thinking stays the same.

## Exercises

All exercises use `~/practice/text/access.log` and `sales.csv`.

### Exercise 1: Quick questions with grep and cut (easy)

Answer each with one pipeline: (a) how many requests came from iPhones? (b) which distinct IPs made POST requests? (c) list the distinct products sold, sorted.

??? success "Solution"

    ```bash
    grep -c 'iPhone' access.log
    grep '"POST ' access.log | cut -d' ' -f1 | sort -u
    tail -n +2 sales.csv | cut -d, -f4 | sort -u
    ```

    ```text
    5
    192.0.2.10
    198.51.100.7
    keyboard
    laptop
    monitor
    mouse
    webcam
    ```

    In (b), the pattern `"POST ` includes the quote and space so that "POST" elsewhere in a line (say, in a URL) cannot match. In (c), `tail -n +2` removes the header before it can be counted as a product.

### Exercise 2: Orders per region (easy)

Count the orders per region, biggest first, using the frequency-count idiom. Then produce the same counts with a single `awk` command.

??? success "Solution"

    ```bash
    tail -n +2 sales.csv | cut -d, -f3 | sort | uniq -c | sort -rn
    awk -F, 'NR > 1 {n[$3]++} END {for (r in n) print n[r], r}' sales.csv | sort -rn
    ```

    ```text
          4 north
          3 south
          3 east
          2 west
    4 north
    3 south
    3 east
    2 west
    ```

    Both give the same answer. The pipeline is easier to build step by step; the awk version scales better when you want several aggregates at once.

### Exercise 3: Revenue report (medium)

Print revenue per product (quantity × unit price), formatted to two decimals, sorted by revenue descending, with a `TOTAL` line.

??? success "Solution"

    ```bash
    awk -F, 'NR > 1 {rev[$4] += $5 * $6; total += $5 * $6}
             END {for (p in rev) printf "%-10s %9.2f\n", p, rev[p]
                  printf "%-10s %9.2f\n", "TOTAL", total}' sales.csv | sort -k2,2nr
    ```

    ```text
    TOTAL        4971.40
    laptop       3646.00
    monitor       688.50
    keyboard      245.00
    mouse         199.90
    webcam        192.00
    ```

    `TOTAL` sorts first because it is the largest number. To keep it last regardless, print the total separately after the sort: wrap the pipeline in `{ ...; }` or print the products with awk, sort them, and compute the total in a second awk.

### Exercise 4: Convert a CSV for a European spreadsheet (medium)

Make a copy of `sales.csv` called `sales-eu.csv` and, using `sed -i` with a backup, convert it so the separator is `;` and dates (but not the header) are `DD/MM/YYYY`. Check the result with `head` and the change with `diff`.

??? success "Solution"

    ```bash
    cp sales.csv sales-eu.csv
    sed -i.orig -E '1!s/^([^,]*),([0-9]{4})-([0-9]{2})-([0-9]{2}),/\1,\4\/\3\/\2,/; s/,/;/g' sales-eu.csv
    head -3 sales-eu.csv
    diff sales-eu.csv.orig sales-eu.csv | head -4
    ```

    ```text
    order_id;date;region;product;qty;unit_price
    1001;01/09/2026;north;laptop;1;899.00
    1002;01/09/2026;south;mouse;3;19.99
    1,13c1,13
    < order_id,date,region,product,qty,unit_price
    < 1001,2026-09-01,north,laptop,1,899.00
    < 1002,2026-09-01,south,mouse,3,19.99
    ```

    Every line changed, so `diff` reports one block: lines 1-13 of the original became lines 1-13 of the new file.

    Two commands, separated by `;`. The first, addressed with `1!` (every line but the header), captures the order ID, year, month, and day, and writes the date back reordered, with `\/` for literal slashes. The second replaces every comma. The order matters: the date regex relies on commas, so it must run before they are replaced.

### Exercise 5: Per-IP report (hard)

Produce this table from `access.log` in one pipeline: one row per IP with its number of requests, total bytes, and number of error responses (status 400 or above), sorted by requests descending, aligned with `column -t`, with a header row on top.

```text
IP            REQUESTS  BYTES  ERRORS
192.0.2.10    6         33321  1
...
```

??? success "Solution"

    ```bash
    {
      echo "IP REQUESTS BYTES ERRORS"
      awk '{req[$1]++; bytes[$1] += $10; if ($9 >= 400) err[$1]++}
           END {for (ip in req) print ip, req[ip], bytes[ip], err[ip] + 0}' access.log | sort -k2,2nr
    } | column -t
    ```

    ```text
    IP            REQUESTS  BYTES  ERRORS
    192.0.2.10    6         33321  1
    198.51.100.7  5         22248  1
    192.0.2.33    4         4516   2
    203.0.113.5   3         486    3
    ```

    Three arrays share the same key (the IP). `err[ip] + 0` forces a number, so IPs with no errors print `0` instead of an empty string. The header must not go through `sort`, so it is printed separately; `{ ...; }` groups both outputs into one stream for `column -t`. The scanner at `203.0.113.5` stands out: every one of its requests failed.

## Check yourself

1. Why does `uniq -c` usually need `sort` in front of it?

    ??? note "Answer"

        `uniq` only compares each line with the previous one, so it collapses **adjacent** duplicates. `sort` makes all identical lines adjacent. This design lets `uniq` work on endless streams with constant memory.

2. What is the difference between `sort -k2` and `sort -k2,2`?

    ??? note "Answer"

        `-k2` sorts by everything from field 2 to the end of the line. `-k2,2` sorts by field 2 only, which is almost always what you mean.

3. In a regex, what do `.`, `*`, and `^` mean? How do you match a literal dot?

    ??? note "Answer"

        `.` is any single character, `*` is zero or more of the previous item, and `^` anchors to the start of the line. A literal dot is `\.` (or `[.]`).

4. When do you need `grep -E` instead of plain `grep`?

    ??? note "Answer"

        When the pattern uses `+`, `?`, `{n,m}`, `( )`, or `|` as operators. In plain `grep` (BRE) these are literal unless backslashed. `-E` (ERE) makes them special without backslashes.

5. Why is `awk '$9 == 500'` more reliable than `grep 500` for finding server errors in an access log?

    ??? note "Answer"

        `grep 500` matches the text anywhere in the line, including byte counts like `5004`, paths, and timestamps. `$9 == 500` tests only the status field.

6. What does `awk '{c[$1]++} END {for (k in c) print c[k], k}'` compute, and in what order is the output?

    ??? note "Answer"

        The number of lines for each distinct value of field 1. The order of `for (k in c)` is unspecified, so pipe it to `sort -rn` for a ranking.

7. Why does `find . -name '*.txt' | xargs rm` fail on `my notes.txt`, and what is the fix?

    ??? note "Answer"

        `xargs` splits input on whitespace, so it passes `./my` and `notes.txt` as two arguments. Use NUL separators: `find . -name '*.txt' -print0 | xargs -0 rm`.

8. What does `sed -n '/start/,/end/p' file` print, and what does `-i.bak` do?

    ??? note "Answer"

        Every line from one that matches `start` through the next one matching `end`, inclusive (and again for later ranges). `-n` turns off automatic printing so only `p` prints. `-i.bak` edits the file in place and keeps the original as `file.bak`.

## Key takeaways

- Filters read lines and write lines; build pipelines one stage at a time, checking the output as you go.
- `extract | sort | uniq -c | sort -rn | head` answers "top N of anything".
- `grep` selects lines (`-v -c -n -w -o -i -E -F -r -A/-B/-C`); `cut` picks simple columns; `tr` works on characters.
- Regex: `.` is any character, `*` repeats the previous item, anchors are `^` and `$`, matching is leftmost and greedy. Use `-E` for `+ ? {} () |`, and always single-quote patterns.
- `sed` substitutes and selects by line address; preview before `-i`, and keep a backup suffix.
- `awk` handles fields, conditions, arithmetic, and grouping with associative arrays. Reach for it as soon as `cut` and `grep` feel awkward.
- `xargs` turns lines into arguments; pair `find -print0` with `xargs -0`.

## Next

You can now search inside files. Next, learn to find the files themselves, by name, size, age, and owner: [Finding files](06-finding-files.md).
