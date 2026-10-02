# Level 1 capstone: solution

> **Level 1 · Capstone solution** · Back to the [capstone questions](../level-1-capstone.md)

This page answers all ten questions about the generated `access.log`, explains each pipeline stage by stage, and points out the traps. Try every question yourself first. If your pipeline looks different but prints the same numbers, it is a correct answer: there are always several good ways to do this.

## Before you start

Run every command in the directory with the generated log, and confirm it is the expected file:

```bash
cd ~/practice/capstone
sha256sum access.log
```

```text
834d88d503b0e9d0f79dda5d64bd260d4f1b3ea8bed3d0fb8faf9d055c635cd6  access.log
```

If the checksum differs, regenerate the file from the [capstone page](../level-1-capstone.md); otherwise your numbers will not match.

## How the pipelines are built

Every answer follows the same method, which is worth more than any individual pipeline:

1. **Extract** the one thing you care about (an IP, a path, an hour) from each line.
2. **Filter** to the lines that matter (errors, 404s, one client), testing a specific field.
3. **Group and count**, either with `sort | uniq -c` or with an awk associative array.
4. **Rank and trim** with `sort -rn | head`.

Build each pipeline one stage at a time and look at the output after every `|`. Add `| head -n 3` while you are experimenting.

Lines with equal counts may appear in a different order on your machine if your language settings differ. The counts themselves will match.

## Question 1: Size of the problem

```bash
wc -l < access.log
cut -d' ' -f1 access.log | sort -u | wc -l
```

```text
5000
113
```

**5,000 requests from 113 distinct IPs.**

| Stage | Output |
|---|---|
| `wc -l < access.log` | The number of lines. The `<` redirection hides the file name, so you get just the number. |
| `cut -d' ' -f1 access.log` | One IP per line, 5,000 lines, in log order. |
| `sort -u` | Sorted, with duplicates removed: one line per distinct IP. |
| `wc -l` | Counts those lines. |

`sort | uniq | wc -l` gives the same result. `uniq` alone would not, because it only collapses **adjacent** duplicates.

## Question 2: Top talkers

```bash
cut -d' ' -f1 access.log | sort | uniq -c | sort -rn | head
```

```text
    283 192.0.2.77
    264 203.0.113.10
    231 198.51.100.34
    147 198.51.100.112
    140 198.51.100.120
    135 192.0.2.4
    133 203.0.113.233
    132 198.51.100.96
    111 198.51.100.196
    107 198.51.100.23
```

This is the frequency-count idiom. Here is what flows through each pipe:

| Stage | Sample output | What it does |
|---|---|---|
| `cut -d' ' -f1 access.log` | `192.0.2.157`<br>`203.0.113.203`<br>`192.0.2.88` | Field 1 of each line, split on single spaces |
| `sort` | `192.0.2.109`<br>`192.0.2.109`<br>`192.0.2.109` | Identical IPs become adjacent |
| `uniq -c` | `9 192.0.2.109`<br>`12 192.0.2.113`<br>`22 192.0.2.119` | One line per run, prefixed with its length |
| `sort -rn` | `283 192.0.2.77`<br>`264 203.0.113.10` | Numeric sort on the leading count, biggest first |
| `head` | (the 10 lines above) | Keep the first 10 |

The top two are not people. Question 9 will show that `192.0.2.77` is Googlebot and `203.0.113.10` is a Python script. Number 10, `198.51.100.23`, comes back in question 7.

=== "awk alternative"

    ```bash
    awk '{n[$1]++} END {for (ip in n) print n[ip], ip}' access.log | sort -rn | head
    ```

    The array `n` is keyed by IP; `n[$1]++` counts. awk does the grouping, so the first `sort` is not needed, but the output still needs `sort -rn` because `for (ip in n)` visits keys in no particular order.

## Question 3: Popular pages

```bash
cut -d' ' -f7 access.log | cut -d'?' -f1 | sort | uniq -c | sort -rn | head
```

```text
    532 /
    512 /api/products
    346 /static/css/main.css
    340 /static/js/app.js
    334 /products
    279 /search
    273 /login
    271 /api/orders
    252 /images/logo.png
    206 /api/cart
```

| Stage | Sample output | What it does |
|---|---|---|
| `cut -d' ' -f7` | `/api/products?page=3`<br>`/search?q=webcam` | The request path, with any query string |
| `cut -d'?' -f1` | `/api/products`<br>`/search` | Everything before the first `?`. Lines without a `?` pass through unchanged. |
| `sort | uniq -c | sort -rn | head` | (above) | Frequency count |

Without the second `cut`, `/search?q=laptop`, `/search?q=monitor`, and the others would each be counted separately, and `/search` would drop out of the top 10.

Individual product pages (`/products/1` to `/products/60`) are each counted separately, so none of them makes the list. Counting them as one group would need another transformation, for example `sed -E 's#/products/[0-9]+#/products/N#'`.

## Question 4: Status codes

```bash
cut -d' ' -f9 access.log | sort | uniq -c | sort -rn
awk '$9 >= 400 {err++} END {printf "%d of %d requests failed (%.1f%%)\n", err, NR, 100 * err / NR}' access.log
```

```text
   4459 200
    262 404
    204 304
     27 500
     26 401
     18 502
      4 503
337 of 5000 requests failed (6.7%)
```

**6.7% of requests failed.** Most failures are 404s.

The awk program, piece by piece:

| Part | Meaning |
|---|---|
| `$9 >= 400` | Pattern: the status field, compared as a number |
| `{err++}` | Action for matching lines: count them |
| `END {...}` | After the last line |
| `NR` | In `END`, the total number of lines read |
| `%.1f%%` | A number with one decimal place, then a literal `%` |

A quick view by status class (2xx, 3xx, 4xx, 5xx) takes the first digit:

```bash
cut -d' ' -f9 access.log | cut -c1 | sort | uniq -c
```

```text
   4459 2
    204 3
    288 4
     49 5
```

!!! warning "Trap: matching text instead of fields"
    `grep -c ' 404 ' access.log` happens to give the right answer here, but `grep -c 404` would also count any line with `404` in a path, a byte count, or a timestamp. `$9 == 404` tests only the status field.

## Question 5: Traffic by hour

```bash
cut -d: -f2 access.log | uniq -c
```

```text
     59 00
     35 01
     74 02
     65 03
     33 04
     63 05
    119 06
    174 07
    245 08
    290 09
    307 10
    380 11
    350 12
    308 13
    321 14
    321 15
    284 16
    263 17
    214 18
    266 19
    281 20
    268 21
    186 22
     94 23
```

| Stage | Sample output | What it does |
|---|---|---|
| `cut -d: -f2` | `00` | Splits on colons. The first colon on each line is the one after the year in `[21/Sep/2026:00:00:11`, so field 2 is the hour. |
| `uniq -c` | `59 00` | Counts runs. The log is in time order, so each hour is already one contiguous run and no `sort` is needed. |

The busiest hour:

```bash
cut -d: -f2 access.log | sort | uniq -c | sort -rn | head -n 1
```

```text
    380 11
```

**11:00 to 11:59 was busiest, with 380 requests.**

The odd hours are **02 and 03**: 74 and 65 requests, twice as many as 01 and 04 on either side. A real shop is quietest at that time of night. The extra traffic is the vulnerability scanner you will identify in question 7, which was active only between 02:00 and 03:59.

!!! warning "Trap: cut -d: with IPv6"
    This only works because IPv4 addresses contain no colons. An IPv6 client such as `2001:db8::1` would shift every field. `awk '{print substr($4, 14, 2)}'` takes the hour from a fixed position inside the timestamp field instead, which is robust to that.

## Question 6: The outage

Server errors per hour:

```bash
awk '$9 >= 500 {print substr($4, 14, 2)}' access.log | sort | uniq -c
```

```text
      2 00
      1 05
      1 07
      2 09
      1 11
      1 13
     27 14
      2 15
      2 16
      3 17
      1 18
      2 19
      3 20
      1 21
```

**The outage was in the 14:00 hour: 27 server errors, against a background of 0 to 3 per hour.**

| Stage | What it does |
|---|---|
| `$9 >= 500` | Keep only 5xx responses, tested on the status field |
| `substr($4, 14, 2)` | In `[21/Sep/2026:14:02:38`, the hour is at characters 14 and 15 |
| `sort | uniq -c` | Count per hour. Hours with no errors simply do not appear. |

Which endpoints failed, and how:

```bash
awk '$9 >= 500 && substr($4, 14, 2) == "14" {print $9, $7}' access.log | sort | uniq -c | sort -rn
```

```text
      9 502 /api/products
      7 502 /api/orders
      2 503 /api/orders
      2 503 /api/cart
      2 502 /api/cart
      2 500 /static/css/main.css
      1 500 /products
      1 500 /api/products
      1 500 /api/cart
```

Printing two fields, `$9` and `$7`, and counting the pairs groups by status **and** path at once. The pattern is clear: almost all errors are **502 Bad Gateway** and **503 Service Unavailable** on **`/api/*`** endpoints. Those codes mean nginx could not get an answer from the backend application behind it. The few 500s on other pages are the normal background noise you saw in other hours.

When did it start and stop?

```bash
awk '$9 >= 500 && substr($4, 14, 2) == "14" {print substr($4, 14, 8)}' access.log | sed -n '1p;$p'
```

```text
14:02:38
14:55:54
```

`substr($4, 14, 8)` is `HH:MM:SS`. `sed -n '1p;$p'` prints only the first and last lines, which are the earliest and latest error, because the log is in time order. **The API backend failed intermittently from about 14:02 to 14:56.**

A useful follow-up for the incident report is how many distinct clients saw an error:

```bash
awk '$9 >= 500 && substr($4, 14, 2) == "14" {print $1}' access.log | sort -u | wc -l
```

```text
20
```

!!! warning "Trap: a regex that matches minutes as well as hours"
    A natural first attempt is `awk '$9 >= 500 && $4 ~ /:14:/'`. It finds 28 lines, not 27:

    ```bash
    awk '$9 >= 500 && $4 ~ /:14:/ {print $4}' access.log | grep -v ':14:..:..$'
    ```

    ```text
    [21/Sep/2026:00:14:07
    ```

    `:14:` also matches **minute** 14 of any hour, here 00:14:07. Extracting the hour by position, or anchoring the regex as `/:14:[0-9][0-9]:[0-9][0-9]$/`, avoids it. This is the "leftmost match" lesson from [Text processing](../../chapters/01-command-line/05-text-processing.md) in a real setting: always ask what else your pattern could match.

## Question 7: Not found

Top 404 paths:

```bash
awk '$9 == 404 {print $7}' access.log | sort | uniq -c | sort -rn | head
```

```text
     24 /xmlrpc.php
     21 /products/56
     21 /.git/config
     19 /products/54
     18 /products/59
     18 /products/58
     18 /admin
     17 /.env
     16 /products/52
     15 /products/55
```

Two different stories are mixed here: product pages above `/products/50` that no longer exist, and paths like `/xmlrpc.php`, `/.git/config`, `/admin`, and `/.env` that this shop never had.

Who generates the 404s:

```bash
awk '$9 == 404 {print $1}' access.log | sort | uniq -c | sort -rn | head -n 5
```

```text
    107 198.51.100.23
     51 192.0.2.77
      7 198.51.100.112
      6 198.51.100.34
      5 192.0.2.93
```

**`198.51.100.23` caused 107 of the 262 404s.** Everything it requested:

```bash
awk '$1 == "198.51.100.23" {print $7}' access.log | sort | uniq -c | sort -rn
```

```text
     24 /xmlrpc.php
     21 /.git/config
     18 /admin
     17 /.env
     14 /phpmyadmin/
     13 /wp-login.php
```

It is a **vulnerability scanner**. It probes for WordPress (`/wp-login.php`, `/xmlrpc.php`), exposed secrets (`/.env`, `/.git/config`), and admin panels. Every one of its requests got a 404, so it found nothing. Its user agent, `zgrab`, is a well-known internet scanning tool.

When was it active?

```bash
awk '$1 == "198.51.100.23" {print substr($4, 14, 2)}' access.log | uniq -c
```

```text
     58 02
     49 03
```

**Only between 02:00 and 03:59**, which explains the night-time bump in question 5. The second-biggest 404 source, `192.0.2.77`, is Googlebot following links to removed product pages, a sign that those pages should redirect or be removed from the sitemap.

## Question 8: Bandwidth

```bash
awk '{sum += $10} END {printf "%d bytes = %.1f MiB\n", sum, sum / 1024 / 1024}' access.log
```

```text
68571008 bytes = 65.4 MiB
```

**65.4 MiB in total.** `sum` starts at 0 and adds field 10 on every line; the `END` block converts bytes to MiB (1,048,576 bytes).

Bytes per path:

```bash
awk '{split($7, u, "?"); bytes[u[1]] += $10}
     END {for (p in bytes) printf "%7.1f MiB  %s\n", bytes[p] / 1048576, p}' access.log | sort -rn | head -n 5
```

```text
   40.9 MiB  /static/js/app.js
    4.9 MiB  /static/css/main.css
    3.2 MiB  /
    2.1 MiB  /products
    1.8 MiB  /search
```

| Part | Meaning |
|---|---|
| `split($7, u, "?")` | Split the path at `?` into array `u`; `u[1]` is the part before it |
| `bytes[u[1]] += $10` | Add this response's size to that path's total |
| `printf "%7.1f MiB  %s\n"` | Right-align the size in 7 characters with one decimal |
| `sort -rn` | The numbers come first on each line, so a numeric sort ranks them |

**`/static/js/app.js` alone is about 62% of all traffic** (40.9 of 65.4 MiB). It is a 150 KB JavaScript bundle downloaded on hundreds of page views. Caching it in browsers longer, or compressing it, would cut the shop's bandwidth by more than half. Note the 304 responses in question 4: those are browsers that already had a cached copy, which cost 0 bytes.

## Question 9: Who is visiting

```bash
awk -F'"' '{print $6}' access.log | sort | uniq -c | sort -rn | head
```

```text
    961 Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36
    952 Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0
    864 Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1
    790 Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15
    779 Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36
    283 Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)
    264 python-requests/2.31.0
    107 Mozilla/5.0 zgrab/0.x
```

There are only 8 distinct user agents, so `head` shows them all.

| Stage | What it does |
|---|---|
| `awk -F'"'` | Split each line at double quotes. Field 2 is the request, 4 the referer, 6 the user agent. |
| `{print $6}` | The user agent, spaces and all |
| `sort | uniq -c | sort -rn` | Frequency count |

Splitting on whitespace would have failed: the user agents contain different numbers of spaces, so they span a varying number of fields.

The bot share:

```bash
awk -F'"' '$6 ~ /bot|python-requests|zgrab/ {b++} END {printf "%d of %d (%.1f%%)\n", b, NR, 100 * b / NR}' access.log
```

```text
654 of 5000 (13.1%)
```

**13.1% of requests (654) came from bots and scripts.** Testing the user-agent field (`$6 ~`) rather than the whole line ensures that a path or referer containing "bot" cannot be miscounted. `grep -c -E 'bot|python-requests|zgrab' access.log` also gives 654 here.

## Question 10: What customers want

```bash
grep -o 'q=[^ ]*' access.log | cut -d= -f2 | tr '+' ' ' | sort | uniq -c | sort -rn
```

```text
     46 monitor
     45 keyboard
     41 usb-c cable
     40 laptop
     40 desk lamp
     35 headphones
     32 webcam
```

| Stage | Sample output | What it does |
|---|---|---|
| `grep -o 'q=[^ ]*'` | `q=webcam`<br>`q=laptop` | Print only the matched part: `q=` followed by non-space characters |
| `cut -d= -f2` | `webcam` | The value after `=` |
| `tr '+' ' '` | `usb-c cable` | In URLs, `+` encodes a space |
| `sort | uniq -c | sort -rn` | (above) | Frequency count |

**Monitors and keyboards are the most searched for**, closely followed by USB-C cables. A real query string can contain several parameters (`?q=laptop&page=2`); the pattern `q=[^ &]*` would stop at the `&`.

The total, 279 searches, matches the `/search` count in question 3, which is a good cross-check.

## Stretch: an hourly report in one awk program

```bash
awk '{h = substr($4, 14, 2); n[h]++; if ($9 >= 500) e[h]++}
     END {for (h in n) printf "%s:00  %4d requests  %3d server errors  %5.1f%%\n", h, n[h], e[h], 100 * e[h] / n[h]}' access.log | sort
```

```text
00:00    59 requests    2 server errors    3.4%
01:00    35 requests    0 server errors    0.0%
...
11:00   380 requests    1 server errors    0.3%
12:00   350 requests    0 server errors    0.0%
13:00   308 requests    1 server errors    0.3%
14:00   321 requests   27 server errors    8.4%
15:00   321 requests    2 server errors    0.6%
16:00   284 requests    2 server errors    0.7%
...
```

How it works:

- For every line, `h` holds the hour, `n[h]` counts all requests in that hour, and `e[h]` counts only server errors.
- In `END`, the loop visits every hour that had requests. For hours with no errors, `e[h]` was never set; awk treats an unset value as 0 in arithmetic and prints it as `0` with `%3d`.
- `for (h in n)` has no defined order, so `sort` puts the hours in order. Because every line starts with a zero-padded hour, a plain text sort is correct.

The error **rate** confirms what the counts suggested: 8.4% of requests failed with server errors during the 14:00 hour, against well under 1% at other busy times. Rates matter more than counts when traffic varies: 3 errors at 00:00 is a higher rate than 3 errors at 17:00.

## Bonus: real logs

Your output will differ, because these logs describe your own machine. These pipelines show the technique; adapt them freely. Mint 22 writes `syslog` and `auth.log` lines like this:

```text
2026-09-21T10:15:02.123456+00:00 mint systemd[1]: Started session-4.scope - Session 4 of User alex.
```

Field 1 is the timestamp, field 2 the hostname, and field 3 the program, usually with `[pid]` and a trailing colon.

**Which programs write the most to syslog?**

```bash
awk '{print $3}' /var/log/syslog | sed 's/\[[0-9]*\]//; s/:$//' | sort | uniq -c | sort -rn | head -n 5
```

```text
   5618 kernel
   2898 systemd
    787 NetworkManager
    502 dbus-daemon
    341 cinnamon-session
```

`sed` makes two substitutions: remove `[digits]`, then remove a colon at the end, so `systemd[1]:` and `systemd:` both become `systemd`.

**Messages per hour, and error messages per hour:**

```bash
cut -c1-13 /var/log/syslog | uniq -c | tail -n 3
grep -i 'error' /var/log/syslog | cut -c1-13 | sort | uniq -c | sort -rn | head -n 3
```

```text
   2884 2026-09-21T09
    542 2026-09-21T10
    186 2026-09-21T11
     55 2026-09-20T10
     52 2026-09-20T13
     45 2026-09-21T05
```

The first 13 characters of an ISO timestamp are the date and hour, so `cut -c1-13` is all the extraction you need. A burst right after boot is normal.

**Most frequent sudo commands:**

```bash
grep 'COMMAND=' /var/log/auth.log | sed 's/.*COMMAND=//' | sort | uniq -c | sort -rn | head -n 5
```

```text
     22 /usr/bin/apt update
      8 /usr/bin/apt upgrade
      3 /usr/bin/systemctl restart NetworkManager
```

`sed 's/.*COMMAND=//'` deletes everything up to and including `COMMAND=`. Because `.*` is greedy, it removes as much as possible, which is exactly what you want here.

**Package activity:**

```bash
awk '{print $3}' /var/log/dpkg.log | sort | uniq -c | sort -rn
awk '$3 == "upgrade" {print $4}' /var/log/dpkg.log | cut -d: -f1 | sort | uniq -c | sort -rn | head -n 5
```

```text
    306 status
     38 upgrade
     38 configure
     13 trigproc
      4 startup
      2 install
```

`dpkg.log` lines look like `2026-09-21 10:19:59 upgrade firefox:amd64 1.0 1.1`. Field 3 is the action and field 4 the package with its architecture, which `cut -d: -f1` strips. Older logs are rotated to `dpkg.log.1` and compressed as `dpkg.log.2.gz`; `zcat /var/log/dpkg.log.*.gz | awk ...` reads the compressed ones, and [Archives and compression](../../chapters/01-command-line/08-archives-and-compression.md) explains the tools.

## What you practised

- The frequency-count idiom, `extract | sort | uniq -c | sort -rn | head`, answered six of the ten questions.
- awk associative arrays for sums and multi-column aggregates, with `END` and `printf` for reports.
- Testing **fields** (`$9 >= 500`, `$6 ~ /bot/`) instead of text anywhere in the line, and extracting values by position (`substr`) when a regex could match the wrong place.
- Splitting on a different delimiter (`-F'"'`, `cut -d:`, `cut -d'?'`) to reach awkward fields.
- Cross-checking answers against each other (search count versus `/search` hits, scanner hours versus the night-time bump).

## Next

When you can solve these without notes, you are ready for [Level 2: Shell scripting](../../chapters/02-scripting/index.md), where you will turn pipelines like these into reusable, robust scripts.
