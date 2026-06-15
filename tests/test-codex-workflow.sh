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
grep -q 'Codex subagents' "$SKILL" || fail "Codex subagents marker missing"
grep -q 'Do not invoke Claude Code Workflow scripts' "$SKILL" || fail "Claude Workflow prohibition missing"
grep -qi 'spawn Codex subagents' "$SKILL" || fail "subagent execution phase missing"
grep -q 'project-workflow-codex' "$ROOT/AGENTS.md" || fail "AGENTS.md does not mention Codex workflow"
grep -q 'HAS_CODEX' "$ROOT/install.sh" || fail "install.sh does not detect Codex"
grep -q 'CODEX_SYNC_HOME="$HOME/.jessy-skills-codex"' "$ROOT/install.sh" || fail "install.sh does not define Codex snapshot"
grep -q 'CLAUDE_SYNC_HOME="$HOME/.jessy-skills-claude"' "$ROOT/install.sh" || fail "install.sh does not define Claude snapshot"
grep -q 'sync_repo_snapshot "$CODEX_SYNC_HOME"' "$ROOT/install.sh" || fail "install.sh does not sync Codex snapshot"
grep -q 'sync_repo_snapshot "$CLAUDE_SYNC_HOME"' "$ROOT/install.sh" || fail "install.sh does not sync Claude snapshot"
grep -q 'CODEX_DISCOVERY_SKILLS=' "$ROOT/install.sh" || fail "install.sh does not define curated Codex discovery skills"
grep -q '"project-workflow-codex"' "$ROOT/install.sh" || fail "install.sh does not expose project-workflow-codex to Codex discovery"
grep -q '"karpathy-guidelines"' "$ROOT/install.sh" || fail "install.sh does not expose karpathy-guidelines to Codex discovery"
grep -q 'CODEX_DISCOVERY_HOME="$CODEX_SYNC_HOME/codex/skill-discovery"' "$ROOT/install.sh" || fail "install.sh does not define Codex discovery home"
grep -q 'ln -sfn "$CODEX_DISCOVERY_HOME" "$HOME/.agents/skills/jessy-skills"' "$ROOT/install.sh" || fail "install.sh does not link Codex from curated discovery"
if grep -q 'ln -sfn "$CODEX_SYNC_HOME/skills" "$HOME/.agents/skills/jessy-skills"' "$ROOT/install.sh"; then
  fail "install.sh still links all skills into Codex startup discovery"
fi
grep -q 'Skill Discovery Budget' "$SKILL" || fail "project-workflow-codex does not document Codex skill discovery budget"
grep -q '~/.jessy-skills-codex/skills/<skill>/SKILL.md' "$SKILL" || fail "project-workflow-codex does not document explicit domain skill loading"
grep -q 'Codex Subagent Execution' "$SKILL" || fail "project-workflow-codex does not name Phase 4 as subagent execution"
grep -q 'Runtime watchdog' "$SKILL" || fail "project-workflow-codex does not document Phase 4 watchdog"
grep -q 'Prefer parallel subagents for read-heavy work' "$SKILL" || fail "project-workflow-codex does not prefer read-heavy subagents"
grep -q 'Default to one writer subagent' "$SKILL" || fail "project-workflow-codex does not limit writer subagents"
grep -q 'BLOCKED_AGENT' "$SKILL" || fail "project-workflow-codex does not define blocked subagent evidence"
grep -q 'Codex Subagent Execution' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference does not document subagents"
grep -q 'First update window' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference lacks first update window"
grep -q 'Subagent Execution Map' "$ROOT/skills/project-workflow-codex/references/contract-template.md" || fail "contract template does not name subagent execution map"
grep -q 'Codex subagent workflow' "$ROOT/skills/project-workflow-codex/agents/openai.yaml" || fail "openai.yaml does not describe subagent workflow"
grep -q 'model = "gpt-5.3-codex"' "$ROOT/codex/agents/executor.toml" || fail "executor agent model is not gpt-5.3-codex"
grep -q 'model = "gpt-5.3-codex"' "$ROOT/codex/agents/worker.toml" || fail "worker agent model is not gpt-5.3-codex"
grep -q 'model = "gpt-5.3-codex"' "$ROOT/codex/agents/test-engineer.toml" || fail "test-engineer agent model is not gpt-5.3-codex"
grep -q 'model = "gpt-5.3-codex"' "$ROOT/codex/agents/build-fixer.toml" || fail "build-fixer agent model is not gpt-5.3-codex"
grep -q 'model = "gpt-5.3-codex"' "$ROOT/codex/agents/debugger.toml" || fail "debugger agent model is not gpt-5.3-codex"
grep -q 'model = "gpt-5.4-mini"' "$ROOT/codex/agents/code-reviewer.toml" || fail "code-reviewer agent model is not gpt-5.4-mini"
grep -q 'model = "gpt-5.4-mini"' "$ROOT/codex/agents/verifier.toml" || fail "verifier agent model is not gpt-5.4-mini"
python3 - "$SKILL" <<'PY' || fail "project-workflow-codex description exceeds 180 characters"
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
match = re.search(r"^description:\s*['\"]?(.*?)['\"]?$", text, re.MULTILINE)
if not match:
    raise SystemExit(1)
raise SystemExit(0 if len(match.group(1)) <= 180 else 1)
PY

echo "PASS: Codex workflow structure verified"
