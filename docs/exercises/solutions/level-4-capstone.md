# Level 4 capstone solution: Build a server from scratch

> **Level 4 · Capstone solution** · Back to the [challenge](../level-4-capstone.md)

This is one complete, working way to build the capstone server. Your IP address, PIDs, UIDs, fingerprints, and timestamps will differ. What should match are the security decisions and the results of the verification commands.

The setup used here:

| Role | Name | Address |
|------|------|---------|
| Host (your Mint machine) | `mint`, user `alex` | `192.168.122.1` on the VM network |
| VM (Ubuntu Server 24.04) | `lab`, user `alex` | `192.168.122.57` |

Commands are labeled **(host)** or **(VM)**. Run VM commands over SSH once Part 1 is done.

!!! danger "⚠️ VM only"
    Everything marked (VM) changes system configuration. Run it only in your VM, and take a snapshot first.

## Part 0: Baseline the fresh VM

**(VM)**, at the console or over SSH with the password for now:

```bash
sudo apt update && sudo apt full-upgrade -y
hostnamectl --static
ip -br addr
systemctl is-active ssh.socket ssh
sudo ufw status
ls /etc/ssh/sshd_config.d/
```

```text
lab
lo               UNKNOWN        127.0.0.1/8 ::1/128
enp1s0           UP             192.168.122.57/24 fe80::5054:ff:fe3a:1b2c/64
active
active
Status: inactive
50-cloud-init.conf
```

Two things to notice before starting. The firewall is installed but **inactive**. And there is already a drop-in, `50-cloud-init.conf`, that the installer created:

```bash
cat /etc/ssh/sshd_config.d/50-cloud-init.conf
```

```text
PasswordAuthentication yes
```

Because sshd uses the **first** value it reads for each keyword, and drop-ins are read in alphabetical order, any hardening file that sorts after `50-` would be silently overridden. That is why the hardening file below is named `10-hardening.conf`.

Take a VM snapshot now, named for example `fresh-install`.

## Part 1: Secure SSH

### 1.1 Key and host key verification

**(host)** Create a key if you do not have one:

```bash
ls ~/.ssh/id_ed25519 2>/dev/null || ssh-keygen -t ed25519 -C "alex@mint"
```

**(VM)** Read the host key fingerprint at the VM's console (a channel the network cannot tamper with):

```bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

```text
256 SHA256:3vQm7Ck1Xp4cKdYb0W9mJzq2fT8hR5nL6sE1aV0uGiQ root@lab (ED25519)
```

**(host)** Install the key. On first contact, compare the fingerprint in the prompt with the one above before typing `yes`:

```bash
ssh-copy-id alex@192.168.122.57
```

```text
The authenticity of host '192.168.122.57 (192.168.122.57)' can't be established.
ED25519 key fingerprint is SHA256:3vQm7Ck1Xp4cKdYb0W9mJzq2fT8hR5nL6sE1aV0uGiQ.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
alex@192.168.122.57's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'alex@192.168.122.57'"
and check to make sure that only the key(s) you wanted were added.
```

### 1.2 Client config

**(host)** Add this block to `~/.ssh/config`, **above** any `Host *` block:

```text
Host lab
    HostName 192.168.122.57
    User alex
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

```bash
chmod 600 ~/.ssh/config
ssh lab hostname
```

```text
lab
```

No account password was requested (at most the key's passphrase, once, through the agent). Key login works, so it is now safe to disable passwords.

### 1.3 Harden sshd

Open **two** SSH sessions to `lab`. Use one for the changes and keep the other untouched as a lifeline.

**(VM)** `/etc/ssh/sshd_config.d/10-hardening.conf`:

```bash
sudo tee /etc/ssh/sshd_config.d/10-hardening.conf > /dev/null <<'EOF'
# Level 4 capstone: SSH hardening.
# Named 10-... so it is read before 50-cloud-init.conf; sshd keeps the
# first value it sees for each keyword.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers alex
MaxAuthTries 3
X11Forwarding no
EOF
sudo chmod 644 /etc/ssh/sshd_config.d/10-hardening.conf
```

Validate, then check the effective values:

```bash
sudo sshd -t && echo "syntax OK"
sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin|allowusers|maxauthtries|x11forwarding) '
```

```text
syntax OK
maxauthtries 3
permitrootlogin no
passwordauthentication no
kbdinteractiveauthentication no
x11forwarding no
allowusers alex
```

Every value is the hardened one, which proves `10-hardening.conf` wins over `50-cloud-init.conf`. Apply:

```bash
sudo systemctl reload ssh
systemctl status ssh --no-pager | head -n 4
```

```text
● ssh.service - OpenBSD Secure Shell server
     Loaded: loaded (/usr/lib/systemd/system/ssh.service; disabled; preset: enabled)
     Active: active (running) since Fri 2026-10-02 09:12:40 UTC; 21min ago
TriggeredBy: ● ssh.socket
```

(`disabled` for `ssh.service` is normal on a fresh Ubuntu 24.04 install: `ssh.socket` is the enabled unit and starts the service on demand. If yours says `enabled`, that works too.)

### 1.4 Prove it

**(host)**, in a **new** terminal:

```bash
ssh lab 'echo key login works'
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password lab
ssh -o PubkeyAuthentication=no root@192.168.122.57
```

```text
key login works
alex@192.168.122.57: Permission denied (publickey).
root@192.168.122.57: Permission denied (publickey).
```

The server only offers `publickey` now. **(VM)** The journal shows the refusals:

```bash
journalctl -u ssh --since "5 min ago" --no-pager | tail -n 3
```

```text
Oct 02 09:35:02 lab sshd[2214]: Accepted publickey for alex from 192.168.122.1 port 40712 ssh2: ED25519 SHA256:MgS+3a64Uk1wgQbZkz8RzDY3AnqJo78kBMM0Sp/YALY
Oct 02 09:35:09 lab sshd[2240]: Connection closed by authenticating user alex 192.168.122.1 port 40720 [preauth]
Oct 02 09:35:15 lab sshd[2251]: User root from 192.168.122.1 not allowed because not listed in AllowUsers
```

Now it is safe to close the lifeline session. Take a snapshot: `ssh-hardened`.

## Part 2: Firewall

**(VM)** Set policies and rules **before** enabling:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp comment 'SSH, rate limited'
sudo ufw allow from 192.168.122.0/24 to any port 8080 proto tcp comment 'webapp'
sudo ufw show added
```

```text
Default incoming policy changed to 'deny'
(be sure to update your rules accordingly)
Default outgoing policy changed to 'allow'
(be sure to update your rules accordingly)
Rules updated
Rules updated (v6)
Rules updated
Added user rules (see 'ufw status' for running firewall):
ufw limit 22/tcp comment 'SSH, rate limited'
ufw allow from 192.168.122.0/24 to any port 8080 proto tcp comment 'webapp'
```

The 8080 rule names an IPv4 network, so ufw creates it only for IPv4 (one "Rules updated" line). SSH gets both IPv4 and IPv6 rules.

```bash
sudo ufw enable
sudo ufw status verbose
sudo ufw status numbered
```

```text
Command may disrupt existing ssh connections. Proceed with operation (y|n)? y
Firewall is active and enabled on system startup
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     LIMIT IN    Anywhere                   # SSH, rate limited
8080/tcp                   ALLOW IN    192.168.122.0/24           # webapp
22/tcp (v6)                LIMIT IN    Anywhere (v6)              # SSH, rate limited

Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     LIMIT IN    Anywhere                   # SSH, rate limited
[ 2] 8080/tcp                   ALLOW IN    192.168.122.0/24           # webapp
[ 3] 22/tcp (v6)                LIMIT IN    Anywhere (v6)              # SSH, rate limited
```

Your SSH session survived the `enable`, because its packets are `ESTABLISHED` in conntrack. Test that **new** connections work too.

**(VM)** Start a throwaway listener on a port with no rule:

```bash
python3 -m http.server 9090 --bind 0.0.0.0 > /dev/null 2>&1 &
```

**(host)**:

```bash
nc -zv -w 3 192.168.122.57 22
nc -zv -w 3 192.168.122.57 9090
ssh lab true && echo "new SSH connection OK"
```

```text
Connection to 192.168.122.57 22 port [tcp/ssh] succeeded!
nc: connect to 192.168.122.57 port 9090 (tcp) timed out: Operation now in progress
new SSH connection OK
```

Port 9090 is listening on all addresses in the VM, but the default-deny policy drops the packets, so the host times out. (Port 8080 is tested in Part 3, once the app listens on it.) **(VM)** Stop the test listener with `kill %1`.

Snapshot: `firewall-on`.

## Part 3: The web app as a service

### 3.1 The service user

**(VM)**

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin webapp
id webapp
getent passwd webapp
```

```text
uid=998(webapp) gid=998(webapp) groups=998(webapp)
webapp:x:998:998::/home/webapp:/usr/sbin/nologin
```

UID 998 is below 1000: a system account. The home field is listed but the directory does not exist, and the shell is `nologin`, so nobody can log in as `webapp`.

### 3.2 The code

The app uses only Python's standard library. It logs each request to stderr (which systemd sends to the journal), stores notes as JSON lines in `$DATA_DIR/notes.jsonl`, and exits cleanly on SIGTERM, which is how systemd stops services.

**(VM)** Create `/opt/webapp/app.py`:

```bash
sudo mkdir -p /opt/webapp
sudo nano /opt/webapp/app.py
```

```python
#!/usr/bin/env python3
"""A tiny notes web app using only the Python standard library."""
import json
import os
import signal
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("PORT", "8080"))
BIND = os.environ.get("BIND", "0.0.0.0")
DATA_DIR = Path(os.environ.get("DATA_DIR", "/var/lib/webapp"))
NOTES = DATA_DIR / "notes.jsonl"


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self._send(200, json.dumps({"status": "ok"}) + "\n")
        elif self.path == "/notes":
            lines = NOTES.read_text().splitlines() if NOTES.exists() else []
            notes = [json.loads(line) for line in lines]
            self._send(200, json.dumps(notes, indent=2) + "\n")
        else:
            self._send(200, "Hello from webapp on Linux!\n", "text/plain")

    def do_POST(self):
        if self.path != "/notes":
            self._send(404, json.dumps({"error": "not found"}) + "\n")
            return
        length = int(self.headers.get("Content-Length", 0))
        text = self.rfile.read(length).decode(errors="replace").strip()
        note = {"time": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "text": text}
        with NOTES.open("a") as f:
            f.write(json.dumps(note) + "\n")
        self._send(201, json.dumps(note) + "\n")

    def log_message(self, fmt, *args):
        # stderr goes to the journal when run under systemd
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))


def main():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((BIND, PORT), Handler)
    # systemd stops services with SIGTERM; turn it into a clean exit
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(0))
    print(f"webapp listening on {BIND}:{PORT}, data in {DATA_DIR}", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        print("webapp stopped", flush=True)


if __name__ == "__main__":
    main()
```

!!! note "Why `sys.exit(0)` and not `server.shutdown()` in the signal handler"
    The signal handler runs in the main thread, which is the thread inside `serve_forever()`. `server.shutdown()` waits for `serve_forever()` to finish, so calling it from that same thread deadlocks, and systemd would have to kill the app with SIGKILL after a 90-second timeout. Raising `SystemExit` unwinds `serve_forever()` immediately, and the `finally` block closes the socket.

Set ownership so `webapp` can read but not change the code:

```bash
sudo chown -R root:root /opt/webapp
sudo chmod 755 /opt/webapp
sudo chmod 644 /opt/webapp/app.py
python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read(), sys.argv[1])' /opt/webapp/app.py && echo "syntax OK"
```

```text
syntax OK
```

Parsing the file catches syntax errors now instead of at service start. (`python3 -m py_compile` would do the same, but it also tries to write a `__pycache__` directory, which fails with `Permission denied` in this root-owned directory. That is the permission setup working as intended.)

### 3.3 Configuration

```bash
sudo mkdir -p /etc/webapp
sudo tee /etc/webapp/webapp.env > /dev/null <<'EOF'
# Read by systemd (as root) before the service starts.
BIND=0.0.0.0
PORT=8080
DATA_DIR=/var/lib/webapp
EOF
sudo chmod 700 /etc/webapp
sudo chmod 600 /etc/webapp/webapp.env
```

The file holds no secrets yet, but treating config as private from day one means a future `API_TOKEN=` line is protected automatically.

### 3.4 The unit file

`/etc/systemd/system/webapp.service`:

```ini
[Unit]
Description=Notes web app (Python standard library)
Documentation=file:///opt/webapp/app.py
After=network.target

[Service]
Type=exec
User=webapp
Group=webapp
WorkingDirectory=/opt/webapp
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/etc/webapp/webapp.env
ExecStart=/usr/bin/python3 /opt/webapp/app.py
Restart=on-failure
RestartSec=2

# Data directory /var/lib/webapp, created and owned by User= automatically
StateDirectory=webapp
StateDirectoryMode=0750

# Resource limit
MemoryMax=256M

# Sandboxing
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
SystemCallArchitectures=native
SystemCallFilter=@system-service
CapabilityBoundingSet=
UMask=0027

[Install]
WantedBy=multi-user.target
```

```bash
sudo nano /etc/systemd/system/webapp.service
sudo systemd-analyze verify /etc/systemd/system/webapp.service && echo "unit OK"
```

```text
unit OK
```

Why each part is there:

| Setting | Reason |
|---------|--------|
| `Type=exec` | Foreground program; a bad `ExecStart=` path fails `systemctl start` immediately |
| `User=`/`Group=webapp` | Never run as root |
| `EnvironmentFile=` (no `-`) | The config is required; a missing file should stop the start loudly |
| `ExecStart=` with absolute paths | systemd does not search `PATH` the way a shell does, and no shell is involved |
| `Restart=on-failure`, `RestartSec=2` | Come back two seconds after a crash or kill |
| `StateDirectory=webapp` | systemd creates `/var/lib/webapp`, owned by `webapp`, mode 0750, and keeps it writable under `ProtectSystem=strict` |
| `MemoryMax=256M` | A leak kills only this service (the kernel logs a "Memory cgroup out of memory" kill), not the server |
| `ProtectSystem=strict` | Whole filesystem read-only for the service, except its state directory |
| `ProtectHome=true` | `/home`, `/root`, and `/run/user` are invisible |
| `PrivateTmp=true` | Its own private `/tmp` |
| `NoNewPrivileges=true`, `CapabilityBoundingSet=` | Cannot gain privileges through setuid binaries; holds no capabilities at all |
| `RestrictAddressFamilies=` | Only IP and Unix sockets |
| `SystemCallFilter=@system-service` | Only the system calls ordinary services need |
| `UMask=0027` | New files (the notes) are not world-readable |

### 3.5 Start, enable, and inspect

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now webapp
systemctl status webapp --no-pager
```

```text
Created symlink /etc/systemd/system/multi-user.target.wants/webapp.service → /etc/systemd/system/webapp.service.
● webapp.service - Notes web app (Python standard library)
     Loaded: loaded (/etc/systemd/system/webapp.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-10-02 10:02:31 UTC; 2s ago
       Docs: file:///opt/webapp/app.py
   Main PID: 3105 (python3)
      Tasks: 1 (limit: 2276)
     Memory: 10.4M (max: 256.0M available: 245.5M peak: 10.6M)
        CPU: 79ms
     CGroup: /system.slice/webapp.service
             └─3105 /usr/bin/python3 /opt/webapp/app.py

Oct 02 10:02:31 lab systemd[1]: Starting webapp.service - Notes web app (Python standard library)...
Oct 02 10:02:31 lab systemd[1]: Started webapp.service - Notes web app (Python standard library).
Oct 02 10:02:31 lab python3[3105]: webapp listening on 0.0.0.0:8080, data in /var/lib/webapp
```

Check the user, the listening socket, and the file layout:

```bash
ps -o pid,user,cmd -p "$(systemctl show -p MainPID --value webapp)"
sudo ss -tlnp 'sport = :8080'
namei -l /opt/webapp/app.py
sudo ls -ld /var/lib/webapp /etc/webapp /etc/webapp/webapp.env
sudo -u webapp test -w /opt/webapp/app.py && echo "WRITABLE (bad)" || echo "not writable (good)"
```

```text
    PID USER     CMD
   3105 webapp   /usr/bin/python3 /opt/webapp/app.py
State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process
LISTEN 0      5            0.0.0.0:8080      0.0.0.0:*     users:(("python3",pid=3105,fd=3))
f: /opt/webapp/app.py
drwxr-xr-x root root /
drwxr-xr-x root root opt
drwxr-xr-x root root webapp
-rw-r--r-- root root app.py
drwxr-x--- webapp webapp /var/lib/webapp
drwx------ root   root   /etc/webapp
-rw------- root   root   /etc/webapp/webapp.env
not writable (good)
```

Check the sandbox score:

```bash
systemd-analyze security webapp --no-pager | tail -n 1
```

```text
→ Overall exposure level for webapp.service: 1.7 OK 🙂
```

Without the sandboxing block, the same unit scores about 9.0 UNSAFE. Your exact number may differ slightly between systemd versions.

### 3.6 Test from the host

**(host)**

```bash
curl -s http://192.168.122.57:8080/
curl -s http://192.168.122.57:8080/health
curl -s -X POST --data 'first note from the host' http://192.168.122.57:8080/notes
curl -s -X POST --data 'second note' http://192.168.122.57:8080/notes
curl -s http://192.168.122.57:8080/notes
```

```text
Hello from webapp on Linux!
{"status": "ok"}
{"time": "2026-10-02T10:04:12+00:00", "text": "first note from the host"}
{"time": "2026-10-02T10:04:15+00:00", "text": "second note"}
[
  {
    "time": "2026-10-02T10:04:12+00:00",
    "text": "first note from the host"
  },
  {
    "time": "2026-10-02T10:04:15+00:00",
    "text": "second note"
  }
]
```

**(VM)** The requests are in the journal:

```bash
journalctl -u webapp -n 4 --no-pager
sudo ls -l /var/lib/webapp/
```

```text
Oct 02 10:04:12 lab python3[3105]: 192.168.122.1 "POST /notes HTTP/1.1" 201 -
Oct 02 10:04:15 lab python3[3105]: 192.168.122.1 "POST /notes HTTP/1.1" 201 -
Oct 02 10:04:18 lab python3[3105]: 192.168.122.1 "GET /notes HTTP/1.1" 200 -
total 4
-rw-r----- 1 webapp webapp 140 Oct  2 10:04 notes.jsonl
```

`-rw-r-----` comes from `UMask=0027`.

### 3.7 Crash recovery

**(VM)**

```bash
old=$(systemctl show -p MainPID --value webapp); echo "old PID $old"
sudo kill -9 "$old"
sleep 3
echo "new PID $(systemctl show -p MainPID --value webapp)"
systemctl is-active webapp
journalctl -u webapp -n 5 --no-pager
```

```text
old PID 3105
new PID 3188
active
Oct 02 10:06:40 lab systemd[1]: webapp.service: Main process exited, code=killed, status=9/KILL
Oct 02 10:06:40 lab systemd[1]: webapp.service: Failed with result 'signal'.
Oct 02 10:06:42 lab systemd[1]: webapp.service: Scheduled restart job, restart counter is at 1.
Oct 02 10:06:42 lab systemd[1]: Started webapp.service - Notes web app (Python standard library).
Oct 02 10:06:42 lab python3[3188]: webapp listening on 0.0.0.0:8080, data in /var/lib/webapp
```

Killed at 10:06:40, back at 10:06:42: `RestartSec=2`. A clean stop also works, thanks to the SIGTERM handler:

```bash
sudo systemctl restart webapp
journalctl -u webapp -n 4 --no-pager | grep -E 'stopped|Stopping|Stopped'
```

```text
Oct 02 10:07:05 lab systemd[1]: Stopping webapp.service - Notes web app (Python standard library)...
Oct 02 10:07:05 lab python3[3188]: webapp stopped
Oct 02 10:07:05 lab systemd[1]: Stopped webapp.service - Notes web app (Python standard library).
```

Snapshot: `webapp-running`.

## Part 4: Nightly backups on a timer

### 4.1 The backup script

`/usr/local/sbin/backup-webapp` (no `.sh`; it is a command, and the name would also be valid for `run-parts` if you ever moved it to `/etc/cron.daily`):

```bash
#!/usr/bin/env bash
# backup-webapp: archive the web app's data and config, verify the archive,
# and keep only the newest $KEEP archives. Run by backup-webapp.service.
set -euo pipefail

DEST=${BACKUP_DEST:-/var/backups/webapp}
KEEP=${BACKUP_KEEP:-7}
SOURCES=(var/lib/webapp etc/webapp)   # relative to /, see --directory below

stamp=$(date +%Y%m%d-%H%M%S)
archive="$DEST/webapp-$stamp.tar.gz"

umask 077                             # archives may contain secrets
mkdir -p "$DEST"
echo "Backing up ${SOURCES[*]} (relative to /) to $archive"

# Write under a temporary name, so a half-written archive never looks finished.
tar --create --gzip --file "$archive.part" --directory / "${SOURCES[@]}"
mv -- "$archive.part" "$archive"

# Prove the archive is readable before trusting it.
tar --list --gzip --file "$archive" > /dev/null
echo "Verified $archive ($(du -h "$archive" | cut -f1))"

# Names contain the timestamp, so glob order is oldest first.
archives=("$DEST"/webapp-*.tar.gz)
excess=$(( ${#archives[@]} - KEEP ))
for (( i = 0; i < excess; i++ )); do
    echo "Removing old backup ${archives[i]}"
    rm -f -- "${archives[i]}"
done

kept=("$DEST"/webapp-*.tar.gz)
echo "Backup complete: ${#kept[@]} archive(s) in $DEST"
```

```bash
sudo nano /usr/local/sbin/backup-webapp
sudo chown root:root /usr/local/sbin/backup-webapp
sudo chmod 755 /usr/local/sbin/backup-webapp
bash -n /usr/local/sbin/backup-webapp && echo "syntax OK"
```

Design notes:

- **`set -euo pipefail`**: any failing command stops the script with a non-zero exit, so systemd marks the run `failed` and it shows up in `systemctl --failed`. A backup that fails silently is the worst kind.
- **`--directory /` with relative paths** stores `var/lib/webapp/...`, not `/var/lib/webapp/...`. Extracting into a scratch directory can then never overwrite live data by accident.
- **`.part` then `mv`**: `mv` within one filesystem is atomic, so a crash mid-backup leaves a `.part` file that the rotation glob ignores, never a truncated `.tar.gz`.
- **`tar --list`** reads the whole archive and fails on corruption.
- **`umask 077`**: the archives contain `webapp.env`, which may hold secrets later, so they are created `-rw-------` and the directory `drwx------`.
- **Rotation by glob**: timestamps sort correctly as text, so no `ls` parsing is needed.

!!! info "Consistency"
    This app appends small lines to a file, so copying it while the app runs is safe enough. For a real database, never `tar` its live data files: dump it first (`pg_dump`, `sqlite3 .backup`) and back up the dump.

### 4.2 Service and timer

`/etc/systemd/system/backup-webapp.service`:

```ini
[Unit]
Description=Back up webapp data and configuration
Documentation=file:///usr/local/sbin/backup-webapp

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/backup-webapp
Nice=10
IOSchedulingClass=idle
```

`/etc/systemd/system/backup-webapp.timer`:

```ini
[Unit]
Description=Nightly webapp backup at 02:30

[Timer]
OnCalendar=*-*-* 02:30:00
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

The service runs as root (the default), because it must read `/etc/webapp/webapp.env` (mode 600) and `/var/lib/webapp` (mode 750). It has no `[Install]` section: only the timer is enabled.

Check the schedule before trusting it:

```bash
systemd-analyze calendar --iterations=2 "*-*-* 02:30:00"
```

```text
  Original form: *-*-* 02:30:00
Normalized form: *-*-* 02:30:00
    Next elapse: Sat 2026-10-03 02:30:00 UTC
       From now: 16h left
   Iteration #2: Sun 2026-10-04 02:30:00 UTC
       From now: 1 day 16h left
```

### 4.3 Run it once by hand, then enable the timer

```bash
sudo systemd-analyze verify /etc/systemd/system/backup-webapp.service /etc/systemd/system/backup-webapp.timer && echo "units OK"
sudo systemctl daemon-reload
sudo systemctl start backup-webapp.service
journalctl -u backup-webapp -n 6 --no-pager
```

```text
units OK
Oct 02 10:12:01 lab systemd[1]: Starting backup-webapp.service - Back up webapp data and configuration...
Oct 02 10:12:01 lab backup-webapp[3350]: Backing up var/lib/webapp etc/webapp (relative to /) to /var/backups/webapp/webapp-20261002-101201.tar.gz
Oct 02 10:12:01 lab backup-webapp[3350]: Verified /var/backups/webapp/webapp-20261002-101201.tar.gz (4.0K)
Oct 02 10:12:01 lab backup-webapp[3350]: Backup complete: 1 archive(s) in /var/backups/webapp
Oct 02 10:12:01 lab systemd[1]: backup-webapp.service: Deactivated successfully.
Oct 02 10:12:01 lab systemd[1]: Finished backup-webapp.service - Back up webapp data and configuration.
```

`systemctl start` waited for the oneshot to finish, and the script's output went to the journal with no redirection needed.

```bash
sudo ls -la /var/backups/webapp/
sudo tar -tzvf /var/backups/webapp/webapp-20261002-101201.tar.gz
```

```text
total 12
drwx------ 2 root root 4096 Oct  2 10:12 .
drwxr-xr-x 3 root root 4096 Oct  2 10:12 ..
-rw------- 1 root root  412 Oct  2 10:12 webapp-20261002-101201.tar.gz
drwxr-x--- webapp/webapp     0 2026-10-02 10:04 var/lib/webapp/
-rw-r----- webapp/webapp   140 2026-10-02 10:04 var/lib/webapp/notes.jsonl
drwx------ root/root         0 2026-10-02 09:58 etc/webapp/
-rw------- root/root        86 2026-10-02 09:58 etc/webapp/webapp.env
```

Ownership and permissions are recorded in the archive, so a restore as root puts them back exactly. Now enable the timer:

```bash
sudo systemctl enable --now backup-webapp.timer
systemctl list-timers backup-webapp.timer
```

```text
Created symlink /etc/systemd/system/timers.target.wants/backup-webapp.timer → /etc/systemd/system/backup-webapp.timer.
NEXT                        LEFT LAST                        PASSED UNIT                ACTIVATES
Sat 2026-10-03 02:41:27 UTC  16h Fri 2026-10-02 10:12:01 UTC 1min ago backup-webapp.timer backup-webapp.service

1 timers listed.
Pass --all to see loaded but inactive timers, too.
```

NEXT is 02:41:27: 02:30 plus a random delay under 15 minutes. LAST shows the manual run, because the timer tracks its service.

### 4.4 Rotation test

Run the backup until there are more than 7 archives, one second apart so the names differ:

```bash
for i in $(seq 1 8); do sudo systemctl start backup-webapp.service; sleep 1; done
sudo sh -c 'ls -1 /var/backups/webapp/ | wc -l'
journalctl -u backup-webapp -n 4 --no-pager | grep -E 'Removing|complete'
```

```text
7
Oct 02 10:14:09 lab backup-webapp[3512]: Removing old backup /var/backups/webapp/webapp-20261002-101401.tar.gz
Oct 02 10:14:09 lab backup-webapp[3512]: Backup complete: 7 archive(s) in /var/backups/webapp
```

Nine runs in total (one earlier, eight now), seven archives kept, oldest removed first.

### 4.5 Restore drill

Record the current notes, take a fresh backup, then lose the data:

```bash
curl -s http://localhost:8080/notes > /tmp/notes-before.json
sudo systemctl start backup-webapp.service
sudo systemctl stop webapp
sudo mv /var/lib/webapp/notes.jsonl /root/notes.jsonl.lost
sudo systemctl start webapp
curl -s http://localhost:8080/notes
```

```text
[]
```

The data is "gone". Restore, carefully. First into a scratch directory, to check the archive before touching live data:

```bash
latest=$(sudo sh -c 'ls -1 /var/backups/webapp/webapp-*.tar.gz | tail -n 1'); echo "$latest"
sudo rm -rf /tmp/restore && sudo mkdir /tmp/restore
sudo tar -xzf "$latest" -C /tmp/restore
sudo cmp /tmp/restore/var/lib/webapp/notes.jsonl /root/notes.jsonl.lost && echo "archive matches the lost file"
```

```text
/var/backups/webapp/webapp-20261002-101530.tar.gz
archive matches the lost file
```

Then restore just the data file into place, with the app stopped:

```bash
sudo systemctl stop webapp
sudo tar -xzf "$latest" -C / var/lib/webapp/notes.jsonl
sudo ls -l /var/lib/webapp/
sudo systemctl start webapp
curl -s http://localhost:8080/notes > /tmp/notes-after.json
diff /tmp/notes-before.json /tmp/notes-after.json && echo "RESTORE OK: notes identical"
```

```text
total 4
-rw-r----- 1 webapp webapp 140 Oct  2 10:04 notes.jsonl
RESTORE OK: notes identical
```

- Naming a member (`var/lib/webapp/notes.jsonl`) extracts only that file.
- Because tar runs as root, it restores the original owner (`webapp`), permissions, and modification time.
- Clean up: `sudo rm -rf /tmp/restore /root/notes.jsonl.lost /tmp/notes-*.json`.

Snapshot: `backups-working`.

## Part 5: Reboot and verify

**(VM)**

```bash
sudo reboot
```

**(host)**, after about 20 seconds:

```bash
ssh lab 'uptime; systemctl is-active webapp ssh.socket ufw; systemctl list-timers backup-webapp.timer --no-legend'
ssh -t lab 'sudo ufw status | head -n 1'
curl -s http://192.168.122.57:8080/health
```

```text
 10:21:44 up 0 min,  1 user,  load average: 0.31, 0.09, 0.03
active
active
active
Sat 2026-10-03 02:41:27 UTC 16h Fri 2026-10-02 10:15:30 UTC 6min ago backup-webapp.timer backup-webapp.service
[sudo] password for alex:
Status: active
Connection to 192.168.122.57 closed.
{"status": "ok"}
```

`ssh -t` allocates a terminal so that `sudo` can ask for your password; without it, `sudo` fails with `a terminal is required to read the password`. `ufw.service` being `active` means the rules were loaded at boot. Everything came back without manual steps: SSH with keys only, the firewall, the app, and the timer. (LAST for the timer shows the restore drill's backup at 10:15:30; the timer remembers it across the reboot. If the VM had been off at 02:30, `Persistent=true` would have triggered a catch-up run right after boot.)

## The verification script

**(VM)**

```bash
check() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; fi; }
check "sshd config valid"           "sudo sshd -t"
check "password auth off"           "sudo sshd -T | grep -qx 'passwordauthentication no'"
check "root login off"              "sudo sshd -T | grep -qx 'permitrootlogin no'"
check "firewall active"             "sudo ufw status | grep -q 'Status: active'"
check "ssh rate-limited"            "sudo ufw status | grep -q '22/tcp.*LIMIT'"
check "webapp enabled"              "systemctl is-enabled --quiet webapp"
check "webapp active"               "systemctl is-active --quiet webapp"
check "webapp not root"             "[ \"\$(ps -o user= -p \$(systemctl show -p MainPID --value webapp))\" = webapp ]"
check "webapp healthy"              "curl -fsS http://localhost:8080/health | grep -q ok"
check "code not writable by webapp" "! sudo -u webapp test -w /opt/webapp/app.py"
check "backup timer enabled"        "systemctl is-enabled --quiet backup-webapp.timer"
check "backup timer scheduled"      "systemctl list-timers backup-webapp.timer --no-legend | grep -q backup-webapp"
check "backups exist"               "sudo sh -c 'ls /var/backups/webapp/webapp-*.tar.gz'"
check "backups private"             "[ -z \"\$(sudo find /var/backups/webapp -name '*.tar.gz' -perm /077)\" ]"
```

```text
PASS  sshd config valid
PASS  password auth off
PASS  root login off
PASS  firewall active
PASS  ssh rate-limited
PASS  webapp enabled
PASS  webapp active
PASS  webapp not root
PASS  webapp healthy
PASS  code not writable by webapp
PASS  backup timer enabled
PASS  backup timer scheduled
PASS  backups exist
PASS  backups private
```

`check` runs each test with `eval` and prints only the verdict. The escaped `\$` inside double quotes delays expansion until `eval` runs the test.

## Common problems and how they were diagnosed

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| `sshd -T` still shows `passwordauthentication yes` | `50-cloud-init.conf` is read first; first value wins | Name the hardening file `10-...` |
| `ssh lab` asks for a password after hardening, then fails | Key not offered: wrong `IdentityFile`, or `~/.ssh` permissions on the VM | `ssh -v lab`; `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys` on the VM |
| `curl` from the host times out on 8080, but works in the VM | No ufw rule, or the rule's source network does not match the host | `sudo ufw status numbered`; check the host's address with `ip -br addr` |
| `curl` from the host says "Connection refused" | App bound to `127.0.0.1`, or not running | `sudo ss -tlnp 'sport = :8080'`; check `BIND=` in the env file |
| `webapp.service` fails with `status=217/USER` | `webapp` user not created, or a typo in `User=` | `id webapp`; fix and `daemon-reload` |
| App fails with `PermissionError` writing notes | Data directory not owned by `webapp`, or `StateDirectory=` missing under `ProtectSystem=strict` | `sudo ls -ld /var/lib/webapp`; add `StateDirectory=webapp` |
| `systemctl stop webapp` takes 90 seconds | The app ignored SIGTERM (for example, calling `server.shutdown()` in the handler deadlocks) | Exit via `sys.exit(0)` in the handler, as in the code above |
| Backup service fails with `Permission denied` | The service was given `User=webapp`, which cannot read the env file | Run the backup as root (no `User=`), or adjust what is backed up |
| Timer shows no NEXT time | The timer was not enabled, or the service was enabled instead | `sudo systemctl enable --now backup-webapp.timer` |

## Going further

Once everything passes, these extensions make the server closer to production:

- **Off-site copy.** Add an `ExecStartPost=` line (or a second service) that pushes the newest archive to another machine with `rsync -a` over SSH, using a dedicated, restricted key. That completes 3-2-1.
- **Failure alerts.** Add `OnFailure=notify-failure@%n.service` to `backup-webapp.service` and write a template unit that logs loudly or sends a message.
- **Restic instead of tar.** Replace the script with restic for deduplicated, encrypted, versioned backups, as in [Disks and backups](../../chapters/04-sysadmin/06-disks-and-backups.md).
- **Reverse proxy and TLS.** Put nginx in front of the app on port 443, bind the app to `127.0.0.1`, and close 8080 in the firewall.
- **fail2ban** for SSH, as described in [SSH](../../chapters/04-sysadmin/05-ssh.md).
- **Rebuild from scratch** on a new VM using only your notes. If you can, you have truly finished Level 4.
