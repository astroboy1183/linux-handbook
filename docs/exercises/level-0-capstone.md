# Level 0 capstone: Find your way around

> **Level 0 · Capstone** · ⏱️ ~1–2 hours · Prerequisites: all six [Level 0 chapters](../chapters/00-first-steps/index.md)

This capstone proves the three Level 0 skills: you can move around the filesystem confidently, you can explain where config, logs, programs, and personal files live, and you can find any command's documentation without a browser.

## Scenario

You've just joined a data team. Your team lead hands you a fresh Linux Mint 22.3 machine, named `mint`, that will eventually host a small reporting job. Before you get access to the production servers, your lead wants proof that you can find your way around a Linux system on your own.

"Production has no browser and no internet," they tell you. "When something breaks at 2 a.m., you'll have a terminal, the man pages, and whatever's in your head. Show me you can get around with just those."

Your job is to complete the five parts below and write your answers in a plain-text **field guide**: a file you can use later as your own reference. Use Mint's Text Editor app (or paper) for the write-up; the terminal is for finding the answers.

## Rules

- **Terminal only** for finding answers. No file manager, no web browser, no AI assistant.
- **Documentation on the machine is allowed**: `man`, `--help`, `help`, `info`, `apropos`, `whatis`, `tldr`, and `/usr/share/doc`.
- **First attempt: notes allowed.** Use the chapters if you're stuck. Then repeat the capstone a few days later **without notes**. You've passed when the second attempt works.
- **No `sudo`** except where a task explicitly says so. Nothing in this capstone needs to change the system.
- Every answer should include **the command you used**, not just the result.

## Setup

Create a small practice tree. `mkdir -p` creates directories (and any missing parents); `touch` creates empty files. Copy these lines as they are:

```bash
mkdir -p ~/capstone0/warehouse/landing/2026-09 ~/capstone0/warehouse/landing/2026-10
mkdir -p ~/capstone0/warehouse/curated ~/capstone0/jobs/nightly ~/capstone0/jobs/hourly ~/capstone0/docs
touch ~/capstone0/warehouse/landing/2026-10/orders.csv ~/capstone0/warehouse/landing/2026-10/customers.csv
touch ~/capstone0/jobs/nightly/load.sh ~/capstone0/docs/README.md ~/capstone0/docs/.runbook
```

Check the result:

```bash
tree -a ~/capstone0
```

```text
/home/alex/capstone0
├── docs
│   ├── README.md
│   └── .runbook
├── jobs
│   ├── hourly
│   └── nightly
│       └── load.sh
└── warehouse
    ├── curated
    └── landing
        ├── 2026-09
        └── 2026-10
            ├── customers.csv
            └── orders.csv

10 directories, 5 files
```

## Tasks

### Part 1: Navigate

1. Starting in your home directory, get into `~/capstone0/warehouse/landing/2026-10` using tab completion. Print your location.
2. From there, using **only a relative path** in one `cd` command, go to `~/capstone0/jobs/nightly`. Print your location.
3. Return to the `2026-10` directory with the shortest possible command. Then go to your home directory with the shortest possible command.
4. Without changing directory, from your home directory, list **everything** in `~/capstone0/docs`, including hidden files but not `.` and `..`.
5. Predict, then verify: if you're in `~/capstone0/jobs/hourly` and run `cd ../../warehouse/./curated/..`, which directory are you in?
6. Answer these with `ls` (plus `head` or `tail` if you like):
    1. The 5 most recently modified entries in `/var/log`, with the newest at the **bottom**.
    2. The 3 largest files directly inside `/usr/bin`, with human-readable sizes.
    3. Which entries in `/` are symbolic links, and where each one points.
    4. The owner, group, and permissions of `/tmp` itself (not its contents). What does the last character of the permissions mean?
    5. Prove that `/bin/bash` and `/usr/bin/bash` are the same file.

### Part 2: Map the system

7. For each item, give the **path** and a **command that proves it** (for example, `ls -l path`):

    | # | Find |
    |---|---|
    | a | The system-wide configuration file for the SSH **client** |
    | b | Your personal bash settings |
    | c | The template `.bashrc` that new users get |
    | d | The log that records every use of `sudo` |
    | e | A log of package installations and upgrades |
    | f | The program that runs when you type `python3`, and what it really is |
    | g | The `apt` that runs when you type `apt` on Mint, and why it isn't `/usr/bin/apt` |
    | h | The package manager's database of installed packages |
    | i | Downloaded `.deb` package files kept after installation |
    | j | The kernel file for the kernel you're running right now |
    | k | Details about your CPU |
    | l | The list of your network interfaces |
    | m | A place for temporary files that must survive a reboot |
    | n | Where a USB stick labelled `BACKUP` will appear when you plug it in |
    | o | The license of the package that provides `ls` |
    | p | Your private runtime directory |

8. From memory, write **one sentence** describing each of these top-level directories: `/`, `/bin`, `/boot`, `/dev`, `/etc`, `/home`, `/media`, `/mnt`, `/opt`, `/proc`, `/root`, `/run`, `/srv`, `/sys`, `/tmp`, `/usr`, `/var`.

9. Summarise the four categories from the Level 0 goal in a short table: **where do config, logs, programs, and personal files live**, both system-wide and per user?

### Part 3: Documentation without a browser

10. Using **only** `apropos` (and `whatis` to confirm), find the command that does each job. Record the search that worked, and any that didn't:
    1. Counts the lines and words in a file.
    2. Reports free disk space on each filesystem.
    3. Compresses a file.
    4. Sorts the lines of a text file.
    5. Tells how long the system has been running.
    6. Determines what type of data a file contains.
11. Which exact command opens the documentation for the **format** of `/etc/fstab`? Of `/etc/hosts`? Why does the number matter?
12. Using the `df` man page or `--help`, find the options for human-readable sizes and for showing each filesystem's type. Run `df` with both on `/`, and explain each column of the output.
13. Using `wc --help`, find how to count **only** lines. Use it to count the accounts in `/etc/passwd`.
14. Read the SYNOPSIS of `mv`. Explain what each of its lines means, and which form you'd use to move three CSV files into `~/capstone0/warehouse/curated`.
15. Get the documentation for the bash builtins `type` and `history`. What does `type -P` do? What does `man history` show on your machine, and why isn't it what you want?
16. Find bash's README in `/usr/share/doc` and print its first 5 lines without decompressing it to disk.

### Part 4: Who you are

17. Show your username, UID, primary group, and all supplementary groups. Explain what `sudo` and `adm` membership each allow.
18. Print your own line from `/etc/passwd` and label all seven fields. Compare it with the line for `www-data` and explain why that account's shell is different.
19. Without running anything as root, find out what `sudo` lets you do. Explain each part of the rule that grants it.
20. Run `sudo whoami` **once**, then find the matching line in the system log and identify who ran what, from where, as whom.
21. In three or four sentences, explain to a colleague why `sudo pip install pandas` is a bad idea, and what the principle of least privilege says instead.

### Part 5: Explain it (stretch)

22. In 10–15 lines, explain everything that happens from the moment you type `ll /etc` and press ++enter++ until the next prompt appears. Name every component: terminal emulator, pty, shell, alias, PATH, the program file, the kernel, and the exit status.

## Acceptance criteria

You've completed the capstone when every box is ticked **on a no-notes attempt**:

- [ ] I can reach any directory in `~/capstone0` from anywhere using both absolute and relative paths, and I use tab completion without thinking.
- [ ] I can predict where a relative path like `../../x/./y/..` leads before running it.
- [ ] I can use `ls` flags (`-a`, `-A`, `-l`, `-h`, `-t`, `-r`, `-S`, `-d`, `-F`, `-i`) to answer questions about newest, largest, hidden, ownership, and links.
- [ ] My field guide gives a correct path and a proving command for all 16 items in task 7.
- [ ] I can describe every top-level directory in one sentence from memory.
- [ ] I can state where **config, logs, programs, and personal files** live, system-wide and per user.
- [ ] I found all six commands in task 10 with `apropos`, and I know to try another wording when a search fails.
- [ ] I can choose the right man section, read a SYNOPSIS, and navigate `less` with `/`, ++n++, ++g++, ++shift+g++, and ++q++.
- [ ] I know when to use `help` instead of `man`, and why.
- [ ] I can explain my UID, groups, `/etc/passwd` fields, and the `%sudo` rule.
- [ ] I can find my own `sudo` activity in the system log.
- [ ] I can explain why root is dangerous and what least privilege means in practice.
- [ ] (Stretch) I can explain the full path from typing `ll /etc` to seeing the output.

## Hints

??? tip "Hint for task 2: one relative cd"
    Count how many levels you need to climb from `2026-10` to reach `capstone0`: `2026-10` → `landing` → `warehouse` → `capstone0`. Each level is one `..`. Then descend into `jobs/nightly`.

??? tip "Hint for task 3: shortest commands"
    `cd` has a one-character argument that means "the previous directory", and needs no argument at all to go home.

??? tip "Hint for task 5: predicting paths"
    Work left to right, one component at a time, writing down where you are after each step. `.` means "stay here"; `..` means "go up one".

??? tip "Hint for task 6: ls sort order"
    `-t` sorts newest first; `-r` reverses it so the newest is last. `-S` sorts by size. To see a directory itself rather than its contents, add `-d`. To compare two paths at the file level, look at their inode numbers.

??? tip "Hint for task 7: where to look"
    Configuration: `/etc` and dotfiles. Logs: `/var/log`. Programs: use `type -a`. Package state: `/var/lib`. Caches: `/var/cache`. Kernel: `/boot` plus `uname -r`. Hardware and kernel info: `/proc` and `/sys`. Licenses: `/usr/share/doc`.

??? tip "Hint for task 10: apropos finds nothing"
    `apropos` searches the one-line NAME descriptions, which are short and written by programmers. If `apropos 'word count'` says "nothing appropriate", try a single word that might appear in the description, like `counts`, or limit the search to section 1 with `-s 1` to cut the noise. Then confirm with `whatis`.

??? tip "Hint for task 11: sections"
    File formats live in section 5. Put the section number before the page name.

??? tip "Hint for task 15: builtins"
    Run `type type` and `type history` first. If it says "shell builtin", the documentation comes from bash itself, not from a man page.

??? tip "Hint for task 16: compressed docs"
    Files ending in `.gz` can be read with `zcat` (pipe it into `head`) or `zless`.

??? tip "Hint for task 20: finding your sudo log line"
    You're probably in the `adm` group, which can read `/var/log/auth.log`. Use `grep` for `COMMAND=` and `tail` to see only the last few matches.

??? tip "Hint for task 22: the full path"
    Go back to [How the shell finds and runs a command](../chapters/00-first-steps/02-terminal-shell-prompt.md#how-the-shell-finds-and-runs-a-command). Start with the keystrokes reaching the terminal emulator and end with bash reading the exit status.

## Solution

Try every task yourself before looking. When you're done, compare with the [worked solution](solutions/level-0-capstone.md). Your outputs will differ in dates, sizes, and version numbers; what matters is that your commands and reasoning match.

When you can complete this capstone without notes, you're ready for [Level 1: Command-line fluency](../chapters/01-command-line/index.md).
