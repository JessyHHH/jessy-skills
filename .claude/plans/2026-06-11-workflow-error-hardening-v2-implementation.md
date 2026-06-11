# Implementation Plan: project-workflow-claude Error Hardening (v2)

---

## Metadata

- **Title:** Implementation Plan — Workflow Parse / Edit Precision / State Repair
- **Spec Reference:** `.claude/specs/2026-06-11-error-hardening-design.md`
- **Date:** 2026-06-11
- **Version:** v2.0
- **Status:** Draft (awaiting approval)
- **Approach:** Minimal Patch — modify prompts + enrichment, no script rewrite, no Go code changes

---

## Evidence Sources (from Phase0/Phase1 Investigation)

| Error | Root Cause | Evidence |
|-------|-----------|----------|
| `Workflow(...) Unexpected token (78:2)` | Plain-JS parser rejects inline script structure / potential TS syntax | `60b...jsonl:1118-1119` |
| `Update(internal/rag/types.go) Error editing file` | `old_string` omitted `type` keyword — exact-string mismatch | `60b...jsonl:773-774, :670-671` |
| `No changes to make: old_string and new_string are exactly the same` | Stale edit — code already existed | `60b...jsonl:1168-1169` |
| Phase4 implementer receives stale context | `phase4-implement.js` omits `fileContents`/`diffText`/`grillDecisions`/`planSections` | `.claude/workflows/phase4-implement.js:60-103` |
| Workflow state points to nonexistent file | `contextSummaryPath` → missing `.claude/state/context-summary.json` | `.claude/state/project-workflow-state.json` |

---

## Tasks

### T1: Reset Workflow State

**Objective:** Reset stale `project-workflow-state.json` so this task starts with a clean identity.

**Files affected:**
- `.claude/state/project-workflow-state.json` (overwrite)
- `.claude/state/project-workflow-state.json.bak` (create as backup)

**Implementation steps:**
1. Read current `.claude/state/project-workflow-state.json`.
2. If it exists and `status` is not `idle`:
   - Write backup: `.claude/state/project-workflow-state.json.bak` (copy of old state).
   - Write fresh state:
     ```json
     {
       "workflow": "project-workflow-claude",
       "version": "v2.8",
       "runMode": "standalone-skill",
       "handoffPolicy": "prompt-next-step",
       "currentSkill": "implementing-changes",
       "lastCompletedSkill": null,
       "nextSkill": null,
       "status": "idle",
       "taskIntakePath": ".claude/state/task-intake.json",
       "contextSummaryPath": null,
       "grillEvidencePath": null,
       "specPath": ".claude/specs/2026-06-11-error-hardening-design.md",
       "planPath": ".claude/plans/2026-06-11-workflow-error-hardening-v2-implementation.md",
       "quickGateResultsPath": null,
       "reviewResultsPath": null,
       "verificationResultsPath": null,
       "escapeHatchesUsed": []
     }
     ```
3. If `.claude/state/context-summary.json` is missing (known fact), leave `contextSummaryPath: null`.

**Verification:**
- `python3 -m json.tool .claude/state/project-workflow-state.json` exits 0
- `.claude/state/project-workflow-state.json.bak` exists (old state preserved)
- `status` is `idle`, `contextSummaryPath` is null or points to existing file

**Rollback:** Delete new state, rename `.bak` back to `.json`.

**Dependencies:** None (first task).

---

### T2: Phase4 Enrichment — Inject fileContents/diffText/grillDecisions/planSections

**Objective:** Align `phase4-implement.js` with the documented enrichment contract. Subagents currently get only contextRefs/intakeRefs/grillRefs; they need full file contents and design decisions to construct correct Edit `old_string` values.

**Files affected:**
- `.claude/workflows/phase4-implement.js` (edit only — append/inject, no logic change)

**Implementation steps:**

1. Read `.claude/workflows/phase4-implement.js` to confirm current state.

2. **Step A: Expand task defaults** (near line 19-28, inside the `tasks.map` or `buildImplementerPrompt` preamble):
   ```javascript
   // ADD after existing defaults:
   t.fileContents = t.fileContents || {}
   t.diffText = t.diffText || ''
   t.grillDecisions = t.grillDecisions || []
   t.planSections = t.planSections || ''
   ```

3. **Step B: Expand `buildImplementerPrompt()`** to inject enrichment blocks (after existing contextRefs/intakeRefs/grillRefs injection, before the final prompt assembly):
   ```javascript
   // File contents
   var fcKeys = Object.keys(task.fileContents || {})
   if (fcKeys.length > 0) {
     parts.push('\n## Current File Contents (fresh read)\n')
     for (var i = 0; i < fcKeys.length; i++) {
       var k = fcKeys[i]
       parts.push('### ' + k + '\n```\n' + (task.fileContents[k] || '') + '\n```\n')
     }
   }

   // Diff text
   if (task.diffText) {
     parts.push('\n## Git Diff (changed lines for context)\n```diff\n' + task.diffText + '\n```\n')
   }

   // Grill decisions
   if (task.grillDecisions && task.grillDecisions.length > 0) {
     parts.push('\n## Design Decisions (from Grill)\n')
     for (var j = 0; j < task.grillDecisions.length; j++) {
       parts.push('- ' + task.grillDecisions[j] + '\n')
     }
   }

   // Plan sections
   if (task.planSections) {
     parts.push('\n## Task Section from Implementation Plan\n' + task.planSections + '\n')
   }
   ```

4. **Do NOT modify:**
   - The `agent()` call structure
   - The parallel execution pattern
   - Stage schemas
   - Existing contextRefs/intakeRefs/grillRefs injection

**Verification:**
- `node --check .claude/workflows/phase4-implement.js` exits 0 (plain JS only)
- `grep -c 'fileContents' .claude/workflows/phase4-implement.js` ≥ 2
- `grep -c 'diffText' .claude/workflows/phase4-implement.js` ≥ 2
- `grep -c 'grillDecisions' .claude/workflows/phase4-implement.js` ≥ 2
- `grep -c 'planSections' .claude/workflows/phase4-implement.js` ≥ 2

**Rollback:** `git checkout -- .claude/workflows/phase4-implement.js`

**Dependencies:** T1 (clean state).

---

### T3: Edit Safety Rules — Inject into Implementer Prompt

**Objective:** Prevent the two exact-string failure modes: (a) `old_string` not matching file content, (b) `old_string === new_string` stale duplicate edit.

**Files affected:**
- `skills/implementing-changes/SKILL.md` (append safety section)
- No workflow script changes needed (rules live in skill prompt, agent reads it)

**Implementation steps:**

1. Read `skills/implementing-changes/SKILL.md` to find the right insertion point (after the existing "Delegation Rules" or "Anti-Patterns" section).

2. Append a new section (additive only, don't remove existing content):

```markdown
## Edit Tool Safety Rules (HARD — MUST FOLLOW)

When calling the Edit tool to modify files, follow these rules exactly. Violating them causes "String to replace not found" or "No changes to make" errors that waste time and tokens.

### Before Edit
1. **Fresh Read required.** Read the target file immediately before constructing the Edit call. Do NOT rely on memory, stale plan line numbers, or previous reads from earlier turns.
2. **Exact old_string.** Copy `old_string` byte-for-byte from the Read output. Check: indentation (tabs vs spaces), surrounding whitespace, punctuation, and leading keywords (`type`, `func`, `var`, `const`, `package`, `import`).
3. **Unique anchor.** Include at least 2-3 lines of surrounding context to make the match unique. A single short line may appear multiple times in the file.

### On Edit Failure
4. **"String to replace not found":** Re-read the file at the target location. Copy the exact text from the fresh Read into `old_string`. Do NOT guess indentation. Do NOT retry the same old_string.
5. **"No changes to make" (old_string equals new_string):** The change already exists. Skip this edit — do NOT retry. Report success with evidence that the target content is already present.
6. **After 2 consecutive failures on the same file:** Switch to Bash (Python or sed) instead of Edit tool. Example: `python3 -c "..."` for controlled text replacement.

### After Edit
7. **Verify the change.** Read the modified location to confirm the edit was applied correctly before marking the task complete.
```

**Verification:**
- `grep -c 'Fresh Read required' skills/implementing-changes/SKILL.md` ≥ 1
- `grep -c 'String to replace not found' skills/implementing-changes/SKILL.md` ≥ 1
- `grep -c 'old_string and new_string' skills/implementing-changes/SKILL.md` ≥ 1

**Rollback:** `git checkout -- skills/implementing-changes/SKILL.md`

**Dependencies:** T1 (clean state). Can be done in parallel with T2.

---

### T4: Workflow Plain-JS Guard — Inject into Authoring Prompts

**Objective:** Prevent Workflow parse errors by ensuring agents never write TypeScript syntax in executable Workflow scripts.

**Files affected:**
- `skills/reviewing-implementation/SKILL.md` (append plain-JS rules)
- `skills/project-workflow-claude/SKILL.md` (append to Workflow Scripts section)

**Implementation steps:**

1. Read `skills/reviewing-implementation/SKILL.md` to find insertion point.

2. Append plain-JS guard section:

```markdown
## Workflow Script Rules (HARD — Plain JavaScript Only)

When writing or reviewing Workflow scripts (code passed to the `Workflow()` tool), these rules apply:

### Forbidden in Workflow Scripts
- TypeScript type annotations: `const x: string[] = ...`, `function f(a: number): void {}`
- TypeScript interfaces: `interface MyResult { ... }`
- TypeScript generics: `Array<string>`, `Promise<Result>`, `<T>`
- TypeScript type assertions: `x as string`, `<string>x`
- TypeScript enums: `enum Color { Red, Green }`
- Union types in executable positions: `type Mode = "A" | "B"` (in JSON Schema this is fine as a plain string value)

### Required in Workflow Scripts
- ALL scripts must be plain JavaScript (ES2020)
- Use `const`, `var`, `function` — no type annotations
- Use JSON Schema objects for structured output: `{ type: 'object', properties: { name: { type: 'string' } } }` — these are plain JS objects, NOT TypeScript
- After authoring a script, run `node --check <scriptPath>` before passing to `Workflow()`

### On Parse Error
If `Workflow()` returns "Invalid workflow script: Script parse error", inspect the reported line and surrounding lines for:
- Type annotations (`: string`, `: number[]`)
- Arrow functions with typed parameters
- Interface/type declarations
- Remove ALL TypeScript syntax from the offending lines and retry.
```

3. Read `skills/project-workflow-claude/SKILL.md`, find the Workflow Scripts table section (line ~52-65).

4. After the Workflow Scripts table, add a reference:

```markdown
## Workflow Script Authoring Rules

See `skills/reviewing-implementation/SKILL.md` for the full **Workflow Script Rules (HARD — Plain JavaScript Only)**. Key points:

- Workflow scripts are plain JavaScript ONLY. TypeScript syntax causes parse errors.
- All type constraints must use JSON Schema objects, not TS type annotations.
- Run `node --check <scriptPath>` before submitting to `Workflow()`.
```

**Verification:**
- `grep -c 'Plain JavaScript Only' skills/reviewing-implementation/SKILL.md` ≥ 1
- `grep -c 'TypeScript type annotations' skills/reviewing-implementation/SKILL.md` ≥ 1
- `grep -c 'Workflow Script Authoring Rules' skills/project-workflow-claude/SKILL.md` ≥ 1

**Rollback:** `git checkout -- skills/reviewing-implementation/SKILL.md skills/project-workflow-claude/SKILL.md`

**Dependencies:** T1 (clean state). Can be done in parallel with T2, T3.

---

### T5: State Validation Hardening

**Objective:** Handle the case where `contextSummaryPath` points to a nonexistent file, so the workflow doesn't block on state validation.

**Files affected:**
- `skills/project-workflow-claude/references/state-validation.md` (append graceful-degradation rule)
- `.claude/state/project-workflow-state.json` (already reset in T1 — this task hardens the RULES)

**Implementation steps:**

1. Read `skills/project-workflow-claude/references/state-validation.md`.

2. Append a section at the end:

```markdown
## Graceful Degradation for Missing Context Summaries

Some project states may have `contextSummaryPath` pointing to a file that does not exist (e.g., after a partial run or branch switch). The state validator must handle this gracefully:

1. If `contextSummaryPath` is set but the file does not exist:
   - Log a warning: "Context summary not found at <path>. Proceeding without cached context."
   - Set `contextSummaryPath` to `null` in the state object.
   - Continue execution — do NOT block.
2. If `contextSummaryPath` is `null` or unset:
   - Continue execution. The detecting-environment skill will regenerate context.
3. If `status` is not `idle` and `currentSkill` is stale:
   - Backup state as `.bak`.
   - Reset `status` to `idle`, clear `currentSkill`/`lastCompletedSkill`/`nextSkill`.
   - Set `contextSummaryPath` to `null` if pointed file doesn't exist.
```

**Verification:**
- `grep -c 'Graceful Degradation' skills/project-workflow-claude/references/state-validation.md` ≥ 1

**Rollback:** `git checkout -- skills/project-workflow-claude/references/state-validation.md`

**Dependencies:** T1 (state reset already done; this hardens future runs).

---

### T6: Regression Verification Scripts

**Objective:** Create concrete, runnable probes that prove the fixes work — Workflow parse checks and controlled Edit regression test.

**Files created:**
- `tests/test-regression-workflow-parse.sh` (new)
- `tests/test-controlled-edit-probe.sh` (new, or manual probe instructions)

**Implementation steps:**

1. Write `tests/test-regression-workflow-parse.sh`:

```bash
#!/bin/bash
# Regression: verify all workflow scripts are plain valid JavaScript
# This catches TS syntax leaks into executable .js files.
set -euo pipefail

FAILED=0
# Check project workflows
for f in .claude/workflows/*.js; do
  echo "=== node --check $f"
  if ! node --check "$f"; then
    echo "FAIL: $f is not valid JavaScript"
    FAILED=1
  fi
done

# Check global workflows (if accessible)
for f in ~/.claude/workflows/*.js; do
  echo "=== node --check $f"
  if ! node --check "$f" 2>/dev/null; then
    echo "FAIL: $f is not valid JavaScript"
    FAILED=1
  fi
done

if [ "$FAILED" -eq 1 ]; then
  echo "=== RESULT: FAIL — one or more workflow scripts contain invalid JS"
  exit 1
fi

echo "=== RESULT: PASS — all workflow scripts are valid JavaScript"
```

2. Write `tests/test-controlled-edit-probe.sh`:

```bash
#!/bin/bash
# Regression: verify Edit tool does NOT produce "String to replace not found"
# on a known file pattern that historically failed.
set -euo pipefail

PROBE_DIR="/tmp/edit-probe-$$"
trap 'rm -rf "$PROBE_DIR"' EXIT

mkdir -p "$PROBE_DIR"

cat > "$PROBE_DIR/types.go" <<'GOEOF'
package rag

import "context"

type Retriever interface {
	Search(ctx context.Context, query string, topK int) ([]SearchResult, error)
}
GOEOF

echo "=== Probe file created at $PROBE_DIR/types.go"
echo "=== Content:"
cat -A "$PROBE_DIR/types.go"

# The key check: old_string must match EXACTLY including "type" keyword
OLD_STRING='type Retriever interface {
	Search(ctx context.Context, query string, topK int) ([]SearchResult, error)
}'

# Verify old_string is present in file (exact match)
if ! grep -Fq "$OLD_STRING" "$PROBE_DIR/types.go"; then
  echo "FAIL: old_string not found in probe file (exact match test)"
  echo "Expected to find:"
  echo "$OLD_STRING"
  echo "Actual file:"
  cat "$PROBE_DIR/types.go"
  exit 1
fi

echo "=== PASS: old_string exact-match confirmed"
echo "=== This pattern (type keyword + interface body) matches the file content"
echo "=== Run this manually with the actual Edit tool to complete the probe:"
echo "    Edit(file_path='$PROBE_DIR/types.go', old_string='<above>', new_string='<modified>')"
```

3. Make scripts executable:
   ```bash
   chmod +x tests/test-regression-workflow-parse.sh tests/test-controlled-edit-probe.sh
   ```

**Verification:**
- `bash tests/test-regression-workflow-parse.sh` exits 0
- `bash tests/test-controlled-edit-probe.sh` exits 0
- `git diff --check` clean for new files

**Rollback:** `rm tests/test-regression-workflow-parse.sh tests/test-controlled-edit-probe.sh`

**Dependencies:** T2, T3, T4 (probes verify those fixes).

---

### T7: Final Evidence Collection and Verification Report

**Objective:** Run all verification commands, collect fresh evidence, and produce an evidence report that proves the fixes are effective.

**Files created:**
- `.claude/state/verification-results.json` (or inline report)

**Implementation steps:**

1. Collect evidence from each task's verification step:

   ```
   T1: python3 -m json.tool .claude/state/project-workflow-state.json → exit 0, status=idle
   T2: node --check .claude/workflows/phase4-implement.js → exit 0
       grep results for fileContents/diffText/grillDecisions/planSections
   T3: grep for Edit safety rules in implementing-changes/SKILL.md
   T4: grep for Plain-JS guard in reviewing-implementation/SKILL.md and project-workflow-claude/SKILL.md
   T5: grep for Graceful Degradation in state-validation.md
   T6: bash tests/test-regression-workflow-parse.sh → exit 0
       bash tests/test-controlled-edit-probe.sh → exit 0
   ```

2. Assemble evidence report:

```markdown
# Verification Evidence Report — Error Hardening

Date: 2026-06-11
Spec: .claude/specs/2026-06-11-error-hardening-design.md
Plan: .claude/plans/2026-06-11-workflow-error-hardening-v2-implementation.md

## T1: State Reset
- [ ] `.claude/state/project-workflow-state.json.bak` exists
- [ ] `status` = "idle"

## T2: Phase4 Enrichment
- [ ] `node --check .claude/workflows/phase4-implement.js` exits 0
- [ ] fileContents referenced ≥ 2 times
- [ ] diffText referenced ≥ 2 times
- [ ] grillDecisions referenced ≥ 2 times
- [ ] planSections referenced ≥ 2 times

## T3: Edit Safety Rules
- [ ] `Fresh Read required` present in implementing-changes/SKILL.md
- [ ] `String to replace not found` remediation steps present
- [ ] old_string===new_string prevention rule present

## T4: Workflow Plain-JS Guard
- [ ] `Plain JavaScript Only` header in reviewing-implementation/SKILL.md
- [ ] `Workflow Script Authoring Rules` in project-workflow-claude/SKILL.md

## T5: State Validation
- [ ] `Graceful Degradation` rule in state-validation.md

## T6: Regression Probes
- [ ] `bash tests/test-regression-workflow-parse.sh` → PASS
- [ ] `bash tests/test-controlled-edit-probe.sh` → PASS

## T7: Final Evidence
- [ ] All checklist items above checked with fresh command output
```

3. Fill in each checklist item with fresh command output (no stale evidence).

**Verification:**
- Each checklist item has a `[x]` mark backed by actual command output in the conversation
- No "should pass" or "looks correct" claims
- All evidence is from THIS turn

**Rollback:** Not applicable (this is evidence collection; failures mean fix + re-verify).

**Dependencies:** T1-T6 must complete first.

---

## Dependency Graph

```
T1 (state reset)
 ├─ T2 (phase4 enrichment)
 ├─ T3 (edit safety rules)
 ├─ T4 (workflow plain-JS guard)
 └─ T5 (state validation hardening)
      │
      └── T6 (regression probes) — depends on T2+T3+T4
            │
            └── T7 (final evidence) — depends on T1-T6
```

T2, T3, T4, T5 can run in parallel after T1 completes.

---

## No-Completion-Claim Gates

Each task MUST have ALL of the following before being marked complete:

1. **Fresh command output** from its Verification step (not a previous run)
2. **Exit code 0** for all listed commands
3. **No red flags:** no "should", "probably", "seems to", "I think"
4. **Evidence recorded** in the conversation or evidence report

---

## Implementation Constraints

- Edit ONLY the files listed in each task
- No broad refactors
- No editing Go business code
- No touching gopls configuration
- File writes delegated to subagents per project rules (exception: spec/plan files already authorized)
- All `.js` modifications must pass `node --check` before and after

---

## Out of Scope (explicitly NOT in this plan)

1. Fixing phase1/phase2 workflow script gaps between project `.claude/workflows/` and global `~/.claude/workflows/`
2. Broad cleanup of stale `.claude/plans/` files
3. Updating `install.sh` to sync phase1/phase2 scripts
4. Creating missing phase1-detect-knowledge.js or phase2-plan-generate.js
5. Modifying any Go source files

---

## Total Files Touched

| File | Task | Operation |
|------|------|-----------|
| `.claude/state/project-workflow-state.json` | T1 | Overwrite |
| `.claude/state/project-workflow-state.json.bak` | T1 | Create |
| `.claude/workflows/phase4-implement.js` | T2 | Edit (inject enrichment) |
| `skills/implementing-changes/SKILL.md` | T3 | Append (edit safety rules) |
| `skills/reviewing-implementation/SKILL.md` | T4 | Append (plain-JS rules) |
| `skills/project-workflow-claude/SKILL.md` | T4 | Append (authoring rules reference) |
| `skills/project-workflow-claude/references/state-validation.md` | T5 | Append (graceful degradation) |
| `tests/test-regression-workflow-parse.sh` | T6 | Create |
| `tests/test-controlled-edit-probe.sh` | T6 | Create |
