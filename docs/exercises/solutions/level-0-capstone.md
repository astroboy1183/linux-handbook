# Level 0 capstone: worked solution

> **Level 0 · Capstone solution** · Task list: [Level 0 capstone](../level-0-capstone.md)

This is one complete, worked answer to the [Level 0 capstone](../level-0-capstone.md). Your dates, sizes, version numbers, and hardware names will differ. Your commands and reasoning should match. Where several commands work, the alternatives are noted.

!!! warning "Try it first"
    Reading a solution teaches far less than struggling with the task for ten minutes. If you haven't attempted the capstone yet, go back and do that first.

## Part 1: Navigate

### Task 1: Tab completion into 2026-10

Type `cd ca` ++tab++ `w` ++tab++ `l` ++tab++ `2026-1` ++tab++ ++enter++. Bash completes each directory name and adds a `/`. At `landing/`, both `2026-09` and `2026-10` start with `2026-`, so you type enough (`2026-1`) to make it unique.

```bash
cd ~/capstone0/warehouse/landing/2026-10
pwd
```

```text
/home/alex/capstone0/warehouse/landing/2026-10
```

### Task 2: One relative cd

Three levels up gets you from `2026-10` to `capstone0` (`2026-10` → `landing` → `warehouse` → `capstone0`), then down into `jobs/nightly`:

```bash
cd ../../../jobs/nightly
pwd
```

```text
/home/alex/capstone0/jobs/nightly
```

### Task 3: Shortest way back, shortest way home

```bash
cd -
cd
pwd
```

```text
/home/alex/capstone0/warehouse/landing/2026-10
/home/alex
```

`cd -` switches to the previous directory (stored in `OLDPWD`) and prints it. `cd` with no argument goes to `$HOME`.

### Task 4: List hidden files without moving

```bash
ls -A ~/capstone0/docs
```

```text
README.md  .runbook
```

`-A` shows hidden entries but leaves out `.` and `..`. (`-a` would include them.) `ls -lA ~/capstone0/docs` adds details.

### Task 5: Predict a relative path

Start in `~/capstone0/jobs/hourly` and walk `../../warehouse/./curated/..` one part at a time:

| Step | Component | Now in |
|---|---|---|
| start | | `~/capstone0/jobs/hourly` |
| 1 | `..` | `~/capstone0/jobs` |
| 2 | `..` | `~/capstone0` |
| 3 | `warehouse` | `~/capstone0/warehouse` |
| 4 | `.` | `~/capstone0/warehouse` (unchanged) |
| 5 | `curated` | `~/capstone0/warehouse/curated` |
| 6 | `..` | `~/capstone0/warehouse` |

Verify:

```bash
cd ~/capstone0/jobs/hourly
cd ../../warehouse/./curated/..
pwd
```

```text
/home/alex/capstone0/warehouse
```

### Task 6: Questions answered with ls

**6.1: The five most recent entries in `/var/log`, newest at the bottom.**

```bash
ls -ltr /var/log | tail -5
```

```text
-rw-r--r--  1 root   root      312560 Oct  2 10:25 dpkg.log
-rw-r-----  1 syslog adm       587681 Oct  2 10:43 kern.log
-rw-r--r--  1 root   root       20194 Oct  2 10:44 mintupdate.log
-rw-r-----  1 syslog adm        43659 Oct  2 10:44 auth.log
-rw-r-----  1 syslog adm      1891754 Oct  2 10:44 syslog
```

`-t` sorts newest first, `-r` reverses it so the newest is last, and `tail -5` keeps the last five lines.

**6.2: The three largest files in `/usr/bin`.**

```bash
ls -lhS /usr/bin | head -4
```

```text
total 628M
-rwxr-xr-x 1 root root     107M Oct  1 01:02 dockerd
-rwxr-xr-x 1 root root      46M Oct  1 01:02 docker
-rwxr-xr-x 1 root root      44M Jul 18  2025 gh
```

This output is from a developer machine with Docker and the GitHub CLI installed. The names depend entirely on what's installed, so yours will differ. The first line is the `total`, so `head -4` shows the top three files. `-S` sorts by size, largest first; `-h` makes sizes readable.

**6.3: Symbolic links in `/`.**

```bash
ls -l / | grep '^l'
```

```text
lrwxrwxrwx   1 root root          7 Jun  9 19:01 bin -> usr/bin
lrwxrwxrwx   1 root root          7 Jun  9 19:01 lib -> usr/lib
lrwxrwxrwx   1 root root          9 Jun  9 19:01 lib64 -> usr/lib64
lrwxrwxrwx   1 root root          8 Jun  9 19:01 sbin -> usr/sbin
```

Lines starting with `l` are symlinks; `grep '^l'` keeps only those. Without `grep`, `ls -F /` marks them with `@`, and `ls -l /` shows them among the rest. These four links exist because Mint uses merged /usr.

**6.4: `/tmp` itself.**

```bash
ls -ld /tmp
```

```text
drwxrwxrwt 21 root root 4096 Oct  2 10:37 /tmp
```

Owner `root`, group `root`, permissions `rwxrwxrwt`: everyone can read, write, and enter. The final `t` is the **sticky bit**: although anyone can create files here, users can only delete or rename their own. Without `-d`, `ls -l /tmp` would list the contents instead.

**6.5: `/bin/bash` and `/usr/bin/bash` are one file.**

```bash
ls -i /bin/bash /usr/bin/bash
readlink -f /bin/bash
```

```text
4587731 /bin/bash  4587731 /usr/bin/bash
/usr/bin/bash
```

The same inode number means the same file on disk. `readlink -f` follows the `/bin -> usr/bin` link to the real path.

## Part 2: Map the system

### Task 7: Where things live

| # | Item | Path | Proving command |
|---|---|---|---|
| a | SSH client system config | `/etc/ssh/ssh_config` | `ls -l /etc/ssh/ssh_config` |
| b | Your bash settings | `~/.bashrc` (`/home/alex/.bashrc`) | `ls -l ~/.bashrc` |
| c | Template for new users | `/etc/skel/.bashrc` | `ls -lA /etc/skel` |
| d | `sudo` usage log | `/var/log/auth.log` | `ls -l /var/log/auth.log` |
| e | Package install log | `/var/log/dpkg.log` and `/var/log/apt/history.log` | `tail -n 3 /var/log/dpkg.log` |
| f | `python3` | `/usr/bin/python3`, a symlink to `python3.12` | `type -a python3` then `ls -l /usr/bin/python3` |
| g | Mint's `apt` | `/usr/local/bin/apt` | `type -a apt` |
| h | Package database | `/var/lib/dpkg/` | `ls /var/lib/dpkg` |
| i | Downloaded `.deb` cache | `/var/cache/apt/archives/` | `ls /var/cache/apt/archives` |
| j | Running kernel file | `/boot/vmlinuz-6.14.0-37-generic` | `uname -r` then `ls -l /boot` |
| k | CPU details | `/proc/cpuinfo` | `grep -m1 'model name' /proc/cpuinfo` |
| l | Network interfaces | `/sys/class/net/` | `ls /sys/class/net` |
| m | Temp files that survive reboot | `/var/tmp` | `ls -ld /var/tmp` |
| n | USB stick `BACKUP` | `/media/alex/BACKUP` | `ls /media/alex` (with the stick plugged in) |
| o | License of `ls`'s package | `/usr/share/doc/coreutils/copyright` | `grep -m1 License /usr/share/doc/coreutils/copyright` |
| p | Private runtime directory | `/run/user/1000` | `id -u` then `ls -ld /run/user/1000` |

A few of these deserve a closer look.

**f: python3.**

```bash
type -a python3
ls -l /usr/bin/python3
```

```text
python3 is /usr/bin/python3
python3 is /bin/python3
lrwxrwxrwx 1 root root 10 Apr 10  2024 /usr/bin/python3 -> python3.12
```

`python3` is a symlink to the real interpreter, `python3.12`. The second line appears because `/bin` is a link to `/usr/bin`, and PATH contains both.

!!! note "Your type -a output may vary"
    Depending on your PATH, `type -a python3` might list fewer lines. If you've installed Python another way (pyenv, conda, `~/.local/bin`), an earlier PATH entry wins, and that's exactly the kind of thing this command is for.

**g: Mint's apt.**

```bash
type -a apt
```

```text
apt is /usr/local/bin/apt
apt is /usr/bin/apt
apt is /bin/apt
```

`/usr/local/bin` comes before `/usr/bin` in PATH, so Mint's wrapper runs first. It adds friendlier output and extra subcommands, then calls the real `apt`.

**j: the running kernel.**

```bash
uname -r
ls /boot
```

```text
6.14.0-37-generic
config-6.14.0-36-generic      initrd.img-6.14.0-37-generic  vmlinuz
config-6.14.0-37-generic      initrd.img.old                vmlinuz-6.14.0-36-generic
efi                           System.map-6.14.0-36-generic  vmlinuz-6.14.0-37-generic
grub                          System.map-6.14.0-37-generic  vmlinuz.old
initrd.img                    initrd.img-6.14.0-36-generic
```

The running kernel's file is the `vmlinuz-` file matching `uname -r`: `/boot/vmlinuz-6.14.0-37-generic`.

**p: your runtime directory.** It's named after your UID:

```bash
id -u
ls -ld /run/user/1000
```

```text
1000
drwx------ 19 alex alex 680 Oct  2 10:27 /run/user/1000
```

### Task 8: Top-level directories in one sentence

| Directory | One sentence |
|---|---|
| `/` | The root of the single directory tree; every path starts here. |
| `/bin` | On Mint, a symlink to `/usr/bin`, kept so old paths like `/bin/bash` still work. |
| `/boot` | The kernel, initial RAM disk, and bootloader files needed to start the system. |
| `/dev` | Device files: disks, terminals, and special devices like `/dev/null`, created by the kernel and udev. |
| `/etc` | System-wide configuration, mostly plain-text files edited by administrators and packages. |
| `/home` | One personal directory per regular user, where their own files live. |
| `/media` | Where removable media like USB sticks are mounted automatically, under `/media/<user>/<label>`. |
| `/mnt` | An empty spot for an administrator to mount a filesystem by hand, temporarily. |
| `/opt` | Self-contained third-party software installed outside the package manager. |
| `/proc` | A virtual filesystem with one directory per process plus kernel and hardware information. |
| `/root` | The root user's home directory, kept outside `/home` so it's available even if `/home` isn't. |
| `/run` | In-memory runtime data since the last boot: PID files, sockets, per-user runtime dirs. |
| `/srv` | Data this machine serves to others (websites, FTP); usually empty on Mint. |
| `/sys` | A virtual filesystem describing devices, drivers, and kernel subsystems. |
| `/tmp` | World-writable temporary files with the sticky bit, emptied at every boot. |
| `/usr` | Installed programs, libraries, and shared data managed by the package manager; `/usr/local` is for hand-installed software. |
| `/var` | Data that changes while the system runs: logs, service state, caches, spools. |

### Task 9: The four categories

| Category | System-wide | Per user |
|---|---|---|
| **Config** | `/etc` (e.g. `/etc/ssh/ssh_config`, `/etc/bash.bashrc`) | Dotfiles (`~/.bashrc`, `~/.profile`, `~/.gitconfig`) and `~/.config/` |
| **Logs** | `/var/log` (`syslog`, `auth.log`, `kern.log`, `dpkg.log`, per-service directories) and the systemd journal in `/var/log/journal` | Some apps in `~/.local/state/` or `~/.cache/` |
| **Programs** | `/usr/bin` and `/usr/sbin` (packages); `/usr/local/bin` and `/opt` (installed by hand) | `~/.local/bin` |
| **Personal files** | | `/home/alex` (and `/root` for root) |

Closely related: service data in `/var/lib`, caches in `/var/cache` and `~/.cache`, temporary files in `/tmp` and `/var/tmp`, documentation in `/usr/share/man` and `/usr/share/doc`.

## Part 3: Documentation without a browser

### Task 10: Find commands with apropos

**10.1: Count lines and words.**

```bash
apropos 'word count'
apropos -s 1 counts
```

```text
word count: nothing appropriate.
wc (1)               - print newline, word, and byte counts for each file
```

The phrase "word count" isn't in any description. The word `counts` is, in `wc`'s. If extra tools are installed you may see a few more matches, such as `editdiff` from patchutils ("fix offsets and counts of a hand-edited diff"); `whatis wc` confirms the right one. (Searching for `count` alone matches dozens of unrelated pages containing "account", which is a good lesson in why shorter isn't always better.)

**10.2: Free disk space.**

```bash
apropos 'disk space'
apropos 'space usage'
```

```text
disk space: nothing appropriate.
df (1)               - report file system space usage
du (1)               - estimate file space usage
```

`df` reports free space per filesystem. `du` measures how much space files use.

**10.3: Compress a file.**

```bash
apropos -s 1 compress | grep -i '^gzip'
whatis gzip
```

```text
gzip (1)             - compress or expand files
gzip (1)             - compress or expand files
```

`apropos -s 1 compress` alone returns a long list (`bzip2`, `xz`, `zip`, `7z`...). Any of the general-purpose ones is a valid answer; `gzip` is the classic.

**10.4: Sort lines.**

```bash
apropos 'sort lines'
```

```text
sort (1)             - sort lines of text files
```

**10.5: How long the system has been running.**

```bash
apropos 'how long'
```

```text
uptime (1)           - Tell how long the system has been running.
```

**10.6: Determine file type.**

```bash
apropos -s 1 'file type'
```

```text
[ (1)                - check file types and compare values
file (1)             - determine file type
grub-file (1)        - check file type
test (1)             - check file types and compare values
...
```

`file` is the answer. `test` and `[` check whether something is a file or directory in scripts, which is a different job.

### Task 11: Man pages for file formats

```bash
man 5 fstab
man 5 hosts
```

```text
FSTAB(5)                   File Formats                   FSTAB(5)

NAME
       fstab - static information about the filesystems
...
```

Section 5 holds file formats. The number matters when a name exists in several sections: `man passwd` opens the **command** (section 1), while `man 5 passwd` opens the **file format**. `whatis fstab hosts` confirms which sections exist.

### Task 12: df with human sizes and types

```bash
df --help | grep -E -- '-(h|T),'
```

```text
  -h, --human-readable  print sizes in powers of 1024 (e.g., 1023M)
  -T, --print-type      print file system type
```

(In `man df`, type `/^ +-T` to jump straight to the `-T` definition.)

```bash
df -hT /
```

```text
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/nvme0n1p2 ext4  468G   61G  384G  14% /
```

| Column | Meaning |
|---|---|
| Filesystem | The device holding the filesystem: partition 2 of the first NVMe disk |
| Type | The filesystem format: `ext4`, Linux's standard |
| Size | Total capacity |
| Used | Space in use |
| Avail | Space available to normal users. Size minus Used is slightly more than Avail, because ext4 reserves about 5% for root |
| Use% | Used as a percentage. Above 90% on a server is a warning sign |
| Mounted on | Where in the tree this filesystem is attached: here, `/` itself |

### Task 13: Count lines with wc

```bash
wc --help | grep -- '-l,'
wc -l /etc/passwd
```

```text
  -l, --lines            print the newline counts
45 /etc/passwd
```

One line per account, so 45 accounts. `wc -l < /etc/passwd` prints just the number without the file name.

### Task 14: The mv synopsis

```bash
man mv
```

```text
SYNOPSIS
       mv [OPTION]... [-T] SOURCE DEST
       mv [OPTION]... SOURCE... DIRECTORY
       mv [OPTION]... -t DIRECTORY SOURCE...
```

| Line | Meaning |
|---|---|
| 1 | Move or rename one `SOURCE` to `DEST`. `-T` forces `DEST` to be treated as a plain name, never as a directory to move into |
| 2 | Move one or more `SOURCE`s (`...` = repeatable) into an existing `DIRECTORY`, which must come last |
| 3 | The same, but name the `DIRECTORY` first with `-t`, then the sources |

Everything in `[ ]` is optional. Moving three CSV files into `curated` uses form 2:

```bash
mv a.csv b.csv c.csv ~/capstone0/warehouse/curated/
```

Form 3 would be `mv -t ~/capstone0/warehouse/curated/ a.csv b.csv c.csv`. (You don't need to run either; `mv` is taught in Level 1.)

### Task 15: Docs for builtins

```bash
type type history
```

```text
type is a shell builtin
history is a shell builtin
```

Both are builtins, so use `help`:

```bash
help type
```

```text
type: type [-afptP] name [name ...]
    Display information about command type.
...
      -P	force a PATH search for each NAME, even if it is an alias,
    		builtin, or function, and returns the name of the disk file
    		that would be executed
...
```

`type -P name` ignores aliases, builtins, and functions and prints the program file that a PATH search finds, like `which` does.

```bash
help history
```

```text
history: history [-c] [-d offset] [n] or history -anrw [filename] or history -ps arg [arg...]
    Display or manipulate the history list.
...
```

What about `man history`? Check what it would open first:

```bash
whatis history
```

```text
history (3readline)  - GNU History Library
```

On Mint, `man history` opens `history(3readline)`, the manual for the GNU History **C library** that programs use to store input lines. (On a system without that page you'd get `No manual entry for history`.) Either way, it isn't the bash builtin you're using. The builtin's documentation lives in bash: `help history`, or the SHELL BUILTIN COMMANDS section of `man bash`.

### Task 16: Bash's README

```bash
ls /usr/share/doc/bash
zcat /usr/share/doc/bash/README.gz | head -5
```

```text
changelog.Debian.gz  INTRO.gz  README.abs-guide    README.md.bash_completion.gz
COMPAT.gz            NEWS.gz   README.commands.gz
copyright            POSIX.gz  README.Debian.gz
inputrc.arrows       RBASH     README.gz
Introduction
============

This is GNU Bash, version 5.2. Bash is the GNU Project's Bourne
Again SHell, a complete implementation of the POSIX shell spec,
```

`zcat` decompresses to the screen only; nothing is written to disk. `zless /usr/share/doc/bash/README.gz` lets you scroll it.

## Part 4: Who you are

### Task 17: Identity and groups

```bash
whoami
id
```

```text
alex
uid=1000(alex) gid=1000(alex) groups=1000(alex),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),100(users),105(lpadmin),125(sambashare)
```

- Username `alex`, UID 1000 (the first human account).
- Primary group `alex` (GID 1000), a private group just for this user.
- Supplementary groups: `adm`, `cdrom`, `sudo`, `dip`, `plugdev`, `users`, `lpadmin`, `sambashare`.
- `sudo` membership matches the `%sudo` rule in `/etc/sudoers`, which lets you run any command as root after typing your own password. It's what makes you an administrator.
- `adm` membership lets you read system logs such as `/var/log/syslog` and `/var/log/auth.log`, which are group-readable by `adm`. That's read access only, with no other power.

### Task 18: Your passwd line vs www-data

```bash
grep -E '^(alex|www-data):' /etc/passwd
```

```text
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
alex:x:1000:1000:Alex Example,,,:/home/alex:/bin/bash
```

| Field | `alex` | `www-data` |
|---|---|---|
| 1. Username | `alex` | `www-data` |
| 2. Password | `x` (hash in `/etc/shadow`) | `x` |
| 3. UID | `1000` (human range) | `33` (fixed system range) |
| 4. Primary GID | `1000` | `33` |
| 5. GECOS | `Alex Example,,,` | `www-data` |
| 6. Home | `/home/alex` | `/var/www` |
| 7. Shell | `/bin/bash` | `/usr/sbin/nologin` |

`www-data` is a service account for web servers. Its shell is `nologin` so that nobody can log in as it interactively; it exists only to run the web server with limited rights. If the web server is compromised, the attacker gets `www-data`'s narrow access, not a login shell and not your files.

### Task 19: What sudo allows

```bash
sudo -l
```

```text
[sudo] password for alex: ********
Matching Defaults entries for alex on mint:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin,
    use_pty, pwfeedback

User alex may run the following commands on mint:
    (ALL : ALL) ALL
```

`sudo -l` only lists; it runs nothing as root. The rule that grants this is `%sudo ALL=(ALL:ALL) ALL` in `/etc/sudoers`:

| Part | Meaning |
|---|---|
| `%sudo` | Members of the group `sudo` (`%` marks a group) |
| `ALL` | On any host |
| `(ALL:ALL)` | As any user and any group |
| `ALL` | Any command |

### Task 20: Find your own sudo in the log

```bash
sudo whoami
grep 'COMMAND=/usr/bin/whoami' /var/log/auth.log | tail -1
```

```text
root
2026-10-02T11:02:40.112903+00:00 mint sudo:     alex : TTY=pts/0 ; PWD=/home/alex ; USER=root ; COMMAND=/usr/bin/whoami
```

| Field | Value | Meaning |
|---|---|---|
| Timestamp | `2026-10-02T11:02:40...` | When it happened |
| Host | `mint` | Which machine |
| Program | `sudo:` | Who logged it |
| Who | `alex` | The person who ran `sudo` |
| `TTY` | `pts/0` | The terminal it came from |
| `PWD` | `/home/alex` | The working directory |
| `USER` | `root` | The identity the command ran as |
| `COMMAND` | `/usr/bin/whoami` | Exactly what ran, with its full path |

### Task 21: Why not sudo pip install

A sample answer:

> `sudo pip install pandas` runs pip as root and installs into the system's own Python, which belongs to the package manager. That can overwrite or conflict with packages Mint's own tools depend on, and it leaves root-owned files that cause permission errors later. It also gives full root power to whatever code the package runs during installation. Least privilege says to give each task only the access it needs: install Python packages as yourself, in a virtual environment (`python3 -m venv`) or with `pipx`, and save `sudo` for changes that genuinely need to modify the system.

## Part 5: Explain it

### Task 22: From `ll /etc` to the next prompt

A sample answer:

1. You type `ll /etc`. The **terminal emulator** (GNOME Terminal) sends each keystroke through the **pseudo-terminal** `/dev/pts/0` to **bash**, which shows them via readline.
2. You press ++enter++. Bash reads the complete line and splits it into words: `ll` and `/etc`.
3. Bash checks whether `ll` is an **alias**. It is: Mint's `~/.bashrc` defines `ll` as `ls -alF`. The line becomes `ls -alF /etc`. Then `ls` itself is also an alias, for `ls --color=auto`, so the line becomes `ls --color=auto -alF /etc`.
4. Bash checks keywords, functions, and builtins for `ls`. There's no match, so `ls` is an external command.
5. Bash looks in its hash table, or searches the **PATH** directories left to right, and finds the program file `/usr/bin/ls`.
6. Bash asks the **kernel** to **fork** a child process, a copy of bash running as `alex`. The child calls **exec** to replace itself with `/usr/bin/ls`, passing the arguments `--color=auto`, `-alF`, and `/etc`.
7. `ls` makes **system calls** asking the kernel to open and read the directory `/etc`, and to look up each entry's inode (owner, permissions, size, time) because of `-l`. The kernel checks that `alex` is allowed to read `/etc`; it is.
8. `ls` looks up user and group names in `/etc/passwd` and `/etc/group`, sorts the entries by name according to the locale, adds `-F` type markers, and adds colour codes because its output is a terminal.
9. `ls` writes the text to its standard output, which is the pseudo-terminal. The terminal emulator draws it on screen.
10. `ls` exits with **status 0** (success). The kernel tells bash its child has finished.
11. Bash stores `0` in `$?`, expands **PS1**, and prints the next prompt, `alex@mint:~$`, ready for the next command.

## Where to go next

If you could do all of this without notes, Level 0 is complete. Tick it off in your [progress checklist](../../progress.md) and move on to [Level 1: Command-line fluency](../../chapters/01-command-line/index.md).

If some parts needed the chapters, note which ones in your mistakes log, revisit those chapters, and try the capstone again in a few days.
