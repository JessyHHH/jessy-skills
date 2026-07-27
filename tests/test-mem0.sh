#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export MEM0_TEST_ROOT="$ROOT"

python3 - <<'PY'
import json
import os
import socket
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


root = Path(os.environ["MEM0_TEST_ROOT"])
client = root / "skills/mem0/scripts/mem0_client.py"
skill = root / "skills/mem0/SKILL.md"
agent = root / "skills/mem0/agents/openai.yaml"
requests = []


class Handler(BaseHTTPRequestHandler):
    def _handle(self):
        parsed = urlsplit(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length) if length else b""
        body = json.loads(raw_body) if raw_body else None
        requests.append(
            {
                "method": self.command,
                "path": parsed.path,
                "query": parse_qs(parsed.query),
                "headers": {key.lower(): value for key, value in self.headers.items()},
                "body": body,
            }
        )

        if self.headers.get("X-API-Key") != "test-secret":
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"detail":"unauthorized"}')
            return

        if parsed.path == "/memories/broken-json":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b"not json")
            return

        response = {
            "ok": True,
            "method": self.command,
            "path": parsed.path,
        }
        payload = json.dumps(response).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    do_GET = _handle
    do_POST = _handle
    do_PUT = _handle
    do_DELETE = _handle

    def log_message(self, _format, *_args):
        pass


def run_client(base_url, *args, api_key="test-secret"):
    env = os.environ.copy()
    env["MEM0_BASE_URL"] = base_url
    if api_key is None:
        env.pop("MEM0_API_KEY", None)
    else:
        env["MEM0_API_KEY"] = api_key
    return subprocess.run(
        [sys.executable, str(client), *args],
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )


def expect_success(base_url, *args):
    result = run_client(base_url, *args)
    assert result.returncode == 0, (args, result.stderr)
    assert result.stderr == "", (args, result.stderr)
    value = json.loads(result.stdout)
    assert isinstance(value, dict) and value["ok"] is True, (args, value)
    assert result.stdout.count("\n") == 1, (args, result.stdout)
    return requests[-1]


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
base_url = f"http://127.0.0.1:{server.server_port}"

try:
    assert client.is_file(), f"missing client: {client}"

    request = expect_success(base_url, "status")
    assert (request["method"], request["path"], request["query"]) == (
        "GET",
        "/memories",
        {"user_id": ["codex"], "top_k": ["0"]},
    )

    request = expect_success(
        base_url,
        "add",
        "durable fact",
        "--metadata",
        '{"project":"jessy"}',
    )
    assert request["method"] == "POST" and request["path"] == "/memories"
    assert request["body"] == {
        "messages": [{"role": "user", "content": "durable fact"}],
        "user_id": "codex",
        "metadata": {"project": "jessy"},
    }

    request = expect_success(
        base_url,
        "add",
        "scoped fact",
        "--agent-id",
        "planner",
        "--run-id",
        "run-7",
    )
    assert request["body"] == {
        "messages": [{"role": "user", "content": "scoped fact"}],
        "agent_id": "planner",
        "run_id": "run-7",
    }

    request = expect_success(
        base_url,
        "search",
        "what worked",
        "--top-k",
        "4",
        "--threshold",
        "0.65",
    )
    assert request["method"] == "POST" and request["path"] == "/search"
    assert request["body"] == {
        "query": "what worked",
        "filters": {"user_id": "codex"},
        "top_k": 4,
        "threshold": 0.65,
    }

    request = expect_success(base_url, "list", "--user-id", "alice", "--top-k", "8")
    assert (request["method"], request["path"], request["query"]) == (
        "GET",
        "/memories",
        {"user_id": ["alice"], "top_k": ["8"]},
    )

    request = expect_success(base_url, "get", "memory/id")
    assert request["method"] == "GET" and request["path"] == "/memories/memory%2Fid"

    request = expect_success(
        base_url,
        "update",
        "memory-1",
        "revised fact",
        "--metadata",
        '{"source":"review"}',
    )
    assert request["method"] == "PUT" and request["path"] == "/memories/memory-1"
    assert request["body"] == {
        "text": "revised fact",
        "metadata": {"source": "review"},
    }

    request = expect_success(base_url, "delete", "memory-1")
    assert request["method"] == "DELETE" and request["path"] == "/memories/memory-1"
    assert request["body"] is None

    for request in requests:
        assert request["headers"].get("x-api-key") == "test-secret", request
        assert request["headers"].get("accept") == "application/json", request
        if request["body"] is not None:
            assert request["headers"].get("content-type") == "application/json", request

    result = run_client(base_url, "status", api_key=None)
    assert result.returncode == 1 and result.stdout == ""
    assert result.stderr.startswith("mem0: ") and "MEM0_API_KEY" in result.stderr
    assert "Traceback" not in result.stderr

    result = run_client(base_url, "status", api_key="wrong-secret")
    assert result.returncode == 1 and result.stdout == ""
    assert result.stderr.startswith("mem0: ") and "401" in result.stderr
    assert "Traceback" not in result.stderr

    result = run_client(base_url, "add", "fact", "--metadata", "[]")
    assert result.returncode == 1 and result.stdout == ""
    assert result.stderr.startswith("mem0: ") and "metadata" in result.stderr.lower()
    assert "Traceback" not in result.stderr

    result = run_client(base_url, "get", "broken-json")
    assert result.returncode == 1 and result.stdout == ""
    assert result.stderr.startswith("mem0: ") and "json" in result.stderr.lower()
    assert "Traceback" not in result.stderr

    unused = socket.socket()
    unused.bind(("127.0.0.1", 0))
    unavailable_url = f"http://127.0.0.1:{unused.getsockname()[1]}"
    result = run_client(unavailable_url, "status")
    unused.close()
    assert result.returncode == 1 and result.stdout == ""
    assert result.stderr.startswith("mem0: ") and "Traceback" not in result.stderr

    assert skill.is_file(), f"missing skill: {skill}"
    text = skill.read_text()
    parts = text.split("---", 2)
    assert len(parts) == 3 and parts[0] == "", "SKILL.md must have YAML frontmatter"
    keys = [line.split(":", 1)[0].strip() for line in parts[1].splitlines() if ":" in line]
    assert keys == ["name", "description"], f"unexpected frontmatter keys: {keys}"
    assert "name: mem0" in parts[1]
    for phrase in (
        "MEM0_API_KEY",
        "mem0_client.py",
        "$HOME/.agents/skills/jessy-skills/mem0/scripts/mem0_client.py",
        "user_id=codex",
        "search before",
        "durable",
        "credentials",
        "verify",
    ):
        assert phrase.lower() in text.lower(), f"SKILL.md missing guidance: {phrase}"

    assert agent.is_file(), f"missing agent metadata: {agent}"
    agent_text = agent.read_text().lower()
    assert "rest" in agent_text and "mcp" in agent_text and "no mcp" in agent_text
    assert not (root / "skills/mempalace").exists(), "legacy skills/mempalace still exists"
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)

print("PASS: Mem0 REST skill and client")
PY
