# Level 6 capstone: build it from the inside

> **Level 6 · Capstone** · ⏱️ Option A: 4–8 hours · Option B: several days · Prerequisites: all of [Level 6](../chapters/06-expert/index.md)

This capstone proves you understand Linux below the tools. Pick **one** option:

- **Option A: a minimal container.** Build a working container runtime as a shell script, using only `unshare`, `pivot_root`, mounts, and cgroups v2. Every claim it makes about isolation must be demonstrated with a command.
- **Option B: Linux From Scratch.** Compile an entire Linux system from source code, from the toolchain to the kernel and bootloader, and boot it.

Option A takes an afternoon or two and draws directly on [Containers from scratch](../chapters/06-expert/01-containers-from-scratch.md). Option B is a much longer project that exercises everything in the handbook. If you're unsure, do A now and B later.

## Option A: a minimal container with unshare and cgroups

### The task

Write a script, `minicontainer.sh`, that runs a command inside a container built from an Alpine Linux root filesystem. The container must have:

1. **Its own hostname** (UTS namespace), without changing the host's.
2. **Its own PID 1**: the container's command sees itself as PID 1 and `ps` shows only container processes (PID namespace with `/proc` mounted).
3. **Its own root filesystem**: a mount namespace where `/` is the Alpine rootfs after `pivot_root`, and the host's files are unreachable.
4. **`/proc`, `/sys`, `/tmp`, and a minimal `/dev`** mounted inside.
5. **A memory limit**, enforced: a process that allocates more than the limit is OOM-killed.
6. **A process-count limit**, enforced: forking past the limit fails.
7. **An isolated network**: only a loopback interface.
8. **Clean exit**: nothing left behind on the host (no mounts, no cgroups, no leftover units).

The script should take the rootfs directory and an optional command (default `/bin/sh`), and options for the memory limit, the process limit, and the hostname. It must pass `shellcheck` with no warnings.

**Stretch goals** (pick any):

- A CPU limit (`cpu.max`), demonstrated with `cpu.stat`'s throttling counters.
- The cgroup namespace, so the container sees its own cgroup as `/`.
- A **root mode** for your VM that writes the cgroup files directly under `/sys/fs/cgroup` instead of using systemd.
- **Networking** in root mode: a veth pair connecting the container (`10.200.0.2`) to the host (`10.200.0.1`), with a working `ping` in both directions. ⚠️ VM only.

!!! info "Rootless on Mint, root in the VM"
    On Linux Mint 22 the whole core task can be done **rootless**, as your normal user: user namespaces are allowed (Mint sets `kernel.apparmor_restrict_unprivileged_userns = 0`), and `systemd-run --user --scope` can apply cgroup limits. On a plain Ubuntu 24.04 VM you'll need the AppArmor workaround from the containers chapter, or root. The root mode and networking stretch goals are ⚠️ VM only.

### Setup

Get an Alpine minirootfs into a lab directory. Use the latest version from <https://alpinelinux.org/downloads/> (row "Mini root filesystem", x86_64); 3.20.3 is shown here:

```bash
mkdir -p ~/lab/capstone && cd ~/lab/capstone
V=3.20.3
wget "https://dl-cdn.alpinelinux.org/alpine/v${V%.*}/releases/x86_64/alpine-minirootfs-${V}-x86_64.tar.gz"{,.sha256}
sha256sum -c "alpine-minirootfs-${V}-x86_64.tar.gz.sha256"
mkdir alpine && tar -xzf "alpine-minirootfs-${V}-x86_64.tar.gz" -C alpine
cat alpine/etc/alpine-release
```

```text
alpine-minirootfs-3.20.3-x86_64.tar.gz: OK
3.20.3
```

### Acceptance criteria

Check each box only when the verification command produces the expected result. Commands marked "inside" are run as the container's command, for example `./minicontainer.sh alpine sh -c '...'`.

- [ ] **Script quality.** `shellcheck minicontainer.sh` prints nothing. `./minicontainer.sh -h` prints usage.
- [ ] **Hostname.** `./minicontainer.sh alpine hostname` prints your container hostname (for example `minibox`), and `hostname` on the host afterwards still prints `mint`.
- [ ] **PID 1.** Inside: `sh -c 'echo $$; ps'` prints `1`, and `ps` lists only processes started inside the container.
- [ ] **Root filesystem.** Inside: `cat /etc/alpine-release` prints the Alpine version; `ls /home` is empty; `ls /.oldroot` (or whatever you called the old root) fails with "No such file or directory".
- [ ] **Kernel filesystems.** Inside: `cat /proc/mounts` lists `proc`, `sysfs`, `tmpfs` on `/tmp`, and `/dev` entries, and no host paths like `/home/alex`.
- [ ] **Memory limit visible.** Inside: `cat /sys/fs/cgroup/memory.max` prints your limit in bytes (64M = `67108864`), and `memory.swap.max` prints `0`. (Rootless without the cgroup namespace: read the scope's files on the host instead.)
- [ ] **Memory limit enforced.** Inside: `dd if=/dev/zero of=/dev/null bs=200M count=1; echo $?` prints `Killed` and `137`, and `grep oom_kill /sys/fs/cgroup/memory.events` shows `oom_kill 1`. On the host, `journalctl -k | tail` shows `Memory cgroup out of memory: Killed process ... (dd)`.
- [ ] **PID limit enforced.** With a limit of 8: inside, `sh -c 'for i in 1 2 3 4 5 6 7 8 9 10 11 12; do sleep 2 & done; wait'` reports `can't fork: Resource temporarily unavailable`, and `/sys/fs/cgroup/pids.events` shows a non-zero `max` count.
- [ ] **Network isolated.** Inside: `ip link` shows only `lo`.
- [ ] **Namespaces confirmed from the host.** While a container runs `sleep 300`, `lsns -p $(pgrep -n -x sleep)` on the host shows new `mnt`, `uts`, `ipc`, `pid`, `net`, and `user` namespaces (and `cgroup` if you did that stretch goal) that differ from your shell's.
- [ ] **Clean exit.** After the container exits: `findmnt | grep -c alpine` prints `0`; `systemctl --user list-units --all 'run-*'` shows no leftover scope (rootless), or `ls /sys/fs/cgroup | grep minicontainer` prints nothing (root mode).

Stretch goals:

- [ ] **CPU limit.** Inside: `cat /sys/fs/cgroup/cpu.max` prints `50000 100000`, and after running a busy loop for a few seconds, `nr_throttled` in `/sys/fs/cgroup/cpu.stat` is above zero.
- [ ] **Root mode.** ⚠️ VM only. `sudo ./minicontainer.sh alpine cat /proc/self/cgroup` runs, and the host's `/sys/fs/cgroup/` has a `minicontainer-*` directory only while the container runs.
- [ ] **Networking.** ⚠️ VM only. `sudo ./minicontainer.sh -n alpine ping -c 1 10.200.0.1` succeeds, and while a networked container runs, `ping -c 1 10.200.0.2` from the host succeeds.

### Hints

Try the task without these first. Open one only when you're stuck.

??? tip "Hint 1: the script needs two halves"
    Some steps happen on the host (applying limits, creating namespaces), and some must happen *inside* the new namespaces (setting the hostname, mounting, `pivot_root`). A clean pattern is for the script to re-execute itself: the host half runs `unshare ... "$0" __init ARGS`, and when the script sees `__init` as its first argument, it runs the inside half.

??? tip "Hint 2: order of the unshare flags"
    Put `--user --map-root-user` first so you're "root" in the new user namespace before creating the others. You need `--fork` with `--pid`, or the namespace dies after the first child exits (`fork: Cannot allocate memory`). Add `--kill-child` so the container dies if `unshare` is killed.

??? tip "Hint 3: cgroups without root"
    You can't write to `/sys/fs/cgroup` as a normal user, but systemd delegates `cpu`, `memory`, and `pids` to your user manager. Wrap the `unshare` command: `systemd-run --user --scope --quiet --collect -p MemoryMax=64M -p MemorySwapMax=0 -p TasksMax=32 unshare ...`. Everything started from there is inside the scope's cgroup. Don't forget `MemorySwapMax=0`, or the memory test will swap instead of being killed.

??? tip "Hint 4: pivot_root keeps failing with 'Invalid argument'"
    The new root must be a mount point and must not be shared. Run `mount --make-rprivate /` and then `mount --bind "$ROOT" "$ROOT"` before `cd "$ROOT"; mkdir -p .oldroot; pivot_root . .oldroot`. Then `umount -l /.oldroot` and `rmdir /.oldroot`.

??? tip "Hint 5: commands disappear after pivot_root"
    After `pivot_root`, every external command your script runs comes from the *container's* `/bin` and `/usr/bin`, not the host's. Do all the mounting (proc, sysfs, tmpfs, `/dev`) *before* `pivot_root`, using paths under `$ROOT`, so the host's `mount` does the work. Alpine's BusyBox provides `umount`, `rmdir`, and `env` for the few steps after.

??? tip "Hint 6: /dev in a user namespace"
    You can't `mknod` device files inside a user namespace. Mount a small tmpfs on `$ROOT/dev`, `touch` empty files for `null`, `zero`, `random`, `urandom`, and `tty`, and bind-mount the host's devices onto them: `mount --bind /dev/null "$ROOT/dev/null"`.

??? tip "Hint 7: seeing the cgroup from inside"
    Add `--cgroup` to `unshare` (after the process is already in the limited cgroup), then mount `cgroup2` on `$ROOT/sys/fs/cgroup` after mounting sysfs. Inside, `/proc/self/cgroup` then shows `0::/` and `/sys/fs/cgroup/memory.max` is your container's limit.

??? tip "Hint 8: a clean environment"
    End the inside half with `exec env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM="${TERM:-xterm}" "$@"`. `exec` makes your command PID 1 (replacing the script), and `env -i` stops host environment variables leaking in.

### Solution

A complete, tested script with a step-by-step explanation and verification output is in the [Level 6 capstone solution](solutions/level-6-capstone.md). It's also in the repository as `scripts/minicontainer.sh`.

## Option B: Linux From Scratch

### The task

Follow the [Linux From Scratch book](https://www.linuxfromscratch.org/lfs/) (current stable version, systemd or SysVinit edition) to build a complete Linux system from source in a VM, and boot it.

**Linux From Scratch (LFS)** is a free book that walks you through compiling every piece of a minimal Linux system yourself: a cross-compiler toolchain, the GNU C library, GCC, the core utilities, Bash, the init system, the kernel, and the GRUB bootloader. You end with a bootable system of roughly 80 packages, every one of which you configured and compiled. Nothing teaches how a distribution is put together like building one.

### Scope and expectations

- **Time.** Expect 2–5 days of work spread over a few weeks. LFS measures build times in **SBUs** (standard build units: the time to build the first package, binutils pass 1). The whole book is around 200–400 SBUs; on a modern 4-core VM one SBU is a couple of minutes.
- **Where.** In a VM with a second virtual disk (at least 30 GB) for the LFS partition, 4+ CPUs, and 4+ GB of RAM. Ubuntu 24.04 or Mint 22 works as the host system.
- **Rules.** Follow the book exactly the first time. Read each package's explanation instead of pasting commands blindly. Keep a log of every command you run (the `script` command, or a notes file).
- **The ⚠️ VM only rule applies throughout.** You'll partition disks, run as root, and chroot into a half-built system.

### Milestones

| # | Milestone | LFS chapters | You're done when |
|---|---|---|---|
| 1 | **Host ready** | 2 | The book's `version-check.sh` reports all OK; a partition is created, formatted, and mounted at `$LFS` (`/mnt/lfs`) |
| 2 | **Sources downloaded** | 3 | All packages and patches are in `$LFS/sources` and pass `md5sum -c md5sums` |
| 3 | **Build environment** | 4 | An unprivileged `lfs` user exists with the clean environment from the book; `echo $LFS $LFS_TGT` prints the expected values |
| 4 | **Cross toolchain** | 5 | Binutils and GCC pass 1, Linux API headers, Glibc, and Libstdc++ are built; the toolchain sanity check (compiling `int main(){}` and checking the interpreter with `readelf`) passes |
| 5 | **Temporary tools** | 6 | Cross-compiled temporary tools (Bash, Coreutils, Make, and others) are installed into `$LFS` |
| 6 | **Into chroot** | 7 | You `chroot` into `$LFS`, create the directory layout and essential files, and build the remaining temporary tools. Take a backup of `$LFS` here |
| 7 | **Base system** | 8 | All of chapter 8's packages are built, with test suites run where the book says they're critical (Glibc, GCC, Binutils) |
| 8 | **System configuration** | 9 | Network, clock, console, locale, and `/etc/fstab` are configured for your init system |
| 9 | **Kernel and bootloader** | 10 | You've configured (`make menuconfig`), compiled, and installed a kernel, and installed GRUB to the LFS disk |
| 10 | **First boot** | 11 | The VM boots from the LFS disk to a login prompt; you can log in and `uname -a` shows your kernel |

### Acceptance criteria

- [ ] The LFS system boots on its own (detach or deprioritize the host disk) to a login prompt.
- [ ] `cat /etc/lfs-release` (or `/etc/os-release`) shows the LFS version you followed.
- [ ] `uname -r` shows the kernel version you compiled, and `cat /proc/cmdline` shows the command line from your `grub.cfg`.
- [ ] `gcc --version` and `ldd --version` work *on the LFS system* and match the book's versions.
- [ ] Networking works: `ping -c 1` to the host or gateway succeeds.
- [ ] You can explain, without notes, why the toolchain is built twice (cross toolchain, then native), and what the chroot step changes.
- [ ] Your build log is saved in `notes/`, including every error you hit and how you fixed it.

### Hints

??? tip "Hint 1: the environment is everything"
    Most LFS failures come from a wrong environment: building as root instead of `lfs`, a missing `$LFS` variable after a reboot, or forgetting to re-mount the virtual filesystems before re-entering chroot. Before each session, check `echo $LFS`, `whoami`, and `findmnt | grep $LFS`.

??? tip "Hint 2: one package, one clean directory"
    For every package: extract the tarball, `cd` into it, follow the instructions, then `cd ..` and delete the extracted directory. Reusing a half-built directory causes strange errors.

??? tip "Hint 3: snapshots"
    Snapshot the VM at the end of each milestone. When chapter 8 goes wrong, rolling back to the end of chapter 7 costs a minute instead of a day.

??? tip "Hint 4: when it won't boot"
    Check, in this order: the kernel has your disk controller and root filesystem *built in* (`=y`, not `=m`, unless you made an initramfs); `root=` in `grub.cfg` names the right partition; `/etc/fstab` matches. The kernel's panic message (`VFS: Unable to mount root fs`) tells you which.

### Solution

LFS has no single "answer": the book itself is the walkthrough. The [solution page](solutions/level-6-capstone.md#option-b-linux-from-scratch-milestone-guide) has a milestone guide with checks, common failures, and what to verify at each stage.
