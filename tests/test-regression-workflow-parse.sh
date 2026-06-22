#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if find "$ROOT/.claude" -type f 2>/dev/null | grep -q .; then
  fail ".claude workflow files should not exist on the Codex-only branch"
fi

if find "$ROOT" -path '*/.claude/workflows/*.js' -type f 2>/dev/null | grep -q .; then
  fail "Claude Workflow JS scripts should not exist on the Codex-only branch"
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
  [ -f "$ROOT/skills/$skill/SKILL.md" ] || fail "missing skill: $skill"
done

echo "PASS: Codex-only workflow has no Claude Workflow JS scripts"
