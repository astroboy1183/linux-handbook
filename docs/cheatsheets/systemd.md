# systemd Cheat Sheet

Quick reference for managing services with `systemctl`, reading logs with
`journalctl`, writing unit and timer files, and analyzing boot. Chapters:
[systemd and journalctl](../chapters/04-sysadmin/01-systemd-and-journalctl.md),
[Scheduling tasks](../chapters/04-sysadmin/02-scheduling.md),
[Your program as a service](../chapters/05-programming/05-services-with-systemd.md),
[The boot process](../chapters/03-internals/01-boot-process.md).

## systemctl: control services

Commands that change state need `sudo`. Add `--user` to manage your own
per-user services instead (no `sudo`).

| Command | What it does |
|---|---|
| `systemctl status nginx` | State, PID, memory, and the last log lines |
| `sudo systemctl start nginx` | Start now |
| `sudo systemctl stop nginx` | Stop now |
| `sudo systemctl restart nginx` | Stop, then start |
| `sudo systemctl reload nginx` | Ask it to reload config without stopping (if supported) |
| `sudo systemctl reload-or-restart nginx` | Reload if possible, else restart |
| `sudo systemctl enable nginx` | Start automatically at boot |
| `sudo systemctl enable --now nginx` | Enable **and** start |
| `sudo systemctl disable --now nginx` | Disable **and** stop |
| `systemctl is-active nginx` | Prints `active`/`inactive`; exit status 0 if active |
| `systemctl is-enabled nginx` | Prints `enabled`/`disabled`/`masked`/`static` |
| `systemctl is-failed nginx` | Exit status 0 if failed |
| `sudo systemctl mask nginx` | Make it impossible to start (links the unit to `/dev/null`) |
| `sudo systemctl unmask nginx` | Undo `mask` |
| `sudo systemctl kill -s HUP nginx` | Send a signal to the service's processes |
| `sudo systemctl reset-failed` | Clear the "failed" state of units |

## systemctl: inspect

| Command | What it shows |
|---|---|
| `systemctl` | All loaded units (same as `list-units`) |
| `systemctl list-units --type=service` | Loaded services |
| `systemctl list-units --type=service --state=running` | Running services |
| `systemctl --failed` | Failed units: check this first when something's wrong |
| `systemctl list-unit-files --type=service` | Installed services and enabled state |
| `systemctl list-timers --all` | Timers, with next and last run times |
| `systemctl cat nginx` | The unit file and all its drop-ins |
| `systemctl show nginx -p MainPID,ActiveState` | Specific properties |
| `systemctl show -P MainPID nginx` | Just the value |
| `systemctl list-dependencies nginx` | Dependency tree |
| `systemctl get-default` | Default boot target (`graphical.target`) |

## Editing units

| Command | What it does |
|---|---|
| `sudo systemctl edit nginx` | Create a **drop-in** override (`/etc/systemd/system/nginx.service.d/override.conf`) |
| `sudo systemctl edit --full nginx` | Edit a full copy of the unit in `/etc/systemd/system/` |
| `sudo systemctl daemon-reload` | Reload unit files after editing them by hand |
| `sudo systemctl revert nginx` | Remove your overrides, back to the vendor unit |
| `systemd-analyze verify ./myapp.service` | Check a unit file for errors |

Unit file locations, highest priority first:

| Path | Used for |
|---|---|
| `/etc/systemd/system/` | Your units and overrides (admin) |
| `/run/systemd/system/` | Runtime units (gone at reboot) |
| `/usr/lib/systemd/system/` | Units installed by packages (don't edit) |
| `~/.config/systemd/user/` | Your per-user units (`systemctl --user`) |

## journalctl: read logs

Reading the full system journal needs membership in the `adm` or
`systemd-journal` group, or `sudo`. Without it, you see only your own
user's logs.

| Command | What it shows |
|---|---|
| `journalctl -u nginx` | Logs for one unit |
| `journalctl -u nginx -f` | Follow live, like `tail -f` |
| `journalctl -u nginx -n 50` | Last 50 lines |
| `journalctl -u nginx -e` | Jump to the end in the pager |
| `journalctl -u nginx --since "1 hour ago"` | Time window |
| `journalctl --since "2026-10-02 09:00" --until "2026-10-02 10:00"` | Absolute window |
| `journalctl --since today` | Also `yesterday`, `-2h`, `-15min` |
| `journalctl -b` | Since the current boot |
| `journalctl -b -1` | The previous boot (why did it crash?) |
| `journalctl --list-boots` | All recorded boots |
| `journalctl -p err -b` | Priority `err` and worse, this boot |
| `journalctl -k` | Kernel messages (like `dmesg`) |
| `journalctl -t sshd` | By syslog identifier |
| `journalctl _PID=1234` | By process ID |
| `journalctl -g 'timeout|refused'` | Filter messages by regex |
| `journalctl -x -u nginx` | Add explanatory help text |
| `journalctl -r` | Newest first |
| `journalctl -o json-pretty -n 1` | Show all fields of an entry |
| `journalctl -o cat -u myapp` | Message text only, no metadata |
| `journalctl --no-pager -u myapp | grep ...` | Pipe-friendly output |
| `journalctl --user -u myapp` | Your user services |
| `journalctl --disk-usage` | Space used by the journal |
| `sudo journalctl --vacuum-time=2weeks` | Delete entries older than 2 weeks |
| `sudo journalctl --vacuum-size=500M` | Shrink the journal to 500 MB |

Priorities: `emerg` (0), `alert` (1), `crit` (2), `err` (3), `warning` (4),
`notice` (5), `info` (6), `debug` (7). `-p warning` means 4 and worse.

## Service unit template

Save as `/etc/systemd/system/myapp.service`:

```ini
[Unit]
Description=My web app
Documentation=https://example.com/docs
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=alex
Group=alex
WorkingDirectory=/opt/myapp
EnvironmentFile=-/etc/myapp/env
ExecStart=/usr/bin/python3 /opt/myapp/app.py --port 8080
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5

# Hardening (see systemd-analyze security myapp)
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
StateDirectory=myapp
LogsDirectory=myapp

[Install]
WantedBy=multi-user.target
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
systemctl status myapp
journalctl -u myapp -f
```

| Directive | Meaning |
|---|---|
| `After=` / `Before=` | Ordering only: start after/before these units |
| `Wants=` / `Requires=` | Dependency: also start these (`Requires` fails if they fail) |
| `Type=simple` | The `ExecStart` process **is** the service (default) |
| `Type=exec` | Like simple, but start fails if the binary can't be executed |
| `Type=oneshot` | Runs to completion, then exits (scripts, timer jobs) |
| `Type=forking` | Old-style daemon that forks into the background |
| `Type=notify` | The program tells systemd when it's ready (`sd_notify`) |
| `ExecStart=` | The command. Use an absolute path; no shell features like `|` or `>` |
| `Environment=` / `EnvironmentFile=` | Variables; a `-` prefix means "ignore if missing" |
| `Restart=` | `no`, `on-failure`, `always`, `on-abnormal` |
| `StateDirectory=myapp` | Creates `/var/lib/myapp`, owned by the service user |
| `ProtectSystem=strict` | Whole filesystem read-only except allowed paths |
| `WantedBy=multi-user.target` | `enable` hooks it into normal (non-graphical) boot |

## Timer template

A timer starts a service of the same name on a schedule. Two files:

```ini title="/etc/systemd/system/backup.service"
[Unit]
Description=Nightly backup

[Service]
Type=oneshot
User=alex
ExecStart=/usr/local/bin/backup.sh
```

```ini title="/etc/systemd/system/backup.timer"
[Unit]
Description=Run backup.service every night

[Timer]
OnCalendar=*-*-* 02:30:00
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer    # enable the timer, not the service
systemctl list-timers backup.timer
sudo systemctl start backup.service         # run the job once now, to test
```

| Directive | Meaning |
|---|---|
| `OnCalendar=` | Wall-clock schedule (see below) |
| `OnBootSec=10min` | 10 minutes after boot |
| `OnUnitActiveSec=1h` | 1 hour after the service last started (repeats) |
| `Persistent=true` | If the machine was off at the scheduled time, run at next boot |
| `RandomizedDelaySec=` | Random delay, so many machines don't all fire at once |
| `Unit=other.service` | Start a differently named service |

For a quick one-off: `sudo systemd-run --on-active=30min /usr/local/bin/cleanup.sh`.

## OnCalendar examples

Format: `DayOfWeek Year-Month-Day Hour:Minute:Second`. `*` means any;
`a/b` means "starting at a, every b"; `..` is a range.

| Expression | When |
|---|---|
| `hourly` | `*-*-* *:00:00`: every hour on the hour |
| `daily` | `*-*-* 00:00:00`: midnight |
| `weekly` | `Mon *-*-* 00:00:00`: Monday midnight |
| `monthly` | `*-*-01 00:00:00`: first of the month |
| `*-*-* 02:30:00` | Every day at 02:30 |
| `Mon..Fri 09:00` | Weekdays at 09:00 |
| `Sat,Sun 10:00` | Weekends at 10:00 |
| `*:0/15` | Every 15 minutes (:00, :15, :30, :45) |
| `*-*-* 08..18:00:00` | Every hour from 08:00 to 18:00 |
| `*-*-01 03:00` | First day of every month at 03:00 |
| `*-01,07-01 00:00` | January 1 and July 1 |
| `quarterly` | `*-01,04,07,10-01 00:00:00` |

Always check an expression before using it:

```bash
systemd-analyze calendar 'Mon..Fri 09:00'
```

```text
  Original form: Mon..Fri 09:00
Normalized form: Mon..Fri *-*-* 09:00:00
    Next elapse: Mon 2026-10-05 09:00:00 IST
       (in UTC): Mon 2026-10-05 03:30:00 UTC
       From now: 2 days left
```

## systemd-analyze

| Command | What it shows |
|---|---|
| `systemd-analyze` | Total boot time: firmware, loader, kernel, userspace |
| `systemd-analyze blame` | Units sorted by startup time |
| `systemd-analyze critical-chain` | The chain of units that delayed boot the most |
| `systemd-analyze plot > boot.svg` | A boot timeline chart to open in a browser |
| `systemd-analyze calendar 'EXPR'` | Validate an `OnCalendar` expression |
| `systemd-analyze timespan 1h30min` | Validate a time span |
| `systemd-analyze verify FILE` | Check unit files for errors |
| `systemd-analyze security myapp` | Exposure score and hardening suggestions |

## Other systemd tools

| Command | What it does |
|---|---|
| `hostnamectl` | Show or set the hostname |
| `timedatectl` | Time, time zone, and NTP sync status |
| `localectl` | Locale and keyboard layout |
| `loginctl list-sessions` | Logged-in sessions |
| `systemd-cgls` | Control group tree: which process belongs to which unit |
| `systemd-cgtop` | `top` for control groups |
| `resolvectl status` | DNS servers in use |
| `systemctl reboot` / `poweroff` | Reboot / power off |

## Troubleshooting a service that won't start

1. `systemctl status myapp`: read the `Active:` line and the last log lines.
2. `journalctl -u myapp -b --no-pager | tail -50`: the full error.
3. `systemctl cat myapp`: is the unit what you think it is? Any overrides?
4. Run the `ExecStart` command by hand **as the service user**:
   `sudo -u alex /usr/bin/python3 /opt/myapp/app.py --port 8080`.
5. Check paths, permissions, and missing environment variables.
6. After fixing the unit file: `sudo systemctl daemon-reload`, then restart.
