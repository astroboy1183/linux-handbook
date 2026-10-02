# How to Use This Handbook

This page explains how the handbook is organized, where you should start,
and how to study so the material actually sticks. Read it once before you
begin, and come back whenever you feel stuck or rushed.

## The shape of the handbook

The handbook has **seven levels** in **three tiers**. Each level is a group of
chapters on one theme, and each level ends with a **capstone**: a larger,
realistic project that proves you can use the skills.

| Tier | Levels | Goal | Rough time |
|---|---|---|---|
| [🌱 Beginner](tiers/beginner.md) | 0 First steps · 1 Command line · 2 Scripting | Fluency | 6–10 weeks |
| [🔧 Intermediate](tiers/intermediate.md) | 3 How Linux works · 4 System administration | Understanding, then operations | 8–12 weeks |
| [🚀 Expert](tiers/expert.md) | 5 Building for Linux · 6 Expert topics | Building and mastery | 10–16 weeks |

The times assume 45–60 minutes a day, most days. Each tier page ends with a
**tier checkpoint**: a short list of things you should be able to do without
notes before you move to the next tier.

The [full roadmap](roadmap.md) lists every chapter with the concepts it
teaches. Use it to see where you are and what's coming next.

## Where to start

Be honest with yourself here. Skipping ahead feels efficient, but gaps in the
basics cost far more time later.

| Your experience | Start at |
|---|---|
| Never used a terminal, or only paste commands from the internet | [Level 0: First steps](chapters/00-first-steps/index.md). Read every chapter in order. |
| You can `cd`, `ls`, and edit files, but pipes and permissions are fuzzy | Skim Level 0, then start properly at [Level 1](chapters/01-command-line/index.md). |
| Comfortable in the shell day to day | Take the [Level 1 capstone](exercises/level-1-capstone.md) as a **placement test**. If you finish it without notes, start at [Level 2](chapters/02-scripting/index.md). If not, start at Level 1. |
| You write bash scripts already | Try the [Level 2 capstone](exercises/level-2-capstone.md). If your script passes `shellcheck` cleanly and handles errors properly, start at [Level 3](chapters/03-internals/index.md). |
| You run servers but never learned the internals | Do the [Beginner tier checkpoint](tiers/beginner.md), then start at Level 3. Don't skip Level 3: it explains *why* the sysadmin commands behave the way they do. |
| You administer Linux professionally | Try the [Level 4 capstone](exercises/level-4-capstone.md) and the [Intermediate tier checkpoint](tiers/intermediate.md). If both are easy, start at [Level 5](chapters/05-programming/index.md). |

!!! tip "Placement tests are cheap"
    Attempting a capstone costs an hour or two. If you get stuck, you've
    found exactly which chapters to read, and nothing is wasted.

## How each chapter is structured

Every chapter uses the same five parts, so you always know where to look.

1. **Why it matters.** A short story about a real situation where this
   knowledge saves time or prevents a mistake.
2. **Concepts.** The ideas in plain language, built up step by step, with
   diagrams. This is where you learn how things work underneath.
3. **Commands and examples.** Runnable commands with realistic output, and
   explanations of what each part of the output means.
4. **Exercises.** 3–5 tasks from easy to hard, each with a hidden solution.
5. **Check yourself.** Questions to answer from memory, with hidden answers.

Chapters close with **key takeaways** and a link to the next chapter.

Read the Concepts section slowly. The commands make sense only once you
understand the model behind them. Then type every example yourself.

## The study rhythm

Linux is a skill, like a language or an instrument. Skills come from
frequent practice, not from long reading sessions.

- **A short session most days beats a long one once a week.** Forty-five
  minutes a day for a week teaches more than a five-hour Sunday.
- **Write the chapter in your own words** after you finish it. A few
  paragraphs in your notes is enough. Explaining forces you to notice the
  parts you don't really understand yet.
- **Do the exercises in a real terminal, not in your head.** Reading a
  command and typing it are different skills. Only the second one counts.
- **Once a week, do one capstone-style task** or solve one real problem with
  that week's skills. For example: "Which directory is filling my disk?",
  "Which process keeps waking my laptop?", or "Automate my Downloads cleanup."

## How to do the exercises

Exercises are where learning happens. Reading the chapter only prepares you
for them.

1. **Use a real terminal.** Open one next to the page. On Mint, press
   ++ctrl+alt+t++.
2. **Work in a scratch directory** so mistakes stay contained:

    ```bash
    mkdir -p ~/lab && cd ~/lab
    ```

3. **Attempt the task before looking at anything.** Use `man`, `--help`,
   and the [cheat sheets](cheatsheets/index.md). Looking things up in the
   documentation is part of the skill, and it is not cheating.
4. **Don't peek at the solution.** Each solution is hidden in a collapsible
   box like the one below. Open it only after you have a working answer, or
   after you have been truly stuck for 15–20 minutes.

    ??? success "Solution"
        Solutions look like this. They show the commands, the output, and an
        explanation of *why* the answer works.

5. **Compare, don't copy.** If your answer differs from the solution but
   works, that's fine. Read the solution anyway: it often shows a cleaner
   approach or an edge case you missed.
6. **If you peeked, redo it tomorrow** from a blank terminal without looking.

## Capstones

A **capstone** is a larger project at the end of each level. It combines
everything from that level into one realistic task, like analyzing a real log
file, writing a backup tool, or building a secured server.

The rule is simple:

!!! warning "Don't move on until the capstone works without notes"
    "Works without notes" means you can rebuild it from a blank terminal
    using only `man` pages and `--help`, not the chapters or the solution.
    If you can't, go back to the chapters where you got stuck, then try
    again a few days later.

Capstone solutions are in a separate section on purpose. See the
[capstones overview](exercises/index.md) for all seven projects.

## Keep a "mistakes I made" log

Every mistake you make is a lesson that's worth more than any chapter,
because it's *yours*. Write each one down while it's fresh. Keep the file in
your notes, for example `~/linux-notes/mistakes.md`.

Use a simple format:

```markdown
## 2026-10-02: rm -rf with an empty variable

- What I did: ran `rm -rf "$dir/"*` in a script where $dir was empty.
- What happened: it tried to delete everything under / (in my VM, luckily).
- Why: an unset variable expands to nothing, so the path became "/*".
- Lesson: use `set -u`, and `${dir:?}` to stop if a variable is empty.
```

Reread the log every few weeks. Most people repeat the same handful of
mistakes, and seeing them in writing breaks the habit.

## Note-taking tips

- **Keep notes in plain text or Markdown in a git repository.** You're
  learning Linux, so manage your notes the Linux way. You'll practice git and
  your editor for free.
- **Write commands with their purpose**, not just the command. `du -sh * |
  sort -h` is useless in six months. "Find which folder is eating disk space"
  is what you'll search for.
- **Save output you found surprising**, with a line explaining what you
  learned from it.
- **Build your own cheat sheet.** The ones in this handbook are a starting
  point. Yours should contain the commands *you* actually use.
- **Record "how I figured it out"**, not just the answer. The method (which
  man page, which log, which command) transfers to the next problem.

## Conventions used in this handbook

### Code blocks and output

Commands appear in `bash` blocks with no prompt, so the copy button
(top-right of each block) copies only the command:

```bash
ls -l /etc/hostname
```

The output appears in a separate `text` block right after it:

```text
-rw-r--r-- 1 root root 5 Mar  2 09:14 /etc/hostname
```

Your output will differ in details like dates, sizes, and process IDs. That's
expected. Focus on the shape of the output.

When the prompt matters, for example to show which user or machine you're on,
a `console` block shows it with a `$` (normal user) or `#` (root):

```console
alex@mint:~$ whoami
alex
```

Examples use the username **alex**, the hostname **mint**, and the home
directory **/home/alex**. Substitute your own.

### Keyboard keys

Key combinations look like this: ++ctrl+c++ means hold Ctrl and press C.
++ctrl+alt+t++ means hold Ctrl and Alt together and press T.

### Admonitions

Colored boxes, called **admonitions**, mark different kinds of information:

!!! note
    Background detail or a side note.

!!! tip
    A faster or better way to do something.

!!! info
    Extra context, often about how things work underneath.

!!! example
    A worked example.

!!! warning "Common mistake"
    Something that trips up most people. Read these carefully.

!!! danger "⚠️ VM only"
    Run this in your throwaway VM, never on your main machine. These steps
    can delete data, break the boot process, or lock you out.

Some boxes are collapsible. Click the title to open them. Exercise solutions
and check-yourself answers use collapsible boxes so you don't see them by
accident.

### ⚠️ VM only

Anything that could damage your system is marked <span class="vm-only">⚠️ VM
only</span>. That includes deleting system files, partitioning disks,
changing firewall rules, editing kernel parameters, and most commands run as
root that change system configuration. Never run those on your main machine.
Set up a practice VM with the [lab setup guide](lab-setup.md) before you
reach Level 3, and take a snapshot before every risky exercise.

## The reference distro

Everything in this handbook is tested on **Linux Mint 22.3**, which is based
on **Ubuntu 24.04 LTS**. That means:

- The shell is **bash**.
- Packages are managed with **apt** (and `dpkg` underneath).
- The init system and service manager is **systemd**.

If you use **Ubuntu 24.04** itself, everything applies as written. **Debian
12/13** and other Ubuntu-based distros (Pop!_OS, Zorin, elementary) should
also be fine. You'll find occasional differences in default packages or
desktop tools.

### Notes for Fedora and Arch users

You can follow along on Fedora or Arch, but expect to translate some
commands. The concepts are identical; mostly the package manager and a few
defaults differ.

| Task | Mint / Ubuntu / Debian | Fedora | Arch |
|---|---|---|---|
| Refresh package lists | `sudo apt update` | automatic (`dnf check-update` to see updates) | `sudo pacman -Sy` (only as part of `-Syu`) |
| Upgrade everything | `sudo apt upgrade` | `sudo dnf upgrade` | `sudo pacman -Syu` |
| Install a package | `sudo apt install htop` | `sudo dnf install htop` | `sudo pacman -S htop` |
| Remove a package | `sudo apt remove htop` | `sudo dnf remove htop` | `sudo pacman -R htop` |
| Search packages | `apt search nginx` | `dnf search nginx` | `pacman -Ss nginx` |
| Show package details | `apt show nginx` | `dnf info nginx` | `pacman -Si nginx` |
| List installed packages | `apt list --installed` | `rpm -qa` | `pacman -Q` |
| Which package owns a file? | `dpkg -S /usr/bin/ls` | `rpm -qf /usr/bin/ls` | `pacman -Qo /usr/bin/ls` |
| List a package's files | `dpkg -L coreutils` | `rpm -ql coreutils` | `pacman -Ql coreutils` |
| Remove unneeded dependencies | `sudo apt autoremove` | `sudo dnf autoremove` | `sudo pacman -Rns $(pacman -Qdtq)` |
| Compiler toolchain | `build-essential` | `sudo dnf group install development-tools` | `base-devel` |

Other differences to watch for:

- **Admin group:** Ubuntu and Mint use the `sudo` group. Fedora and Arch use
  `wheel`.
- **Firewall:** this handbook uses `ufw`. Fedora uses `firewalld`
  (`firewall-cmd`). Arch has no firewall enabled by default.
- **Mandatory access control:** Ubuntu uses AppArmor. Fedora uses SELinux.
- **Package names:** some differ, for example `dnsutils` (Debian) versus
  `bind-utils` (Fedora) for `dig`.

!!! tip "Easiest option"
    If you're on another distro, run Ubuntu Server 24.04 or Mint 22.3 in a VM
    for the exercises. The [lab setup guide](lab-setup.md) shows how. Then
    every command works exactly as written.

## Your first steps

1. [Set up your practice lab](lab-setup.md), at least the "first-day setup"
   part. The VM can wait until Level 3.
2. Copy the [progress checklist](progress.md) into your notes.
3. Start your "mistakes I made" log (an empty file is fine).
4. Begin at the level you chose above. For most people, that's
   [Level 0: First steps](chapters/00-first-steps/index.md).
