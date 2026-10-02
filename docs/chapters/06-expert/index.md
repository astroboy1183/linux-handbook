# Level 6: Expert topics

> ⏱️ About 10 hours of reading, plus 20–40 hours of hands-on practice and the capstone · Prerequisites: Levels 0–5, and a throwaway VM from [Set up your practice lab](../../lab-setup.md)

By now you can use Linux fluently, script it, run services on it, and write programs that talk to the kernel. Level 6 opens up the machinery underneath the tools you use every day, then puts it to work. You'll build a container with nothing but `unshare` and a few files under `/sys`, find out exactly where a slow system spends its time, lock a server down layer by layer, load your own code into the running kernel, trace packets through the network stack, run virtual machines, use Docker and Podman with a clear picture of what they do underneath, and describe whole servers as code with Ansible.

These are the topics that separate someone who *uses* Linux from someone who can explain and fix anything that happens on it.

## What this level covers

- **Containers from first principles.** What Docker really does: namespaces, cgroups v2, `pivot_root`, overlayfs, veth networking, and the security layers on top. You'll build a working container in about 30 lines of shell.
- **Performance analysis.** A method instead of guesswork: the USE and RED methods, the 60-second checklist, `sysstat` (`iostat`, `mpstat`, `pidstat`, `sar`), `perf`, flame graphs, and eBPF tools.
- **Security.** Threat models, `sudo` hardening, capabilities, AppArmor, seccomp, auditing with `auditd`, and an operational hardening checklist.
- **Kernel basics.** Kernel subsystems and versions, modules, `sysctl` tuning, reading `dmesg`, taint, the kernel command line, panics and kdump, and building your own kernel module.
- **Advanced networking.** Packet capture with `tcpdump`, TCP states, virtual networks from namespaces, `nftables`, policy routing, WireGuard, and network performance.
- **Virtualization.** KVM, QEMU, and libvirt; cloud images with cloud-init; `virsh`; disk images and snapshots; and when a VM beats a container.
- **Docker and Podman.** The everyday container tools: Dockerfiles, storage, networking, Compose, rootless Podman under systemd, and image security.
- **Automation with Ansible.** Infrastructure as code: inventories, playbooks, handlers, templates, roles, and secrets, ending with a rebuild of your Level 4 server.

## What you'll be able to do

After this level you will be able to:

- Explain what a container is in terms of kernel features, and build one by hand that has its own hostname, PID 1, root filesystem, and memory and process limits.
- Diagnose a slow machine methodically, name the bottleneck resource, and prove it with numbers and histograms.
- Profile CPU usage with `perf` and read a flame graph.
- Trace system activity safely in production with eBPF tools such as `execsnoop`, `opensnoop`, and `biolatency`.
- Give a service only the privileges it needs, confine it with AppArmor and seccomp, and keep an audit trail of who changed what.
- Find, load, configure, and blacklist kernel modules, and make kernel tunables persistent.
- Read the kernel log and recognize OOM kills, disk errors, segfaults, and hung tasks.
- Write, build, and load a simple kernel module.
- Capture and read network traffic, build firewalls with `nftables`, and connect machines with WireGuard.
- Create and manage virtual machines with KVM and libvirt.
- Build, run, and secure container images with Docker and Podman.
- Configure servers repeatably with Ansible playbooks and roles.

## Chapters

| # | Chapter | What you'll learn | Time |
|---|---|---|---|
| 1 | [Containers from scratch](01-containers-from-scratch.md) | Namespaces, `unshare`, `nsenter`, cgroups v2, `pivot_root`, overlayfs, veth pairs, and how Docker, containerd, and runc fit together | ~75 min |
| 2 | [Performance analysis](02-performance-analysis.md) | USE and RED methods, the 60-second checklist, reading `iostat -x`, `perf`, flame graphs, and eBPF tools | ~70 min |
| 3 | [Security](03-security.md) | Threat models, `sudo` hardening, capabilities, AppArmor, seccomp, `auditd`, updates, fail2ban, and a hardening checklist | ~70 min |
| 4 | [Kernel basics](04-kernel-basics.md) | Subsystems, GA vs HWE kernels, modules, `sysctl`, `dmesg`, taint, the command line, a hello-world module, and kdump | ~65 min |
| 5 | [Advanced networking](05-advanced-networking.md) | `tcpdump`, TCP states, network namespaces, `nftables`, policy routing, WireGuard, and measuring network performance | ~75 min |
| 6 | [Virtualization](06-virtualization.md) | KVM, QEMU, and libvirt; cloud-init; `virsh`; disk images and snapshots; VMs vs containers | ~65 min |
| 7 | [Docker and Podman](07-docker-and-podman.md) | Installing Docker, Dockerfiles, volumes and networks, Compose, rootless Podman with systemd, and image security | ~75 min |
| 8 | [Automation with Ansible](08-automation-ansible.md) | Idempotency, inventories, playbooks, handlers, templates, roles, and Ansible Vault | ~75 min |
| ★ | [Level 6 capstone](../../exercises/level-6-capstone.md) | Build a minimal container with `unshare` and cgroups, or build Linux From Scratch | 4–8 h (A) or several days (B) |

Read the chapters in order. Chapters 1–4 cover the kernel features everything else is built on; chapters 5–8 apply them to networks, virtual machines, container tooling, and automation. The containers chapter in particular introduces namespaces, cgroups, capabilities, and seccomp, which later chapters rely on.

!!! danger "⚠️ VM only: this level needs your throwaway VM"
    More of this level touches the running kernel than any other: loading modules, changing kernel parameters, AppArmor policy, audit rules, firewall rules, network namespaces, and writing to the root of the cgroup tree. Every step like that is marked **⚠️ VM only**. The rootless container experiments, the read-only inspection commands, and building (not loading) the kernel module are safe on your main Mint machine.

## How to study this level

- **Run everything.** These topics only make sense once you've seen a process believe it is PID 1, or watched the OOM killer fire on a limit you set.
- **Keep the kernel log open.** Run `journalctl -kf` (or `dmesg -w`) in a spare terminal while you work. Half of what happens in this level shows up there first.
- **Take snapshots.** Snapshot the VM before each ⚠️ section, so a mistake costs a minute instead of a reinstall.
- **Write it up.** After each chapter, explain the topic in your own words in `notes/`. If you can't explain how a container gets its own `/proc`, reread that section.

## Where to go after this handbook

Finishing Level 6 means you have a solid map of Linux. These resources take you deeper into each territory.

**Books**

- *How Linux Works*, 3rd edition, by Brian Ward. A friendly, complete tour of the system from boot to networking: an excellent review of this whole handbook.
- *The Linux Programming Interface* by Michael Kerrisk. The definitive reference for system calls, processes, signals, namespaces, and more. Long, precise, and worth it if you write systems code.
- *Systems Performance*, 2nd edition, and *BPF Performance Tools*, both by Brendan Gregg. The books behind the USE method, flame graphs, and most of the eBPF tools in chapter 2.
- *Linux Kernel Development*, 3rd edition, by Robert Love. A readable introduction to kernel internals. Some details are dated (it covers 2.6), but the concepts hold.
- *Linux Device Drivers*, 3rd edition, by Corbet, Rubini, and Kroah-Hartman. Old, but free online and still the classic starting point for driver work.

**Build a system yourself**

- [Linux From Scratch (LFS)](https://www.linuxfromscratch.org/) walks you through compiling an entire Linux system from source code: toolchain, C library, core utilities, kernel, and bootloader. It's option B of the capstone. Beyond LFS (BLFS) continues with networking, a desktop, and servers.

**Documentation you'll keep coming back to**

- [The Linux kernel documentation](https://docs.kernel.org/): the admin guide (`sysctl`, kernel parameters, cgroups v2, taint), the user-space API guide, and driver documentation.
- [man7.org](https://man7.org/linux/man-pages/): the Linux man-pages project, maintained by Michael Kerrisk. Start with `namespaces(7)`, `cgroups(7)`, `capabilities(7)`, `user_namespaces(7)`, and `seccomp(2)`.
- [Brendan Gregg's website](https://www.brendangregg.com/): the USE method, the Linux performance tool maps, flame graphs, and eBPF articles.
- [LWN.net](https://lwn.net/): weekly, in-depth coverage of kernel development. The best way to understand *why* kernel features exist.
- [Kernel Newbies](https://kernelnewbies.org/): human-readable summaries of every kernel release, and a starting point if you want to contribute.
- [The AppArmor wiki](https://gitlab.com/apparmor/apparmor/-/wikis/home) and the [OCI runtime specification](https://github.com/opencontainers/runtime-spec) for the security and container chapters.

**Practice**

- Read the source of small, real tools: `runc`'s `libcontainer`, BusyBox applets, or the bcc tools in `/usr/sbin/*-bpfcc` (they're Python scripts you can open).
- Run a real service on your VM for a month and fix whatever breaks. Nothing teaches like your own outages.

## Capstone

When you've worked through the chapters, prove it with the [Level 6 capstone](../../exercises/level-6-capstone.md): build a minimal container from `unshare`, `pivot_root`, and cgroups that enforces real limits, or take on Linux From Scratch.
