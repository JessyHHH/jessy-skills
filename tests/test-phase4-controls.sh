#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$ROOT/skills/implementing-changes/scripts/phase4_guard.py"
TEST_ROOT="$(mktemp -d)"
REPO="$TEST_ROOT/repo"
WORKTREE="$TEST_ROOT/task-worktree"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -x "$GUARD" ] || fail "phase4 guard is missing or not executable"

PLAN="$TEST_ROOT/plan.md"
cat >"$PLAN" <<'EOF'
# Test Plan

```json:tasks
[
  {
    "id": "T1-core",
    "prompt": "Change the allowed file.",
    "files": ["allowed.txt"],
    "readFiles": ["input.txt"],
    "resources": ["service:a"],
    "dependsOn": [],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f allowed.txt"],
    "expectedEvidence": ["allowed file exists"],
    "forbiddenEvidence": ["no other file changes"],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T2-independent",
    "prompt": "Change an independent file.",
    "files": ["independent.txt"],
    "readFiles": [],
    "resources": ["service:b"],
    "dependsOn": [],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f independent.txt"],
    "expectedEvidence": ["independent file exists"],
    "forbiddenEvidence": ["no other file changes"],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T4-independent",
    "prompt": "Change another independent file.",
    "files": ["another.txt"],
    "readFiles": [],
    "resources": ["service:d"],
    "dependsOn": [],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f another.txt"],
    "expectedEvidence": ["another file exists"],
    "forbiddenEvidence": ["no other file changes"],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T3-dependent",
    "prompt": "Consume the first task.",
    "files": ["dependent.txt"],
    "readFiles": ["allowed.txt"],
    "resources": ["service:c"],
    "dependsOn": ["T1-core"],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f dependent.txt"],
    "expectedEvidence": ["dependent file exists"],
    "forbiddenEvidence": ["no other file changes"],
    "patchBackStrategy": "harness-managed"
  }
]
```
EOF

python3 "$GUARD" validate-plan "$PLAN" >"$TEST_ROOT/validate.json"
python3 - "$TEST_ROOT/validate.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["valid"] is True
assert data["taskCount"] == 4
PY

python3 "$GUARD" schedule "$PLAN" >"$TEST_ROOT/schedule.json"
python3 - "$TEST_ROOT/schedule.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["writerLimit"] == 3
assert data["integration"] == "serial"
assert data["waves"] == [["T1-core", "T2-independent", "T4-independent"], ["T3-dependent"]]
PY

CONFLICT_PLAN="$TEST_ROOT/conflict-plan.md"
cat >"$CONFLICT_PLAN" <<'EOF'
# Conflict Plan

```json:tasks
[
  {
    "id": "T1-producer",
    "prompt": "Produce shared input.",
    "files": ["shared.txt"],
    "readFiles": [],
    "resources": ["service:shared"],
    "dependsOn": [],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f shared.txt"],
    "expectedEvidence": ["shared input exists"],
    "forbiddenEvidence": ["no other changes"],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T2-resource-conflict",
    "prompt": "Use the same external service.",
    "files": ["resource.txt"],
    "readFiles": [],
    "resources": ["service:shared"],
    "dependsOn": [],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f resource.txt"],
    "expectedEvidence": ["resource output exists"],
    "forbiddenEvidence": ["no other changes"],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T3-read-conflict",
    "prompt": "Read the producer output.",
    "files": ["consumer.txt"],
    "readFiles": ["shared.txt"],
    "resources": ["service:other"],
    "dependsOn": [],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f consumer.txt"],
    "expectedEvidence": ["consumer output exists"],
    "forbiddenEvidence": ["no other changes"],
    "patchBackStrategy": "harness-managed"
  }
]
```
EOF

python3 "$GUARD" schedule "$CONFLICT_PLAN" >"$TEST_ROOT/conflict-schedule.json"
python3 - "$TEST_ROOT/conflict-schedule.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["waves"] == [["T1-producer"], ["T2-resource-conflict", "T3-read-conflict"]]
PY

NO_ISOLATION_PLAN="$TEST_ROOT/no-isolation-plan.md"
python3 - "$PLAN" "$NO_ISOLATION_PLAN" <<'PY'
import json
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
tasks = json.loads(re.search(r"```json:tasks\s*(\[.*?\])\s*```", text, re.S).group(1))
writer = tasks[0]
writer["patchBackStrategy"] = "no-isolation"
reader = {
    "id": "T4-reader",
    "prompt": "Read an independent input.",
    "files": [],
    "readFiles": ["other.txt"],
    "resources": ["service:reader"],
    "dependsOn": [],
    "complexity": "simple",
    "mutatesFiles": False,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": ["test -f other.txt"],
    "expectedEvidence": ["reader reports evidence"],
    "forbiddenEvidence": ["no file modifications"]
}
with open(sys.argv[2], "w", encoding="utf-8") as output:
    output.write("# No Isolation Plan\n\n```json:tasks\n")
    json.dump([writer, reader], output)
    output.write("\n```\n")
PY

python3 "$GUARD" schedule "$NO_ISOLATION_PLAN" >"$TEST_ROOT/no-isolation-schedule.json"
python3 - "$TEST_ROOT/no-isolation-schedule.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["waves"] == [["T1-core"], ["T4-reader"]]
PY

INVALID_PLAN="$TEST_ROOT/invalid-plan.md"
sed '/"acceptanceCommands"/s/\["test -f allowed.txt"\]/[]/' "$PLAN" >"$INVALID_PLAN"
if python3 "$GUARD" validate-plan "$INVALID_PLAN" >"$TEST_ROOT/invalid.json"; then
  fail "plan without an acceptance command passed validation"
fi
grep -q 'acceptanceCommands' "$TEST_ROOT/invalid.json" || fail "invalid plan did not explain the missing command"

git init -q "$REPO"
git -C "$REPO" config user.name "Phase4 Test"
git -C "$REPO" config user.email "phase4@example.invalid"
printf 'base\n' >"$REPO/allowed.txt"
printf 'input\n' >"$REPO/input.txt"
git -C "$REPO" add allowed.txt input.txt
git -C "$REPO" commit -qm base
BASE="$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" worktree add -q -b phase4-test "$WORKTREE" "$BASE"

printf 'allowed change\n' >>"$WORKTREE/allowed.txt"
python3 "$GUARD" check-scope "$PLAN" T1-core --worktree "$WORKTREE" --base "$BASE" >"$TEST_ROOT/scope-pass.json"
grep -q '"status": "PASS"' "$TEST_ROOT/scope-pass.json" || fail "allowed change failed the scope gate"

printf 'unexpected\n' >"$WORKTREE/outside.txt"
if python3 "$GUARD" check-scope "$PLAN" T1-core --worktree "$WORKTREE" --base "$BASE" >"$TEST_ROOT/scope-fail.json"; then
  fail "out-of-scope change passed the scope gate"
fi
grep -q '"status": "BOUNDARY_VIOLATION"' "$TEST_ROOT/scope-fail.json" || fail "scope violation status missing"
grep -q 'outside.txt' "$TEST_ROOT/scope-fail.json" || fail "scope violation omitted unexpected file"

rm "$WORKTREE/outside.txt"
python3 "$GUARD" check-plan-scope "$PLAN" --worktree "$WORKTREE" --base "$BASE" >"$TEST_ROOT/plan-scope.json"
grep -q '"status": "PASS"' "$TEST_ROOT/plan-scope.json" || fail "combined plan scope rejected an allowed change"

echo "PASS: Phase 4 contract, scheduling, and worktree scope controls verified"
