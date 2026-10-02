# SSH Cheat Sheet

Quick reference for SSH keys, client configuration, the agent, copying
files, tunnels, server hardening, and troubleshooting. Chapter:
[SSH](../chapters/04-sysadmin/05-ssh.md). See also
[Set up your practice lab](../lab-setup.md) for SSH-ing into your VM.

## Connecting

| Command | What it does |
|---|---|
| `ssh alex@lab` | Log in to host `lab` as `alex` |
| `ssh lab` | Same, if your username matches or `~/.ssh/config` sets `User` |
| `ssh -p 2222 alex@127.0.0.1` | Non-standard port |
| `ssh -i ~/.ssh/id_ed25519_work alex@lab` | Use a specific key |
| `ssh lab 'df -h /'` | Run one command remotely and return |
| `ssh -t lab 'sudo systemctl restart nginx'` | Force a terminal (needed for `sudo` prompts) |
| `ssh -J alex@bastion alex@10.0.0.5` | Jump through a bastion host |
| `ssh -o ConnectTimeout=5 lab` | Any config option on the command line |
| `exit` or ++ctrl+d++ | Log out |
| ++enter++ `~` `.` | Kill a frozen session (type the three keys in order) |

## Keys

An SSH **key pair** is a private key (stays on your machine, never shared)
and a public key (`.pub`, copied to servers). Key authentication is both
safer and more convenient than passwords.

| Command | What it does |
|---|---|
| `ssh-keygen -t ed25519 -C "alex@mint"` | Create a modern Ed25519 key pair (with a passphrase!) |
| `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_work -C "alex work"` | Create a key with a custom file name |
| `ssh-keygen -t rsa -b 4096` | RSA key, only for old servers that lack Ed25519 |
| `ssh-keygen -p -f ~/.ssh/id_ed25519` | Change or add a passphrase |
| `ssh-keygen -l -f ~/.ssh/id_ed25519.pub` | Show a key's fingerprint |
| `ssh-keygen -y -f ~/.ssh/id_ed25519` | Regenerate the public key from the private key |
| `ssh-copy-id alex@lab` | Append your public key to the server's `~/.ssh/authorized_keys` |
| `ssh-copy-id -i ~/.ssh/id_ed25519_work.pub -p 2222 alex@lab` | Specific key and port |
| `ssh-keygen -R lab` | Remove an old host key from `known_hosts` (after a reinstall) |
| `ssh-keygen -F lab` | Look up a host in `known_hosts` |

Required permissions (SSH refuses keys that others can read or write):

| Path | Mode |
|---|---|
| `~/.ssh/` | `700` |
| `~/.ssh/id_ed25519` (private key) | `600` |
| `~/.ssh/id_ed25519.pub` | `644` |
| `~/.ssh/authorized_keys` (on the server) | `600` |
| `~/.ssh/config` | `600` |

```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519 ~/.ssh/config
```

## ~/.ssh/config

The client config saves typing. The first value found for each option wins,
so put specific hosts at the top and `Host *` defaults at the bottom.

```text title="~/.ssh/config"
# The practice VM
Host lab
    HostName 192.168.122.57
    User alex
    IdentityFile ~/.ssh/id_ed25519

# A cloud server on a non-standard port
Host web1
    HostName 203.0.113.10
    User alex
    Port 2222
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes

# A private server reached through a bastion
Host db1
    HostName 10.0.0.5
    User alex
    ProxyJump web1

# Defaults for every host
Host *
    AddKeysToAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Now `ssh lab`, `scp file web1:`, and `ssh db1` just work.

| Option | Meaning |
|---|---|
| `HostName` | Real address or DNS name |
| `User`, `Port` | Login name, port |
| `IdentityFile` | Private key to offer |
| `IdentitiesOnly yes` | Offer **only** the listed key (avoids "too many authentication failures") |
| `ProxyJump` | Connect through another SSH host |
| `ServerAliveInterval 60` | Send a keepalive every 60 s, so idle sessions don't drop |
| `AddKeysToAgent yes` | Add the key to the agent the first time you unlock it |
| `ForwardAgent yes` | Let the remote host use your agent. Only for hosts you fully trust |
| `LocalForward 5432 localhost:5432` | Same as `-L` every time you connect |
| `ControlMaster auto` + `ControlPath ~/.ssh/cm-%r@%h:%p` + `ControlPersist 10m` | Reuse one connection for many sessions (much faster) |

## ssh-agent

The **agent** holds your unlocked private keys in memory, so you type the
passphrase once per session. Mint's desktop session usually starts one for
you.

| Command | What it does |
|---|---|
| `eval "$(ssh-agent -s)"` | Start an agent in this shell (if none is running) |
| `ssh-add` | Add the default keys |
| `ssh-add ~/.ssh/id_ed25519_work` | Add a specific key |
| `ssh-add -t 1h ~/.ssh/id_ed25519` | Add a key for one hour only |
| `ssh-add -l` | List loaded keys (fingerprints) |
| `ssh-add -D` | Remove all keys from the agent |
| `echo "$SSH_AUTH_SOCK"` | The agent's socket; empty means no agent |

## Copying files: scp and rsync

| Command | What it does |
|---|---|
| `scp report.pdf lab:` | Copy to your home directory on `lab` |
| `scp report.pdf lab:/tmp/` | Copy to a specific directory |
| `scp lab:/var/log/syslog .` | Copy from the server |
| `scp -r site/ lab:/srv/` | Copy a directory |
| `scp -P 2222 file alex@host:` | Port is a capital `-P` for scp |
| `rsync -avz site/ lab:/srv/site/` | Sync a directory (only changed files are sent) |
| `rsync -avzn --delete site/ lab:/srv/site/` | **Dry run** (`-n`) of a mirror that deletes extra files |
| `rsync -avz --delete site/ lab:/srv/site/` | Mirror for real |
| `rsync -avP big.iso lab:` | Show progress, keep partial files to resume |
| `rsync -avz --exclude='.git' --exclude='*.log' src/ lab:app/` | Exclude patterns |
| `rsync -avz -e 'ssh -p 2222' src/ alex@host:dst/` | Custom SSH options |
| `sftp lab` | Interactive file transfer session |

| rsync flag | Meaning |
|---|---|
| `-a` | Archive: recursive, keep permissions, times, symlinks, owner and group |
| `-v` | Verbose |
| `-z` | Compress during transfer |
| `-P` | `--partial --progress` |
| `-n` | Dry run: show what would happen |
| `--delete` | Delete files on the destination that aren't in the source |

!!! warning "Common mistake: the trailing slash in rsync"
    `rsync -a site/ dest/` copies the **contents** of `site` into `dest`.
    `rsync -a site dest/` copies the **directory** itself, creating
    `dest/site/`. Always do a dry run with `-n` before using `--delete`.

## Tunnels and port forwarding

| Command | What it does |
|---|---|
| `ssh -L 8080:localhost:80 lab` | **Local forward**: your `localhost:8080` → port 80 on `lab` |
| `ssh -L 5432:db.internal:5432 web1` | Reach a private database through `web1` |
| `ssh -R 9000:localhost:3000 lab` | **Remote forward**: `lab`'s `localhost:9000` → your port 3000 |
| `ssh -D 1080 lab` | **Dynamic forward**: a SOCKS5 proxy on your port 1080, exiting from `lab` |
| `ssh -N -L 8080:localhost:80 lab` | Forward only, no remote shell |
| `ssh -fN -L 8080:localhost:80 lab` | Same, in the background |

```mermaid
flowchart LR
    A["Your laptop<br/>localhost:5432"] -- "SSH tunnel (encrypted)" --> B["web1"]
    B -- "plain TCP" --> C["db.internal:5432"]
```

Read `-L 5432:db.internal:5432` as "listen on **my** port 5432, and from
the server, connect to `db.internal:5432`". Note that `localhost` in a
forward means localhost **as seen from the SSH server**.

## sshd hardening

Put your settings in a drop-in file. On Ubuntu, `sshd_config` includes
`/etc/ssh/sshd_config.d/*.conf` at the top, and for each option the **first**
value read wins, so a drop-in overrides the main file. Name it so it sorts
before other drop-ins (cloud images often ship `50-cloud-init.conf`).

```text title="/etc/ssh/sshd_config.d/10-hardening.conf"
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers alex
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
```

```bash
sudo sshd -t                     # test the config; no output means OK
sudo sshd -T | grep -iE 'passwordauth|permitroot'   # show effective settings
sudo systemctl restart ssh       # apply (the service is "ssh" on Ubuntu)
```

On Ubuntu 24.04, sshd is started by **socket activation** (`ssh.socket`).
If you change `Port` or `ListenAddress`, run `sudo systemctl daemon-reload`
and `sudo systemctl restart ssh.socket` as well.

!!! danger "⚠️ VM only: keep a second session open"
    Before disabling passwords or changing the port, confirm key login works.
    Then keep your current session open, apply the change, and test with a
    **new** connection. If it fails, fix it from the open session. Practice in
    your VM first, and allow the new port in `ufw` before switching.

## Troubleshooting

Start with verbose output. `-v` shows the main steps, `-vv` and `-vvv` add
detail.

```bash
ssh -vvv lab
```

```text
debug1: Reading configuration data /home/alex/.ssh/config
...
debug1: Connecting to 192.168.122.57 [192.168.122.57] port 22.
debug1: Connection established.
debug1: Server host key: ssh-ed25519 SHA256:...
...
debug1: Authentications that can continue: publickey
debug1: Offering public key: /home/alex/.ssh/id_ed25519 ED25519 SHA256:...
debug1: Authentications that can continue: publickey
debug1: No more authentication methods to try.
alex@192.168.122.57: Permission denied (publickey).
```

This client offered its key and the server refused it: check
`authorized_keys` on the server.

| Symptom | Likely cause | Check or fix |
|---|---|---|
| `Connection refused` | sshd not running, or wrong port | On the server: `systemctl status ssh`, `sudo ss -tlnp | grep ssh` |
| `Connection timed out` | Firewall, wrong IP, or host down | `ping`, `nc -zv host 22`, `sudo ufw status` |
| `Permission denied (publickey)` | Key not in `authorized_keys`, wrong user, or bad permissions | `ssh -v`; on the server `ls -ld ~ ~/.ssh`, `ls -l ~/.ssh/authorized_keys` |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` | Server reinstalled (or a real attack) | Verify the new fingerprint out of band, then `ssh-keygen -R host` |
| `Too many authentication failures` | The agent offers too many keys | `IdentitiesOnly yes` and `IdentityFile` in the config |
| `UNPROTECTED PRIVATE KEY FILE!` | Private key readable by others | `chmod 600 ~/.ssh/id_ed25519` |
| Session freezes when idle | NAT or firewall drops idle connections | `ServerAliveInterval 60` |
| Long pause before the prompt | A slow lookup or auth method | `ssh -v` shows where it pauses; try `-o GSSAPIAuthentication=no` |

The server's side of the story is in its log:

```bash
sudo journalctl -u ssh -f
```
