#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/codex/global/config.toml"
INSTRUCTIONS="$ROOT/codex/global/AGENTS.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

python3 - "$CONFIG" <<'PY' || fail "tracked Codex config has the wrong integration shape"
import pathlib
import sys
import tomllib

config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
servers = config["mcp_servers"]
graphify = servers["graphify"]
assert graphify["url"] == "http://127.0.0.1:8001/mcp"
assert graphify["bearer_token_env_var"] == "GRAPHIFY_API_KEY"
assert "codebase-memory-mcp" not in servers
assert "mempalace" not in servers
assert "SessionStart" not in config.get("hooks", {})

instructions = config["developer_instructions"]
assert "/root/hzx_mixlinker/jessy-skills" in instructions
assert "/root/.jessy-skills-codex/skills" in instructions
PY

grep -q 'Graphify' "$INSTRUCTIONS" || fail "global instructions do not name Graphify"
grep -q '\$mem0' "$INSTRUCTIONS" || fail "global instructions do not route to the mem0 skill"
grep -q 'mem0_client.py' "$INSTRUCTIONS" || fail "global instructions do not name the Mem0 REST helper"
grep -q 'Use only `gpt-5.6-luna` or `gpt-5.6-terra` for Codex subagents' "$INSTRUCTIONS" || fail "global instructions do not enforce Luna/Terra subagents"
grep -q 'Never use `gpt-5.6-sol` or DeepSeek for a subagent' "$INSTRUCTIONS" || fail "global instructions do not forbid Sol/DeepSeek subagents"

if grep -Eqi 'codebase-memory-mcp|mempalace' "$INSTRUCTIONS"; then
  fail "tracked global instructions still name a legacy integration"
fi
if grep -Eq '^\[mcp_servers\.(codebase-memory-mcp|mempalace)(\.|\])|Code discovery: prefer codebase-memory-mcp' "$CONFIG"; then
  fail "tracked global config still activates a legacy integration"
fi

[ -f "$ROOT/skills/mem0/SKILL.md" ] || fail "mem0 skill is missing"
[ -f "$ROOT/skills/mem0/scripts/mem0_client.py" ] || fail "mem0 REST helper is missing"
[ ! -e "$ROOT/skills/mempalace" ] || fail "legacy mempalace skill still exists"
if rg -qi 'codebase-memory-mcp|mempalace' "$ROOT/skills"; then
  fail "an active skill still names a legacy integration"
fi

echo "PASS: Codex Graphify and Mem0 snapshots"
