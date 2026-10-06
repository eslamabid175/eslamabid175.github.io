#!/usr/bin/env python3
"""Probe (and drive) the project MCP servers from .mcp.json without a client.

Claude Code only loads `.mcp.json` at session start. This script speaks the
MCP stdio protocol directly, so a server can be checked (or used from a shell)
right away:

    python3 .claude/bin/mcp_probe.py                      # initialize + list tools of every server
    python3 .claude/bin/mcp_probe.py dart marionette      # only these servers
    python3 .claude/bin/mcp_probe.py marionette --call connect '{"uri": "ws://127.0.0.1:<PORT>/<TOKEN>=/ws"}' \
                               --call take_screenshots '{}'

Each `--call NAME JSON` runs in order on the same server session; image
results are saved as PNGs under build/. Exit code 1 if any server failed.
No dependencies beyond the standard library (Python 3.8+, POSIX select()).
"""
from __future__ import annotations

import json
import os
import select
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
PROTOCOL = "2025-06-18"


class Server:
    def __init__(self, name: str, spec: dict):
        env = {**os.environ, **spec.get("env", {}), "CLAUDE_PROJECT_DIR": str(ROOT)}
        self.name = name
        # stderr goes to a temp file, not a pipe: chatty servers (npx installs,
        # debug logs) would otherwise fill the pipe buffer and hang.
        self.err = tempfile.TemporaryFile(mode="w+")
        self.proc = subprocess.Popen(
            [spec["command"], *spec.get("args", [])],
            cwd=ROOT, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=self.err, text=True, bufsize=1,
        )
        self._id = 0

    def _send(self, payload: dict) -> None:
        self.proc.stdin.write(json.dumps(payload) + "\n")
        self.proc.stdin.flush()

    def request(self, method: str, params: dict | None = None, timeout: float = 120) -> dict:
        self._id += 1
        rid = self._id
        self._send({"jsonrpc": "2.0", "id": rid, "method": method, "params": params or {}})
        deadline = time.time() + timeout
        while time.time() < deadline:
            ready, _, _ = select.select([self.proc.stdout], [], [], 1)
            if not ready:
                if self.proc.poll() is not None:
                    raise RuntimeError(f"{self.name} exited: {self.stderr_tail()}")
                continue
            line = self.proc.stdout.readline()
            if line == "":  # EOF: the server closed stdout (usually it died)
                self.proc.wait(timeout=5)
                raise RuntimeError(f"{self.name} exited ({self.proc.returncode}): {self.stderr_tail()}")
            if not line.strip():
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue  # a server logging to stdout
            if msg.get("id") == rid:
                if "error" in msg:
                    raise RuntimeError(f"{method}: {msg['error']}")
                return msg["result"]
        raise TimeoutError(f"{self.name}: no answer to {method} in {timeout}s. stderr: {self.stderr_tail(800)}")

    def stderr_tail(self, n: int = 2000) -> str:
        self.err.flush()
        self.err.seek(0)
        return self.err.read()[-n:]

    def start(self) -> dict:
        info = self.request("initialize", {
            "protocolVersion": PROTOCOL, "capabilities": {},
            "clientInfo": {"name": "flutter-kit-mcp-probe", "version": "1"},
        }, timeout=180)
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        return info

    def close(self) -> None:
        try:
            self.proc.stdin.close()
            self.proc.terminate()
            self.proc.wait(timeout=5)
        except Exception:
            self.proc.kill()
        finally:
            self.err.close()


def main() -> int:
    args = sys.argv[1:]
    calls: list[tuple[str, dict]] = []
    names: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--call":
            calls.append((args[i + 1], json.loads(args[i + 2])))
            i += 3
        else:
            names.append(args[i])
            i += 1
    servers = json.loads((ROOT / ".mcp.json").read_text())["mcpServers"]
    failures = 0
    for name in names or list(servers):
        if name not in servers:
            print(f"FAIL {name:16} not in .mcp.json")
            failures += 1
            continue
        server = Server(name, servers[name])
        try:
            info = server.start()
            tools = server.request("tools/list")["tools"]
            label = info.get("serverInfo", {}).get("name", "?")
            print(f"ok   {name:16} {label}: {len(tools)} tools — "
                  + ", ".join(t["name"] for t in tools[:25]))
            for tool, params in calls:
                result = server.request("tools/call", {"name": tool, "arguments": params}, timeout=600)
                for block in result.get("content", []):
                    if block.get("type") == "text":
                        print(block["text"][:4000])
                    elif block.get("type") == "image":
                        out = ROOT / "build" / f"mcp_{name}_{int(time.time())}.png"
                        out.parent.mkdir(exist_ok=True)
                        import base64
                        out.write_bytes(base64.b64decode(block["data"]))
                        print(f"[image saved to {out}]")
        except Exception as exc:  # noqa: BLE001 — report every server
            failures += 1
            print(f"FAIL {name:16} {exc}")
        finally:
            server.close()
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
