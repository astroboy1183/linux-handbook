# Permissions Cheat Sheet

Quick reference for reading and changing file permissions, ownership, the
umask, special bits, and `sudo`. Chapters:
[Users, groups, and sudo](../chapters/00-first-steps/06-users-groups-sudo.md),
[Permissions](../chapters/01-command-line/03-permissions.md),
[User management and PAM](../chapters/04-sysadmin/08-user-management.md).

## Anatomy of `ls -l`

```bash
ls -l /home/alex/deploy.sh
```

```text
-rwxr-x--- 1 alex devs 2048 Oct  2 09:14 /home/alex/deploy.sh
```

```text
 -   rwx   r-x   ---   1   alex   devs   2048   Oct  2 09:14   deploy.sh
 │   ─┬─   ─┬─   ─┬─   │   ──┬─   ──┬─   ──┬─   ──────┬─────   ────┬────
 │    │     │     │    │     │      │      │          │            └─ name
 │    │     │     │    │     │      │      │          └─ last modified (mtime)
 │    │     │     │    │     │      │      └─ size in bytes
 │    │     │     │    │     │      └─ group owner
 │    │     │     │    │     └─ user owner
 │    │     │     │    └─ hard link count
 │    │     │     └─ other (everyone else): no access
 │    │     └─ group: read and execute
 │    └─ user (owner): read, write, execute
 └─ file type
```

| Type char | Meaning | Type char | Meaning |
|---|---|---|---|
| `-` | Regular file | `c` | Character device (`/dev/tty`) |
| `d` | Directory | `b` | Block device (`/dev/sda`) |
| `l` | Symbolic link | `p` | Named pipe (FIFO) |
| `s` | Socket | | |

Check who you are and what groups you're in:

```bash
id
```

```text
uid=1000(alex) gid=1000(alex) groups=1000(alex),4(adm),27(sudo),1001(devs)
```

## What r, w, x mean

| Bit | On a file | On a directory |
|---|---|---|
| `r` (read) | Read the contents | List the names inside (`ls`) |
| `w` (write) | Change the contents | Create, delete, and rename entries inside (needs `x` too) |
| `x` (execute) | Run it as a program | Enter it (`cd`) and access entries by name |

!!! warning "Common mistake: deleting is a directory permission"
    Whether you can delete a file depends on `w` on the **directory**, not
    on the file. A read-only file in your own directory can still be deleted.

Linux checks **one** class, in order: if you're the owner, only the user bits
apply; else if you're in the group, only the group bits; else the other
bits.

## `chmod`: octal mode

Each digit is the sum of r=4, w=2, x=1, for user, group, and other.

| Digit | Bits | Meaning |
|---|---|---|
| 0 | `---` | No access |
| 1 | `--x` | Execute only |
| 2 | `-w-` | Write only |
| 3 | `-wx` | Write and execute |
| 4 | `r--` | Read only |
| 5 | `r-x` | Read and execute |
| 6 | `rw-` | Read and write |
| 7 | `rwx` | Everything |

| Mode | `ls -l` | Typical use |
|---|---|---|
| `644` | `rw-r--r--` | Normal files: config, documents |
| `600` | `rw-------` | Private files: SSH private keys, `.env` secrets |
| `640` | `rw-r-----` | Readable by a group, e.g. logs for `adm` |
| `755` | `rwxr-xr-x` | Programs, scripts, and normal directories |
| `750` | `rwxr-x---` | Directories or scripts for owner and group only |
| `700` | `rwx------` | Private directories: `~/.ssh` |
| `775` | `rwxrwxr-x` | Shared group project directories |
| `777` | `rwxrwxrwx` | Almost never correct. Anyone can change it. |

```bash
chmod 600 ~/.ssh/id_ed25519
chmod 755 ~/bin/backup.sh
chmod -R 750 /srv/project      # -R recurses into the directory
```

## `chmod`: symbolic mode

Format: **who** (`u` user, `g` group, `o` other, `a` all) + **operator**
(`+` add, `-` remove, `=` set exactly) + **permissions** (`r`, `w`, `x`, `X`,
`s`, `t`).

| Command | Effect |
|---|---|
| `chmod +x script.sh` | Add execute for everyone (respecting the umask) |
| `chmod u+x script.sh` | Add execute for the owner only |
| `chmod go-w file` | Remove write from group and other |
| `chmod o= file` | Remove all permissions from other |
| `chmod u=rw,go=r file` | Set exactly `rw-r--r--` (644) |
| `chmod g+w,o-rwx dir` | Combine several changes |
| `chmod -R u+rwX,go+rX dir` | Recursively: `X` adds execute to directories (and files already executable), not to plain files |
| `chmod --reference=a b` | Copy a's mode to b |

!!! tip "Fix a tree's permissions safely"
    Files and directories need different modes. Use `find` to treat them
    separately:

    ```bash
    find /srv/site -type d -exec chmod 755 {} +
    find /srv/site -type f -exec chmod 644 {} +
    ```

## Ownership: `chown` and `chgrp`

Changing a file's owner requires root. You can change a file's group to any
group you belong to.

| Command | Effect |
|---|---|
| `sudo chown bob file` | Make `bob` the owner |
| `sudo chown bob:devs file` | Set owner and group |
| `sudo chown :devs file` | Set group only |
| `chgrp devs file` | Set group only (if you're in `devs`) |
| `sudo chown -R www-data:www-data /var/www/site` | Recursively |
| `sudo chown alex: file` | Owner `alex`, group = alex's login group |

## `umask`: default permissions

New files start from `666` and new directories from `777`. The **umask**
removes bits from those defaults. Mint and Ubuntu give normal users a umask
of `002`; root gets `022`.

| umask | New file | New directory | Meaning |
|---|---|---|---|
| `002` | `664` `rw-rw-r--` | `775` `rwxrwxr-x` | Group can write (Ubuntu user default) |
| `022` | `644` `rw-r--r--` | `755` `rwxr-xr-x` | Only you can write (root's default) |
| `027` | `640` `rw-r-----` | `750` `rwxr-x---` | Group can read, others nothing |
| `077` | `600` `rw-------` | `700` `rwx------` | Private: only you |

```bash
umask          # show as octal: 0002
umask -S       # show symbolically: u=rwx,g=rwx,o=rx
umask 027      # set for this shell; put it in ~/.bashrc to persist
```

The umask only *removes* bits. It never adds execute to new files, which is
why you always need `chmod +x` on a new script.

## Special bits

| Bit | Octal | On a file | On a directory | `ls -l` shows |
|---|---|---|---|---|
| **setuid** | `4000` | Runs with the **file owner's** privileges | (ignored on Linux) | `s` in user x: `rwsr-xr-x` |
| **setgid** | `2000` | Runs with the **file group's** privileges | New files inherit the directory's group | `s` in group x: `rwxr-sr-x` |
| **sticky** | `1000` | (ignored) | Only a file's owner (or root) can delete or rename it | `t` in other x: `rwxrwxrwt` |

A capital `S` or `T` means the special bit is set but the matching execute
bit isn't, which is usually a mistake.

```bash
ls -l /usr/bin/passwd
ls -ld /tmp
```

```text
-rwsr-xr-x 1 root root 64152 May 30  2024 /usr/bin/passwd
drwxrwxrwt 19 root root 4096 Oct  2 10:37 /tmp
```

```bash
sudo chmod 2775 /srv/shared       # setgid shared directory: files get group of /srv/shared
sudo chmod +t /srv/dropbox        # sticky: users can't delete each other's files
find / -perm -4000 -type f 2>/dev/null   # audit: list all setuid files
```

!!! danger "⚠️ VM only: never setuid a script"
    Don't add setuid to shell scripts or to copies of system binaries. The
    kernel ignores setuid on scripts anyway, and a setuid binary you don't
    fully control is a classic way to give root to any user. Experiment with
    special bits only in your VM.

## `sudo`

`sudo` runs one command as root (or another user), after checking
`/etc/sudoers` and asking for **your** password. Members of the `sudo` group
are allowed everything.

| Command | Effect |
|---|---|
| `sudo CMD` | Run a command as root |
| `sudo -u bob CMD` | Run as another user |
| `sudo -i` | Root login shell (root's environment) |
| `sudo -s` | Root shell in the current directory, without a full login |
| `sudo -l` | List what you're allowed to run |
| `sudo -k` | Forget the cached password now |
| `sudo !!` | Re-run the previous command with sudo |
| `sudoedit /etc/hosts` | Edit a root-owned file safely with your own editor |
| `sudo visudo` | Edit `/etc/sudoers` with a syntax check |
| `sudo visudo -f /etc/sudoers.d/deploy` | Add a drop-in rule file |

!!! warning "Common mistake: `sudo` and redirection"
    `sudo echo "x" > /etc/file` fails: your *unprivileged* shell opens the
    file before `sudo` runs. Use `tee` instead:

    ```bash
    echo "127.0.1.1 mint" | sudo tee -a /etc/hosts
    ```

!!! danger "⚠️ VM only: editing sudoers"
    A syntax error in `/etc/sudoers` can lock everyone out of `sudo`. Always
    use `visudo`, and practice in your VM first.

## Troubleshooting "Permission denied"

1. **Who am I?** `id`
2. **What are the permissions on the file?** `ls -l file`
3. **What about every directory on the way?** You need `x` on each one:
   `namei -l /srv/app/config/settings.ini`
4. **Is it a script?** It needs `x`, and a valid shebang line.
5. **Did group changes take effect?** New group membership applies only to
   new logins. Log out and in, or run `newgrp devs` in this shell.
6. **Still denied as root?** Look for a read-only mount (`findmnt -T file`),
   an immutable attribute (`lsattr file`), or an AppArmor denial
   (`sudo journalctl -k | grep -i apparmor`).
