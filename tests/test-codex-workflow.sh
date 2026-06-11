#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/project-workflow-codex/SKILL.md"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -f "$ROOT/AGENTS.md" ] || fail "AGENTS.md missing"
[ -f "$SKILL" ] || fail "project-workflow-codex SKILL.md missing"
[ -f "$ROOT/skills/project-workflow-codex/agents/openai.yaml" ] || fail "openai.yaml missing"
[ -f "$ROOT/skills/project-workflow-codex/references/agent-execution.md" ] || fail "agent execution reference missing"
[ -f "$ROOT/skills/project-workflow-codex/references/contract-template.md" ] || fail "contract template missing"
[ -f "$ROOT/skills/project-workflow-codex/references/validation.md" ] || fail "validation reference missing"

grep -q '^name: project-workflow-codex$' "$SKILL" || fail "skill name missing"
grep -q 'Codex agents' "$SKILL" || fail "Codex agents marker missing"
grep -q 'Do not invoke Claude Code Workflow scripts' "$SKILL" || fail "Claude Workflow prohibition missing"
grep -qi 'spawn Codex agents' "$SKILL" || fail "agent execution phase missing"
grep -q 'project-workflow-codex' "$ROOT/AGENTS.md" || fail "AGENTS.md does not mention Codex workflow"
grep -q 'HAS_CODEX' "$ROOT/install.sh" || fail "install.sh does not detect Codex"
grep -q 'CODEX_SYNC_HOME="$HOME/.jessy-skills-codex"' "$ROOT/install.sh" || fail "install.sh does not define Codex snapshot"
grep -q 'CLAUDE_SYNC_HOME="$HOME/.jessy-skills-claude"' "$ROOT/install.sh" || fail "install.sh does not define Claude snapshot"
grep -q 'sync_repo_snapshot "$CODEX_SYNC_HOME"' "$ROOT/install.sh" || fail "install.sh does not sync Codex snapshot"
grep -q 'sync_repo_snapshot "$CLAUDE_SYNC_HOME"' "$ROOT/install.sh" || fail "install.sh does not sync Claude snapshot"
grep -q 'ln -sfn "$CODEX_SYNC_HOME/skills" "$HOME/.agents/skills/jessy-skills"' "$ROOT/install.sh" || fail "install.sh does not link Codex from snapshot"

echo "PASS: Codex workflow structure verified"
