# Glossary

Short definitions of the terms used across the handbook, in alphabetical
order. Each chapter explains its terms in depth the first time they appear;
this page is for quick lookups.

[A](#a) · [B](#b) · [C](#c) · [D](#d) · [E](#e) · [F](#f) · [G](#g) ·
[H](#h) · [I](#i) · [J](#j) · [K](#k) · [L](#l) · [M](#m) · [N](#n) ·
[O](#o) · [P](#p) · [Q](#q) · [R](#r) · [S](#s) · [T](#t) · [U](#u) ·
[V](#v) · [W](#w) · [Z](#z)

## A

ABI (Application Binary Interface)
:   The low-level contract between compiled programs and the system: how
    functions are called, how data is laid out in memory, and how system
    calls are made. Programs built for the same ABI run without recompiling.

Absolute path
:   A path that starts at the root directory `/`, such as `/etc/hosts`. It
    means the same thing no matter what your current directory is.

Alias
:   A shell shortcut that replaces one word with a longer command, for
    example `alias ll='ls -alF'`. Defined in `~/.bashrc` to persist.

AppArmor
:   The **mandatory access control** system used by Ubuntu and Mint. It
    confines programs with per-program profiles that list which files,
    capabilities, and network access they may use, even when running as root.

apt
:   Ubuntu's high-level package manager. It downloads packages from
    repositories, resolves dependencies, and calls `dpkg` to install them.

Argument
:   A word passed to a command after its name. In `cp a.txt b.txt`, both
    file names are arguments. Options such as `-r` are arguments too.

## B

Bash
:   The **B**ourne **A**gain **SH**ell, the default interactive shell on Mint
    and Ubuntu and the language of this handbook's scripts.

Block device
:   A device file for hardware that is read and written in fixed-size blocks
    with random access, such as disks (`/dev/sda`, `/dev/nvme0n1`). Shown
    with type `b` in `ls -l`.

Bootloader
:   The small program the firmware starts, which loads the kernel and the
    initramfs into memory and starts the kernel. On Mint this is **GRUB**.

Builtin
:   A command implemented inside the shell itself, not as a separate program,
    such as `cd`, `echo`, `read`, and `export`. `type cd` shows
    `cd is a shell builtin`.

## C

CA (Certificate Authority)
:   An organization (or a key you control) that signs **TLS** certificates.
    Clients trust a certificate if it chains up to a CA in their trust store,
    on Ubuntu `/etc/ssl/certs`. Let's Encrypt is a free public CA.

Capability
:   One slice of root's power, such as `CAP_NET_BIND_SERVICE` (bind to ports
    below 1024) or `CAP_SYS_ADMIN`. The kernel splits root privileges into
    about 40 capabilities so a program can get only the ones it needs.

cgroup (control group)
:   A kernel feature that groups processes and limits, accounts for, and
    isolates their resource use: CPU, memory, I/O, and number of processes.
    systemd puts every service in its own cgroup. Ubuntu 24.04 uses
    **cgroups v2**, a single unified hierarchy under `/sys/fs/cgroup`.

Character device
:   A device file for hardware accessed as a stream of bytes, such as
    terminals (`/dev/tty`) and `/dev/null`. Shown with type `c` in `ls -l`.

Child process
:   A process created by another process (its **parent**) with `fork()`.
    Every process except PID 1 has a parent.

CIDR (Classless Inter-Domain Routing)
:   The `address/prefix` notation for IP networks. In `192.168.1.0/24`, the
    first 24 bits are the network part, leaving 8 bits (256 addresses) for
    hosts.

cloud-init
:   The tool that configures a cloud or VM image on its first boot: hostname,
    users, SSH keys, packages, and scripts, read from **user data** supplied
    by the cloud provider or hypervisor.

Command substitution
:   Running a command and inserting its output into another command, written
    `$(command)`. For example, `echo "Today is $(date +%F)"`.

Container
:   An ordinary process (or group of processes) isolated with
    **namespaces**, limited with **cgroups**, and given its own root
    filesystem. Containers share the host's kernel, unlike VMs.

Core dump
:   A file containing a process's memory at the moment it crashed, used to
    debug the crash afterwards with `gdb`. On Ubuntu, `systemd-coredump` (if
    installed) stores them and `coredumpctl` lists them.

cron
:   The classic daemon that runs commands on a schedule defined in
    **crontab** files, using five time fields: minute, hour, day of month,
    month, and day of week.

## D

Daemon
:   A background program that runs without a terminal, usually started at
    boot, providing a service. Names often end in `d`: `sshd`,
    `systemd-journald`, `systemd-udevd`.

DHCP (Dynamic Host Configuration Protocol)
:   The protocol a machine uses at startup to get an IP address, gateway, and
    DNS servers automatically from a server on the local network.

Distribution (distro)
:   A complete operating system built around the Linux kernel: GNU tools, a
    package manager, an init system, a desktop, and default settings. Mint,
    Ubuntu, Debian, Fedora, and Arch are distributions.

DNS (Domain Name System)
:   The distributed directory that translates names like `example.com` into
    IP addresses (and stores other records such as mail servers).

dpkg
:   Debian's low-level package tool. It installs, removes, and queries
    individual `.deb` files, but doesn't download packages or resolve
    dependencies; that's `apt`'s job.

Drop-in
:   A small config file placed in a `.d` directory (such as
    `/etc/ssh/sshd_config.d/` or `/etc/systemd/system/nginx.service.d/`)
    that adds to or overrides the main config without editing it.

## E

eBPF
:   A kernel feature that runs small, verified programs inside the kernel in
    response to events. Used for tracing and performance tools (`bpftrace`,
    bcc), networking, and security.

ELF (Executable and Linkable Format)
:   The file format of Linux executables, shared libraries, object files, and
    core dumps. `file /usr/bin/ls` reports `ELF 64-bit LSB pie executable`.

Environment variable
:   A named string passed from a process to its children, such as `PATH`,
    `HOME`, or `LANG`. Set one for child processes with `export NAME=value`;
    list them with `env`.

Exit status
:   The number 0–255 a process returns when it ends. `0` means success; any
    other value means failure. The shell stores the last one in `$?`.

ext4
:   The default filesystem on Ubuntu and Mint: a mature, journaling
    filesystem.

## F

FHS (Filesystem Hierarchy Standard)
:   The convention for where things live in a Linux filesystem: config in
    `/etc`, variable data in `/var`, programs in `/usr/bin`, home directories
    in `/home`, and so on.

FIFO (named pipe)
:   A special file that works like a pipe with a name on the filesystem: one
    process writes into it and another reads from it. Created with `mkfifo`.
    Shown with type `p` in `ls -l`.

File descriptor (fd)
:   A small integer a process uses to refer to an open file, pipe, socket, or
    device. By convention 0 is **stdin**, 1 is **stdout**, and 2 is
    **stderr**. Listed in `/proc/PID/fd/`.

Firewall
:   Software that allows or blocks network packets by rules on addresses,
    ports, and connection state. On Linux, filtering is done by the kernel's
    **netfilter**; `ufw` and `nftables` configure it.

fork / exec
:   The two system calls behind every new program. `fork()` clones the
    calling process; `exec()` replaces the clone's program with a new one.
    The shell runs `ls` by forking itself and having the child exec `ls`.

## G

Gateway (default gateway)
:   The router that receives packets for any destination outside the local
    network. Shown as `default via ...` in `ip route`.

GID (group ID)
:   The number that identifies a group. Names are mapped to GIDs in
    `/etc/group`.

Glob (wildcard)
:   A filename pattern the **shell** expands before running a command: `*`
    matches any characters, `?` one character, and `[abc]` one of a set. In
    `rm *.tmp`, `rm` receives the expanded list of names.

GRUB
:   The GRand Unified Bootloader, the bootloader used by Mint and Ubuntu. It
    shows the boot menu and loads the kernel and initramfs.

Group
:   A named set of users. Files have a group owner, and group permissions
    apply to its members. Memberships are listed by `id`.

## H

Hard link
:   An additional directory entry (name) pointing to the same inode as an
    existing file. All hard links are equal; the data is freed only when the
    last link is removed and no process has it open.

Here-document
:   A block of text fed to a command's stdin, written `<<EOF` … `EOF`. Quote
    the marker (`<<'EOF'`) to stop variable expansion inside it.

Host key
:   The key pair that identifies an SSH **server**. Clients record its
    fingerprint in `~/.ssh/known_hosts` on first connection and warn loudly
    if it later changes.

Hypervisor
:   Software that creates and runs virtual machines by sharing the
    hardware between them. **Type 1** runs directly on hardware (KVM, which
    turns Linux itself into one, Hyper-V, Xen); **type 2** runs as an app on
    a host OS (VirtualBox).

## I

Idempotency
:   The property that running an operation many times has the same result as
    running it once. `mkdir -p dir` is idempotent; `echo line >> file` is
    not. Configuration management tools like Ansible are built around it.

Init
:   The first user-space process the kernel starts, with PID 1. It starts
    everything else and adopts orphaned processes. On Mint and Ubuntu, init
    is **systemd**.

initramfs
:   A small temporary root filesystem loaded with the kernel at boot. It
    contains the drivers and tools needed to find and mount the real root
    filesystem (for example on LVM or an encrypted disk), then hands over.

Inode
:   The on-disk structure that describes a file: type, permissions, owner,
    size, timestamps, link count, and the location of its data. It does
    **not** contain the file's name; directories map names to inode numbers.
    `ls -i` shows them.

IP address
:   The numeric address of a network interface. IPv4 addresses are 32 bits,
    written `192.168.1.50`; IPv6 addresses are 128 bits, written
    `fe80::a00:27ff:fe4e:66a1`.

## J

Job
:   A pipeline the shell started from the current terminal, running in the
    foreground or background. Managed with `jobs`, `fg`, `bg`, and
    ++ctrl+z++.

journald
:   `systemd-journald`, the systemd service that collects logs from the
    kernel, services, and programs into a structured, indexed binary journal.
    Read it with `journalctl`.

## K

Kernel
:   The core of the operating system. It runs with full hardware privileges
    and manages the CPU, memory, devices, filesystems, and networking, and
    provides services to programs through system calls. "Linux" strictly
    means the kernel.

Kernel module
:   A piece of kernel code (often a driver) loaded into the running kernel on
    demand, without rebooting. Listed with `lsmod`; loaded with `modprobe`.

Kernel space / user space
:   The two privilege levels the CPU runs code in. The kernel runs in kernel
    space with full access to hardware. Programs run in user space and must
    ask the kernel, through system calls, to do anything privileged.

KVM (Kernel-based Virtual Machine)
:   The Linux kernel feature that uses the CPU's hardware virtualization
    (Intel VT-x, AMD-V) to run virtual machines at near-native speed, with
    **QEMU** providing the virtual devices.

## L

Load average
:   The average number of processes that are running, waiting for a CPU, or
    in uninterruptible sleep, over 1, 5, and 15 minutes. Compare it with the
    number of CPUs (`nproc`).

logrotate
:   The tool that rotates log files on a schedule: it renames the current log,
    starts a new one, compresses old ones, and deletes the oldest. Configured
    in `/etc/logrotate.conf` and `/etc/logrotate.d/`.

Logical volume (LV)
:   In LVM, a virtual partition carved out of a volume group. It holds a
    filesystem and can be resized or snapshotted.

Loopback
:   The virtual network interface `lo` with address `127.0.0.1` (and
    `::1`), through which a machine talks to itself. Traffic never leaves
    the host.

LVM (Logical Volume Manager)
:   A layer between disks and filesystems. **Physical volumes** are pooled
    into **volume groups**, from which **logical volumes** are carved. It
    allows resizing, spanning disks, and snapshots.

## M

Man page
:   A program's built-in manual, read with `man`. Pages are grouped into
    sections, such as 1 (commands), 5 (file formats), and 8 (admin commands),
    which is why you'll see references like `crontab(5)`.

MMU (Memory Management Unit)
:   The CPU hardware that translates the virtual addresses a program uses
    into physical RAM addresses, using page tables the kernel maintains. It
    also enforces memory protection between processes.

Mount
:   To attach a filesystem to a directory (the **mount point**) so its
    contents appear there. `findmnt` lists mounts; `/etc/fstab` lists those
    mounted at boot.

## N

Namespace
:   A kernel feature that gives a process its own isolated view of a global
    resource. Types include PID, mount, network, UTS (hostname), IPC, user,
    and cgroup namespaces. Containers are built from them.

NAT (Network Address Translation)
:   Rewriting addresses in packets as they pass through a router, so many
    private devices can share one public IP address. Home routers and VM
    "NAT" networks do this.

netfilter
:   The packet-filtering framework inside the Linux kernel. `nftables`,
    `iptables`, and `ufw` are tools that configure its rules.

Nice value
:   A process's scheduling priority hint, from −20 (highest priority) to 19
    (lowest). The default is 0. Set with `nice` and `renice`.

NSS (Name Service Switch)
:   The C library mechanism that decides where lookups of users, groups, and
    hostnames come from (files, DNS, LDAP, systemd). Configured in
    `/etc/nsswitch.conf`; queried with `getent`.

## O

OCI (Open Container Initiative)
:   The standards body that defines the container **image format**, the
    **runtime spec**, and the **distribution spec**. Docker, Podman, and
    containerd all use OCI images, which is why images are portable between
    them.

OOM killer
:   The kernel's Out-Of-Memory killer. When memory and swap are exhausted, it
    picks a process (usually the largest) and kills it with `SIGKILL` to keep
    the system alive. Logged in `journalctl -k`.

Orphan process
:   A process whose parent has exited. It is adopted by PID 1 (or a
    designated "subreaper"), which will collect its exit status.

overlayfs
:   A union filesystem that stacks a writable upper directory on top of one
    or more read-only lower directories, presenting them as one. Container
    images use it: image layers are read-only lowers, and the container's
    changes go in the upper.

## P

Package
:   An archive containing a program's files plus metadata: version,
    dependencies, and install scripts. On Ubuntu and Mint, packages are
    `.deb` files.

Page
:   The fixed-size unit (usually 4 KiB) in which the kernel and MMU manage
    memory.

Page cache
:   RAM the kernel uses to cache file contents. It speeds up repeated reads
    and buffers writes, and is given back automatically when programs need
    memory. It's why "free" memory is usually low on a healthy system.

PAM (Pluggable Authentication Modules)
:   The framework that programs like `login`, `sshd`, and `sudo` use for
    authentication. Each service has a stack of modules in `/etc/pam.d/`
    that check passwords, enforce policies, set limits, and so on.

Parent process
:   The process that created another process. Its PID is the child's
    **PPID**.

Partition
:   A defined region of a disk, described in its partition table (GPT or
    MBR), that can hold a filesystem, swap, or an LVM physical volume.

PATH
:   The environment variable listing the directories the shell searches, in
    order, for a command name you type. Show it with `echo "$PATH"`.

Physical volume (PV)
:   In LVM, a disk or partition initialized for LVM use with `pvcreate`.

PID (process ID)
:   The unique number the kernel gives each running process. PID 1 is init
    (systemd).

Pipe
:   A one-way kernel buffer connecting one process's stdout to another's
    stdin, written `|` in the shell: `ls | wc -l`.

Playbook
:   An Ansible file, written in YAML, that lists tasks to run on groups of
    hosts to bring them to a desired state.

Port
:   A 16-bit number (0–65535) that identifies a specific service or
    connection on a host, alongside its IP address. Ports below 1024 are
    **privileged**: binding them needs root or `CAP_NET_BIND_SERVICE`.

POSIX
:   A family of IEEE standards for Unix-like systems: system calls, shell
    language, and utilities. Writing to POSIX makes scripts and programs more
    portable.

Process
:   A running instance of a program: its memory, open file descriptors,
    credentials, and at least one thread of execution, identified by a PID.

pty (pseudo-terminal)
:   A software pair that emulates a terminal device. Terminal emulators,
    `ssh`, and `tmux` give the shell a pty slave such as `/dev/pts/0` to talk
    to.

## Q

qcow2
:   QEMU's "copy on write" disk image format. Files grow only as the guest
    writes data, and they support internal snapshots and backing files.

QEMU
:   The open-source machine emulator and virtualizer. With KVM it runs
    virtual machines at near-native speed, emulating disks, network cards,
    and other devices.

## R

RAID (Redundant Array of Independent Disks)
:   Combining several disks into one logical device for redundancy, speed,
    or both. Common levels: RAID 0 (striping, no redundancy), 1 (mirroring),
    5 and 6 (striping with parity), 10 (mirrored stripes). RAID is not a
    backup.

Redirection
:   Changing where a command's input or output goes: `>` writes stdout to a
    file, `>>` appends, `2>` redirects stderr, `<` reads stdin from a file.

Regular expression (regex)
:   A pattern language for matching text, used by `grep`, `sed`, `awk`, and
    most programming languages. For example, `^[0-9]{3}$` matches a line of
    exactly three digits.

Relative path
:   A path interpreted from the current directory, such as `notes/todo.md`
    or `../logs`.

Reverse proxy
:   A server (such as nginx) that accepts client requests and forwards them to
    one or more backend servers, often also handling TLS, caching, and load
    balancing.

Root
:   Two meanings: the superuser account with UID 0, which bypasses permission
    checks; and the root directory `/`, the top of the filesystem tree.

RSS (Resident Set Size)
:   The amount of a process's memory that is currently in physical RAM. See
    also **VSZ**.

## S

setuid / setgid
:   Permission bits that make an executable run with the privileges of the
    file's owner (setuid) or group (setgid), not the user who started it.
    `passwd` is setuid root. On a directory, setgid makes new files inherit
    the directory's group.

Shebang
:   The first line of a script, starting with `#!`, which tells the kernel
    which interpreter to run it with, such as `#!/usr/bin/env bash`.

Shell
:   The program that reads your commands, expands them, and runs them, such
    as bash. It's also a scripting language.

Signal
:   A small asynchronous notification sent to a process, such as `SIGTERM`
    (please exit), `SIGKILL` (die now), or `SIGINT` (++ctrl+c++). Processes
    can catch most signals; `SIGKILL` and `SIGSTOP` can't be caught.

SNI (Server Name Indication)
:   A TLS extension in which the client sends the hostname it wants at the
    start of the handshake, so one IP address can serve many HTTPS sites with
    different certificates.

Socket
:   An endpoint for communication between processes, on the same machine
    (**Unix domain socket**, a file such as `/run/docker.sock`) or across a
    network (**TCP/UDP socket**, an address and port).

soname
:   The name a shared library advertises for compatibility, such as
    `libc.so.6`. Programs record the sonames they need, and the dynamic
    loader finds files with those names at run time. The number changes only
    when the ABI breaks.

SSH (Secure Shell)
:   The encrypted protocol for logging in to and running commands on remote
    machines, and for copying files (`scp`, `sftp`, `rsync`) and tunneling
    ports.

Standard streams (stdin, stdout, stderr)
:   The three file descriptors every process starts with: 0 for input, 1 for
    normal output, 2 for errors and diagnostics.

Sticky bit
:   A permission bit on a directory that lets only a file's owner (or root)
    delete or rename it, even if others can write to the directory. `/tmp`
    has it (`drwxrwxrwt`).

sudo
:   The command that runs a single command as root (or another user) after
    checking the rules in `/etc/sudoers`, logging each use.

Swap
:   Disk space (a partition or file) used as overflow for RAM. The kernel
    moves rarely used memory pages there under memory pressure. Much slower
    than RAM.

Symbolic link (symlink)
:   A special file containing a path to another file or directory. Opening
    the link opens the target. It breaks if the target is moved or deleted.

Syslog facility
:   A category in the classic syslog protocol saying which part of the system
    produced a message, such as `kern`, `auth`, `cron`, `mail`, `daemon`, or
    `local0`–`local7`. Combined with a **severity** (from `emerg` to
    `debug`) to route log messages.

System call (syscall)
:   The interface through which a program asks the kernel to do something it
    can't do itself, such as `open`, `read`, `write`, `fork`, or `socket`.
    Watch them with `strace`.

systemd
:   The init system and service manager on Mint and Ubuntu. Runs as PID 1,
    starts and supervises services, and includes logging (journald), timers,
    DNS (resolved), and more.

## T

Target
:   A systemd unit that groups other units into a synchronization point or
    system state, such as `multi-user.target` (a normal server boot) or
    `graphical.target` (with a desktop). Replaces SysV runlevels.

TCP (Transmission Control Protocol)
:   A connection-oriented transport protocol that delivers a reliable,
    ordered byte stream, retransmitting lost data. Used by HTTP, SSH, and
    databases.

Terminal emulator
:   The graphical app (such as GNOME Terminal on Mint) that draws a terminal
    window, passes your keystrokes to the shell through a pty, and displays
    the output.

Thread
:   A separate flow of execution inside a process. Threads share the
    process's memory and file descriptors but have their own stack and
    registers.

Timer (systemd)
:   A `.timer` unit that starts a matching service on a schedule
    (`OnCalendar=`) or after a delay (`OnBootSec=`). The systemd alternative
    to cron.

TLS (Transport Layer Security)
:   The protocol that encrypts and authenticates network connections, the
    "S" in HTTPS. Servers prove their identity with a certificate signed by
    a **CA**.

tmux session
:   A collection of terminal windows and panes managed by the tmux server.
    It keeps running when you detach or your SSH connection drops, and you
    can reattach later.

TTY
:   Originally a teletypewriter; now any terminal device. The text consoles
    you reach with ++ctrl+alt+f3++ are virtual TTYs (`/dev/tty3`). `tty`
    prints your current terminal device.

## U

UDP (User Datagram Protocol)
:   A connectionless transport protocol that sends individual packets
    (datagrams) with no delivery guarantee. Used by DNS, DHCP, NTP, and
    streaming.

UEFI
:   The modern firmware interface that replaced the BIOS. It initializes the
    hardware, then starts a bootloader from the EFI System Partition.

UID (user ID)
:   The number that identifies a user to the kernel. Root is 0; regular
    users on Ubuntu start at 1000. Names are mapped to UIDs in
    `/etc/passwd`.

umask
:   A per-process mask of permission bits to **remove** from newly created
    files and directories. With umask `022`, new files get `644` and new
    directories `755`.

Unit
:   Any object systemd manages, described by a unit file: services
    (`.service`), timers (`.timer`), sockets (`.socket`), mounts (`.mount`),
    targets (`.target`), and more.

## V

VFS (Virtual File System)
:   The kernel layer that gives every filesystem (ext4, xfs, tmpfs, `/proc`,
    network filesystems) the same interface, so `open`, `read`, and `write`
    work the same everywhere.

Virtual machine (VM)
:   A complete computer simulated by a hypervisor, with its own virtual CPU,
    memory, disks, and network, running its own operating system (the
    **guest**) on top of a **host**.

Virtual memory
:   The abstraction giving each process its own private address space. The
    kernel and MMU map these virtual addresses to physical RAM pages, swap,
    or files on demand.

Volume group (VG)
:   In LVM, a pool of storage made from one or more physical volumes, from
    which logical volumes are allocated.

VSZ (Virtual memory Size)
:   The total size of a process's virtual address space, including memory
    that is mapped but not in RAM. Usually much larger than **RSS**.

## W

Word splitting
:   The shell step that splits the result of an unquoted expansion into
    separate words on spaces, tabs, and newlines. The reason to write
    `"$var"` with double quotes.

Working directory
:   The directory a process is currently "in", against which relative paths
    are resolved. Shown by `pwd`; changed with `cd`.

## Z

Zombie
:   A process that has exited but whose parent hasn't yet read its exit
    status with `wait()`. It uses no memory or CPU, only a process table
    entry. Shown with state `Z` in `ps`. It disappears when the parent waits
    or exits.
