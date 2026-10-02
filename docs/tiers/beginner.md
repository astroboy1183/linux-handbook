# 🌱 Beginner Tier

**Levels 0–2 · Goal: fluency** · ~6–10 weeks at 45–60 minutes a day

You start here if you have never used a terminal, or have used one only by copying commands from the internet. By the end you'll be fast and confident at the command line, and you'll write scripts that automate your work.

## What you'll be able to do

- Move around any Linux system and know where config, logs, programs, and personal files live.
- Find the documentation for any command without a browser.
- Create, move, find, archive, and edit files, including in vim over SSH.
- Read and fix permissions, and understand why `chmod 777` is never the answer.
- Chain small tools into pipelines that answer real questions about gigabytes of data.
- Write bash scripts with options, logging, error handling, and cleanup, and know when to switch to Python.

## The levels

<div class="grid cards" markdown>

-   :material-numeric-0-circle:{ .lg .middle } **Level 0: First steps**

    ---

    What Linux is, the terminal and shell, your first commands, getting help, the filesystem layout, and users and sudo.

    [:octicons-arrow-right-24: Start Level 0](../chapters/00-first-steps/index.md)

-   :material-numeric-1-circle:{ .lg .middle } **Level 1: Command-line fluency**

    ---

    Files, globbing, permissions, pipes, text processing, finding things, shell productivity, archives, vim, and tmux.

    [:octicons-arrow-right-24: Start Level 1](../chapters/01-command-line/index.md)

-   :material-numeric-2-circle:{ .lg .middle } **Level 2: Shell scripting**

    ---

    Scripts, variables and quoting, control flow, error handling, argument parsing, and knowing when to use Python.

    [:octicons-arrow-right-24: Start Level 2](../chapters/02-scripting/index.md)

</div>

## Tier checkpoint

You're ready for the [Intermediate tier](intermediate.md) when you can do all of these without notes:

- [ ] Explain the purpose of `/etc`, `/var/log`, `/usr/bin`, `/home`, and `/tmp`.
- [ ] Write a pipeline that prints the 10 most frequent IP addresses in a web server log.
- [ ] Explain why `x` permission on a directory is different from `x` on a file.
- [ ] Write a script that uses `set -euo pipefail`, `trap`, and `getopts`, and passes shellcheck.
- [ ] Recover from a dropped SSH connection without losing your running job (tmux).

See the [full roadmap](../roadmap.md) for every concept in this tier.
