# Cheat Sheets

One-page quick references to keep open in a browser tab while you work. Each
one groups commands by task, with a short description and a practical
example. They're reminders, not tutorials: if a command here is new to you,
read the linked chapter first.

!!! tip "Make your own"
    The best cheat sheet is the one you write. Copy the commands you actually
    use into your own notes, with your own examples, and delete the rest.

<div class="grid cards" markdown>

-   :material-folder-outline:{ .lg .middle } **Navigation and files**

    ---

    `cd`, `ls`, `cp`, `mv`, `rm`, viewing files, `tar`/`gzip`/`zip`, disk
    usage, and links.

    [:octicons-arrow-right-24: Open](files-and-navigation.md)

-   :material-shield-key-outline:{ .lg .middle } **Permissions**

    ---

    Reading `ls -l`, `chmod` in octal and symbolic form, `chown`, `umask`,
    special bits, and `sudo`.

    [:octicons-arrow-right-24: Open](permissions.md)

-   :material-text-search:{ .lg .middle } **Text processing**

    ---

    `grep`, `sed`, `awk`, `cut`, `sort`, `uniq`, `tr`, `xargs`, regular
    expressions, `jq`, and classic one-liners.

    [:octicons-arrow-right-24: Open](text-processing.md)

-   :material-script-text-outline:{ .lg .middle } **Bash scripting**

    ---

    A safe script template, parameter expansion, tests, loops, functions,
    arrays, `getopts`, redirection, and special variables.

    [:octicons-arrow-right-24: Open](bash-scripting.md)

-   :material-chart-timeline-variant:{ .lg .middle } **Processes**

    ---

    `ps`, `top` and `htop` keys, signals and `kill`, job control, `nice`,
    `pgrep`/`pkill`, `lsof`, and `/proc`.

    [:octicons-arrow-right-24: Open](processes.md)

-   :material-cog-play-outline:{ .lg .middle } **systemd**

    ---

    `systemctl`, `journalctl`, a service unit template, a timer template,
    `OnCalendar` examples, and `systemd-analyze`.

    [:octicons-arrow-right-24: Open](systemd.md)

-   :material-lan:{ .lg .middle } **Networking**

    ---

    `ip`, `ss`, `ping`, `dig`, `curl`, `nc`, `ufw`, `nmcli`, common ports,
    and a CIDR table.

    [:octicons-arrow-right-24: Open](networking.md)

-   :material-key-chain:{ .lg .middle } **SSH**

    ---

    Keys, `~/.ssh/config`, the agent, `scp` and `rsync`, tunnels, `sshd`
    hardening, and troubleshooting.

    [:octicons-arrow-right-24: Open](ssh.md)

-   :material-keyboard-outline:{ .lg .middle } **Vim and tmux**

    ---

    Vim modes, motions, operators, search and replace, plus tmux sessions,
    windows, panes, and copy mode.

    [:octicons-arrow-right-24: Open](vim-tmux.md)

-   :material-book-alphabet:{ .lg .middle } **Glossary**

    ---

    Short, precise definitions of every term used in the handbook, from
    *ABI* to *zombie*.

    [:octicons-arrow-right-24: Open](glossary.md)

</div>

## Which chapter goes with which sheet?

| Cheat sheet | Main chapters |
|---|---|
| [Navigation and files](files-and-navigation.md) | [Your first commands](../chapters/00-first-steps/03-first-commands.md), [Working with files](../chapters/01-command-line/01-working-with-files.md), [Archives and compression](../chapters/01-command-line/08-archives-and-compression.md), [Filesystems, inodes, and links](../chapters/03-internals/04-filesystems-and-links.md) |
| [Permissions](permissions.md) | [Users, groups, and sudo](../chapters/00-first-steps/06-users-groups-sudo.md), [Permissions](../chapters/01-command-line/03-permissions.md) |
| [Text processing](text-processing.md) | [Pipes and redirection](../chapters/01-command-line/04-pipes-and-redirection.md), [Text processing](../chapters/01-command-line/05-text-processing.md) |
| [Bash scripting](bash-scripting.md) | All of [Level 2](../chapters/02-scripting/index.md) |
| [Processes](processes.md) | [Processes and signals](../chapters/03-internals/02-processes-and-signals.md), [Devices, /proc, and /sys](../chapters/03-internals/05-devices-proc-sys.md) |
| [systemd](systemd.md) | [systemd and journalctl](../chapters/04-sysadmin/01-systemd-and-journalctl.md), [Scheduling tasks](../chapters/04-sysadmin/02-scheduling.md), [Your program as a service](../chapters/05-programming/05-services-with-systemd.md) |
| [Networking](networking.md) | [Networking basics](../chapters/04-sysadmin/03-networking-basics.md), [Firewalls with ufw](../chapters/04-sysadmin/04-firewall-ufw.md) |
| [SSH](ssh.md) | [SSH](../chapters/04-sysadmin/05-ssh.md) |
| [Vim and tmux](vim-tmux.md) | [Vim essentials](../chapters/01-command-line/09-vim-essentials.md), [tmux](../chapters/01-command-line/10-tmux.md) |
