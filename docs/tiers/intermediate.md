# 🔧 Intermediate Tier

**Levels 3–4 · Goal: understanding, then operations** · ~8–12 weeks at 45–60 minutes a day

You can use Linux. Now you'll learn how it *works*: what the kernel does at boot, how processes and memory behave, and how filesystems are built. Then you'll use that understanding to run real servers.

## What you'll be able to do

- Trace the whole path from power-on to login screen, and from a keypress to command output.
- Read `top`, `free`, `vmstat`, and `df` correctly, including why "free memory is low" usually isn't a problem.
- Explain inodes, hard and soft links, mounts, and why `df` and `du` disagree.
- Manage software, services, timers, users, logs, disks (LVM and RAID), and firewalls.
- Set up hardened SSH, nginx as a reverse proxy, and TLS certificates.
- Troubleshoot a broken server methodically instead of guessing.

## The levels

<div class="grid cards" markdown>

-   :material-numeric-3-circle:{ .lg .middle } **Level 3: How Linux works**

    ---

    Boot, processes and signals, memory, filesystems and links, devices with `/proc` and `/sys`, and package management.

    [:octicons-arrow-right-24: Start Level 3](../chapters/03-internals/index.md)

-   :material-numeric-4-circle:{ .lg .middle } **Level 4: System administration**

    ---

    systemd, scheduling, networking, firewalls, SSH, disks and backups, troubleshooting, users and PAM, logging, LVM and RAID, and web servers with TLS.

    [:octicons-arrow-right-24: Start Level 4](../chapters/04-sysadmin/index.md)

</div>

## Tier checkpoint

You're ready for the [Expert tier](expert.md) when you can do all of these without notes:

- [ ] Explain what GRUB, the initramfs, and systemd each do during boot.
- [ ] Explain what a zombie process is and how to get rid of one.
- [ ] Explain the difference between "free" and "available" memory.
- [ ] Write a systemd service and a timer from scratch, and debug them with `journalctl`.
- [ ] Explain how a DNS lookup works on Ubuntu, from `/etc/nsswitch.conf` to the stub resolver at 127.0.0.53.
- [ ] Rebuild the Level 4 capstone server in a fresh VM in under an hour.

See the [full roadmap](../roadmap.md) for every concept in this tier.
