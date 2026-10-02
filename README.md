# Linux Handbook

A hands-on handbook for learning Linux from the ground up and working up to
expert level. It assumes no prior Linux knowledge. It's written for beginners,
such as developers and data engineers, who want to truly master Linux, not
just get by.

📖 **Read it online:** <https://astroboy1183.github.io/linux-handbook/>

The handbook has three goals, and every chapter serves at least one of them:

1. **Fluency.** Get comfortable with the command line and become fast at
   everyday tasks.
2. **Understanding.** Learn how Linux actually works underneath: boot, kernel,
   processes, memory, filesystems, networking.
3. **Building.** Write scripts, programs, and services that run well on Linux.

## Environment

- **Distro:** Linux Mint 22.3 (based on Ubuntu 24.04, so `apt` and systemd).
  Any Ubuntu or Debian system works too.
- **Shell:** bash
- **Practice ground:** your machine for safe exercises, plus a throwaway
  virtual machine (VM) for anything risky. Never try deleting files,
  partitioning disks, or changing firewall rules on the main machine first.

## Roadmap

Three tiers, seven levels, and 54 chapters, from complete beginner to expert.
Each level ends with a capstone exercise that proves the skills. Don't move on
until the capstone works without notes. The full syllabus, with the concepts
taught in every chapter, is in [`docs/roadmap.md`](docs/roadmap.md).

| Tier | Levels | Goal | Est. time |
|---|---|---|---|
| 🌱 Beginner | 0–2 | Fluency: command line and scripting | 6–10 weeks |
| 🔧 Intermediate | 3–4 | Understanding and operations: internals and sysadmin | 8–12 weeks |
| 🚀 Expert | 5–6 | Building and mastery: programming, containers, performance, security, automation | 10–16 weeks |

### 🌱 Beginner

**Level 0: First steps.** What Linux is (kernel, GNU, distributions) · the
terminal, shell, and prompt · first commands · getting help (`man`, `--help`,
`apropos`, `tldr`) · the filesystem layout · users, groups, and `sudo`.
**Capstone:** move around confidently, explain where config, logs, programs,
and personal files live, and find any command's docs without a browser.

**Level 1: Command-line fluency.** Working with files · globbing and brace
expansion · permissions and umask · pipes and redirection · text processing
(`grep`, `sed`, `awk`, `sort`, `uniq`, `xargs`, …) · `find` and `locate` ·
history, aliases, and `.bashrc` · archives and compression · vim essentials ·
tmux.
**Capstone:** answer questions about a real log file using only pipelines.

**Level 2: Shell scripting.** Shebangs and running scripts · variables,
quoting, and arrays · conditionals, loops, and functions · error handling
(`set -euo pipefail`, `trap`, shellcheck) · `getopts` · when to switch to
Python.
**Capstone:** a backup script with options, logging, rotation, and dry-run mode
that passes shellcheck.

### 🔧 Intermediate

**Level 3: How Linux works.** Boot (firmware → GRUB → kernel → systemd) ·
processes and signals · virtual memory, the page cache, swap, and the OOM
killer · filesystems, inodes, links, and mounting · devices, `/proc`, and
`/sys` · installing software (apt, dpkg, PPAs, snap, flatpak, source).
**Capstone:** explain power-on to login screen, and keypress to `ls` output,
naming every component.

**Level 4: System administration.** systemd and journalctl · cron and systemd
timers · networking (IP, CIDR, DNS, `ip`, `ss`, `dig`, `curl`) · ufw ·
SSH (keys, config, hardening, tunnels, rsync) · disks and backups ·
troubleshooting runbooks · user management and PAM · logging and logrotate ·
LVM and RAID · nginx, reverse proxies, and TLS.
**Capstone:** set up a server from scratch in a VM with secure SSH, a firewall,
a web app as a systemd service, and nightly backups on a timer.

### 🚀 Expert

**Level 5: Building for Linux.** System calls and `strace` · file descriptors
in code · processes and signals in code · pipes and sockets · running your
program as a hardened systemd service · building software (gcc, ELF, shared
libraries, make, `.deb` packages) · debugging (gdb, core dumps, valgrind,
sanitizers).
**Capstone:** a multi-client network server in Python with clean signal
handling, running as a systemd service.

**Level 6: Expert topics.** Containers from first principles (namespaces,
cgroups, overlayfs) · performance analysis (`perf`, `sar`, `iostat`, flame
graphs, eBPF) · security (capabilities, AppArmor, seccomp, auditd) · kernel
basics (modules, `sysctl`, `dmesg`) · advanced networking (tcpdump, network
namespaces, nftables, WireGuard) · virtualization (KVM, QEMU, libvirt,
cloud-init) · Docker and Podman · automation with Ansible.
**Capstone (pick one):** build a minimal container using `unshare` and
cgroups, or build Linux From Scratch.

## Structure

```
linux-handbook/
  README.md            this file: goals, roadmap, conventions
  STYLE.md             the writing and formatting rules every page follows
  mkdocs.yml           website configuration and navigation
  docs/                everything published on the website
    index.md           home page
    roadmap.md         the full syllabus
    tiers/             beginner / intermediate / expert overviews
    chapters/          one Markdown file per topic, grouped by level
      00-first-steps/
      01-command-line/
      02-scripting/
      03-internals/
      04-sysadmin/
      05-programming/
      06-expert/
    exercises/         capstones, with solutions kept separate in solutions/
    cheatsheets/       one-page quick references and a glossary
  scripts/             reference scripts from the capstones
  notes/               personal notes, plus a "mistakes I made" log (not published)
```

## Chapter format

Every chapter follows the same parts so the handbook stays consistent:

1. **Why it matters.** A real situation where this knowledge saves time or
   prevents a mistake.
2. **Concepts.** The idea explained in plain language, with diagrams where
   they help. No assumed knowledge beyond earlier chapters.
3. **Commands and examples.** Runnable on Mint, with output shown and
   explained.
4. **Exercises.** 3–5 tasks, from easy to hard, with collapsible solutions.
5. **Check yourself.** Questions to answer without notes.

Then come key takeaways and a link to the next chapter. See
[STYLE.md](STYLE.md) for the full rules.

## Conventions

- Every command must run on Linux Mint 22.3 / bash as written.
- Mark anything risky with **⚠️ VM only**.
- Define every new term the first time it appears.
- Teach the classic tool first, then mention modern alternatives.
- Keep a running "mistakes I made" log in `notes/`.

## Study rhythm

- A short session most days beats a long one once a week.
- After each topic, write the chapter in your own words. Writing it is how
  the material sticks.
- Do the exercises in a real terminal, not in your head.
- Once a week, do one capstone-style task or solve one real problem using
  that week's skills.

## Working on the site

The site is built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt   # pinned: MkDocs 2.0 is incompatible
.venv/bin/mkdocs serve        # live preview at http://127.0.0.1:8000
.venv/bin/mkdocs build --strict
```

Every push to `main` deploys the site to GitHub Pages through
`.github/workflows/deploy.yml`.
