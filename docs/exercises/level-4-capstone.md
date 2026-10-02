# Level 4 capstone: Build a server from scratch

> **Level 4 · Capstone** · ⏱️ ~4–8 hours · Prerequisites: all of [Level 4: System administration](../chapters/04-sysadmin/index.md)

Take a freshly installed VM and turn it into a small production-style server: key-only SSH, a default-deny firewall, a web app running as a hardened systemd service under its own user, and nightly backups on a systemd timer, with a restore you have actually tested.

## The challenge

Every skill in Level 4 shows up here, in the order a real admin would use them on a new machine. You will:

1. **Secure remote access** so that only your key can log in, and only as your user.
2. **Turn on a firewall** that lets in SSH and the web app, and nothing else.
3. **Deploy a small web app** as a systemd service that runs as a dedicated, unprivileged user, restarts on crashes, starts at boot, and logs to the journal.
4. **Schedule nightly backups** of the app's data and configuration with a systemd timer, keep a week of them, and prove you can restore.
5. **Prove it all** with verification commands, including after a reboot.

Keep a log as you go, for example `notes/level-4-capstone.md` in your handbook repository: every command you ran, its important output, and anything that went wrong. Your "mistakes I made" entries from this capstone will be some of the most valuable in the whole log.

### Setup

- A VM running **Ubuntu Server 24.04** (as in [Set up your practice lab](../lab-setup.md)), with the server name `lab`, your user `alex` (or your own name) with `sudo`, and **OpenSSH server installed**. A Mint 22 VM works too.
- Your Mint machine is the **host**: the "outside world" you test from.
- Find the VM's IP address with `ip -br addr` in the VM. This page uses `192.168.122.57`; substitute yours everywhere.

!!! danger "⚠️ VM only"
    This whole capstone changes SSH, firewall, users, and services. Do every step in the VM, never on your main machine. **Take a VM snapshot before you start**, and another after each part that works, so a mistake costs you minutes, not a reinstall.

### Rules

- Work over SSH from your host as much as possible, as you would with a real server. Keep the VM's console window available as your emergency way back in.
- Before every change to SSH or the firewall, make sure you have a second session open.
- You may use the Level 4 chapters, `man` pages, and `--help`. Try to work from your understanding first and look things up only when stuck.
- Do not use `chmod 777`, run the app as root, or disable the firewall to make something work. If you are tempted to, that is the problem to solve.

## Part 1: Secure SSH

On your **host**:

1. Create an ed25519 key with a passphrase if you do not have one.
2. Before trusting the VM's host key, verify its fingerprint against the one the VM itself reports.
3. Install your public key on the VM, and add a `Host lab` entry to `~/.ssh/config` so that `ssh lab` just works.

On the **VM**:

4. Using a drop-in file in `/etc/ssh/sshd_config.d/`, configure the SSH server so that: password and keyboard-interactive authentication are off, root cannot log in, only your user may log in, and at most 3 authentication attempts are allowed per connection.
5. Validate the configuration before applying it, and confirm the **effective** values.
6. Apply it without dropping your existing session, then prove from the host that key login works and password login is refused.

## Part 2: Firewall

On the **VM**, with ufw:

1. Default policies: deny incoming, allow outgoing.
2. Allow SSH with brute-force rate limiting.
3. Allow the web app's port, **8080/tcp**, only from your host's network (for KVM's default network, `192.168.122.0/24`), with a comment.
4. Enable the firewall without losing your session, and check its status in verbose and numbered form.
5. Prove from the host that SSH and 8080 are reachable and that some other listening port is not.

## Part 3: The web app as a service

Deploy a small notes app written with Python's standard library only. It serves `GET /`, `GET /health`, `GET /notes`, and `POST /notes` (which appends a note to a file). Its code is given in the solution; you may write your own instead, or use `python3 -m http.server` if you want a simpler start, as long as the app writes some data you can back up.

Requirements:

1. A dedicated **system user** `webapp` with no login shell and no home directory.
2. Code in `/opt/webapp/`, owned by root and **not writable** by `webapp`.
3. Data in `/var/lib/webapp/`, writable only by `webapp`.
4. Configuration (the port and data directory) in an environment file `/etc/webapp/webapp.env`, readable only by root.
5. A unit `/etc/systemd/system/webapp.service` that:
    - runs the app as `webapp`, with an absolute `ExecStart=` path;
    - restarts it two seconds after a crash;
    - starts at boot;
    - sends all output to the journal;
    - limits its memory to 256 MB;
    - uses at least `NoNewPrivileges=`, `ProtectSystem=strict`, `ProtectHome=`, and `PrivateTmp=`.
6. Prove that it serves requests from the host, that `kill -9` on its main process brings it back within seconds, and that its log lines appear in the journal.

## Part 4: Nightly backups on a timer

1. Write a backup script `/usr/local/sbin/backup-webapp` that archives `/var/lib/webapp` and `/etc/webapp` into a timestamped `.tar.gz` under `/var/backups/webapp/`, verifies that the archive is readable, keeps only the newest 7 archives, and fails loudly (non-zero exit) if anything goes wrong. Archives must not be readable by other users.
2. Create `backup-webapp.service` (a oneshot) and `backup-webapp.timer` that runs it every night at 02:30, spread by up to 15 minutes, and catches up after the VM was powered off. Give the backup low CPU and I/O priority.
3. Check your schedule expression before using it.
4. Run the backup once by hand through systemd, and read its journal.
5. **Restore drill:** add a few notes through the app, take a backup, then simulate data loss (stop the app and move `/var/lib/webapp/notes.jsonl` away). Restore from the newest archive, start the app, and show that the notes are back.

## Part 5: Prove it survives a reboot

Reboot the VM. Without starting anything by hand, show that SSH (keys only), the firewall, the web app, and the backup timer are all active and correct.

## Acceptance criteria

Tick every box, each backed by a command and its output in your log, before you look at the solution.

**SSH**

- [ ] `ssh lab hostname` from the host prints `lab` without asking for the account password.
- [ ] `sudo sshd -t` prints nothing (success), and `sudo sshd -T` shows `passwordauthentication no`, `kbdinteractiveauthentication no`, `permitrootlogin no`, `allowusers alex`, `maxauthtries 3`.
- [ ] A forced password login from the host fails with `Permission denied (publickey).`
- [ ] Your hardening drop-in sorts before any other file in `/etc/ssh/sshd_config.d/` that sets the same options.

**Firewall**

- [ ] `sudo ufw status verbose` shows `Status: active`, `Default: deny (incoming), allow (outgoing)`, a `LIMIT IN` rule for 22/tcp, and an `ALLOW IN` rule for 8080/tcp from your host network only.
- [ ] From the host, `nc -zv -w 3 192.168.122.57 22` and `... 8080` succeed, and a test listener on another port in the VM (for example `python3 -m http.server 9090`) times out.

**Web app**

- [ ] `id webapp` shows a system user (UID below 1000), and `getent passwd webapp` shows `/usr/sbin/nologin` as its shell.
- [ ] `namei -l /opt/webapp/app.py` and `ls -ld /var/lib/webapp /etc/webapp /etc/webapp/webapp.env` show the ownership and permissions required in Part 3.
- [ ] `systemctl is-enabled webapp` prints `enabled` and `systemctl is-active webapp` prints `active`.
- [ ] `ps -o user= -C python3` (or `systemctl status webapp`) shows the app running as `webapp`, not root.
- [ ] From the host, `curl -s http://192.168.122.57:8080/health` returns `{"status": "ok"}`, and a `POST /notes` is visible in `GET /notes`.
- [ ] After `sudo kill -9` of the main PID, the service is `active (running)` again within 5 seconds with a new PID, and `journalctl -u webapp` shows `Scheduled restart job`.
- [ ] `journalctl -u webapp` contains the app's request log lines.
- [ ] `systemd-analyze security webapp` reports an exposure level better than `UNSAFE`.

**Backups**

- [ ] `systemd-analyze calendar` confirms your `OnCalendar=` fires daily at 02:30.
- [ ] `systemctl list-timers backup-webapp.timer` shows a NEXT time between 02:30 and 02:45, and the timer is enabled.
- [ ] `sudo systemctl start backup-webapp.service` succeeds, and `journalctl -u backup-webapp` shows the archive was written and verified.
- [ ] `sudo ls -l /var/backups/webapp/` shows archives with `-rw-------` permissions, and running the backup 8 times leaves exactly 7.
- [ ] `sudo tar -tzf` on the newest archive lists both `var/lib/webapp/notes.jsonl` and `etc/webapp/webapp.env`.
- [ ] The restore drill brought back the exact notes (compare `GET /notes` before and after, or `diff` the files).

**After reboot**

- [ ] After `sudo reboot`, without manual steps: `ssh lab` works with keys, `sudo ufw status` is active, `curl` to `/health` from the host succeeds, and `systemctl list-timers backup-webapp.timer` shows the next run.

### Verification script

Run this on the VM at the end. Every line should print `PASS`. It is a quick summary, not a substitute for the checks above.

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

## Hints

??? tip "Hint for Part 1: SSH"

    `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the VM's console gives the fingerprint to compare with the first-connection prompt. `ssh-copy-id` installs the key. On Ubuntu Server, look inside `/etc/ssh/sshd_config.d/` before writing your own file: the installer may have created `50-cloud-init.conf` with `PasswordAuthentication yes`, and sshd uses the **first** value it reads. Name your file so it sorts first. Test with `sudo sshd -t`, check with `sudo sshd -T | grep -E '...'`, apply with `sudo systemctl reload ssh`, and test from a **new** terminal with `ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password lab`.

??? tip "Hint for Part 2: firewall"

    Order matters for safety, not just for rules: add the SSH rule **before** `ufw enable`. `ufw show added` lists queued rules while the firewall is still inactive. The full rule syntax is `ufw allow from NETWORK to any port PORT proto tcp comment '...'`. Remember that a listener bound to `127.0.0.1` is unreachable from the host regardless of the firewall, so start your test listener on `0.0.0.0`.

??? tip "Hint for Part 3: users and permissions"

    `useradd --system --no-create-home --shell /usr/sbin/nologin webapp`. A root-owned `/opt/webapp` with mode 755 and a 644 `app.py` is readable but not writable by `webapp`. systemd can create the data directory for you with the right owner: look up `StateDirectory=` in `man systemd.exec`. The environment file is read by systemd itself (as root) before it drops privileges, so mode 600 root-owned is fine. Use `namei -l` to check every directory along a path, and `sudo -u webapp test -w FILE` to check writability exactly as the service sees it.

??? tip "Hint for Part 3: the unit"

    Start from the `webapp.service` in [systemd and journalctl](../chapters/04-sysadmin/01-systemd-and-journalctl.md). `Type=exec`, `Restart=on-failure`, `RestartSec=2`, `MemoryMax=256M`. With `ProtectSystem=strict`, the whole filesystem is read-only for the service except its `StateDirectory=` (or paths in `ReadWritePaths=`). If the service fails, the exit status in `systemctl status` narrows it down (`217/USER`, `200/CHDIR`, `203/EXEC`), and `journalctl -xeu webapp` has the details. Python buffers output when not on a terminal; `PYTHONUNBUFFERED=1` makes log lines appear immediately.

??? tip "Hint for Part 4: the backup script and timer"

    Start the script with `set -euo pipefail` so any failure stops it with a non-zero exit, which makes the service `failed` and visible in `systemctl --failed`. `tar --directory / var/lib/webapp etc/webapp` stores relative paths. Write to `NAME.part` and rename at the end, so a half-written archive never looks complete. `umask 077` at the top makes new files private. Timestamps in file names sort chronologically, so a glob gives you the archives oldest first. For the timer: `OnCalendar=*-*-* 02:30:00`, `RandomizedDelaySec=15min`, `Persistent=true`, and `Nice=`/`IOSchedulingClass=idle` in the service. Enable the **timer**, not the service.

??? tip "Hint for the restore drill"

    Extract into a scratch directory first and compare (`tar -xzf ARCHIVE -C /tmp/restore`, then `diff`), so you know the archive is good before touching live data. Stop the app before restoring its data, extract the one directory you need with `-C /`, check ownership, then start the app.

## Solution

Finished and ticked every box? Compare your work with the [step-by-step solution](solutions/level-4-capstone.md). Your IP address, PIDs, and timestamps will differ. Check that your unit files make the same security decisions and that every verification passes for the same reasons.

## Next

With Level 4 done, you can run, secure, and repair a Linux server. Level 5 turns to building software for Linux, starting from how programs talk to the kernel: begin with [System calls and strace](../chapters/05-programming/01-system-calls-strace.md).
