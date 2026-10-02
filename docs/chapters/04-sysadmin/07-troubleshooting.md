# Troubleshooting

> **Level 4 · Chapter 7** · ⏱️ ~45 min read · Prerequisites: all earlier Level 4 chapters, [Processes and signals](../03-internals/02-processes-and-signals.md), [Memory](../03-internals/03-memory.md)

This chapter turns everything in Level 4 into a method for fixing real problems. You will learn a systematic way to investigate, then work through runbooks for the six problems every Linux admin meets: a full disk, high CPU, low memory, a service that will not start, a network that cannot be reached, and a system that is simply slow.

## Why it matters

At 09:12 on a Monday, Alex gets a message: "the dashboard is down". Alex logs in to the server and does what many people do under pressure: restarts the web app. It comes back for four minutes, then dies again. Alex restarts the database too, just in case. Then the whole server. Forty minutes pass.

A senior colleague joins and spends ninety seconds: `systemctl status webapp` shows `No space left on device` in the last log lines. `df -h` shows `/` at 100%. `du` finds a 38 GB debug log written by a job someone left in verbose mode over the weekend. Delete, restart, done.

The difference was not knowledge of some obscure command. It was **method**: look at the evidence first, form a hypothesis, and test it with one command, instead of changing things and hoping. This chapter teaches that method and gives you the evidence-gathering commands for each common failure.

## Concepts

### Observe, hypothesize, test

Troubleshooting is the scientific method on a deadline. Every investigation repeats one loop:

```mermaid
flowchart LR
    O["Observe<br/>What exactly is wrong?<br/>Collect evidence"] --> H["Hypothesize<br/>What could cause<br/>exactly this?"]
    H --> T["Test<br/>One command that proves<br/>or disproves it"]
    T -->|"disproved"| H
    T -->|"confirmed"| F["Fix<br/>Smallest change<br/>that addresses the cause"]
    F --> V["Verify<br/>Symptom gone?<br/>Write it down"]
    V -->|"no"| O
```

**Observe.** Before touching anything, define the symptom precisely. "The site is down" is not a symptom. "`curl -v http://localhost:8080` returns `Connection refused` since 09:05; `systemctl status webapp` says `failed`" is a symptom. Note **when** it started, and **what changed** around that time: a deploy, an update, a config edit, a traffic spike, a cron job. Most outages are caused by a change.

**Hypothesize.** List possible causes that would produce *exactly* this evidence. "Connection refused" suggests nothing is listening; it does not suggest a slow database.

**Test.** Pick the cheapest test that cleanly separates your hypotheses. Read-only commands first. Change **one thing at a time**, so you know what fixed it.

**Fix and verify.** Apply the smallest fix that addresses the cause, confirm the symptom is gone, and **write down what happened**. The README's "mistakes I made" log is the right place.

Three habits make the loop work:

- **Do not restart first.** A restart often hides the problem for a while and destroys the evidence (the process state, the open files, the error in memory). Collect evidence, *then* restart if needed.
- **Read the actual error message**, completely. Most problems announce themselves: `Permission denied`, `Address already in use`, `No space left on device`.
- **Know what normal looks like.** Run `top`, `free -h`, `df -h`, and `ss -tln` on a healthy system now, so the abnormal stands out later.

### The USE method

When the problem is vague ("everything is slow"), you need a checklist so you do not chase the first thing you notice. Brendan Gregg's **USE method** gives you one. For every **resource** (CPU, memory, disk I/O, disk capacity, network), check three things:

| Letter | Question | Example for CPU | Example for disk |
|--------|----------|-----------------|------------------|
| **U**tilization | How busy is it, as a percentage of time or capacity? | `%Cpu(s): 95 us` in `top` | `%util` in `iostat`; `Use%` in `df` |
| **S**aturation | Is work queuing up because it is too busy? | Load average > number of CPUs; `r` column in `vmstat` | `aqu-sz` and `await` in `iostat` |
| **E**rrors | Are there error events? | Rarely relevant | I/O errors in `dmesg`; SMART errors |

Going through the table resource by resource takes a few minutes and stops you from missing the real bottleneck. A resource can be 100% utilized and fine (a batch job using all CPUs is doing its job), or only 60% utilized but saturated in bursts. Saturation is usually what users feel as "slow".

Linux also exposes saturation directly as **pressure stall information** (PSI), in `/proc/pressure/cpu`, `/proc/pressure/memory`, and `/proc/pressure/io`. `some avg10=12.50` means that over the last 10 seconds, at least one task was stalled waiting for that resource 12.5% of the time. Non-zero memory or I/O pressure is a strong hint.

### Load average, explained properly

`uptime` and `top` show three **load averages**:

```text
 10:38:06 up  1:02,  1 user,  load average: 4.50, 3.69, 2.84
```

They are the average number of tasks that were **running or waiting to run** (on CPU or in the run queue), **plus tasks in uninterruptible sleep** (state `D`, usually waiting for disk or network storage), over the last 1, 5, and 15 minutes.

Two consequences:

1. **Compare load with the number of CPUs** (`nproc`). A load of 4.5 is heavy on a 2-CPU VM (tasks are waiting) and light on a 16-CPU machine.
2. **High load does not always mean high CPU.** On Linux, processes stuck waiting for a slow disk count towards load. A load of 30 with an idle CPU means an I/O problem, not a CPU problem.

The three numbers also show the trend: `4.50, 3.69, 2.84` means load is rising (1-minute is higher than 15-minute).

### Where the evidence lives

| Question | First place to look |
|----------|---------------------|
| What failed and why? | `systemctl status UNIT`, `journalctl -xeu UNIT` |
| What happened around a time? | `journalctl --since "09:00" --until "09:15"` |
| Did the kernel complain? | `journalctl -k` or `sudo dmesg -T` (OOM kills, disk errors, segfaults) |
| Who logged in, who used sudo? | `/var/log/auth.log`, `journalctl -u ssh` |
| What changed? | `/var/log/apt/history.log`, `/var/log/dpkg.log`, `git log` of your config repo, `ls -lt /etc` |
| What is the machine doing right now? | `top`, `vmstat 1`, `ss -tnp`, `iostat -xz 1` |

!!! tip "Install the tools before you need them"
    Several tools in this chapter are not installed on Mint by default: `sysstat` (provides `iostat`, `pidstat`, `sar`), `ncdu`, `htop`, and `traceroute`. Install them on every server you manage, while it is healthy: `sudo apt install sysstat ncdu htop traceroute`. During an outage, a full disk or a broken network may stop you from installing anything.

## Commands and examples

Each runbook below follows the same shape: **symptom → commands → reading the output → fix**, first as a table you can scan during an incident, then with the key commands explained.

### Runbook 1: Disk full

**Symptoms:** `No space left on device` errors; services crash or refuse to start; you cannot save files; `apt` fails; logs stop; database writes fail.

| Step | Command | Reading the output | Fix |
|------|---------|--------------------|-----|
| 1. Which filesystem? | `df -h` | A `Use%` of 100% (or 95%+) and its `Mounted on` | Focus on that mount point |
| 2. Is it inodes instead? | `df -i` | `IUse%` at 100% while `df -h` shows free space | See inode exhaustion below |
| 3. What is big? | `sudo du -xh --max-depth=1 /var | sort -h` | The largest directories at the bottom; repeat one level deeper | Delete, compress, or move the culprit |
| 4. Interactive drill-down | `sudo ncdu -x /` | Browse by size; `d` deletes | Same |
| 5. Big single files | `sudo find / -xdev -type f -size +500M -printf '%s %p\n' | sort -n | tail` | The largest files on that filesystem | Same |
| 6. `df` and `du` disagree | `sudo lsof +L1` | Files marked `(deleted)` still held open, with their size | Restart (or reload) the process holding them |
| 7. Logs | `journalctl --disk-usage`; `ls -lhS /var/log | head` | Journal or text logs taking GBs | `sudo journalctl --vacuum-size=200M`; fix logrotate; fix the noisy app |
| 8. Package cache | `du -sh /var/cache/apt/archives` | Old `.deb` files | `sudo apt clean` |

#### Finding what is big

```bash
df -h
```

```text
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           392M  1.6M  390M   1% /run
/dev/vda2        24G   24G     0 100% /
tmpfs           2.0G     0  2.0G   0% /dev/shm
/dev/vda1       512M  6.1M  506M   2% /boot/efi
```

`/` is full. Drill down with `du`, staying on that one filesystem:

```bash
sudo du -xh --max-depth=1 / 2>/dev/null | sort -h | tail -n 5
```

```text
1.2G	/home
3.1G	/usr
2.4G	/snap
16G	/var
24G	/
```

- **`-x`**: stay on one filesystem; do not descend into `/proc`, other disks, or network mounts. Without it, `du` wanders everywhere and takes forever.
- **`-h`** with **`sort -h`**: human-readable sizes that still sort correctly (`2.4G` above `900M`).
- **`2>/dev/null`**: hides "Permission denied" noise.

`/var` holds 16G. Repeat with `/var`, then `/var/log`, and so on. Usually two or three levels find it:

```bash
sudo du -xh --max-depth=1 /var/log | sort -h | tail -n 3
```

```text
1.1G	/var/log/journal
14G	/var/log/webapp
16G	/var/log
```

`ncdu` (NCurses Disk Usage) does the same thing interactively: arrow keys to navigate, sorted by size. `sudo ncdu -x /` is the fastest way to explore.

!!! warning "Common mistake"
    Deleting a huge log file that a running process is still writing to, then seeing that `df` does not change at all. See the next section. For a log that is actively written, **truncate** it instead of deleting it: `sudo truncate -s 0 /var/log/webapp/debug.log`. The process keeps its open file, which is now empty, and the space is freed immediately.

#### Deleted but still open: when df and du disagree

A file's data is freed only when **no name and no open file descriptor** refer to it (recall link counts from [Filesystems, inodes, and links](../03-internals/04-filesystems-and-links.md)). If you `rm` a 14 GB log while the app still has it open, the name disappears, `du` stops counting it, but `df` still shows the space as used. `lsof +L1` lists open files whose link count is less than 1, meaning deleted:

```bash
sudo lsof +L1
```

```text
COMMAND   PID   USER   FD   TYPE DEVICE    SIZE/OFF NLINK    NODE NAME
python3  2741 webapp    3w   REG  252,2 15032385536     0 1048602 /var/log/webapp/debug.log (deleted)
```

- **`FD 3w`**: file descriptor 3, open for writing.
- **`SIZE/OFF`**: 15 GB, still on disk.
- **`NLINK 0`**: no names left.
- **`(deleted)`**: confirmed.

Fixes, gentlest first: make the program reopen its log (`sudo systemctl reload webapp`, if it supports reload), or restart it (`sudo systemctl restart webapp`). In an emergency, you can even truncate the deleted file through `/proc`: `sudo truncate -s 0 /proc/2741/fd/3`.

#### Inode exhaustion

Every file uses one **inode**, and ext4 has a fixed number of them, chosen at `mkfs` time. Millions of tiny files (session files, cache entries, mail queue files) can use up every inode while gigabytes of space remain:

```bash
df -h /; df -i /
```

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda2        24G   11G   12G  48% /
Filesystem      Inodes   IUsed  IFree IUse% Mounted on
/dev/vda2      1572864 1572864      0  100% /
```

48% space, 100% inodes: new files cannot be created. Find directories with the most files:

```bash
sudo find / -xdev -type f -printf '%h\n' 2>/dev/null | sort | uniq -c | sort -rn | head -n 5
```

```text
1402117 /var/lib/php/sessions
   9841 /usr/share/man/man3
   ...
```

`%h` prints each file's directory; `uniq -c` counts files per directory. Fix: delete the stale files (`find /var/lib/php/sessions -type f -mtime +2 -delete`), then fix whatever was supposed to clean them up.

#### The journal and other usual suspects

```bash
journalctl --disk-usage
sudo journalctl --vacuum-size=200M
ls -lhS /var/log | head -n 5
sudo apt clean
```

Other frequent space hogs: old kernels (`sudo apt autoremove`), Docker images and volumes (`docker system df`), core dumps (`/var/lib/systemd/coredump/`), and snap revisions (`snap list --all`). On ext4, remember the 5% reserved for root: an ordinary user sees "disk full" a little before root does.

### Runbook 2: High CPU

**Symptoms:** everything is sluggish; fans spin; `top` shows a process at 100% or more; load average is high.

| Step | Command | Reading the output | Fix |
|------|---------|--------------------|-----|
| 1. Overall picture | `uptime`; `nproc` | Load vs number of CPUs; rising or falling trend | Decide how urgent it is |
| 2. CPU breakdown | `top` (press `1` for per-CPU) | `us` user code, `sy` kernel, `wa` I/O wait, `st` stolen by hypervisor | High `wa` → go to slow system runbook; high `st` → noisy VM neighbor |
| 3. Who is using it? | `ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head` | The top consumers, how long they have run | Identify the process and its owner |
| 4. Over time | `pidstat 1 5` | Per-process `%usr` and `%system` sampled each second | Confirms a steady hog vs a spike |
| 5. Which service? | `systemctl status PID` or `ps -o unit= -p PID` | The systemd unit the process belongs to | Investigate that service's logs |
| 6. Threads | `top -H -p PID` | Which thread inside the process is busy | Report to developers |

#### Reading top

```bash
top
```

```text
top - 14:02:11 up 3 days,  2:41,  1 user,  load average: 2.31, 1.94, 1.10
Tasks: 142 total,   3 running, 139 sleeping,   0 stopped,   0 zombie
%Cpu(s): 96.7 us,  2.8 sy,  0.0 ni,  0.3 id,  0.0 wa,  0.0 hi,  0.2 si,  0.0 st
MiB Mem :   3915.2 total,    812.4 free,   1704.9 used,   1662.3 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   2210.3 avail Mem

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
   3318 alex      20   0  412060 298212  12440 R 199.0   7.4  14:22.81 python3
    611 root      20   0  245104  10204   7832 S   1.3   0.3   0:42.10 systemd-journal
      1 root      20   0   22468  13532   9312 S   0.0   0.3   0:04.71 systemd
```

The header first:

- **Load average** `2.31` on a 2-CPU machine: the CPUs are fully busy and a little work is queuing.
- **`%Cpu(s)`**: `96.7 us` is user-space code (your programs). `sy` is the kernel. `ni` is niced processes. `id` is idle. **`wa`** is idle-while-waiting-for-I/O. `hi`/`si` are hardware and software interrupts. **`st`** (steal) is time the hypervisor gave to other VMs; high `st` on a cloud VM means you are not getting the CPU you pay for.
- **Tasks**: `3 running`. Watch for a growing number of **zombies** (finished processes whose parent never collected them; harmless in small numbers).

Then the process list, sorted by `%CPU`:

- **`%CPU 199.0`**: the percentage of **one** CPU. 199% means `python3` is using two full cores (multi-threaded or multi-process). Press `1` to see each core separately.
- **`S`**: state. `R` running, `S` sleeping, `D` uninterruptible (usually disk I/O), `Z` zombie.
- **`TIME+`**: total CPU time used. 14 minutes of CPU tells you it has been busy for a while.
- **`RES`**: resident memory, in KiB by default.

Useful keys: `P` sort by CPU, `M` sort by memory, `c` show full command lines, `k` kill (asks for PID and signal), `q` quit. `htop` offers the same with colors, mouse support, and a tree view (`F5`).

#### A non-interactive snapshot

For a ticket, a chat message, or a script, use `ps`:

```bash
ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -n 5
```

```text
    PID    PPID USER     %CPU %MEM     ELAPSED CMD
   3318    3290 alex      196  7.4       07:21 python3 transform.py --input big.csv
    611       1 root      1.2  0.3  3-02:41:10 /usr/lib/systemd/systemd-journald
   1022       1 www-data  0.4  1.1  3-02:40:55 nginx: worker process
```

`ps`'s `%CPU` is the **average over the process's whole lifetime**, unlike `top`'s current value. `etime` (elapsed time) shows `transform.py` started seven minutes ago, which might match when the slowdown began. `ppid` (parent PID) lets you find what launched it: `ps -o cmd= -p 3290`.

`pidstat` (from `sysstat`) samples per process, every second, which avoids `ps`'s lifetime average:

```bash
pidstat 1 3
```

```text
Linux 6.8.0-45-generic (mint)  10/02/2026  _x86_64_  (2 CPU)

02:03:01 PM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
02:03:02 PM  1000      3318  197.00    2.00    0.00    0.00  199.00     1  python3
02:03:02 PM     0       611    1.00    0.00    0.00    0.00    1.00     0  systemd-journal
...
Average:     1000      3318  196.67    2.33    0.00    0.00  199.00     -  python3
```

A high `%wait` here means the process is runnable but waiting for a CPU, which is saturation from that process's point of view.

#### Fixes for high CPU

- **It is legitimate work** (a batch job, a backup): lower its priority so interactive work stays snappy: `renice +10 -p 3318`, or for a service, `Nice=10` and `CPUQuota=50%` in its unit file (as in the scheduling chapter's backup service).
- **It is a runaway** (an infinite loop, a stuck worker): stop it gracefully first, `kill 3318` (SIGTERM), and only if that fails, `kill -9 3318` (SIGKILL). For a service, `sudo systemctl restart UNIT`, then read its logs to find out why.
- **It is unexpected** (an unknown process using 100% CPU, owned by a service account): treat it as a possible compromise, for example a cryptominer. Check `ls -l /proc/PID/exe`, its command line, and its network connections (`sudo ss -tnp | grep PID`) before killing it.

### Runbook 3: Low memory and the OOM killer

**Symptoms:** heavy disk activity and extreme slowness (swapping); processes disappear without an error; `Killed` printed in a terminal; services restart unexpectedly; `MemoryError` or `Cannot allocate memory`.

| Step | Command | Reading the output | Fix |
|------|---------|--------------------|-----|
| 1. How much is available? | `free -h` | The **`available`** column, not `free` | If `available` is near zero, memory is genuinely short |
| 2. Is it swapping? | `vmstat 1 5` | Non-zero `si`/`so` columns, sustained | Swapping hurts; reduce memory use |
| 3. Who uses it? | `ps -eo pid,user,rss,%mem,cmd --sort=-rss | head` | Largest **RSS** (resident memory) first | Identify the hog |
| 4. Did the OOM killer act? | `journalctl -k | grep -iE 'out of memory|oom'` or `sudo dmesg -T | grep -i oom` | `Out of memory: Killed process PID (name)` lines | Find which process was killed and why |
| 5. Service-level kill? | `systemctl status UNIT` | `Failed with result 'oom-kill'` | Fix the leak or raise `MemoryMax=` |

#### Reading free correctly

```bash
free -h
```

```text
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       3.5Gi       112Mi        44Mi       240Mi       141Mi
Swap:          2.0Gi       1.9Gi       102Mi
```

As you learned in [Memory](../03-internals/03-memory.md), Linux uses spare RAM as a page cache, so `free` is almost always small, and that is fine. The column that matters is **`available`**: memory that can be given to programs without swapping, including cache that can be dropped. Here it is 141 MiB of 3.8 GiB, and swap is nearly full: this machine is genuinely out of memory.

Compare with a healthy machine, where `free` is small but `buff/cache` and `available` are large. That is Linux doing its job, not a problem.

#### Finding the memory hog

```bash
ps -eo pid,user,rss,%mem,etime,cmd --sort=-rss | head -n 5
```

```text
    PID USER       RSS %MEM     ELAPSED CMD
   4410 alex   2984312 74.6       12:03 python3 load_all.py --file events.csv
   1155 postgres 187220  4.6  3-02:39:57 postgres: 16/main: checkpointer
   2741 webapp   61440  1.5     1:22:10 /usr/bin/python3 /srv/webapp/app.py
```

**RSS** (resident set size) is the physical memory a process uses right now, in KiB. `load_all.py` holds about 2.9 GB, 75% of RAM. Its name suggests the cause: reading a whole CSV into memory instead of streaming it. That is a code fix, not an admin fix.

`vmstat` confirms whether the system is swapping:

```bash
vmstat 1 5
```

```text
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 1  3 1992040 114300   1204 244116 8120 9340 10240  9520 3120 4511 12 18  8 62  0  0
 2  4 1998120 109872   1196 239876 9912 7804 11220  8040 3305 4720 10 20  6 64  0  0
```

`si` (swap in) and `so` (swap out) in KiB per second are both in the thousands, and `wa` (I/O wait) is above 60%: the CPU is mostly waiting for the disk to shuffle memory pages. This is **thrashing**, and it is why an out-of-memory machine feels frozen long before anything is killed. (The `gu` column, guest time, appears in newer versions of `vmstat` such as Mint 22's.)

#### Reading an OOM kill

When memory and swap are both exhausted, the kernel's **OOM killer** (out-of-memory killer) picks a process, mostly the one using the most memory, adjusted by its `oom_score_adj`, and kills it with SIGKILL to save the system. It logs what it did:

```bash
journalctl -k --since today | grep -iE 'oom|killed process'
```

```text
Oct 02 14:21:07 mint kernel: python3 invoked oom-killer: gfp_mask=0x140cca(GFP_HIGHUSER_MOVABLE|__GFP_COMP), order=0, oom_score_adj=0
Oct 02 14:21:07 mint kernel: Out of memory: Killed process 4410 (python3) total-vm:3512020kB, anon-rss:2981440kB, file-rss:2560kB, shmem-rss:0kB, UID:1000 pgtables:6044kB oom_score_adj:0
Oct 02 14:21:07 mint kernel: oom_reaper: reaped process 4410 (python3), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
```

- **`python3 invoked oom-killer`**: the process whose allocation request **triggered** the OOM killer. It is not necessarily the one that gets killed.
- **`Out of memory: Killed process 4410 (python3)`**: the **victim**.
- **`anon-rss:2981440kB`**: the victim's private memory, about 2.9 GB: clearly the hog.
- **`UID:1000`**: whose process it was.

`sudo dmesg -T` shows the same kernel messages with readable timestamps; on Mint you may not need `sudo`, but on Ubuntu `dmesg` is restricted to root. If the victim was a systemd service, `systemctl status` shows `Failed with result 'oom-kill'`.

On Ubuntu Desktop (not Mint by default), **systemd-oomd** may kill processes earlier, based on memory pressure. Its messages appear in `journalctl -u systemd-oomd`.

#### Fixes for low memory

- **Kill or fix the hog.** Stop the runaway process. If it is your code, stream data instead of loading it all (`pandas.read_csv(..., chunksize=...)`, reading files line by line).
- **Contain services** with systemd so one service cannot starve the machine: `MemoryMax=1G` in the `[Service]` section kills only that service when it exceeds the limit, and `MemoryHigh=800M` throttles it first.
- **Add swap** as a buffer against short spikes (on a VM, a 1–2 GB swap file is cheap insurance). It does not fix a real shortage.
- **Add RAM** when the legitimate workload has simply outgrown the machine.

### Runbook 4: A service that will not start

**Symptoms:** `systemctl start` prints `Job for X.service failed`; `systemctl status` shows `failed` or `activating (auto-restart)` over and over; the port is not listening.

| Step | Command | Reading the output | Fix |
|------|---------|--------------------|-----|
| 1. Status | `systemctl status UNIT` | `Active:` line, exit code, last log lines | Often the answer is right there |
| 2. Full logs | `journalctl -xeu UNIT` | The first error after `Starting ...`; scroll **up** past systemd's summary | Address that error |
| 3. Unit file | `systemctl cat UNIT`; `systemd-analyze verify UNIT` | Typos, wrong paths, wrong `User=` | Fix with `systemctl edit`, then `daemon-reload` |
| 4. Config syntax | The app's own checker (`nginx -t`, `sshd -t`, `apachectl configtest`, `python3 -m py_compile app.py`) | The file and line of the error | Fix the config |
| 5. Port in use | `sudo ss -tlnp 'sport = :8080'` | Another process already listening | Stop the other process or change the port |
| 6. Permissions | `sudo -u webapp ls /srv/webapp`; `namei -l /path/to/file` | `Permission denied` at some path component | `chown`/`chmod` the right path component |
| 7. Run it by hand | `sudo -u webapp /usr/bin/python3 /srv/webapp/app.py` | The error, printed in front of you | Fix, then go back to systemd |
| 8. Start limit | `systemctl status` shows `start-limit-hit` | Too many restarts | Fix the cause, then `sudo systemctl reset-failed UNIT` |

#### Status and exit codes

```bash
systemctl status webapp --no-pager
```

```text
× webapp.service - Tiny demo web app
     Loaded: loaded (/etc/systemd/system/webapp.service; enabled; preset: enabled)
     Active: failed (Result: exit-code) since Fri 2026-10-02 14:40:02 UTC; 8s ago
   Duration: 312ms
    Process: 5120 ExecStart=/usr/bin/python3 /srv/webapp/app.py (code=exited, status=1/FAILURE)
   Main PID: 5120 (code=exited, status=1/FAILURE)
        CPU: 284ms

Oct 02 14:40:02 mint python3[5120]:   File "/usr/lib/python3.12/socketserver.py", line 473, in server_bind
Oct 02 14:40:02 mint python3[5120]:     self.socket.bind(self.server_address)
Oct 02 14:40:02 mint python3[5120]: OSError: [Errno 98] Address already in use
Oct 02 14:40:02 mint systemd[1]: webapp.service: Main process exited, code=exited, status=1/FAILURE
Oct 02 14:40:02 mint systemd[1]: webapp.service: Failed with result 'exit-code'.
```

The `status=` value narrows the cause before you read any logs:

| Status | Meaning |
|--------|---------|
| `1/FAILURE` (or another small number) | The program itself exited with an error. Read its output. |
| `203/EXEC` | systemd could not execute `ExecStart=`: wrong path, missing file, not executable, or a bad shebang |
| `217/USER` | The `User=` does not exist |
| `200/CHDIR` | `WorkingDirectory=` does not exist or is not accessible |
| `226/NAMESPACE` | A sandboxing option (`ReadWritePaths=`, `ProtectSystem=`) refers to a missing path |
| `code=killed, signal=KILL` | Killed, often by the OOM killer or a timeout |
| `Result: timeout` | Did not finish starting within `TimeoutStartSec=` (often a `Type=notify` or `forking` mismatch) |

Here, the log says `Address already in use`: something already holds port 8080.

#### Port already in use

```bash
sudo ss -tlnp 'sport = :8080'
```

```text
State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process
LISTEN 0      5            0.0.0.0:8080      0.0.0.0:*     users:(("python3",pid=4980,fd=3))
```

```bash
ps -o pid,user,etime,cmd -p 4980
```

```text
    PID USER     ELAPSED CMD
   4980 alex       01:12 python3 -m http.server 8080
```

A test server someone left running in a terminal took the port. Stop it, then `sudo systemctl restart webapp`.

#### Permission problems

When a service runs as a dedicated user, it can only reach files that user can reach. `namei -l` shows the permissions of **every directory along a path**, which is where these problems usually hide:

```bash
namei -l /srv/webapp/data/notes.jsonl
```

```text
f: /srv/webapp/data/notes.jsonl
drwxr-xr-x root   root   /
drwxr-xr-x root   root   srv
drwxr-x--- alex   alex   webapp
drwxr-xr-x webapp webapp data
-rw-r--r-- webapp webapp notes.jsonl
```

`/srv/webapp` is `drwxr-x---` owned by `alex`: the `webapp` user has no permission to enter it, so it cannot reach `data/` even though it owns `data/` and the file. Fix: `sudo chown -R webapp:webapp /srv/webapp` (or `chmod o+x /srv/webapp` if it should stay alex's). Test exactly as the service would, with `sudo -u webapp`:

```bash
sudo -u webapp cat /srv/webapp/data/notes.jsonl > /dev/null && echo "webapp can read it"
```

On Ubuntu and Mint, **AppArmor** can also deny access for programs that have a profile, even when file permissions allow it. Look for `apparmor="DENIED"` in `journalctl -k`.

#### Run it by hand, as the service user

When the logs are unclear, run the exact `ExecStart=` command as the service's user, in its working directory:

```bash
cd /srv/webapp && sudo -u webapp env PORT=8080 /usr/bin/python3 /srv/webapp/app.py
```

The error appears directly in your terminal. When it works by hand but not under systemd, compare the environment: variables from `Environment=`/`EnvironmentFile=`, sandboxing options, and the working directory.

### Runbook 5: Network unreachable

**Symptoms:** `Could not resolve host`; `Connection refused`; `Connection timed out`; `No route to host`; "the site does not load".

Work from the bottom layer up, as in [Networking basics](03-networking-basics.md). Stop at the first layer that fails: that is where the problem is.

| Layer | Command | Healthy output | If it fails |
|-------|---------|----------------|-------------|
| 1. Link | `ip -br link` | Interface `UP`, with `LOWER_UP` in `ip link` | Cable, Wi-Fi, VM network adapter; `nmcli device status` |
| 2. Address | `ip -br addr` | An address in the expected subnet | No address or `169.254.x.x`: DHCP failed; `journalctl -u NetworkManager` |
| 3. Route | `ip route get 1.1.1.1` | `via <gateway> dev <iface>` | No default route: DHCP or static config problem |
| 4. Gateway | `ping -c 3 <gateway>` | Replies | LAN problem; check `ip neigh` for `FAILED` |
| 5. Internet by IP | `ping -c 3 1.1.1.1` | Replies | Upstream/ISP/cloud network problem, or ICMP blocked; try `curl -sI http://1.1.1.1` |
| 6. DNS | `dig example.com +short`; `resolvectl status` | Addresses returned | Wrong or dead DNS server; compare with `dig @1.1.1.1` |
| 7. Path | `tracepath -n host` or `mtr -n host` | Reaches the destination | Note the last responding hop |
| 8. Port | `nc -zv -w 3 host 443` | `succeeded!` | `refused`: nothing listening; timed out: firewall |
| 9. Application | `curl -v https://host/` | `HTTP/... 200` | TLS errors, HTTP errors: see the application's logs |

When **you are the server** and clients cannot reach you, reverse the view:

| Check | Command | Look for |
|-------|---------|----------|
| Is it listening? | `sudo ss -tlnp` | The port, and **which address**: `127.0.0.1` means local only |
| Is it reachable locally? | `curl -v http://localhost:PORT/` | Works locally but not remotely → bind address or firewall |
| Does the firewall allow it? | `sudo ufw status verbose` | An `ALLOW` rule for the port, above any matching `DENY` |
| Do packets arrive? | `sudo ufw logging medium`, then `sudo tail -f /var/log/ufw.log` | `[UFW BLOCK]` lines with `DPT=PORT` |
| Is there a cloud firewall? | Provider console | Security groups often block before your server sees anything |

### Runbook 6: The system is slow

**Symptoms:** everything takes longer than usual, but nothing is obviously broken; commands hang for seconds; high load average with no obvious CPU hog.

| Step | Command | Reading the output | Points to |
|------|---------|--------------------|-----------|
| 1. Overview | `uptime`; `top` | Load vs CPUs; `us`, `sy`, `wa`, `st`; processes in state `D` | Which resource to look at |
| 2. Every second | `vmstat 1 10` | `r` (runnable) > CPUs: CPU saturation. `b` (blocked) > 0 and high `wa`: I/O. `si`/`so` > 0: swapping. | CPU, disk, or memory |
| 3. Disks | `iostat -xz 1 5` | `%util` near 100, high `r_await`/`w_await`, large `aqu-sz` | A saturated disk |
| 4. Who does I/O | `sudo iotop -o` or `pidstat -d 1 5` | Processes with high read/write rates | The process causing the I/O |
| 5. Pressure | `cat /proc/pressure/{cpu,memory,io}` | Non-zero `avg10` values | Which resource tasks are stalling on |
| 6. Kernel errors | `journalctl -k -p warning --since "1 hour ago"` | I/O errors, `task blocked for more than 120 seconds`, throttling | Failing hardware, hung storage |

#### Reading vmstat

```bash
vmstat 1 5
```

```text
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 0  4      0 152340  20480 3301220    0    0   512 98304 2210 3105  3  4 21 72  0  0
 1  5      0 150112  20480 3302348    0    0   480 101376 2304 3290  2  5 18 75  0  0
 0  4      0 148876  20488 3303012    0    0   528 99840 2188 3011  3  4 20 73  0  0
```

The first line is an average since boot, so read from the second line on. Column groups:

- **`procs`**: `r` tasks runnable (running or waiting for CPU); **`b`** tasks blocked in uninterruptible sleep, usually on I/O.
- **`memory`** (KiB): `swpd` swap used, `free`, `buff`, `cache`.
- **`swap`**: `si`/`so` KiB/s swapped in and out. Should be 0.
- **`io`**: `bi`/`bo` blocks (KiB) read from and written to disk per second.
- **`system`**: `in` interrupts and `cs` context switches per second.
- **`cpu`**: percentages, as in `top`.

Here: `b` is 4–5, `wa` is over 70%, CPU is otherwise idle, swap is unused, and `bo` shows about 100 MB/s of writes. Diagnosis: **something is writing to disk heavily, and everything else is waiting for the disk**. Memory and CPU are fine.

#### Reading iostat

```bash
sudo apt install sysstat
iostat -xz 1 3
```

```text
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           2.51    0.00    4.27   72.86    0.00   20.35

Device            r/s     rMB/s   r_await     w/s     wMB/s   w_await  aqu-sz  %util
vda             12.00      0.47      8.25  805.00     98.20     38.61   31.20  100.00
```

(Columns trimmed; the real output is wider.)

- **`r/s`, `w/s`**: read and write operations per second. **`rMB/s`, `wMB/s`**: throughput.
- **`r_await`, `w_await`**: average milliseconds per request, **including time spent queued**. An SSD should show low single digits; 38 ms of write latency means requests are waiting in line.
- **`aqu-sz`**: average queue length. 31 requests waiting: heavy **saturation**.
- **`%util`**: the share of time the device was busy. 100% on a single disk means it is the bottleneck. (On SSDs and RAID arrays, which serve requests in parallel, 100% is less conclusive, but high `await` with a deep queue still is.)
- **`-x`** extended stats, **`-z`** hide idle devices, **`1 3`** every second, three times. The first report is since boot; read the later ones.

Find the writer with `sudo iotop -o` (only processes doing I/O) or `pidstat -d 1 5`. In this scenario it might be a backup job without `IOSchedulingClass=idle`, a database vacuum, or a runaway debug log.

#### Fixes for a slow system

| Cause | Fix |
|-------|-----|
| Disk saturated by one process | Lower its I/O priority (`ionice -c3 -p PID`; `IOSchedulingClass=idle` for services); schedule it off-hours; fix excessive logging |
| Swapping | Runbook 3: find the memory hog, add RAM, limit services with `MemoryMax=` |
| CPU saturated | Runbook 2: `renice`, `CPUQuota=`, or more CPUs |
| High `st` on a VM | The host is overcommitted; move or resize the VM |
| Kernel I/O errors in the log | Failing disk: check SMART (Disks and backups chapter) and back up **now** |

### A one-minute health snapshot

When you log in to a machine you do not know, these commands give you the big picture in about a minute. Running them in order is a good habit before any deeper investigation:

```bash
uptime                                # load and how long since boot
journalctl -p err -b --no-pager | tail -n 20   # recent errors this boot
systemctl --failed                    # failed units
df -h; df -i                          # disk space and inodes
free -h                               # memory
vmstat 1 5                            # CPU, memory, swap, I/O over 5 seconds
ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head -n 8   # top processes
sudo ss -tulpn                        # what is listening
ip -br addr; ip route                 # network basics
```

## Exercises

### Exercise 1: Baseline your machine (easy)

On your main machine, run the one-minute health snapshot and write down the "normal" values: load average vs `nproc`, `available` memory, the most used filesystem, the top three CPU and memory processes, and whether any units have failed. Keep this baseline in your notes.

??? success "Solution"

    ```bash
    uptime; nproc
    free -h
    df -h | sort -k5 -h | tail -n 3
    ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head -n 4
    ps -eo pid,user,rss,cmd --sort=-rss | head -n 4
    systemctl --failed
    ```

    There is no single right answer; the point is to know your normal. Typical desktop values: load well under `nproc`, several GB `available`, no failed units. A browser or editor usually tops the memory list.

### Exercise 2: The deleted-but-open file (easy)

On your main machine, in a scratch directory, reproduce the "df and du disagree" problem safely. Start a background process that keeps a file open and writes to it, delete the file, find it with `lsof +L1`, then free the space.

??? success "Solution"

    ```bash
    mkdir -p ~/scratch/open && cd ~/scratch/open
    ( exec 3>big.log; while true; do head -c 1M /dev/zero >&3; sleep 1; done ) &
    sleep 5
    ls -lh big.log
    rm big.log
    lsof +L1 2>/dev/null | grep big.log
    ```

    ```text
    -rw-rw-r-- 1 alex alex 4.0M Oct  2 15:01 big.log
    bash    6233 alex    3w   REG  259,2  5242880     0 4325671 /home/alex/scratch/open/big.log (deleted)
    sleep   6301 alex    3w   REG  259,2  5242880     0 4325671 /home/alex/scratch/open/big.log (deleted)
    ```

    The subshell holds the file on file descriptor 3 (`exec 3>big.log`) and keeps writing, so the deleted file keeps growing. The `sleep` line appears because child processes inherit open file descriptors: every process that holds the descriptor keeps the data alive. Free it by stopping the process:

    ```bash
    kill %1
    lsof +L1 2>/dev/null | grep -c big.log
    ```

    The count is `0`: the space is released once the last descriptor closes.

### Exercise 3: Make your own OOM kill (medium)

!!! danger "⚠️ VM only"
    This deliberately exhausts memory. Do it in your VM, where a freeze costs nothing.

In your VM, start a transient service with a 200 MB memory limit that tries to allocate 1 GB in Python, using `systemd-run`. Find the evidence of the kill in `systemctl status`, the unit's journal, and the kernel log.

??? success "Solution"

    ```bash
    sudo systemd-run --unit=memhog -p MemoryMax=200M -p MemorySwapMax=0 \
        /usr/bin/python3 -c 'x = bytearray(1024*1024*1024); input()'
    sleep 2
    systemctl status memhog --no-pager
    journalctl -k --since "2 min ago" | grep -iE 'oom|killed process'
    ```

    `systemctl status` shows `Failed with result 'oom-kill'`, and the kernel log shows `Memory cgroup out of memory: Killed process ... (python3)`. The words **"Memory cgroup"** tell you the limit was the service's own `MemoryMax=`, not the whole machine running out. This is the safe way to contain a leaky service: only it dies. Clean up with `sudo systemctl reset-failed memhog`.

### Exercise 4: Debug a broken service (medium)

!!! danger "⚠️ VM only"
    Do this in your VM, using the `webapp` service from the systemd chapter.

Introduce these faults one at a time, and for each one, diagnose it using only `systemctl status`, `journalctl -xeu`, `ss`, and `namei` before looking at what you changed: (a) `User=webapp2` (nonexistent), (b) `WorkingDirectory=/srv/webap` (typo), (c) a Python `http.server` already running on port 8080 as your user, (d) `chmod 700 /srv/webapp` with owner root.

??? success "Solution"

    After each change: `sudo systemctl daemon-reload; sudo systemctl restart webapp; systemctl status webapp --no-pager`.

    | Fault | Evidence | Fix |
    |-------|----------|-----|
    | (a) bad user | `status=217/USER`; journal: `Failed to determine user credentials: No such process` | Correct `User=` |
    | (b) bad dir | `status=200/CHDIR`; journal: `Changing to the requested working directory failed: No such file or directory` | Correct the path |
    | (c) port taken | `status=1/FAILURE`; journal: `OSError: [Errno 98] Address already in use`; `sudo ss -tlnp 'sport = :8080'` shows your `python3` | Stop the other process |
    | (d) permissions | `status=200/CHDIR` with `Permission denied`; `namei -l /srv/webapp/index.html` shows `drwx------ root root webapp` | `sudo chown -R webapp:webapp /srv/webapp` and `chmod 755` |

    The exit status alone (`217`, `200`, `1`) narrows each fault down before you read a single log line.

### Exercise 5: Find the bottleneck (hard)

!!! danger "⚠️ VM only"
    This exercise generates heavy load. Use your VM.

In your VM, open two terminals. In one, run a hidden load generator chosen at random by the script below. In the other, without looking at the first terminal, use the USE method and the tools from this chapter to decide whether the problem is CPU, memory, or disk, and name the process responsible. Repeat until you have diagnosed all three.

```bash
case $((RANDOM % 3)) in
  0) python3 -c 'while True: pass' ;;
  1) python3 -c 'import time; x=[bytearray(50*1024*1024) for _ in range(40)]; time.sleep(600)' ;;
  2) while true; do dd if=/dev/zero of=/tmp/io.test bs=1M count=1024 oflag=direct status=none; done ;;
esac
```

??? success "Solution"

    Start with `uptime`, `vmstat 1 5`, then confirm with the matching tool:

    | Load type | `vmstat` signature | Confirming command | Culprit shown as |
    |-----------|--------------------|--------------------|------------------|
    | CPU | `r` ≥ 1, `us` near 100% (on a 1-CPU VM) or `us` = 100/nproc per busy core, `wa` ≈ 0 | `top` (press `1`), `pidstat 1 3` | `python3` at ~100% CPU |
    | Memory | `free` drops, `si`/`so` > 0 if the VM has swap, possibly an OOM kill | `free -h`, `ps --sort=-rss` | `python3` with ~2 GB RSS (or killed: check `journalctl -k`) |
    | Disk | `b` > 0, `wa` high, `bo` large, CPU otherwise idle | `iostat -xz 1 3` (`%util` near 100), `sudo iotop -o` | `dd` writing at full speed |

    The memory case depends on your VM's RAM: with less than 2 GB, the OOM killer ends it quickly, and the evidence is in the kernel log rather than in `top`. Stop the generator with ++ctrl+c++ and remove `/tmp/io.test`.

## Check yourself

1. Describe the troubleshooting loop, and why "restart it" is a poor first step.

    ??? note "Answer"

        Observe (define the symptom precisely, note when it started and what changed), hypothesize (causes that fit the evidence), test (one cheap, mostly read-only check at a time), then fix and verify, and write it down. Restarting first often hides the problem temporarily and destroys evidence such as the process state, open files, and in-memory errors.

2. What do the letters in the USE method stand for, and why does saturation matter most for "slow"?

    ??? note "Answer"

        Utilization, Saturation, Errors, checked for each resource. Saturation means work is queuing because a resource is fully busy; queued work is what users experience as delay, even when average utilization looks acceptable.

3. A 4-CPU server shows a load average of 12, but `top` shows the CPU 90% idle. What is the likely problem and which tools confirm it?

    ??? note "Answer"

        Tasks in uninterruptible sleep (state `D`), usually waiting for disk or network storage, count towards load on Linux. Confirm with `vmstat 1` (high `b` and `wa`) and `iostat -xz 1` (high `%util`, `await`, and `aqu-sz`), then find the process with `iotop` or `pidstat -d`.

4. `df -h` shows `/` at 100%, but `du -sh /` adds up to much less. What is happening and how do you fix it?

    ??? note "Answer"

        Deleted files are still held open by a running process, so their space is not freed. `sudo lsof +L1` lists them. Restart or reload the process holding them (or truncate via `/proc/PID/fd/N`).

5. `df -h` shows 40% used, but you cannot create files and get "No space left on device". What do you check?

    ??? note "Answer"

        Inode usage with `df -i`. If `IUse%` is 100%, too many small files used up every inode. Find the directories with the most files and clean them up.

6. Which column of `free -h` tells you whether memory is actually short, and why not `free`?

    ??? note "Answer"

        `available`. Linux uses idle RAM for the page cache, so `free` is normally small on a healthy system. `available` estimates how much memory programs can get without swapping, counting reclaimable cache.

7. A service shows `status=203/EXEC`. What does that mean?

    ??? note "Answer"

        systemd could not execute the program in `ExecStart=`: the path is wrong, the file is missing or not executable, or its interpreter (shebang) does not exist. The program itself never ran.

8. A web app works with `curl localhost:8080` on the server but not from your laptop. List the checks in order.

    ??? note "Answer"

        `sudo ss -tlnp` to see the bind address (`127.0.0.1` means local only); `sudo ufw status` for an allow rule; `[UFW BLOCK]` lines in `/var/log/ufw.log` with `DPT=8080`; any cloud provider firewall; then from the laptop, `nc -zv server 8080` to distinguish refused (nothing listening on that address) from timed out (firewall).

## Key takeaways

- Troubleshoot with a loop: observe, hypothesize, test one thing, fix, verify, and write it down. Collect evidence before restarting anything.
- Use the USE method (utilization, saturation, errors) for each resource when the problem is vague. Load average counts tasks waiting for CPU **and** for I/O; compare it with `nproc`.
- Disk full: `df -h`, `df -i`, `du -xh --max-depth=1 | sort -h`, `ncdu`, and `lsof +L1` for deleted-but-open files. Truncate active logs instead of deleting them.
- High CPU: `top`, `ps --sort=-%cpu`, `pidstat`. Low memory: `free -h` (`available`), `vmstat` (`si`/`so`), `ps --sort=-rss`, and OOM messages in `journalctl -k`.
- A failing service tells you why: `systemctl status` (exit status), `journalctl -xeu`, the app's config checker, `ss` for port conflicts, `namei -l` and `sudo -u` for permissions.
- Network problems: go layer by layer and stop at the first failure. Slow systems: `vmstat` and `iostat -xz` show whether CPU, memory, or disk is saturated.

## Next

Next, learn to manage the people who use your systems: [User management and PAM](08-user-management.md).
