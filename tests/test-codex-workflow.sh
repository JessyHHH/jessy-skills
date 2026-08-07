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
[ ! -f "$ROOT/CLAUDE.md" ] || fail "CLAUDE.md should not exist"
[ ! -d "$ROOT/.claude" ] || fail ".claude should not exist"
[ ! -d "$ROOT/skills/project-workflow-claude" ] || fail "project-workflow-claude should not exist"
[ ! -d "$ROOT/skills/project-workflow" ] || fail "project-workflow should not exist"

grep -q '^name: project-workflow-codex$' "$SKILL" || fail "skill name missing"
grep -q 'Codex subagents' "$SKILL" || fail "Codex subagents marker missing"
grep -q 'Do not use Claude Code `Workflow' "$SKILL" || fail "Claude Workflow prohibition missing"
grep -qi 'spawn Codex subagents' "$SKILL" || fail "subagent execution phase missing"
grep -q 'project-workflow-codex' "$ROOT/AGENTS.md" || fail "AGENTS.md does not mention Codex workflow"
grep -q 'HAS_CODEX' "$ROOT/install.sh" || fail "install.sh does not detect Codex"
grep -q 'CODEX_SYNC_HOME="$HOME/.jessy-skills-codex"' "$ROOT/install.sh" || fail "install.sh does not define Codex snapshot"
grep -q 'sync_repo_snapshot "$CODEX_SYNC_HOME"' "$ROOT/install.sh" || fail "install.sh does not sync Codex snapshot"
if grep -q 'CLAUDE_SYNC_HOME\|~/.claude\|~/.hermes\|hermes.sh' "$ROOT/install.sh"; then
  fail "install.sh still contains Claude/Hermes install behavior"
fi
grep -q 'ln -sfn "$CODEX_SYNC_HOME/skills" "$HOME/.agents/skills/jessy-skills"' "$ROOT/install.sh" || fail "install.sh does not link all Codex skills"
if grep -q 'CODEX_DISCOVERY_SKILLS=\|codex/skill-discovery' "$ROOT/install.sh"; then
  fail "install.sh still uses curated Codex discovery"
fi
grep -q 'Skill Discovery' "$SKILL" || fail "project-workflow-codex does not document Codex skill discovery"
grep -q '~/.agents/skills/jessy-skills -> ~/.jessy-skills-codex/skills' "$SKILL" || fail "project-workflow-codex does not document full skill symlink"
grep -q 'Use Codex subagents deliberately' "$SKILL" || fail "project-workflow-codex does not document subagent execution"
grep -q '/agent' "$SKILL" || fail "project-workflow-codex does not document /agent supervision"
grep -q 'Prefer parallel subagents for read-heavy work' "$SKILL" || fail "project-workflow-codex does not prefer read-heavy subagents"
grep -q 'parallel writers only when file sets are disjoint' "$SKILL" || fail "project-workflow-codex does not limit writer subagents"
grep -q 'BLOCKED_AGENT' "$SKILL" || fail "project-workflow-codex does not define blocked subagent evidence"
grep -q 'Codex Subagent Execution' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference does not document subagents"
grep -q 'direct-phase4 writer' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference lacks direct Phase 4 writers"
grep -q 'fork_turns="none"' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference lacks task-local context isolation"
grep -q 'same dependency/resource wave' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference lacks plan-driven writer concurrency"
grep -q 'one fresh read-only reviewer' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference lacks focused diff review"
grep -q 'BOUNDARY_BLOCKED' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference lacks hard boundary stop"
grep -q 'phase4_guard.py check-scope' "$ROOT/skills/implementing-changes/SKILL.md" || fail "implementing-changes does not invoke the scope guard"
grep -q 'phase4_guard.py check-plan-scope' "$ROOT/skills/implementing-changes/SKILL.md" || fail "implementing-changes does not invoke the combined scope guard"
if rg -qi 'superpowers?' "$ROOT/skills/project-workflow-codex"; then
  fail "project-workflow-codex should not mention Superpowers"
fi
if rg -q 'controlled-phase4 planning turn|APPROVE_EXECUTION|planning-only first' "$ROOT/skills/implementing-changes" "$ROOT/skills/project-workflow-codex/references/agent-execution.md"; then
  fail "Phase 4 still contains the removed two-turn writer protocol"
fi
grep -q 'phase4-execution-results.json' "$ROOT/skills/reviewing-implementation/SKILL.md" || fail "reviewing-implementation does not consume Phase 4 execution evidence"
grep -q 'Subagent Execution Map' "$ROOT/skills/project-workflow-codex/references/contract-template.md" || fail "contract template does not name subagent execution map"
grep -q 'Codex subagent workflow' "$ROOT/skills/project-workflow-codex/agents/openai.yaml" || fail "openai.yaml does not describe subagent workflow"
for agent in executor worker explorer code-reviewer verifier; do
  grep -q 'model = "gpt-5.6-luna"' "$ROOT/codex/agents/$agent.toml" || fail "$agent agent model is not gpt-5.6-luna"
done
for agent in test-engineer build-fixer debugger; do
  grep -q 'model = "gpt-5.6-terra"' "$ROOT/codex/agents/$agent.toml" || fail "$agent agent model is not gpt-5.6-terra"
done
if rg -q 'model = "(gpt-5\.6-sol|deepseek-v4)' "$ROOT/codex/agents"; then
  fail "an agent template still selects a forbidden Sol or DeepSeek model"
fi
grep -q 'Never dispatch' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference does not forbid subagent models"
grep -q '`gpt-5.6-sol` or a DeepSeek model' "$ROOT/skills/project-workflow-codex/references/agent-execution.md" || fail "agent execution reference does not forbid Sol/DeepSeek subagents"
for agent in executor worker test-engineer build-fixer debugger explorer code-reviewer verifier; do
  grep -q 'model_reasoning_effort = "max"' "$ROOT/codex/agents/$agent.toml" || fail "$agent agent reasoning effort is not max"
done
for agent in executor worker test-engineer; do
  grep -q 'BOUNDARY_BLOCKED' "$ROOT/codex/agents/$agent.toml" || fail "$agent does not stop at task boundaries"
  if rg -q 'PLAN_READY|APPROVE_EXECUTION|full diff' "$ROOT/codex/agents/$agent.toml"; then
    fail "$agent still contains the removed heavyweight Phase 4 protocol"
  fi
done
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
