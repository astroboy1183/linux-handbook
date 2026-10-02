# Progress Checklist

Track every chapter, capstone, tier checkpoint, and milestone in the
handbook here. There are 54 chapters, 7 capstones, and 3 tier checkpoints.

!!! note "These checkboxes are visual only"
    Ticking a box on this website doesn't save anything. To track your real
    progress, copy this page's Markdown into your own notes or git repository
    (for example `~/linux-notes/progress.md`) and change `- [ ]` to `- [x]`
    as you finish each item. Committing each tick gives you a dated history
    of your progress for free.

A chapter counts as done when you have:

1. read it and typed every example yourself,
2. finished all its exercises without opening the solutions (or redone them
   the next day if you peeked),
3. answered the check-yourself questions from memory, and
4. written a short summary in your own words.

A capstone counts as done only when it **works without notes**.

## Getting started

- [ ] Read [How to use this handbook](start-here.md)
- [ ] Skimmed [the full roadmap](roadmap.md)
- [ ] Finished the first-day setup in [Set up your practice lab](lab-setup.md)
- [ ] Created `~/linux-notes` with a `mistakes.md` log and a copy of this checklist

## 🌱 Beginner tier

[Tier overview](tiers/beginner.md)

### Level 0: First Steps

- [ ] [Level 0 overview](chapters/00-first-steps/index.md)
- [ ] [What is Linux?](chapters/00-first-steps/01-what-is-linux.md)
- [ ] [The terminal, shell, and prompt](chapters/00-first-steps/02-terminal-shell-prompt.md)
- [ ] [Your first commands](chapters/00-first-steps/03-first-commands.md)
- [ ] [Getting help](chapters/00-first-steps/04-getting-help.md)
- [ ] [The filesystem layout](chapters/00-first-steps/05-filesystem-layout.md)
- [ ] [Users, groups, and sudo](chapters/00-first-steps/06-users-groups-sudo.md)
- [ ] **Capstone:** [Navigate confidently and explain where everything lives](exercises/level-0-capstone.md)

### Level 1: Command Line

- [ ] [Level 1 overview](chapters/01-command-line/index.md)
- [ ] [Working with files](chapters/01-command-line/01-working-with-files.md)
- [ ] [Globbing and expansion](chapters/01-command-line/02-globbing-and-expansion.md)
- [ ] [Permissions](chapters/01-command-line/03-permissions.md)
- [ ] [Pipes and redirection](chapters/01-command-line/04-pipes-and-redirection.md)
- [ ] [Text processing](chapters/01-command-line/05-text-processing.md)
- [ ] [Finding files](chapters/01-command-line/06-finding-files.md)
- [ ] [Shell productivity](chapters/01-command-line/07-shell-productivity.md)
- [ ] [Archives and compression](chapters/01-command-line/08-archives-and-compression.md)
- [ ] [Vim essentials](chapters/01-command-line/09-vim-essentials.md)
- [ ] [tmux](chapters/01-command-line/10-tmux.md)
- [ ] **Capstone:** [Answer real questions about a log file using only pipelines](exercises/level-1-capstone.md)

### Level 2: Scripting

- [ ] [Level 2 overview](chapters/02-scripting/index.md)
- [ ] [Your first script](chapters/02-scripting/01-first-script.md)
- [ ] [Variables, quoting, and arrays](chapters/02-scripting/02-variables-quoting-arrays.md)
- [ ] [Conditionals, loops, and functions](chapters/02-scripting/03-control-flow-functions.md)
- [ ] [Error handling](chapters/02-scripting/04-error-handling.md)
- [ ] [Arguments and getopts](chapters/02-scripting/05-arguments-getopts.md)
- [ ] [Bash or Python?](chapters/02-scripting/06-bash-vs-python.md)
- [ ] **Capstone:** [A backup script with options, logging, rotation, and dry-run mode](exercises/level-2-capstone.md)

### Beginner tier checkpoint

Without notes, you can:

- [ ] Explain the purpose of `/etc`, `/var/log`, `/usr/bin`, `/home`, and `/tmp`
- [ ] Write a pipeline that prints the 10 most frequent IP addresses in a web server log
- [ ] Explain why `x` permission on a directory differs from `x` on a file
- [ ] Write a script with `set -euo pipefail`, `trap`, and `getopts` that passes shellcheck
- [ ] Recover from a dropped SSH connection without losing a running job (tmux)

## 🔧 Intermediate tier

[Tier overview](tiers/intermediate.md)

### Level 3: How Linux Works

- [ ] [Level 3 overview](chapters/03-internals/index.md)
- [ ] [The boot process](chapters/03-internals/01-boot-process.md)
- [ ] [Processes and signals](chapters/03-internals/02-processes-and-signals.md)
- [ ] [Memory](chapters/03-internals/03-memory.md)
- [ ] [Filesystems, inodes, and links](chapters/03-internals/04-filesystems-and-links.md)
- [ ] [Devices, /proc, and /sys](chapters/03-internals/05-devices-proc-sys.md)
- [ ] [Installing software](chapters/03-internals/06-installing-software.md)
- [ ] **Capstone:** [Explain power-on to login, and keypress to `ls` output](exercises/level-3-capstone.md)

### Level 4: System Administration

- [ ] [Level 4 overview](chapters/04-sysadmin/index.md)
- [ ] [systemd and journalctl](chapters/04-sysadmin/01-systemd-and-journalctl.md)
- [ ] [Scheduling tasks](chapters/04-sysadmin/02-scheduling.md)
- [ ] [Networking basics](chapters/04-sysadmin/03-networking-basics.md)
- [ ] [Firewalls with ufw](chapters/04-sysadmin/04-firewall-ufw.md)
- [ ] [SSH](chapters/04-sysadmin/05-ssh.md)
- [ ] [Disks and backups](chapters/04-sysadmin/06-disks-and-backups.md)
- [ ] [Troubleshooting](chapters/04-sysadmin/07-troubleshooting.md)
- [ ] [User management and PAM](chapters/04-sysadmin/08-user-management.md)
- [ ] [Logging and logrotate](chapters/04-sysadmin/09-logging-and-logrotate.md)
- [ ] [LVM and RAID](chapters/04-sysadmin/10-lvm-and-raid.md)
- [ ] [Web servers and TLS](chapters/04-sysadmin/11-web-servers-and-tls.md)
- [ ] **Capstone:** [Build a secured server from scratch](exercises/level-4-capstone.md)

### Intermediate tier checkpoint

Without notes, you can:

- [ ] Explain what GRUB, the initramfs, and systemd each do during boot
- [ ] Explain what a zombie process is and how to get rid of one
- [ ] Explain the difference between "free" and "available" memory
- [ ] Write a systemd service and timer from scratch, and debug them with `journalctl`
- [ ] Explain how a DNS lookup works on Ubuntu, from `/etc/nsswitch.conf` to the stub resolver
- [ ] Rebuild the Level 4 capstone server in a fresh VM in under an hour

## 🚀 Expert tier

[Tier overview](tiers/expert.md)

### Level 5: Building for Linux

- [ ] [Level 5 overview](chapters/05-programming/index.md)
- [ ] [System calls and strace](chapters/05-programming/01-system-calls-strace.md)
- [ ] [File descriptors in code](chapters/05-programming/02-file-descriptors.md)
- [ ] [Processes and signals in code](chapters/05-programming/03-processes-signals-in-code.md)
- [ ] [Pipes and sockets](chapters/05-programming/04-pipes-and-sockets.md)
- [ ] [Your program as a service](chapters/05-programming/05-services-with-systemd.md)
- [ ] [Building software](chapters/05-programming/06-building-software.md)
- [ ] [Debugging](chapters/05-programming/07-debugging.md)
- [ ] **Capstone:** [A multi-client network server running as a systemd service](exercises/level-5-capstone.md)

### Level 6: Expert Topics

- [ ] [Level 6 overview](chapters/06-expert/index.md)
- [ ] [Containers from scratch](chapters/06-expert/01-containers-from-scratch.md)
- [ ] [Performance analysis](chapters/06-expert/02-performance-analysis.md)
- [ ] [Security](chapters/06-expert/03-security.md)
- [ ] [Kernel basics](chapters/06-expert/04-kernel-basics.md)
- [ ] [Advanced networking](chapters/06-expert/05-advanced-networking.md)
- [ ] [Virtualization](chapters/06-expert/06-virtualization.md)
- [ ] [Docker and Podman](chapters/06-expert/07-docker-and-podman.md)
- [ ] [Automation with Ansible](chapters/06-expert/08-automation-ansible.md)
- [ ] **Capstone:** [A minimal container with unshare and cgroups, or Linux From Scratch](exercises/level-6-capstone.md)

### Expert tier checkpoint

Without notes, you can:

- [ ] Explain, using `strace` output, every syscall `cat file.txt` makes
- [ ] Explain why a container is "just a process", and name each kernel feature that isolates it
- [ ] Find the hottest function in a CPU-bound program with `perf` and a flame graph
- [ ] Debug a segfault from a core dump with `gdb`
- [ ] Rebuild your Level 4 server with a single `ansible-playbook` run

## Milestones

Habits and real-world wins that show the skills are sticking.

- [ ] Studied on at least 5 days in one week
- [ ] Logged 10 entries in the "mistakes I made" log
- [ ] Solved a real problem at work or home with a pipeline
- [ ] Wrote a script you now use every week
- [ ] Set up a practice VM and took its first snapshot
- [ ] Broke the VM badly and recovered it from a snapshot
- [ ] Read a man page end to end to answer your own question
- [ ] SSH'd into your VM with a key, with password login disabled
- [ ] Fixed a broken service using only `systemctl status` and `journalctl`
- [ ] Explained a Linux concept to someone else
- [ ] Rebuilt a capstone from scratch, a month after you first finished it
- [ ] Finished all seven capstones
