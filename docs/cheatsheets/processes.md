# Processes Cheat Sheet

Quick reference for listing, monitoring, signaling, and prioritizing
processes. Chapters:
[Processes and signals](../chapters/03-internals/02-processes-and-signals.md),
[Devices, /proc, and /sys](../chapters/03-internals/05-devices-proc-sys.md),
[Processes and signals in code](../chapters/05-programming/03-processes-signals-in-code.md),
[Troubleshooting](../chapters/04-sysadmin/07-troubleshooting.md).

## ps: snapshot of processes

| Command | What it shows |
|---|---|
| `ps` | Processes in this terminal |
| `ps aux` | Every process, BSD style: user, %CPU, %MEM, VSZ, RSS, STAT, command |
| `ps -ef` | Every process, POSIX style: UID, PID, PPID, start time, command |
| `ps -ef --forest` | Process tree with parent/child indentation |
| `ps -u alex` | Processes owned by `alex` |
| `ps -C nginx` | Processes named exactly `nginx` |
| `ps -p 1234 -o pid,ppid,user,etime,cmd` | Chosen columns for one PID |
| `ps -eo pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head` | Top CPU users |
| `ps -eo pid,rss,cmd --sort=-rss | head` | Top memory users (RSS in KiB) |
| `ps -eLf` | Show threads (LWP column) |
| `pstree -p` | Tree view with PIDs |

```bash
ps aux | head -3
```

```text
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.2  0.0  23140 13656 ?        Ss   09:35   0:10 /sbin/init splash
root           2  0.0  0.0      0     0 ?        S    09:35   0:00 [kthreadd]
```

| Column | Meaning |
|---|---|
| `VSZ` | Virtual memory size (KiB): everything mapped, mostly not in RAM |
| `RSS` | Resident set size (KiB): physical memory actually in use |
| `TTY` | Controlling terminal (`?` = none, typical for daemons) |
| `TIME` | Total CPU time used, not wall-clock time |
| `[name]` | Square brackets: a kernel thread |

### Process state codes (`STAT`)

| Code | State | Code | Modifier |
|---|---|---|---|
| `R` | Running or runnable | `s` | Session leader |
| `S` | Sleeping, interruptible (waiting for an event) | `l` | Multi-threaded |
| `D` | Uninterruptible sleep (usually disk or network I/O) | `+` | In the foreground process group |
| `T` | Stopped (by a signal or ++ctrl+z++) | `<` | High priority (negative nice) |
| `t` | Stopped by a debugger | `N` | Low priority (positive nice) |
| `Z` | Zombie: exited, parent hasn't collected the status | | |
| `I` | Idle kernel thread | | |

## top and htop

`top` is always installed. `htop` is friendlier (`sudo apt install htop`).

| `top` key | Action | `htop` key | Action |
|---|---|---|---|
| ++shift+p++ | Sort by CPU | ++f6++ or `<` `>` | Choose the sort column |
| ++shift+m++ | Sort by memory | ++shift+m++ / ++shift+p++ | Sort by memory / CPU |
| ++shift+t++ | Sort by CPU time | ++f5++ or ++t++ | Tree view |
| ++1++ | Show each CPU separately | ++f3++ or ++slash++ | Search |
| ++c++ | Show full command lines | ++f4++ or ++backslash++ | Filter |
| ++u++ | Show one user's processes | ++u++ | Choose a user |
| ++k++ | Kill a process (asks PID and signal) | ++f9++ or ++k++ | Send a signal |
| ++r++ | Renice a process | ++f7++ / ++f8++ | Nice − / nice + |
| ++shift+h++ | Show threads | ++shift+h++ | Hide/show user threads |
| ++shift+v++ | Forest (tree) view | ++space++ | Tag a process |
| ++d++ | Change refresh delay | ++f2++ | Setup (columns, meters) |
| ++q++ | Quit | ++f10++ or ++q++ | Quit |

The top summary lines:

```text
top - 10:49:31 up  1:14,  2 users,  load average: 3.81, 3.63, 3.21
Tasks: 412 total,   2 running, 410 sleeping,   0 stopped,   0 zombie
%Cpu(s):  9.5 us,  2.9 sy,  0.0 ni, 86.9 id,  0.4 wa,  0.0 hi,  0.3 si,  0.0 st
MiB Mem :  15549.5 total,   2018.7 free,   9867.1 used,   5134.0 buff/cache
MiB Swap:   4096.0 total,   3500.2 free,    595.8 used.   5130.6 avail Mem
```

| Field | Meaning |
|---|---|
| `load average` | Average runnable + uninterruptible tasks over 1, 5, 15 minutes. Compare to the CPU count (`nproc`) |
| `us` / `sy` | CPU time in user programs / in the kernel |
| `ni` | User time for niced (low-priority) processes |
| `id` | Idle |
| `wa` | Idle while waiting for I/O: high means a disk bottleneck |
| `st` | Stolen by the hypervisor (VMs only) |
| `avail Mem` | Memory available for new programs without swapping. Watch this, not `free` |

## Signals and kill

A **signal** is a small asynchronous message the kernel delivers to a
process. `kill` sends one; the default is `SIGTERM`.

| No. | Name | Default action | Typical use |
|---|---|---|---|
| 1 | `SIGHUP` | Terminate | Terminal closed; many daemons reload config on it |
| 2 | `SIGINT` | Terminate | ++ctrl+c++ |
| 3 | `SIGQUIT` | Core dump | ++ctrl+backslash++ |
| 6 | `SIGABRT` | Core dump | Program called `abort()` |
| 9 | `SIGKILL` | Terminate | Force kill: **cannot be caught, blocked, or ignored** |
| 10 | `SIGUSR1` | Terminate | Application-defined (e.g. reopen logs) |
| 11 | `SIGSEGV` | Core dump | Invalid memory access |
| 12 | `SIGUSR2` | Terminate | Application-defined |
| 13 | `SIGPIPE` | Terminate | Wrote to a pipe with no reader |
| 14 | `SIGALRM` | Terminate | Timer expired |
| 15 | `SIGTERM` | Terminate | Polite "please exit": the default for `kill` |
| 17 | `SIGCHLD` | Ignore | A child process exited or stopped |
| 18 | `SIGCONT` | Continue | Resume a stopped process |
| 19 | `SIGSTOP` | Stop | Pause: **cannot be caught or ignored** |
| 20 | `SIGTSTP` | Stop | ++ctrl+z++ |

Numbers are for x86 and ARM Linux. Use names in scripts to be safe.

| Command | What it does |
|---|---|
| `kill 1234` | Send SIGTERM to PID 1234 |
| `kill -TERM 1234` | Same, explicit |
| `kill -HUP 1234` | Ask a daemon to reload |
| `kill -9 1234` / `kill -KILL 1234` | Force kill (last resort) |
| `kill -STOP 1234` / `kill -CONT 1234` | Pause / resume |
| `kill -0 1234` | Send nothing: just check that the PID exists and you may signal it |
| `kill -l` | List signal names and numbers |
| `kill -l 137` | Decode an exit status: prints `KILL` (137 = 128 + 9) |
| `killall nginx` | Signal all processes with that exact name |

!!! tip "Escalate gently"
    Send `SIGTERM` first and wait a few seconds, so the program can save data
    and clean up. Use `SIGKILL` only if it ignores `SIGTERM`. A process in
    state `D` can't be killed at all until its I/O completes.

## pgrep and pkill

| Command | What it does |
|---|---|
| `pgrep nginx` | PIDs whose name matches `nginx` (a regex) |
| `pgrep -a python` | PIDs with their full command lines |
| `pgrep -f 'app.py --port 8080'` | Match against the full command line |
| `pgrep -x bash` | Exact name match |
| `pgrep -u alex` | Processes owned by `alex` |
| `pgrep -n firefox` / `-o` | Newest / oldest matching process |
| `pgrep -c sshd` | Count matches |
| `pkill -f 'app.py'` | Send SIGTERM to matching processes |
| `pkill -HUP -x nginx` | Send a specific signal |
| `pkill -e -f worker` | Echo what was killed |

!!! warning "Common mistake: `pkill -f` matches too much"
    `-f` searches the whole command line, so `pkill -f python` also kills
    every Python program, including ones you didn't mean. Run the same
    pattern with `pgrep -a` first to see exactly what will match.

## Job control

| Command / key | What it does |
|---|---|
| `cmd &` | Start in the background |
| ++ctrl+z++ | Stop (pause) the foreground job |
| `jobs -l` | List jobs with PIDs |
| `bg %1` | Resume job 1 in the background |
| `fg %1` | Bring job 1 to the foreground (`fg` alone: most recent) |
| `kill %1` | Signal a job by job number |
| `wait` / `wait $pid` | Wait for background jobs / one PID to finish |
| `disown -h %1` | Keep job 1 running after the terminal closes |
| `nohup cmd > out.log 2>&1 &` | Start immune to hangup, output to a file |
| `setsid cmd` | Run in a new session, fully detached from the terminal |

For anything long-running, prefer `tmux` (survives disconnects) or a
`systemd-run --user` / systemd service.

## Priority: nice and renice

**Niceness** ranges from −20 (highest priority) to 19 (lowest). The default
is 0. Normal users can only increase niceness; lowering it needs root.

| Command | What it does |
|---|---|
| `nice -n 10 tar -czf big.tgz data/` | Start with niceness 10 |
| `nice -n 19 ./batch-job.sh` | Lowest CPU priority |
| `renice 15 -p 1234` | Set PID 1234's niceness to 15 |
| `renice 5 -u alex` | Set niceness for all of alex's processes |
| `sudo renice -5 -p 1234` | Raise priority (root only) |
| `ionice -c3 -p 1234` | Idle I/O class: disk access only when nothing else needs it |
| `ionice -c2 -n7 rsync -a src/ dst/` | Best-effort I/O, lowest level |
| `ps -o pid,ni,cmd -p 1234` | Show niceness |

## lsof: open files

Everything is a file, so `lsof` (list open files) shows files, directories,
sockets, and pipes in use.

| Command | What it shows |
|---|---|
| `lsof -p 1234` | Everything process 1234 has open |
| `lsof /var/log/syslog` | Which processes have this file open |
| `lsof +D /mnt/usb` | Processes using anything under a directory ("device is busy") |
| `lsof -u alex` | Files opened by `alex`'s processes |
| `sudo lsof -i :8080` | Who is using port 8080 |
| `sudo lsof -i TCP -s TCP:LISTEN` | All listening TCP sockets |
| `sudo lsof -nP -i` | All network connections, no DNS or port-name lookups |
| `sudo lsof +L1` | Deleted files still held open (disk space not freed) |

Alternatives: `ss -tlnp` for sockets, `fuser -v /path` for "who uses this".

## /proc: the kernel's view

Each process has a directory `/proc/PID/`. `/proc/self` is the process
reading it.

| Path | Contents |
|---|---|
| `/proc/PID/status` | Name, state, PPid, UIDs, memory (VmRSS), threads |
| `/proc/PID/cmdline` | Command line, NUL-separated: `tr '\0' ' ' < /proc/PID/cmdline` |
| `/proc/PID/environ` | Environment at start, NUL-separated (owner or root only) |
| `/proc/PID/cwd` | Symlink to the current working directory |
| `/proc/PID/exe` | Symlink to the executable |
| `/proc/PID/fd/` | One symlink per open file descriptor: `ls -l /proc/PID/fd` |
| `/proc/PID/maps` | Memory mappings: libraries, heap, stack |
| `/proc/PID/limits` | Resource limits (open files, processes, …) |
| `/proc/PID/io` | Bytes read and written |
| `/proc/loadavg` | Load averages, running/total tasks, last PID |
| `/proc/meminfo` | Detailed memory statistics (source for `free`) |
| `/proc/cpuinfo` | CPU model, flags, cores |
| `/proc/uptime` | Seconds since boot, and idle seconds |
| `/proc/sys/` | Tunable kernel parameters (see `sysctl`) |

```bash
grep -E '^(State|PPid|Threads|VmRSS)' /proc/$$/status
```

```text
State:	S (sleeping)
PPid:	2451
Threads:	1
VmRSS:	    5376 kB
```

## Quick recipes

```bash
ps -eo pid,%cpu,cmd --sort=-%cpu | head -n 6        # top 5 CPU users
ps -eo pid,rss,cmd --sort=-rss | head -n 6          # top 5 memory users
ps -eo stat,pid,ppid,cmd | awk '$1 ~ /^Z/'          # find zombies and their parents
pgrep -a -u alex python                              # alex's Python processes
watch -n 1 'ps -o pid,stat,%cpu,rss,cmd -p 1234'     # watch one process
timeout 30s ./slow-task.sh                           # kill it after 30 seconds
```
