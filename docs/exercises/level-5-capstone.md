# Level 5 capstone: a key-value server as a service

> **Level 5 · Capstone** · ⏱️ 4–8 hours · Prerequisites: all of [Level 5: Building for Linux](../chapters/05-programming/index.md)

Write a small network server in Python that stores keys and values in memory, serves several clients at the same time, shuts down cleanly when it receives a signal, and runs as a systemd service. It's a miniature Redis or memcached, and it uses every chapter of Level 5: system calls, file descriptors, processes and signals, sockets, and systemd.

Work without the chapters open if you can. When you get stuck, use the hints below before looking at the [reference solution](solutions/level-5-capstone.md).

## The scenario

Your team has several small batch jobs that need to share bits of state: the last processed file, a feature flag, a run counter. Setting up a database for this is overkill. You'll write `kvserver`, a tiny line-based key-value server that any script can talk to with `nc` or a few lines of Python, and run it as a proper service on a server.

## The protocol

Clients connect over TCP and send **one command per line**. Lines are UTF-8 text ending in `\n`. The server must also accept `\r\n`, so `nc -C` and telnet-style clients work. Command names are case-insensitive. Keys are case-sensitive and contain no spaces.

| Command | Reply | Notes |
|---------|-------|-------|
| `SET <key> <value>` | `OK` | The value is everything after the key, and may contain spaces. Overwrites any existing value |
| `GET <key>` | `VALUE <value>` or `NOT_FOUND` | |
| `DEL <key>` | `DELETED` or `NOT_FOUND` | |
| `STATS` | `STATS keys=N clients=N connections=N commands=N uptime=S` | `clients` = connected now; `connections` = total since start; `commands` = total commands handled, including this one; `uptime` in whole seconds |
| `QUIT` | `BYE` | Then the server closes the connection |
| anything else | `ERR <reason>` | Also for a missing key or value, e.g. `SET lonely` |

A blank line gets no reply. When the server shuts down, every connected client receives `BYE server shutting down` and then its connection is closed.

An example session:

```console
$ nc 127.0.0.1 7070
SET user alex
OK
SET motd hello from mint
OK
GET motd
VALUE hello from mint
get user
VALUE alex
DEL user
DELETED
GET user
NOT_FOUND
FLY away
ERR unknown command 'FLY'
STATS
STATS keys=1 clients=1 connections=1 commands=8 uptime=41
QUIT
BYE
```

## Requirements

### The program

1. **One file, standard library only:** `kvserver.py`, Python 3.12. No `pip install`.
2. **Command-line options:** `--host` (default `127.0.0.1`), `--port` (default `7070`), `--data PATH` (optional, see 6), and `--log-level` (default `INFO`). Each should also be settable with an environment variable (`KV_HOST`, `KV_PORT`, `KV_DATA`, `KV_LOG_LEVEL`), so a systemd `EnvironmentFile=` can configure it.
3. **Concurrency:** many clients connected at the same time, each served promptly. A slow or idle client must never block the others. Use `asyncio` or `selectors` (threads are acceptable, but you'll find shutdown harder).
4. **Framing and limits:** handle commands split across several packets and several commands in one packet. Reject lines longer than 64 KiB with an `ERR` reply and close that connection. Reject keys longer than 250 bytes.
5. **Clean shutdown:** on `SIGTERM` or `SIGINT`: stop accepting connections, send every client `BYE server shutting down`, close all connections, save data (if `--data` is set), log a final "stopped cleanly" line, and exit with status **0**. All of this must take well under one second. A second signal during shutdown must not crash it.
6. **Persistence:** with `--data PATH`, load the JSON file at startup (if it exists) and save all keys to it on shutdown. The save must be **atomic**: write a temp file in the same directory, `fsync` it, and rename it over the old file.
7. **Logging:** log to **stderr** (not a file) with the `logging` module: startup (address, PID, number of keys loaded), each connect and disconnect, the signal received, and the final shutdown line. No `print()` calls for logs.
8. **Startup errors:** if the port is already in use, log one clear error line and exit with status 1. No traceback.

### The service

9. **systemd readiness:** support `Type=notify`. When the port is listening, send `READY=1` and a `STATUS=` line to the socket in `NOTIFY_SOCKET` (in pure Python, no libraries). Send `STOPPING=1` when shutdown begins. Do nothing if `NOTIFY_SOCKET` isn't set.
10. **User service (practice, on your main machine):** a unit at `~/.config/systemd/user/kvserver.service` with `Type=notify`, `Restart=on-failure`, `RestartSec=2`, `SyslogIdentifier=kvserver`, and a data file under `StateDirectory=`.
11. **System service (⚠️ VM only):** a hardened unit at `/etc/systemd/system/kvserver.service` running as a dedicated `kvserver` system user (or `DynamicUser=yes`), with code in `/opt/kvserver` (and a venv), data in `/var/lib/kvserver`, and an exposure score of **2.0 or lower** from `systemd-analyze security`.

!!! danger "⚠️ VM only"
    Requirement 11 creates a system user, writes under `/opt`, `/etc`, and `/var/lib`, and installs a service that starts at boot. Do it in your throwaway VM, never on your main machine. Everything else in this capstone is safe on your main machine.

### Stretch goals (optional)

- **Durability on crash:** save after every write that changes data (atomically), so a `SIGKILL` loses nothing.
- **Idle timeout:** disconnect clients that send nothing for 5 minutes.
- **Socket activation:** accept a listening socket from systemd (`LISTEN_FDS`) and ship a `kvserver.socket` unit.
- **`KEYS <prefix>`:** return matching keys, one per line, then `END`.

## Acceptance criteria

Start the server in one terminal (`python3 kvserver.py --data /tmp/kv-test.json`) and run the checks from a second one. Tick each box only when the result matches exactly.

### Protocol

- [ ] Basic commands produce exactly these replies:

    ```bash
    printf 'SET user alex\nSET motd hello from mint\nGET user\nGET motd\nGET nope\nDEL user\nDEL user\nQUIT\n' | nc -q1 127.0.0.1 7070
    ```

    ```text
    OK
    OK
    VALUE alex
    VALUE hello from mint
    NOT_FOUND
    DELETED
    NOT_FOUND
    BYE
    ```

- [ ] Errors are replies, not disconnects or crashes:

    ```bash
    printf 'FLY away\nSET lonely\nGET\nget motd\nQUIT\n' | nc -q1 127.0.0.1 7070
    ```

    ```text
    ERR unknown command 'FLY'
    ERR usage: SET <key> <value>
    ERR usage: GET <key>
    VALUE hello from mint
    BYE
    ```

    (Your error wording may differ. Each line must start with `ERR`.)

- [ ] CRLF line endings work: `printf 'GET motd\r\nQUIT\r\n' | nc -q1 127.0.0.1 7070` prints `VALUE hello from mint` (without a stray `\r`, check with `| od -c`) and `BYE`.
- [ ] A 70,000-byte line gets an `ERR` reply and a closed connection, and the server keeps running:

    ```bash
    python3 -c 'print("SET big " + "x" * 70000)' | nc -q1 127.0.0.1 7070
    printf 'GET motd\nQUIT\n' | nc -q1 127.0.0.1 7070
    ```

- [ ] A command split across two writes still works:

    ```bash
    (printf 'GE'; sleep 1; printf 'T motd\nQUIT\n') | nc -q2 127.0.0.1 7070
    ```

### Concurrency

- [ ] Open `nc 127.0.0.1 7070` in two terminals and leave both connected. Both get immediate replies to `SET` and `GET`, in any order. `STATS` in either shows `clients=2`.
- [ ] With one idle `nc` still connected, this load check reports 0 errors in under a second. Save it as `kv_load.py`:

    ```python title="kv_load.py"
    #!/usr/bin/env python3
    """Load check for the capstone: N clients, all connected at once, interleaved."""
    import socket
    import sys
    import time

    HOST, PORT = "127.0.0.1", int(sys.argv[2]) if len(sys.argv) > 2 else 7070
    N = int(sys.argv[1]) if len(sys.argv) > 1 else 20

    def ask(f, sock, line: str) -> str:
        sock.sendall(line.encode() + b"\n")
        return f.readline().decode().rstrip("\n")

    conns = []
    for i in range(N):
        s = socket.create_connection((HOST, PORT), timeout=5)
        conns.append((s, s.makefile("rb")))

    t0 = time.monotonic()
    errors = 0
    for rnd in range(10):
        for i, (s, f) in enumerate(conns):          # every client takes a turn
            errors += ask(f, s, f"SET load:{i}:{rnd} value {i} {rnd}") != "OK"
        for i, (s, f) in enumerate(conns):
            errors += ask(f, s, f"GET load:{i}:{rnd}") != f"VALUE value {i} {rnd}"
    stats = ask(conns[0][1], conns[0][0], "STATS")
    for s, f in conns:
        f.close()
        s.close()
    print(f"{N} concurrent clients, {N * 20} commands, {errors} errors, "
          f"{time.monotonic() - t0:.2f}s")
    print(stats)
    sys.exit(1 if errors else 0)
    ```

    ```bash
    python3 kv_load.py 20
    ```

    ```text
    20 concurrent clients, 400 commands, 0 errors, 0.02s
    STATS keys=201 clients=21 connections=24 commands=413 uptime=95
    ```

    (Your `STATS` counts will differ. `clients` should be 21: the 20 test clients plus your idle `nc`.) A server that handles one client at a time fails this check with a `TimeoutError`.

- [ ] `ss -tnp '( sport = :7070 )'` shows one `ESTAB` line per connected client, all owned by the same `python3` process (no forked children).

### Signals and shutdown

- [ ] With an `nc` session connected, run `pkill -TERM -f '^python3 kvserver.py'` (the `^` anchor matches only command lines that *start* with `python3 kvserver.py`):
    - the `nc` session prints `BYE server shutting down` and exits,
    - the server logs `got SIGTERM`, `saved N keys to /tmp/kv-test.json`, and `stopped cleanly`,
    - the server's exit status is 0 (`echo $?` in its terminal).
- [ ] ++ctrl+c++ in the server's terminal does the same, with `got SIGINT`, and no `KeyboardInterrupt` traceback.
- [ ] Restarting with the same `--data` file restores the keys: `printf 'GET motd\nQUIT\n' | nc -q1 127.0.0.1 7070` prints `VALUE hello from mint`.
- [ ] The data file is valid JSON: `python3 -m json.tool /tmp/kv-test.json`.
- [ ] The save is atomic. This shows a `rename` of a temp file onto the data file, after an `fsync`:

    ```bash
    strace -f -e trace=fsync,rename,renameat2 -o save.trace python3 kvserver.py --data /tmp/kv-test.json &
    sleep 1
    pkill -TERM -f '^python3 kvserver.py'     # signal the server, not strace
    wait
    grep -E 'fsync|rename' save.trace
    ```

    ```text
    254092 fsync(6)                         = 0
    254092 rename("/tmp/.kvdata-t5qu5khr", "/tmp/kv-test.json") = 0
    254092 fsync(6)                         = 0
    ```

    The first `fsync` is the temp file, then the atomic `rename`, then an `fsync` of the directory (it reuses fd 6 after the temp file was closed). Stop the first server before this check, since the port is in use.

- [ ] Port already in use gives a clean error and exit status 1, with no traceback. Start a second copy while the first is running:

    ```bash
    python3 kvserver.py; echo "exit status: $?"
    ```

    ```text
    11:52:03 ERROR   cannot start: [Errno 98] error while attempting to bind on address ('127.0.0.1', 7070): address already in use
    exit status: 1
    ```

### As a user service

Install your unit at `~/.config/systemd/user/kvserver.service`, then:

- [ ] `systemd-analyze --user verify ~/.config/systemd/user/kvserver.service` prints nothing.
- [ ] After `systemctl --user daemon-reload && systemctl --user start kvserver`, `systemctl --user status kvserver` shows `active (running)` and a `Status:` line with your `STATUS=` text (proof that `READY=1` arrived).
- [ ] `journalctl --user -u kvserver -n 20` shows your startup and connection lines tagged `kvserver[PID]`, each with **one** timestamp (journald's, not a second one from your program).
- [ ] A clean stop is fast:

    ```bash
    time systemctl --user stop kvserver
    ```

    `real` is well under 1 second, and the journal shows `got SIGTERM`, `stopped cleanly`, and `Deactivated successfully`, not `timed out` or `SIGKILL`.
- [ ] Crash recovery works:

    ```bash
    systemctl --user start kvserver
    systemctl --user kill --signal=SIGKILL kvserver
    sleep 3
    systemctl --user show kvserver -p NRestarts -p ActiveState
    ```

    ```text
    NRestarts=1
    ActiveState=active
    ```

- [ ] `journalctl --user -u kvserver -p warning` shows only warnings and errors, not routine connection lines.

### As a system service (⚠️ VM only)

- [ ] `systemctl status kvserver` shows `active (running)`, `enabled`, and your `Status:` line, and survives a VM reboot.
- [ ] `ps -o user,cmd -C python` shows the service running as `kvserver` (or a dynamic user), not root.
- [ ] `sudo ls -l /var/lib/kvserver/` shows the data file owned by the service user.
- [ ] `systemd-analyze security kvserver.service | tail -1` reports an exposure of 2.0 or lower.
- [ ] `sudo journalctl -u kvserver -b` shows the full lifecycle since boot.

## Hints

Try each part on your own first. Open a hint only after you've been stuck for a while.

??? tip "Hint 1: Which concurrency model?"

    `asyncio` makes this capstone easiest. `asyncio.start_server(handler, host, port, limit=65536)` gives each client its own coroutine with a `StreamReader` and `StreamWriter`. `await reader.readuntil(b"\n")` handles framing and the line limit for you. It raises `asyncio.IncompleteReadError` at EOF and `asyncio.LimitOverrunError` for an over-long line. Review [Pipes and sockets](../chapters/05-programming/04-pipes-and-sockets.md).

??? tip "Hint 2: Parsing commands"

    `str.partition(" ")` splits on the first space only and never fails: `cmd, _, rest = line.partition(" ")`. Use it twice for `SET`: once to get the command, and again on `rest` to split the key from the value (which may contain spaces). Strip `\r\n` from the end of the line before parsing.

??? tip "Hint 3: Signals in an asyncio program"

    Don't use `signal.signal()` with asyncio. Use `loop.add_signal_handler(signal.SIGTERM, callback)`, which runs the callback safely inside the event loop. Have it set an `asyncio.Event`. The main coroutine awaits that event, then does the shutdown steps in order. See the graceful shutdown pattern in [Processes and signals in code](../chapters/05-programming/03-processes-signals-in-code.md).

??? tip "Hint 4: Closing every client on shutdown"

    Keep a set (or dict) of the tasks currently serving clients: add `asyncio.current_task()` when a handler starts, and remove it in a `finally` block. On shutdown, call `server.close()` to stop accepting, then `task.cancel()` on each client task, and `await asyncio.gather(*tasks, return_exceptions=True)`. Inside the handler, catch `asyncio.CancelledError`, write the `BYE` line, and re-raise.

??? tip "Hint 5: sd_notify in pure Python"

    ```python
    addr = os.environ.get("NOTIFY_SOCKET")
    if addr:
        if addr.startswith("@"):
            addr = "\0" + addr[1:]          # abstract namespace
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
            s.connect(addr)
            s.sendall(b"READY=1\nSTATUS=Serving on 127.0.0.1:7070")
    ```

    To test it without systemd, bind your own `AF_UNIX`/`SOCK_DGRAM` socket to a temp path, start the server with `NOTIFY_SOCKET` set to that path, and `recv()` from it. The [services chapter](../chapters/05-programming/05-services-with-systemd.md) has a complete `fake_systemd.py`.

??? tip "Hint 6: Logging that suits both the terminal and the journal"

    `logging.basicConfig(level=..., format="%(asctime)s %(levelname)-7s %(message)s")` is right for a terminal. Under systemd, journald adds timestamps itself, so drop `%(asctime)s` when the environment variable `JOURNAL_STREAM` is set. To make `journalctl -p warning` work, prefix each line with the syslog priority, like `<4>` for warnings and `<3>` for errors, using a small `logging.Formatter` subclass.

??? tip "Hint 7: The atomic save"

    `tempfile.mkstemp(dir=os.path.dirname(path))` creates the temp file in the same directory. Write the JSON, `f.flush()`, `os.fsync(f.fileno())`, then `os.replace(tmp, path)`, and finally `fsync` the directory. Delete the temp file if anything fails. This is the `atomic_write` function from [File descriptors in code](../chapters/05-programming/02-file-descriptors.md).

??? tip "Hint 8: The port-in-use error"

    `asyncio.start_server` raises `OSError` with `errno` 98 (`EADDRINUSE`). Catch `OSError` around `asyncio.run(...)` in `main()`, log it with `log.error(...)`, and `return 1`. Then `sys.exit(main())`.

??? tip "Hint 9: The user unit"

    ```ini
    [Service]
    Type=notify
    ExecStart=/usr/bin/python3 %h/kvserver/kvserver.py --port 7070 --data %S/kvserver/data.json
    StateDirectory=kvserver
    SyslogIdentifier=kvserver
    Restart=on-failure
    RestartSec=2
    ```

    `%h` is your home directory, and `%S` is `~/.local/state` for a user service. Add a `[Unit]` `Description=` and an `[Install]` section with `WantedBy=default.target`.

## Solution

When every box is ticked, or when you've made a serious attempt and are truly stuck, compare your work with the [reference solution](solutions/level-5-capstone.md). It includes a complete `kvserver.py`, user and system unit files, an automated end-to-end test script, and an explanation of every design decision. Your code doesn't need to match it. It needs to pass the acceptance criteria.
