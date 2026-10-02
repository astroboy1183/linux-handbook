# Capstones

Each level ends with a **capstone**: a larger, realistic project that pulls
together everything the level taught. Chapter exercises check that you
understood one idea. A capstone checks that you can *combine* ideas to solve
a problem nobody has broken down into steps for you.

## The capstone philosophy

- **It proves skill, not recognition.** Reading a chapter and nodding along
  feels like learning. Building something from a blank terminal shows
  whether it actually is.
- **It's realistic on purpose.** Capstones look like work you'd really do:
  digging through a log file, writing a backup tool, building a server. The
  messiness is part of the lesson.
- **Struggle is the point.** Getting stuck, reading a man page, and getting
  unstuck is the skill you're building. A capstone you finish without effort
  was too easy, and you should skip ahead.
- **"Works without notes" is the bar.** When you're done, close everything
  except `man`, `--help`, and a terminal, and rebuild it. If you can, you're
  ready for the next level. If you can't, find the chapter you needed and
  try again in a few days.

!!! warning "Attempt it before you open the solution"
    The solutions are on separate pages, under **Capstones → Solutions** in
    the navigation, so you don't see them by accident. Open a solution only
    after you have a working result, to compare approaches. If you're truly
    stuck, reread the relevant chapter first, then sleep on it. Looking at
    the solution too early turns a capstone into a reading exercise.

## All seven capstones

| Level | Capstone | What you do | Time (est.) |
|---|---|---|---|
| 0 | [Find your way around](level-0-capstone.md) | Move around the filesystem confidently, explain where config, logs, programs, and personal files live, and find any command's documentation without a browser. | 1–2 hours |
| 1 | [Log file detective](level-1-capstone.md) | Answer real questions about a web server log using only pipelines: most frequent entries, errors per hour, and the top 10 of anything. | 2–4 hours |
| 2 | [A real backup script](level-2-capstone.md) | Write a backup script with options, logging, old-backup cleanup, and a dry-run mode that passes `shellcheck` with no warnings. | 4–8 hours |
| 3 | [Explain the machine](level-3-capstone.md) | Explain, in writing, what happens from power-on to the login screen and from typing `ls` to seeing output, naming every component involved. | 3–6 hours |
| 4 | [Server from scratch](level-4-capstone.md) | On a fresh VM, set up hardened SSH, a firewall, a small web app running as a systemd service, and nightly backups on a timer. | 6–12 hours |
| 5 | [A network server in Python](level-5-capstone.md) | Write a server that handles several clients at once, shuts down cleanly on signals, and runs as a systemd service. | 8–15 hours |
| 6 | [Container or Linux From Scratch](level-6-capstone.md) | Pick one: build a minimal container with `unshare` and cgroups, or build a Linux system from source with Linux From Scratch. | Container: 8–15 hours. LFS: several days |

The time estimates are for focused work, spread over several sessions. Taking
longer is normal and fine. Taking much less probably means the level was
review for you.

!!! danger "⚠️ VM only"
    The Level 4, 5, and 6 capstones change system services, firewall rules,
    users, and kernel features. Do them in your practice VM, and take a
    snapshot before you start. See [Set up your practice lab](../lab-setup.md).

## How to work on a capstone

1. **Read the whole brief first.** Note every requirement in your own words.
2. **Plan before typing.** Sketch the steps in your notes. Which chapters
   cover each part?
3. **Build in small pieces.** Get one part working, test it, then add the
   next. Commit each working step to git.
4. **Test the edge cases.** What happens with an empty file, a missing
   directory, a full disk, a client that disconnects? The briefs list
   specific checks.
5. **Record your mistakes** in your "mistakes I made" log as you go.
6. **Compare with the solution** once yours works. Note anything the solution
   does better.
7. **Rebuild without notes** a few days later. Only then tick it off in your
   [progress checklist](../progress.md).

## Solutions

Open these only after attempting the capstone.

- [Level 0 solution](solutions/level-0-capstone.md)
- [Level 1 solution](solutions/level-1-capstone.md)
- [Level 2 solution](solutions/level-2-capstone.md)
- [Level 3 solution](solutions/level-3-capstone.md)
- [Level 4 solution](solutions/level-4-capstone.md)
- [Level 5 solution](solutions/level-5-capstone.md)
- [Level 6 solution](solutions/level-6-capstone.md)
