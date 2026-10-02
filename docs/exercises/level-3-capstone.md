# Level 3 capstone: From power button to prompt

> **Level 3 · Capstone** · ⏱️ ~4–6 hours · Prerequisites: all of [Level 3: How Linux works](../chapters/03-internals/index.md)

Explain, in your own words and with evidence from your own machine, two journeys: from pressing the power button to the LightDM login screen, and from typing `ls` in a terminal to seeing its output. Name every component involved and show proof that each one really exists on your system.

## The challenge

Most people can use Linux for years without knowing what happens between the keypress and the output. This capstone asks you to open the black box completely.

You'll produce two things:

1. **An investigation log**: commands you ran on your Mint machine and the evidence they produced, one section per task below.
2. **Two written narratives**: a step-by-step explanation of each journey, in prose plus at least one diagram each, written so that a colleague who has finished Level 2 could follow it.

Save both in your handbook repository, for example as `notes/level-3-capstone.md`. Writing it in your own words is the point: if you can explain it, you understand it.

### Rules

- Everything in Parts 1 and 2 is **read-only** and safe to run on your main machine. Nothing needs `sudo` except where marked optional.
- The one task that changes the system (Part 1, task A6) is marked **⚠️ VM only**.
- You may reread the Level 3 chapters, `man` pages, and `--help` output. Try to write the narratives *without* copying from the chapters: look things up, close the page, then write.
- Use real output from your machine. Trim long output with `...`, but don't invent any.

## Part 1: Investigation

### A. The boot journey

**A1. Firmware and boot entries.** Prove whether you booted via UEFI or legacy BIOS. Show the firmware's boot entries and which one was used for this boot. Identify the file on the ESP that the firmware ran. Report your Secure Boot state.

**A2. The bootloader.** Show GRUB's settings file and the kernel command line that was actually used for this boot. Explain every parameter on that command line. Show which kernels and initramfs images are available in `/boot`.

**A3. Kernel and initramfs.** Using the kernel log, find the timestamps for: the kernel starting, the initramfs being unpacked, `/init` being run, the real root filesystem being mounted (and whether it was read-only at that point), and systemd starting. Show one driver from your initramfs that the kernel needed to reach your root disk, and prove it isn't built into the kernel.

**A4. systemd.** Show that PID 1 is systemd, what your default target is, and the critical chain to it. Find one unit that systemd generated from `/etc/fstab`. Show how long each boot stage took.

**A5. Display manager and session.** Show the display manager service, its main process and children (X server, greeter or session), your login session as `logind` sees it, and the process ancestry from PID 1 down to your terminal's shell.

**A6. ⚠️ VM only (optional).** In your VM, boot once into `multi-user.target` using a one-off edit at the GRUB menu, and capture `systemctl get-default`, `cat /proc/cmdline`, and `systemctl is-active lightdm` from the text console. Explain what changed and what didn't.

!!! danger "⚠️ VM only"
    Task A6 changes how the machine boots for that one boot. Do it in your VM, never on your main machine.

### B. The `ls` journey

**B1. What is `ls`?** Show every meaning your shell has for `ls` (alias, function, builtin, file) and which one wins. Show the real file it runs, the package that owns it, and its file type.

**B2. Your terminal.** Show which device file your shell's stdin, stdout, and stderr are connected to, what kind of device it is (block or character, major and minor), and which process holds the other end of it.

**B3. The shell's side.** Using `strace` on a shell that runs `ls`, show the system calls that create the new process, replace its program, and wait for it. Show the PATH search that found `/usr/bin/ls`.

**B4. Loading `ls`.** Show which shared libraries `ls` needs, which program loads them, and the system calls where they get opened and mapped into memory. Find the `ls` and `libc.so.6` mappings in a running process's memory map.

**B5. Doing the work.** Using `strace` on `ls` itself, identify the calls that: check whether output is a terminal, read the directory entries, and write the output. Run it once with output to the terminal and once with output to a pipe (`| cat`), and explain the differences.

**B6. Back to the screen.** Show the terminal settings (`stty -a`) in effect while a program runs, and identify the setting that turns `\n` into `\r\n` on output and the one that turns ++ctrl+c++ into a signal.

**B7. The kernel's view.** Show that the tools you used in B2 to B5 got their information from `/proc`, by finding at least two `/proc` paths they read.

## Part 2: Written deliverables

### Narrative 1: Power-on to login screen

Write the boot story from the moment power reaches the motherboard to the moment the login screen accepts your password and starts your desktop. At minimum, name and explain the role of each of these components, in order:

firmware, POST, NVRAM boot entries, ESP, Secure Boot, shim, GRUB, `grub.cfg`, kernel command line, kernel (`vmlinuz`) decompression, initramfs and its `/init`, udev, root filesystem mount, `switch_root`, systemd (PID 1), units, targets, `default.target`, fstab-generated mounts, journald, LightDM, Xorg, the greeter, PAM, systemd-logind, `systemd --user`, and the Cinnamon session.

Include at least one diagram (mermaid or ASCII) of the chain.

### Narrative 2: Typing `ls` to seeing output

Write the story from the moment your finger presses the ++l++ key in a GNOME Terminal window to the moment the file names appear and a new prompt is shown. At minimum, cover:

the keyboard and its driver, the input subsystem, the X server, the terminal emulator, the pseudo-terminal (master, slave, and line discipline), bash and readline, echoing of typed characters, parsing, alias and other expansions, PATH lookup, fork (clone), process groups and the foreground terminal, execve, the ELF loader and dynamic loader, libc, the system calls `ls` makes (including `getdents64` and `write`), the return path through the pseudo-terminal, terminal rendering, exit, SIGCHLD and `wait`, and the new prompt.

Include at least one sequence diagram.

## Acceptance criteria

Tick every box before you look at the solution.

- [ ] The investigation log has a section for every task A1–A5 and B1–B7, each with the commands run and real (trimmed) output.
- [ ] A1–A3 identify your actual ESP path, boot entry, kernel version, root UUID, and at least one initramfs driver, with evidence.
- [ ] A4 includes `systemd-analyze` timings and `critical-chain`, and names one fstab-generated `.mount` unit.
- [ ] A5 shows the process chain from PID 1 to your shell (`pstree -s` or equivalent).
- [ ] B1 shows `type -a ls` output and explains why the alias wins over the file.
- [ ] B2 identifies `/dev/pts/N` as a character device with major 136 and names the terminal process holding the master side.
- [ ] B3 shows `clone`, `execve`, and `wait4` in a real `strace` capture and the PATH probes before them.
- [ ] B4 lists `ls`'s libraries and shows `ld-linux-x86-64.so.2` opening and `mmap`-ing them.
- [ ] B5 explains why `ls` output differs between a terminal and a pipe, citing the `ioctl` call.
- [ ] Narrative 1 names every component in the list, in the right order, and explains *why* the initramfs and shim exist.
- [ ] Narrative 2 names every component in the list, in the right order, and explains the fork/exec split and who echoes typed characters.
- [ ] Each narrative has at least one diagram.
- [ ] Someone who finished Level 2 could read your narratives and understand them (ask a friend, or reread them a day later).

## Hints

??? tip "Hint for A1: UEFI, entries, and Secure Boot"

    `/sys/firmware/efi` only exists on UEFI boots. `efibootmgr` with no options only reads. `BootCurrent` tells you which `Boot####` entry was used, and the `File(...)` part of that entry is the program on the ESP. `mokutil --sb-state` needs no root.

??? tip "Hint for A2 and A3: command line and handoffs"

    `/proc/cmdline` is the command line actually used. For timestamps, `journalctl -k -b -o short-monotonic` or `dmesg` and grep for `unpack rootfs`, `Run /init`, `mounted filesystem`, and `running in system mode`. `lsinitramfs /boot/initrd.img-$(uname -r)` lists the initramfs, and `/boot/config-$(uname -r)` shows `=y` (built in) or `=m` (module).

??? tip "Hint for A4 and A5: units and sessions"

    `systemctl list-units --type=mount` lists mount units; `systemctl status boot-efi.mount` shows where one came from (look for `Loaded:` and the generator path under `/run/systemd/generator`). For the session: `systemctl status display-manager`, `loginctl list-sessions`, `loginctl session-status`, `pstree -s -p $$`.

??? tip "Hint for B1 and B2: names and terminals"

    `type -a ls`, `alias ls`, `command -v ls`, `readlink -f`, `dpkg -S`, `file`. For the terminal: `tty`, `ls -l /proc/$$/fd`, `stat -c '%F %Hr:%Lr' "$(tty)"`. Your shell's parent process (`ps -o ppid= -p $$`) is the program holding the master side; `ls -l /proc/<that PID>/fd | grep ptmx` confirms it.

??? tip "Hint for B3 and B4: tracing the shell"

    `strace -f -e trace=clone,clone3,execve,wait4,newfstatat bash -c 'ls /tmp; true'` shows a shell forking. The trailing `; true` stops bash from optimizing the last command into a plain `exec` without forking. Plain `strace ls` (no filter) shows the dynamic loader at work right after `execve`. For a running process's memory map, start something slow from `ls` itself, for example `ls -R / > /dev/null 2>&1 &`, and read `/proc/$!/maps` quickly, or use `strace` output instead.

??? tip "Hint for B5 and B6: terminal vs pipe"

    Compare `strace -e trace=ioctl,getdents64,write ls` with `strace -e trace=ioctl,getdents64,write ls | cat`. strace writes to stderr, so its trace stays visible either way. `ls` asks "is stdout a terminal?" with an `ioctl`; look at what it returns in each case. In `stty -a`, look for `onlcr` and `isig`, and the `intr = ^C` setting.

??? tip "Hint for B7 and the narratives"

    `strace -e trace=openat ps -p $$` and `strace -e trace=openat pstree -s $$` show the `/proc` files. For the narratives, write the list of components on paper first, draw arrows, then turn each arrow into a paragraph. If you can't say *why* a component exists, reread that chapter section.

## Solution

Finished and ticked every box? Compare your work with the [model answer](solutions/level-3-capstone.md). Your wording will differ, and your machine's numbers certainly will; check that you named the same components in the same order and that your evidence supports each claim.

## Next

With Level 3 done, you understand the machine underneath. Level 4 puts that knowledge to work running real services: start with [systemd and journalctl](../chapters/04-sysadmin/01-systemd-and-journalctl.md).
