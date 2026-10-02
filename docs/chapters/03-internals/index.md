# Level 3: How Linux works

> **Level 3 · Overview** · ⏱️ ~5 hours of reading, plus 8–12 hours of exercises and the capstone · Prerequisites: [Level 2: Shell scripting](../02-scripting/index.md)

Levels 0 to 2 taught you to *use* Linux. Level 3 opens the machine up. You'll follow the computer from the power button to the login screen, then look underneath the commands you already know: what a process really is, where memory goes, how files and links are stored, how the kernel exposes hardware as files, and how software gets installed and trusted.

Nothing here is theory for its own sake. Every concept comes with commands you can run on your Mint machine to see it happening, and every chapter ends with the kind of problem it helps you solve: a disk that's "full" after you deleted the big file, a job that vanished with exit code 137, a "free memory" number that looks alarming but isn't, a boot that hangs at a black screen.

## What you'll be able to do

By the end of this level, you'll be able to:

- Describe every stage of the boot process (firmware, shim, GRUB, kernel, initramfs, systemd, display manager) and find out how long each took and where a broken boot failed.
- Explain what a process is, how fork and exec create one, what each process state means, and read `ps`, `top`, and `htop` fluently, including load average.
- Stop, pause, resume, and detach programs with signals and job control, and keep long jobs alive when your terminal closes.
- Explain virtual memory, the page cache, and swap, read `free`, `vmstat`, and `/proc/meminfo` correctly, and recognize an OOM kill.
- Explain inodes, hard links, and symbolic links, mount filesystems safely, write `/etc/fstab` entries by UUID, and explain any disagreement between `df` and `du`.
- Use `/dev`, `/proc`, and `/sys` to inspect hardware, processes, and the kernel directly, and show that tools like `ps` and `free` are just reading those files.
- Install, inspect, and remove software with `apt` and `dpkg`, judge the trust implications of PPAs, and choose sensibly between apt, Flatpak, Snap, AppImage, source builds, and Python virtual environments.

## Chapters

| # | Chapter | What it covers | Time |
|---|---|---|---|
| 1 | [The boot process](01-boot-process.md) | UEFI and Secure Boot, shim, GRUB and the kernel command line, the kernel and initramfs, systemd units and targets, LightDM and login. Measuring boot with `systemd-analyze` | ~45 min |
| 2 | [Processes and signals](02-processes-and-signals.md) | Programs vs processes, fork and exec, the process tree, states and zombies, `ps`/`top`/`htop`, load average, nice, signals, `kill`, job control, `nohup`, `tmux` | ~50 min |
| 3 | [Memory](03-memory.md) | Virtual memory, pages and the MMU, address-space layout, shared libraries, the page cache, swap and swappiness, the OOM killer, `free`, `vmstat`, RSS vs PSS | ~50 min |
| 4 | [Filesystems, inodes, and links](04-filesystems-and-links.md) | Block devices and partitions, filesystems and the VFS, inodes, hard and symbolic links, deleted-but-open files, mounting and fstab, `df` vs `du`, `lsblk`, `ncdu` | ~50 min |
| 5 | [Devices, /proc, and /sys](05-devices-proc-sys.md) | Block and character devices, major/minor numbers, pseudo-devices, udev, per-process `/proc` files, `/sys`, hardware tools, and proving that tools read `/proc` | ~45 min |
| 6 | [Installing software](06-installing-software.md) | dpkg vs apt, repositories and signatures, update/upgrade/full-upgrade, PPAs, Mint's Update Manager, Snap vs Flatpak vs AppImage, building from source, pip and PEP 668 | ~55 min |

Read the chapters in order: each one builds on the last. Processes need the boot chapter's PID 1; memory needs processes; filesystems need the page cache; `/proc` and `/sys` tie everything together; and installing software uses all of it.

## How long it takes

Plan on about **two to three weeks** at 45–60 minutes a day:

- **Reading**: about 5 hours in total, but read with a terminal open and run the examples as you go, which roughly doubles it.
- **Exercises**: each chapter has five, from easy to hard. Allow 1–2 hours per chapter.
- **Capstone**: 4–6 hours, ideally spread over two or three sessions.

## Safety

Most of this level is read-only investigation, safe on your main machine. A few things change how the system boots or mounts disks, or install software system-wide: editing GRUB settings, mounting and formatting disks, editing `/etc/fstab`, changing kernel tunables, adding PPAs, and `sudo make install`. Those are marked **⚠️ VM only**. Set up your throwaway VM first if you haven't: [Set up your practice lab](../../lab-setup.md).

## Capstone

The level ends with the [Level 3 capstone](../../exercises/level-3-capstone.md): explain what happens from power-on to the login screen, and from typing `ls` to seeing its output, naming every component involved and backing each claim with evidence from your own machine. Don't move on to Level 4 until you can write both explanations without notes.

## Start

Begin with [The boot process](01-boot-process.md).
