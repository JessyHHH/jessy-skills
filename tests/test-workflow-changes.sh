#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "PASS: $1"
}

[ -f "$ROOT/AGENTS.md" ] || fail "AGENTS.md missing"
[ ! -f "$ROOT/CLAUDE.md" ] || fail "CLAUDE.md should not exist on Codex-only branch"
[ ! -d "$ROOT/.claude" ] || fail ".claude should not exist on Codex-only branch"
[ ! -d "$ROOT/skills/project-workflow-claude" ] || fail "project-workflow-claude should not exist"
[ ! -d "$ROOT/skills/project-workflow" ] || fail "project-workflow should not exist"
[ ! -f "$ROOT/codex/README.md" ] || fail "codex/README.md should be merged into root README"

grep -q "Codex-only" "$ROOT/README.md" || fail "README lacks Codex-only notice"
grep -q "Codex-only" "$ROOT/SETUP.md" || fail "SETUP lacks Codex-only notice"
grep -q "Codex-only" "$ROOT/AGENTS.md" || fail "AGENTS lacks Codex-only notice"

grep -q 'CODEX_SYNC_HOME="$HOME/.jessy-skills-codex"' "$ROOT/install.sh" || fail "install.sh missing Codex snapshot"
grep -q 'CODEX_DISCOVERY_SKILLS=' "$ROOT/install.sh" || fail "install.sh missing curated discovery"
grep -q '"project-workflow-codex"' "$ROOT/install.sh" || fail "install.sh missing project-workflow-codex discovery"
grep -q '"karpathy-guidelines"' "$ROOT/install.sh" || fail "install.sh missing karpathy-guidelines discovery"
grep -q 'codex/agents' "$ROOT/install.sh" || fail "install.sh does not install Codex agents"

if grep -q 'CLAUDE_SYNC_HOME\|~/.claude\|~/.hermes\|hermes.sh' "$ROOT/install.sh"; then
  fail "install.sh still contains Claude/Hermes install behavior"
fi

for skill in \
  project-workflow-codex \
  detecting-environment \
  designing-solutions \
  planning-implementation \
  implementing-changes \
  reviewing-implementation \
  verifying-completion \
  finishing-development; do
  file="$ROOT/skills/$skill/SKILL.md"
  [ -f "$file" ] || fail "missing $skill"
  grep -q '^name:' "$file" || fail "$skill missing name"
  grep -q '^description:' "$file" || fail "$skill missing description"
  if sed -n '1,/^---$/p' "$file" | tail -n +2 | grep -Eq '^(version|metadata|author|triggers|license):'; then
    fail "$skill frontmatter contains non skill-creator fields"
  fi
done

grep -q 'detecting-environment' "$ROOT/skills/project-workflow-codex/SKILL.md" || fail "orchestrator missing detecting-environment"
grep -q 'finishing-development' "$ROOT/skills/project-workflow-codex/SKILL.md" || fail "orchestrator missing finishing-development"
grep -q '/agent' "$ROOT/skills/project-workflow-codex/SKILL.md" || fail "orchestrator missing /agent supervision"

for f in \
  "$ROOT/skills/grill-me/scripts/decision_tree_extractor.py" \
  "$ROOT/skills/grill-me/scripts/question_generator.py" \
  "$ROOT/skills/grill-me/scripts/grill_session_tracker.py" \
  "$ROOT/skills/sync-ccswitch-config-codex/scripts/sync_config.py"; do
  [ -f "$f" ] || fail "missing script $f"
done

pass "Codex-only workflow structure verified"
