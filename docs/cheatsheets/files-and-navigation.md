# Navigation and Files Cheat Sheet

Quick reference for moving around, managing files, reading them, archiving,
checking disk usage, and links. Chapters:
[Your first commands](../chapters/00-first-steps/03-first-commands.md),
[Working with files](../chapters/01-command-line/01-working-with-files.md),
[Archives and compression](../chapters/01-command-line/08-archives-and-compression.md),
[Filesystems, inodes, and links](../chapters/03-internals/04-filesystems-and-links.md).

## Paths at a glance

| Path | Meaning |
|---|---|
| `/` | The root of the whole filesystem |
| `~` | Your home directory (`/home/alex`) |
| `~bob` | Another user's home directory |
| `.` | The current directory |
| `..` | The parent directory |
| `-` | (with `cd`) the previous directory |
| `/etc/hosts` | **Absolute path**: starts at `/`, works from anywhere |
| `notes/todo.md` | **Relative path**: starts at the current directory |

## Moving around

| Command | What it does | Example |
|---|---|---|
| `pwd` | Print the current directory | `pwd` → `/home/alex/projects` |
| `cd DIR` | Change directory | `cd /var/log` |
| `cd` | Go home | `cd` |
| `cd -` | Go back to the previous directory | `cd -` |
| `cd ..` | Go up one level | `cd ../..` goes up two |
| `pushd DIR` / `popd` | Visit a directory, then return to where you were | `pushd /etc/nginx` … `popd` |
| `ls` | List a directory | `ls ~/Downloads` |
| `ls -l` | Long format: permissions, owner, size, date | `ls -l /etc/passwd` |
| `ls -a` | Include hidden "dotfiles" | `ls -a ~` |
| `ls -lh` | Human-readable sizes (K, M, G) | `ls -lh *.csv` |
| `ls -lt` / `ls -ltr` | Sort by time, newest first / oldest first | `ls -ltr /var/log` (newest at bottom) |
| `ls -lS` | Sort by size, largest first | `ls -lS ~/Downloads | head` |
| `ls -ld DIR` | Show the directory itself, not its contents | `ls -ld /tmp` |
| `ls -1` | One name per line (good for scripts) | `ls -1 *.log` |
| `tree -L 2` | Show a directory tree, 2 levels deep | `tree -L 2 -d ~/projects` (dirs only) |

## Creating, copying, moving, deleting

| Command | What it does | Example |
|---|---|---|
| `mkdir DIR` | Create a directory | `mkdir reports` |
| `mkdir -p A/B/C` | Create parents as needed; no error if it exists | `mkdir -p data/2026/10` |
| `touch FILE` | Create an empty file, or update its timestamp | `touch notes.md` |
| `cp SRC DST` | Copy a file | `cp config.ini config.ini.bak` |
| `cp -r SRC DST` | Copy a directory recursively | `cp -r site/ site-old/` |
| `cp -a SRC DST` | Archive copy: recursive, keeps permissions, times, links | `cp -a /etc/nginx ~/nginx-backup` |
| `cp -i` | Ask before overwriting | `cp -i new.csv data.csv` |
| `cp -u` | Copy only if source is newer | `cp -u *.csv backup/` |
| `mv SRC DST` | Move or rename | `mv draft.md final.md` |
| `mv -n` | Never overwrite an existing file | `mv -n *.jpg photos/` |
| `rm FILE` | Delete a file (no trash, no undo) | `rm old.log` |
| `rm -r DIR` | Delete a directory and everything in it | `rm -r build/` |
| `rm -I` | Ask once before deleting more than 3 files or recursing | `rm -rI build/` |
| `rmdir DIR` | Delete an empty directory only | `rmdir empty/` |

!!! danger "`rm` has no undo"
    There's no trash can on the command line. Check a glob first with `ls`
    (`ls *.tmp`, then `rm *.tmp`). Never run `rm -rf` on a path built from a
    variable that might be empty.

## Viewing files

| Command | What it does | Example |
|---|---|---|
| `cat FILE` | Print a whole file | `cat /etc/os-release` |
| `less FILE` | Page through a file (see keys below) | `less /var/log/syslog` |
| `head -n N` | First N lines (default 10) | `head -n 5 data.csv` |
| `tail -n N` | Last N lines | `tail -n 50 app.log` |
| `tail -f` | Follow a file as it grows | `tail -f /var/log/syslog` |
| `tail -F` | Follow, and reopen if the file is rotated | `tail -F app.log` |
| `tail -n +2` | Everything from line 2 (skip a header) | `tail -n +2 data.csv` |
| `wc -l` | Count lines (`-w` words, `-c` bytes) | `wc -l *.csv` |
| `file FILE` | Guess the file type from its contents | `file mystery.bin` |
| `stat FILE` | Size, inode, permissions, timestamps | `stat report.pdf` |
| `diff -u A B` | Show differences between two files | `diff -u old.conf new.conf` |
| `cmp A B` | Check if two files are byte-for-byte equal | `cmp a.bin b.bin` |
| `sha256sum FILE` | Checksum a file | `sha256sum ubuntu.iso` |
| `realpath PATH` | Full absolute path, symlinks resolved | `realpath ../notes` |
| `basename` / `dirname` | Last part / directory part of a path | `basename /var/log/syslog` → `syslog` |

### `less` keys

| Key | Action | Key | Action |
|---|---|---|---|
| ++space++ / ++b++ | Page down / up | `/text` | Search forward |
| ++g++ / ++shift+g++ | Start / end of file | `?text` | Search backward |
| ++n++ / ++shift+n++ | Next / previous match | ++shift+f++ | Follow mode, like `tail -f` (++ctrl+c++ to stop) |
| `-S` | Toggle line wrapping | ++q++ | Quit |

## Archives and compression

A **tarball** bundles many files into one `.tar` file; compression shrinks
it. `tar` does both. Remember the letters: **c**reate, e**x**tract,
lis**t**, **f**ile, **v**erbose, **z** gzip, **j** bzip2, **J** xz.

| Task | Command |
|---|---|
| Create `.tar.gz` | `tar -czf backup.tar.gz project/` |
| Create `.tar.xz` (smaller, slower) | `tar -cJf backup.tar.xz project/` |
| Create `.tar.zst` (fast and small) | `tar --zstd -cf backup.tar.zst project/` |
| Pick compression from the name | `tar -caf backup.tar.zst project/` |
| List contents | `tar -tf backup.tar.gz` (add `-v` for details) |
| Extract here | `tar -xf backup.tar.gz` (compression is auto-detected) |
| Extract into a directory | `tar -xf backup.tar.gz -C /tmp/restore` |
| Extract one file | `tar -xf backup.tar.gz project/config.ini` |
| Print one file to stdout | `tar -xOf backup.tar.gz project/config.ini` |
| Drop the top-level directory | `tar -xf app-1.2.tar.gz --strip-components=1 -C app/` |
| Exclude files | `tar --exclude='*.log' -czf src.tar.gz project/` |
| Copy a directory over SSH | `tar -czf - project/ | ssh alex@lab 'tar -xzf - -C ~'` |

| Single-file tool | Compress | Decompress | Read without extracting |
|---|---|---|---|
| gzip (`.gz`) | `gzip big.log` (`-k` keeps original) | `gunzip big.log.gz` | `zcat`, `zless`, `zgrep` |
| bzip2 (`.bz2`) | `bzip2 big.log` | `bunzip2 big.log.bz2` | `bzcat` |
| xz (`.xz`) | `xz -T0 big.log` (all CPU cores) | `unxz big.log.xz` | `xzcat` |
| zstd (`.zst`) | `zstd big.log` | `unzstd big.log.zst` | `zstdcat` |
| zip (`.zip`) | `zip -r site.zip site/` | `unzip site.zip -d site/` | `unzip -l site.zip` |

!!! tip "Look before you extract"
    Run `tar -tf file.tar.gz | head` first. If the archive doesn't have a
    single top-level directory, extract it into a new empty directory with
    `-C`, so it doesn't scatter files everywhere.

## Disk usage

| Command | What it does | Example |
|---|---|---|
| `df -h` | Free space on each mounted filesystem | `df -h /` |
| `df -hT` | Same, plus the filesystem type | `df -hT` |
| `df -i` | Inode usage (a disk can be "full" of tiny files) | `df -i /` |
| `du -sh DIR` | Total size of a directory | `du -sh ~/Downloads` |
| `du -h -d 1 DIR | sort -h` | Size of each subdirectory, sorted | `du -h -d 1 ~ | sort -h` |
| `du -sh * | sort -h` | Size of everything here, sorted | `du -sh /var/log/* | sort -h` |
| `ncdu DIR` | Interactive explorer; delete with ++d++ | `ncdu ~` |
| `lsblk` | Block devices and where they're mounted | `lsblk -f` (with filesystems and UUIDs) |

Find big or old files:

```bash
find ~ -type f -size +500M -exec ls -lh {} +       # files over 500 MB
find /var/log -name '*.gz' -mtime +30              # compressed logs older than 30 days
find . -type f -printf '%s %p\n' | sort -rn | head # 10 largest files, in bytes
```

## Links

A **hard link** is a second name for the same inode (the same data). A
**symbolic link** (symlink) is a small file that points to a path.

| Command | What it does | Example |
|---|---|---|
| `ln -s TARGET LINK` | Create a symlink | `ln -s /opt/app-2.1 /opt/app` |
| `ln -sfn TARGET LINK` | Repoint an existing symlink | `ln -sfn /opt/app-2.2 /opt/app` |
| `ln TARGET LINK` | Create a hard link (same filesystem, files only) | `ln data.csv data-link.csv` |
| `readlink LINK` | Show where a symlink points | `readlink /opt/app` |
| `readlink -f PATH` | Resolve all symlinks to a final absolute path | `readlink -f /usr/bin/vi` |
| `ls -li` | Show inode numbers (hard links share one) | `ls -li data*.csv` |
| `stat -c %h FILE` | Number of hard links | `stat -c %h data.csv` |
| `find -samefile F` | Find all hard links to a file | `find ~ -samefile data.csv` |
| `find -xtype l` | Find broken symlinks | `find ~ -xtype l` |

```text
-rw-rw-r-- 2 alex alex 6 Oct  2 10:45 data.csv        ← link count 2: two names, one inode
lrwxrwxrwx 1 alex alex 8 Oct  2 10:45 latest -> data.csv   ← symlink: type "l", shows its target
```

| | Hard link | Symbolic link |
|---|---|---|
| Points to | An inode (the data) | A path (a name) |
| Works across filesystems | No | Yes |
| Can link to directories | No | Yes |
| If the original is deleted | Data survives | Link breaks ("dangling") |

!!! warning "Common mistake: symlink argument order"
    It's `ln -s TARGET LINK_NAME`, the same order as `cp SOURCE DEST`. A
    relative target is resolved from the *link's* directory, not from where
    you ran the command.

## Finding files fast

| Command | What it does | Example |
|---|---|---|
| `find DIR -name PAT` | Search by name (quote the pattern) | `find ~ -name '*.csv'` |
| `find DIR -iname PAT` | Case-insensitive name | `find . -iname 'readme*'` |
| `find DIR -type d` | Directories only (`f` files, `l` symlinks) | `find /etc -type d -name '*.d'` |
| `find DIR -mtime -1` | Modified in the last 24 hours | `find ~/projects -mtime -1` |
| `find ... -exec CMD {} +` | Run a command on the results | `find . -name '*.tmp' -exec rm {} +` |
| `locate NAME` | Search a prebuilt index (fast, may be stale) | `locate sshd_config` |
| `which CMD` | Where a command lives in `PATH` | `which python3` |
| `type CMD` | What the shell will run: alias, builtin, or file | `type ls cd` |
