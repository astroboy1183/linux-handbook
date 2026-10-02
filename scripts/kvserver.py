#!/usr/bin/env python3
"""kvserver: a small line-based key-value server (Level 5 capstone).

Protocol (one command per line, UTF-8, lines end with \\n; \\r\\n is accepted):

    SET <key> <value>   -> OK                 value may contain spaces
    GET <key>           -> VALUE <value>  |  NOT_FOUND
    DEL <key>           -> DELETED        |  NOT_FOUND
    STATS               -> STATS keys=N clients=N connections=N commands=N uptime=S
    QUIT                -> BYE   (then the server closes the connection)

Anything else gets "ERR <reason>". On shutdown, connected clients receive
"BYE server shutting down" before their connection is closed.

Linux features used:
  * asyncio (epoll underneath) to serve many clients in one thread
  * SIGTERM / SIGINT handling for a clean, fast shutdown
  * sd_notify readiness (READY=1, STATUS=, STOPPING=1) when run by systemd
  * logs to stderr, so journald captures them; <N> priority prefixes when
    stderr is connected to the journal
  * optional persistence with an atomic write (temp file + fsync + rename)

Standard library only. Python 3.12+.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import signal
import socket
import sys
import tempfile
import time

MAX_LINE = 64 * 1024        # bytes; longer lines get an error and a disconnect
MAX_KEY = 250               # bytes
log = logging.getLogger("kvserver")


# --------------------------------------------------------------------------
# systemd integration (pure Python, no libsystemd needed)
# --------------------------------------------------------------------------
def sd_notify(state: str) -> bool:
    """Send a status message to systemd. Returns False when not under systemd."""
    address = os.environ.get("NOTIFY_SOCKET")
    if not address:
        return False
    if address.startswith("@"):                      # abstract socket namespace
        address = "\0" + address[1:]
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM | socket.SOCK_CLOEXEC) as s:
            s.connect(address)
            s.sendall(state.encode())
        return True
    except OSError as exc:
        log.warning("sd_notify(%r) failed: %s", state, exc)
        return False


class JournalFormatter(logging.Formatter):
    """Prefix each line with <N> so journald records the right priority."""
    PRIORITY = {logging.DEBUG: 7, logging.INFO: 6, logging.WARNING: 4,
                logging.ERROR: 3, logging.CRITICAL: 2}

    def format(self, record: logging.LogRecord) -> str:
        return f"<{self.PRIORITY.get(record.levelno, 6)}>{super().format(record)}"


def setup_logging(level: str) -> None:
    handler = logging.StreamHandler(sys.stderr)      # unbuffered line writes
    if os.environ.get("JOURNAL_STREAM"):             # stderr goes to journald:
        handler.setFormatter(JournalFormatter("%(message)s"))   # it adds timestamps
    else:
        handler.setFormatter(logging.Formatter(
            "%(asctime)s %(levelname)-7s %(message)s", "%H:%M:%S"))
    logging.basicConfig(level=level, handlers=[handler])


# --------------------------------------------------------------------------
# Storage
# --------------------------------------------------------------------------
def load_data(path: str | None) -> dict[str, str]:
    if not path or not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return {str(k): str(v) for k, v in data.items()}


def save_data(path: str, data: dict[str, str]) -> None:
    """Atomically replace `path`: readers see the old file or the new one."""
    directory = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".kvdata-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1, sort_keys=True)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise
    dir_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(dir_fd)
    finally:
        os.close(dir_fd)


# --------------------------------------------------------------------------
# The server
# --------------------------------------------------------------------------
class KVServer:
    def __init__(self, host: str, port: int, data_path: str | None) -> None:
        self.host, self.port, self.data_path = host, port, data_path
        self.store: dict[str, str] = load_data(data_path)
        self.clients: dict[asyncio.Task, asyncio.StreamWriter] = {}
        self.total_connections = 0
        self.total_commands = 0
        self.started = time.monotonic()
        self.stop_event = asyncio.Event()

    # ---- protocol ---------------------------------------------------------
    def execute(self, line: str) -> tuple[str, bool]:
        """Run one command. Returns (reply, keep_connection_open)."""
        cmd, _, rest = line.partition(" ")
        cmd = cmd.upper()
        self.total_commands += 1

        if cmd == "SET":
            key, sep, value = rest.partition(" ")
            if not key or not sep:
                return "ERR usage: SET <key> <value>", True
            if len(key.encode()) > MAX_KEY:
                return f"ERR key longer than {MAX_KEY} bytes", True
            self.store[key] = value
            return "OK", True
        if cmd == "GET":
            key = rest.strip()
            if not key or " " in key:
                return "ERR usage: GET <key>", True
            value = self.store.get(key)
            return ("NOT_FOUND", True) if value is None else (f"VALUE {value}", True)
        if cmd == "DEL":
            key = rest.strip()
            if not key or " " in key:
                return "ERR usage: DEL <key>", True
            return ("DELETED", True) if self.store.pop(key, None) is not None else ("NOT_FOUND", True)
        if cmd == "STATS":
            uptime = time.monotonic() - self.started
            return (f"STATS keys={len(self.store)} clients={len(self.clients)} "
                    f"connections={self.total_connections} "
                    f"commands={self.total_commands} uptime={uptime:.0f}"), True
        if cmd == "QUIT":
            return "BYE", False
        if not cmd:
            self.total_commands -= 1          # blank line: ignore, don't count
            return "", True
        return f"ERR unknown command {cmd[:20]!r}", True

    # ---- one client -------------------------------------------------------
    async def handle_client(self, reader: asyncio.StreamReader,
                            writer: asyncio.StreamWriter) -> None:
        task = asyncio.current_task()
        self.clients[task] = writer
        self.total_connections += 1
        host, port = writer.get_extra_info("peername")[:2]
        peer = f"{host}:{port}"
        log.info("client connected: %s (%d online)", peer, len(self.clients))
        try:
            while True:
                try:
                    raw = await reader.readuntil(b"\n")
                except asyncio.IncompleteReadError:
                    break                             # EOF (client closed)
                except asyncio.LimitOverrunError:
                    writer.write(f"ERR line longer than {MAX_LINE} bytes\n".encode())
                    await writer.drain()
                    break
                line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
                reply, keep_open = self.execute(line)
                if reply:
                    writer.write(reply.encode() + b"\n")
                    await writer.drain()
                if not keep_open:
                    break
        except asyncio.CancelledError:
            # Shutdown: say goodbye politely, then let the cancellation finish.
            try:
                writer.write(b"BYE server shutting down\n")
                await asyncio.wait_for(writer.drain(), timeout=1)
            except (OSError, asyncio.TimeoutError):
                pass
            raise
        except (ConnectionResetError, BrokenPipeError):
            pass
        finally:
            del self.clients[task]
            writer.close()
            try:
                await writer.wait_closed()
            except (OSError, asyncio.CancelledError):
                pass
            log.info("client disconnected: %s (%d online)", peer, len(self.clients))

    # ---- lifecycle --------------------------------------------------------
    def request_stop(self, signum: int) -> None:
        if self.stop_event.is_set():
            log.warning("got %s again; already stopping", signal.Signals(signum).name)
            return
        log.info("got %s, shutting down", signal.Signals(signum).name)
        self.stop_event.set()

    async def run(self) -> None:
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, self.request_stop, sig)

        server = await asyncio.start_server(
            self.handle_client, self.host, self.port, limit=MAX_LINE)
        bound = ", ".join(f"{a[0]}:{a[1]}" for a in
                          (s.getsockname() for s in server.sockets))
        log.info("listening on %s (pid %d, %d keys loaded)",
                 bound, os.getpid(), len(self.store))
        sd_notify(f"READY=1\nSTATUS=Serving on {bound}")

        await self.stop_event.wait()                 # ...until SIGTERM/SIGINT

        sd_notify("STOPPING=1\nSTATUS=Shutting down")
        server.close()                               # 1. stop accepting
        tasks = list(self.clients)
        for task in tasks:                           # 2. end every session
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        await server.wait_closed()
        if self.data_path:                           # 3. persist
            save_data(self.data_path, self.store)
            log.info("saved %d keys to %s", len(self.store), self.data_path)
        log.info("stopped cleanly after %d connections, %d commands",
                 self.total_connections, self.total_commands)


def main() -> int:
    parser = argparse.ArgumentParser(description="Line-based key-value server.")
    parser.add_argument("--host", default=os.environ.get("KV_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("KV_PORT", "7070")))
    parser.add_argument("--data", default=os.environ.get("KV_DATA"),
                        help="JSON file to load at start and save at shutdown")
    parser.add_argument("--log-level", default=os.environ.get("KV_LOG_LEVEL", "INFO"))
    args = parser.parse_args()

    setup_logging(args.log_level.upper())
    try:
        server = KVServer(args.host, args.port, args.data)
        asyncio.run(server.run())
    except OSError as exc:                           # e.g. port already in use
        log.error("cannot start: %s", exc)
        return 1
    except (ValueError, json.JSONDecodeError) as exc:
        log.error("bad data file: %s", exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
