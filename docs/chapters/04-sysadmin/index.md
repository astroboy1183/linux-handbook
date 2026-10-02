# Level 4: System administration

> **Level 4 · Overview** · ⏱️ ~8.5 hours of reading, plus 10–15 hours of exercises and the capstone · Prerequisites: [Level 3: How Linux works](../03-internals/index.md)

Level 3 showed you how Linux works inside. Level 4 is about running it: keeping services alive, scheduling jobs, connecting machines over the network, locking them down, protecting their data, and fixing them when they break. These are the day-to-day skills of a Linux system administrator, and they are just as useful to a developer or data engineer who deploys code to servers.

Every chapter is built around situations you will actually meet: an API that dies when you log out, a cron job that silently fails every night, a database port exposed to the internet, password-guessing bots in your SSH log, a backup that turns out to be empty, and a dashboard that is down at 09:00 on a Monday. By the end of the level, you will build and secure a small server from scratch.

## What you'll be able to do

By the end of this level, you'll be able to:

- Control services with `systemctl`, read any unit file, override packaged units safely with drop-ins, and write your own service units that run as a dedicated user, restart on failure, and start at boot.
- Find what happened and when with `journalctl`, filtering by unit, boot, priority, and time, and manage the journal's disk usage.
- Schedule jobs with cron, anacron, `at`, and systemd timers; avoid the classic cron pitfalls (`PATH`, `%`, lost output); and choose the right tool for each job.
- Explain IP addresses, subnets, routing, NAT, ports, sockets, and DNS resolution on Ubuntu, and inspect each layer with `ip`, `ss`, `ping`, `tracepath`, `mtr`, `dig`, `resolvectl`, and `curl -v`.
- Run a default-deny host firewall with `ufw`, understand the netfilter layers beneath it, order rules correctly, and never lock yourself out.
- Log in with SSH keys, write `~/.ssh/config` files, harden `sshd`, copy files with `scp`, `sftp`, and `rsync`, and build `-L`, `-R`, and `-D` tunnels.
- Partition, format, and mount disks, write safe `fstab` entries, explain LVM, RAID, and SMART, and design and test a 3-2-1 backup strategy.
- Troubleshoot methodically with the USE method and runbooks for a full disk, high CPU, low memory, a failing service, an unreachable network, and a slow system.
- Manage user accounts, password policy, and PAM, and keep logs rotated and under control.
- Grow storage online with LVM, survive a failed disk with RAID, and serve apps through nginx with TLS.

## Chapters

| # | Chapter | What it covers | Time |
|---|---|---|---|
| 1 | [systemd and journalctl](01-systemd-and-journalctl.md) | Units and unit types, unit file locations and precedence, `systemctl` in depth, writing services, `Type=` and `Restart=`, dependencies, drop-in overrides, user services and lingering, journald, `journalctl` filters, rsyslog | ~45 min |
| 2 | [Scheduling tasks](02-scheduling.md) | crontab syntax, user and system crontabs, `cron.daily` and `run-parts`, the cron environment and its pitfalls, anacron, `at`, systemd timers, `OnCalendar=`, `Persistent=`, cron vs timers | ~40 min |
| 3 | [Networking basics](03-networking-basics.md) | The TCP/IP layers, IPv4 and CIDR with subnet math, private ranges, NAT, IPv6, MAC and ARP, interface names, routing, TCP vs UDP, ports, sockets, DNS on Ubuntu, DHCP, NetworkManager, and the tools for each layer | ~50 min |
| 4 | [Firewalls with ufw](04-firewall-ufw.md) | Packet filtering, netfilter → nftables → ufw, stateful filtering and conntrack, default policies, rule order, app profiles, rate limiting, logging, gufw, `nft list ruleset`, and not locking yourself out | ~40 min |
| 5 | [SSH](05-ssh.md) | Key exchange, host keys and TOFU, key authentication, `ssh-keygen`, `ssh-copy-id`, the agent, `~/.ssh/config` and `ProxyJump`, permissions, `sshd_config` hardening, `scp`/`sftp`/`rsync`, port forwarding, fail2ban | ~50 min |
| 6 | [Disks and backups](06-disks-and-backups.md) | Block devices, MBR vs GPT, `fdisk`/`parted` on loop devices, `mkfs`, mounting and `fstab`, LVM and RAID concepts, SMART, 3-2-1, RPO/RTO, full vs incremental, `tar`, rsync snapshots, Timeshift, restic and borg | ~50 min |
| 7 | [Troubleshooting](07-troubleshooting.md) | Observe → hypothesize → test, the USE method, load average, and runbooks for a full disk, high CPU, low memory and OOM, a service that won't start, an unreachable network, and a slow system | ~45 min |
| 8 | [User management and PAM](08-user-management.md) | `useradd`/`adduser`, `usermod -aG`, password aging with `chage`, `/etc/shadow` fields, `/etc/skel`, safe sudoers editing with `visudo`, PAM stacks and modules, NSS and `getent`, onboarding and offboarding | ~45 min |
| 9 | [Logging and logrotate](09-logging-and-logrotate.md) | The logging pipeline (kernel, journald, rsyslog), facilities and severities, `logger`, a `/var/log` tour, journald limits, logrotate in depth, structured and centralized logging | ~40 min |
| 10 | [LVM and RAID](10-lvm-and-raid.md) | PV → VG → LV, growing filesystems online, snapshots, RAID levels, `mdadm` with failure and rebuild, all practiced on loop devices | ~45 min |
| 11 | [Web servers and TLS](11-web-servers-and-tls.md) | HTTP with `curl -v`, nginx server blocks and locations, reverse proxying an app, TLS and certificates, `openssl`, Let's Encrypt with certbot, security headers, Caddy | ~55 min |

Read the chapters in order. Chapters 1–7 are the core; chapters 8–11 build on them with the rest of a sysadmin's daily toolkit. Services come first because everything else runs as one: timers start services, the firewall protects them, SSH is one, backups are scheduled by them, and troubleshooting usually starts with `systemctl status`. Networking comes before the firewall and SSH because both depend on understanding ports and addresses.

## How long it takes

Plan on about **four to five weeks** at 45–60 minutes a day:

- **Reading**: about 8.5 hours in total. Read with a terminal open and run the read-only examples on your Mint machine as you go, which roughly doubles that.
- **Exercises**: each chapter has five, from easy to hard. Allow 1.5–2 hours per chapter. Many of the harder ones need your VM.
- **Capstone**: 4–8 hours, ideally over two or three sessions.

## Safety

Much of this level **changes system state**: installing services, editing firewall rules, hardening SSH, partitioning disks, and editing `/etc/fstab`. A mistake in any of those can cut off network access, lock you out of SSH, or stop a machine from booting. Every such step is marked **⚠️ VM only**. Do them in your throwaway VM, and take a VM snapshot before each chapter's hands-on work so you can roll back in seconds. If you have not set up the VM yet, do it now: [Set up your practice lab](../../lab-setup.md). An Ubuntu Server 24.04 guest with OpenSSH installed is ideal for this level.

Read-only commands (`systemctl status`, `journalctl`, `ip addr`, `ss -tln`, `dig`, `lsblk`, `df`, `top`) are safe on your main machine, and you should run them there too: knowing what "normal" looks like on your own system is half of troubleshooting.

## Capstone

The level ends with the [Level 4 capstone](../../exercises/level-4-capstone.md): set up a server from scratch in your VM, with key-only SSH, a default-deny firewall, a small web app running as a hardened systemd service under its own user, and nightly backups on a systemd timer, all proven with verification commands and a tested restore. Don't move on to Level 5 until you can build it again without notes.

## Start

Begin with [systemd and journalctl](01-systemd-and-journalctl.md).
