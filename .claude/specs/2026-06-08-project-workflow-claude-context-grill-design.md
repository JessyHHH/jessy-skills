# Project Workflow Claude Context + Deep Grill Design

## 1. Goal

Restore `project-workflow-claude` as a context-aware, variable-depth workflow that preserves durable codebase knowledge, captures task-specific intake evidence, and turns ambiguous user requests into reviewed implementation-ready designs before planning or code changes.

The design updates the workflow so Phase 2 through Phase 6 consume explicit Phase 0 and Phase 1 artifacts instead of relying only on the written plan text. The intended outcome is a tighter contract between discovery, design, consensus, implementation, review, and verification for this repository:

- `skills/project-workflow-claude/SKILL.md` documents the restored context model and deep grill process.
- `skills/project-workflow-claude/references/context-md-spec.md` defines the root and directory-scoped `CONTEXT.md` format.
- `.claude/workflows/phase3-consensus.js`, `.claude/workflows/phase4-implement.js`, `.claude/workflows/phase5-review.js`, and `.claude/workflows/phase6-verify.js` accept and enforce the new context, design, and evidence fields.
- Tests verify that the new behavior is present and that known gaps are closed.

## 2. Background / Current Gaps

Prior exploration found these current-state facts in `/home/huangzexi/personal/jessy-skills`:

- `skills/project-workflow-claude/SKILL.md` currently keeps Phase 0 environment detection around lines 52-91, Phase 0.3 `.claude/context/knowledge.md` generation around lines 95-185, and Phase 1 fixed four-dimension grill around lines 231-282.
- Phase 0.3 currently centers on `.claude/context/knowledge.md` and `CLAUDE.md` auto blocks. It does not restore the historical root `CONTEXT.md` contract.
- Historical Hermes/project-workflow `CONTEXT.md` used a two-layer structure:
  - `KNOWLEDGE_START` / `KNOWLEDGE_END` for durable, evidenced codebase facts.
  - `INSTRUCTION_START` / `INSTRUCTION_END` for operational guidance and local conventions.
- Historical lookup rules supported root `CONTEXT.md` plus optional subdirectory `CONTEXT.md` files that override or refine context by proximity.
- A historical spec existed at `skills/project-workflow/references/context-md-spec.md` in commit `0d3c35b`. The useful content includes root `CONTEXT.md` location, two-layer structure, Knowledge fields, Instruction fields, and evidence tags `[confirmed]` and `[auto]`.
- Phase 1 currently exits once four fixed dimensions are clear. That is too rigid: simple tasks can be over-interviewed, and complex tasks can still leave unresolved ambiguity.
- Phase 3 consensus currently accepts only `planContent`, so judge review cannot distinguish durable codebase context, task intake facts, grill outcomes, assumptions, or expected evidence.
- Phase 4 tasks currently use `{id,prompt,files,complexity,mutatesFiles}`. Mutating tasks use `isolation='worktree'`, but the workflow does not specify how a worktree result is patched back or merged into the main working tree.
- Phase 5 currently computes pass status from verified critical findings and spec failures, while ignoring the final review verdict. This allows a rejected final cross-task review to pass.
- Phase 6 currently treats only non-zero command exits as failures. It does not model semantic verification evidence, such as required text that must appear in output or forbidden text that must not appear.

These gaps make the workflow vulnerable to stale context, untracked assumptions, plan drift, ambiguous task boundaries, and false-positive verification success.

## 3. Scope and Non-Goals

### In scope

1. Update `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/SKILL.md`:
   - Phase 0 and Phase 0.3 restore root `CONTEXT.md` two-layer structure.
   - Phase 0 captures a Task Intake Snapshot for the current user request.
   - Phase 1 replaces the fixed four-question grill with a variable-depth Ambiguity Register and Assumption Ledger.
   - Phase 1 requires sectioned design approval before Phase 2.
   - Phase 2, Phase 3, Phase 4, Phase 5, and Phase 6 explicitly consume Phase 0 and Phase 1 outputs: context summary, task intake snapshot, grill summary, assumptions, and evidence requirements.
2. Add or restore `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/references/context-md-spec.md`.
3. Update Claude Code workflow scripts:
   - `/home/huangzexi/personal/jessy-skills/.claude/workflows/phase3-consensus.js`
   - `/home/huangzexi/personal/jessy-skills/.claude/workflows/phase4-implement.js`
   - `/home/huangzexi/personal/jessy-skills/.claude/workflows/phase5-review.js`
   - `/home/huangzexi/personal/jessy-skills/.claude/workflows/phase6-verify.js`
4. Add or update tests verifying:
   - `CONTEXT.md` spec exists and is referenced.
   - Phase 1 is no longer fixed four questions.
   - Phase 5 final review rejection blocks pass.
   - Phase 3, Phase 4, and Phase 6 support the new context and evidence fields.

### Non-goals

- Do not change other skills, including Go, Vue, engineering, or Firecrawl skills.
- Do not change `/home/huangzexi/personal/jessy-skills/install.sh` unless implementation discovers that workflow script installation must be synced to keep the local and installed workflow script contracts aligned.
- Do not add Superpowers as a dependency. Borrow only conceptual interaction patterns where useful.
- Do not modify `/home/huangzexi/.claude/CLAUDE.md` or other user-global configuration.
- Do not execute Phase 4 through Phase 6 implementation as part of this design task.

## 4. Proposed Design

### Phase 0 / 0.3 CONTEXT.md restoration

Update `skills/project-workflow-claude/SKILL.md` so Phase 0 and Phase 0.3 distinguish three context artifacts:

1. `CONTEXT.md` at repository root:
   - Durable human-readable repository context.
   - Uses the two-layer format defined in `skills/project-workflow-claude/references/context-md-spec.md`.
   - May contain both confirmed human-maintained information and auto-generated facts tagged with `[confirmed]` or `[auto]`.
2. Optional subdirectory `CONTEXT.md` files:
   - Apply only to files under that directory.
   - Override or refine the root context by proximity.
   - Must use the same two-layer format.
3. `.claude/context/knowledge.md`:
   - Remains the generated analysis cache used by the workflow.
   - Should not replace root `CONTEXT.md`; instead, Phase 0.3 may use it as generated evidence when refreshing auto-tagged portions of context.

Phase 0.3 should add a hard gate for context discovery:

- Read root `CONTEXT.md` if present.
- Read any relevant nearby `CONTEXT.md` files for the task files identified during exploration.
- If root `CONTEXT.md` is missing, create it during Phase 0.3 for workflow-managed projects using the specified two-layer structure.
- If malformed context markers are present, do not rewrite the malformed file blindly. Surface the marker problem and rely on `.claude/context/knowledge.md` for that run.
- Keep `.claude/context/knowledge.md` generation and freshness checks, but document that root `CONTEXT.md` is the stable repository contract and `knowledge.md` is the generated analysis cache.

Phase 0.3 output should include a `contextSummary` object for downstream phases:

```json
{
  "rootContextPath": "CONTEXT.md",
  "rootContextStatus": "present",
  "nearestContextPaths": ["skills/project-workflow-claude/CONTEXT.md"],
  "knowledgePath": ".claude/context/knowledge.md",
  "knowledgeStatus": "fresh",
  "contextWarnings": [],
  "confirmedFacts": ["Skills are stored under skills/*/SKILL.md"],
  "autoFacts": ["Workflow scripts are stored under .claude/workflows"]
}
```

`nearestContextPaths` may be an empty array when no subdirectory context applies. If root context is created during Phase 0.3, `rootContextStatus` should be `created`.

### Phase 0 Task Intake Snapshot

Add a Phase 0 Task Intake Snapshot before Phase 1. This is a lightweight structured record of the current user request and known boundaries, not an implementation plan.

The snapshot should be captured in memory for the run and copied into the Phase 1 design spec and Phase 2 plan. It should include:

```json
{
  "requestSummary": "Update project-workflow-claude design for context restoration and variable-depth grill.",
  "repoRoot": "/home/huangzexi/personal/jessy-skills",
  "approvedInScope": [
    "Update skills/project-workflow-claude/SKILL.md",
    "Restore skills/project-workflow-claude/references/context-md-spec.md",
    "Update workflow scripts phase3 through phase6",
    "Add or update workflow tests"
  ],
  "approvedOutOfScope": [
    "Other skills",
    "User global Claude configuration",
    "Superpowers dependency"
  ],
  "sourceEvidence": [
    "User-provided scope boundary",
    "Prior exploration notes"
  ],
  "constraints": [
    "Design first",
    "No implementation code changes during this task"
  ]
}
```

This prevents Phase 1 and Phase 2 from re-litigating already-approved boundaries and gives scripts a stable source for scope checks.

### Phase 1 Deep Grill with Ambiguity Register and Assumption Ledger

Replace the fixed four-question grill with a variable-depth process. The new Phase 1 still starts with scope confirmation when scope is not already pinned, but it exits based on unresolved ambiguity rather than a fixed question count.

Phase 1 should maintain two explicit structures:

1. Ambiguity Register:
   - A list of unresolved questions that could change files, behavior, risk, verification, or user-facing outcome.
   - Each item has a status: `open`, `answered`, `assumed`, or `deferred-out-of-scope`.
   - Each item records impact, recommended answer, user answer if provided, and resulting decision.
2. Assumption Ledger:
   - A list of assumptions the workflow is allowed to proceed with.
   - Each assumption must include evidence, confidence, and rollback or correction path.
   - Assumptions cannot contradict the Task Intake Snapshot or `CONTEXT.md` confirmed facts.

Example Ambiguity Register item:

```json
{
  "id": "A1",
  "question": "Should root CONTEXT.md be generated when missing or only documented?",
  "impact": "Changes Phase 0.3 behavior and tests.",
  "recommendedAnswer": "Generate root CONTEXT.md when missing because restoration is explicitly in scope.",
  "status": "answered",
  "decision": "Generate root CONTEXT.md with two-layer markers."
}
```

Example Assumption Ledger item:

```json
{
  "id": "S1",
  "assumption": "No subdirectory CONTEXT.md is required for this implementation unless existing files already contain one.",
  "evidence": "Scope only requires adding or restoring the reference spec and updating project-workflow-claude files.",
  "confidence": "medium",
  "correctionPath": "If implementation finds existing subdirectory context files, include them in context discovery tests."
}
```

Questioning rules:

- Ask one question at a time.
- Include a recommended answer with reasoning.
- Skip any question already answered by the Task Intake Snapshot, root `CONTEXT.md`, nearby `CONTEXT.md`, `.claude/context/knowledge.md`, or direct user instructions.
- Continue only while an open ambiguity could materially change the design or plan.
- For small or fully specified tasks, the register can close with zero additional user questions after documenting the existing evidence.
- For complex tasks, the register may require more than four questions.

### Phase 1 sectioned design approval

Phase 1 should produce a sectioned design spec and self-review it before user approval. The written design does not need a fixed length, but it must include sections scaled to task complexity.

For this project workflow, update `SKILL.md` so Phase 1 design specs include at least:

- Goal
- Context inputs used
- Scope and non-goals
- Proposed behavior by phase
- Script contract changes when scripts are affected
- Test and verification plan
- Risks and mitigations
- Acceptance criteria

Approval should be sectioned:

1. Present a concise summary of the major sections.
2. Call out assumptions that remain in the Assumption Ledger.
3. Ask for approval of the design as written.
4. Move to Phase 2 only after approval or after the user has already explicitly asked for a design-only artifact and no implementation transition is requested.

For the current user task, completion stops after the design spec is written and self-reviewed because executing Phase 2 or implementation is out of scope.

### Phase 2 task schema changes

Phase 2 plans should continue to write a JSON task block, but task objects need additional fields so implementation, review, and verification can trace work back to Phase 0 and Phase 1 decisions.

New task schema:

```json
{
  "id": "T1",
  "prompt": "Self-contained implementation instruction.",
  "files": ["skills/project-workflow-claude/SKILL.md"],
  "complexity": "medium",
  "mutatesFiles": true,
  "contextRefs": ["CONTEXT.md", ".claude/context/knowledge.md"],
  "intakeRefs": ["approvedInScope", "approvedOutOfScope"],
  "grillRefs": ["A1", "S1"],
  "expectedEvidence": [
    "SKILL.md references references/context-md-spec.md",
    "Phase 1 text contains Ambiguity Register and Assumption Ledger"
  ],
  "forbiddenEvidence": [
    "Phase 1 requires exactly four questions",
    "Superpowers is required as a dependency"
  ],
  "patchBackStrategy": "apply-diff"
}
```

Field meanings:

- `contextRefs`: Context artifacts the implementer must consider.
- `intakeRefs`: Task Intake Snapshot keys relevant to the task.
- `grillRefs`: Ambiguity Register or Assumption Ledger IDs relevant to the task.
- `expectedEvidence`: Semantic evidence that should exist after the task is complete.
- `forbiddenEvidence`: Semantic evidence that must not exist after the task is complete.
- `patchBackStrategy`: Required for mutating tasks. Allowed values are `apply-diff`, `merge-commit`, and `manual-report`.

For this repository, default mutating task strategy should be `apply-diff`: collect the isolated worktree diff and apply it to the main working tree after task-level verification. `merge-commit` should be reserved for future branch-based workflows and not used by default. `manual-report` is only for tasks that cannot be safely patched back automatically.

### Phase 3 consensus script changes

Update `.claude/workflows/phase3-consensus.js` so it accepts a richer argument contract:

```json
{
  "planContent": "Full Phase 2 plan text.",
  "contextSummary": {},
  "taskIntakeSnapshot": {},
  "grillSummary": {
    "ambiguities": [],
    "assumptions": [],
    "exitCriteria": []
  },
  "tasks": []
}
```

Required behavior:

- Preserve backward compatibility for callers that pass only `planContent`, but mark missing context fields as review warnings.
- Judge architecture, risk, and feasibility against both the plan and the Phase 0/1 artifacts.
- Reject plans that contradict approved out-of-scope items.
- Require every mutating task to include `patchBackStrategy`.
- Require every task to include either `expectedEvidence` or a clear explanation in its prompt of how completion will be verified.
- Surface unresolved open ambiguities as blockers unless their status is `assumed` with a ledger entry or `deferred-out-of-scope`.

Consensus output should include:

```json
{
  "verdict": "APPROVE",
  "score": 9,
  "findings": [],
  "contextWarnings": [],
  "taskContractWarnings": []
}
```

### Phase 4 implementation script changes, including explicit worktree patch-back/merge strategy requirement

Update `.claude/workflows/phase4-implement.js` so each task receives the context and evidence fields from Phase 2. The implementer prompt generated by the script must include:

- Relevant context paths from `contextRefs`.
- Relevant Task Intake Snapshot values from `intakeRefs`.
- Relevant ambiguity and assumption decisions from `grillRefs`.
- Expected and forbidden evidence lists.
- Patch-back strategy for mutating tasks.

Worktree patch-back requirement:

- If `mutatesFiles` is `true`, the task must declare `patchBackStrategy`.
- If strategy is `apply-diff`, the script must require the implementer result to identify changed files and provide or leave a clean diff that can be applied back to the main working tree.
- If strategy is `merge-commit`, the script must require an explicit branch or worktree merge path and should not be the default for this repository.
- If strategy is `manual-report`, the script must not report the task as fully implemented; it should return `DONE_WITH_CONCERNS` and require Phase 5 attention.
- The script must not silently discard isolated worktree changes.

Phase 4 output should include per-task evidence status:

```json
{
  "taskId": "T1",
  "status": "DONE",
  "selfReviewStatus": "DONE",
  "changedFiles": ["skills/project-workflow-claude/SKILL.md"],
  "expectedEvidenceObserved": [],
  "forbiddenEvidenceObserved": [],
  "patchBackStatus": "applied"
}
```

`expectedEvidenceObserved` can be empty at Phase 4 if semantic verification is deferred to Phase 6, but the field must exist so Phase 5 and Phase 6 have a stable contract.

### Phase 5 review script changes, including finalReview verdict gating

Update `.claude/workflows/phase5-review.js` so final review is a hard gate.

Current gap: pass status can ignore `finalReview.verdict`. New pass condition:

```js
passed = verifiedCritical.length === 0 &&
  specFailed.length === 0 &&
  finalReview &&
  finalReview.verdict === 'APPROVE'
```

Required behavior:

- Spec compliance review must compare changed files against the plan, Task Intake Snapshot, context summary, and grill decisions.
- Code quality review runs only for tasks that pass spec compliance.
- Self-review statuses from Phase 4 remain visible in review context.
- Final review must check cross-task consistency, scope compliance, context consistency, and evidence readiness.
- `finalReview.verdict` values should be `APPROVE`, `ITERATE`, or `REJECT`.
- `ITERATE` and `REJECT` both block pass. `REJECT` should be reported more prominently because it means the final cross-task review found a fundamental issue.
- Tests must include a rejected final review case where critical findings and spec failures are empty but `passed` is still false.

Phase 5 output should include:

```json
{
  "passed": false,
  "criticalCount": 0,
  "highCount": 0,
  "specFailed": [],
  "finalReview": {
    "verdict": "REJECT",
    "reasons": ["Implementation contradicts approved scope."]
  }
}
```

### Phase 6 verification script changes, including expectedEvidence/forbiddenEvidence semantic verification

Update `.claude/workflows/phase6-verify.js` so command success is necessary but not sufficient.

New input contract:

```json
{
  "projectType": "skills-repo",
  "checkResults": [],
  "dryRounds": 0,
  "expectedEvidence": [
    {
      "id": "E1",
      "description": "CONTEXT.md spec exists",
      "type": "file-exists",
      "path": "skills/project-workflow-claude/references/context-md-spec.md"
    }
  ],
  "forbiddenEvidence": [
    {
      "id": "F1",
      "description": "Phase 1 fixed four-question language removed",
      "type": "text-absent",
      "path": "skills/project-workflow-claude/SKILL.md",
      "pattern": "all 4 clarity dimensions"
    }
  ]
}
```

Supported semantic evidence types for this implementation:

- `file-exists`: path must exist.
- `text-present`: path must contain a literal string or regex pattern.
- `text-absent`: path must not contain a literal string or regex pattern.
- `command-output-present`: named check output must contain a literal string or regex pattern.
- `command-output-absent`: named check output must not contain a literal string or regex pattern.

Required behavior:

- `allPassed` is true only when all command checks pass, all expected evidence passes, all forbidden evidence is absent, and dry-round requirements are satisfied.
- Semantic evidence failures must be reported separately from command failures.
- `shouldContinue` should remain true when semantic evidence fails and fixes are possible.
- The script should include evidence failure details in its fix guidance.
- Backward compatibility: if no evidence arrays are supplied, the script uses command-only behavior but emits a warning that semantic evidence was not provided.

## 5. CONTEXT.md Format

Add `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/references/context-md-spec.md` with the canonical format below.

Root file location:

- Repository root: `/home/huangzexi/personal/jessy-skills/CONTEXT.md` for this repository.
- Generic workflow wording in the reference should say: root `CONTEXT.md` lives at the project root.

Optional scoped files:

- Any subdirectory may contain its own `CONTEXT.md`.
- During task execution, load root context first, then each nearest scoped context from broadest to nearest directory.
- More specific context refines less specific context. Confirmed facts in a nearer context override auto facts in root context for files under that directory.
- Contradictions between confirmed facts should be surfaced as warnings, not silently resolved.

Required marker structure:

```markdown
# Project Context

<!-- KNOWLEDGE_START -->
## Architecture
- [confirmed] Durable architecture fact with source path.

## Entity Map
- [auto] Entity or domain object inferred from repository analysis.

## Entities
- [confirmed] Important entity, responsibility, and location.

## Key Interfaces
- [auto] Public interface, command, or script contract.

## Package Map
- [auto] Directory or package responsibilities.

## Confidence
- [auto] High-confidence facts and low-confidence areas requiring caution.
<!-- KNOWLEDGE_END -->

<!-- INSTRUCTION_START -->
## Build & Test Commands
- [confirmed] `bash tests/test-workflow-changes.sh`

## Code Conventions
- [confirmed] `SKILL.md` files use agentskills.io frontmatter.

## Invariants
- [confirmed] Do not update unrelated skills for project-workflow-claude changes.

## Domain Glossary
- [confirmed] Ambiguity Register: unresolved design questions tracked during Phase 1.
<!-- INSTRUCTION_END -->
```

Allowed evidence tags:

- `[confirmed]`: Human-provided, user-approved, or directly verified source fact.
- `[auto]`: Generated by workflow analysis and subject to refresh.

Update rules:

- Never remove `[confirmed]` entries during automatic refresh.
- Automatic refresh may replace `[auto]` entries inside known sections.
- If markers are missing or nested incorrectly, do not rewrite automatically. Report a malformed context warning.
- `context-md-spec.md` should document the exact fields, marker rules, precedence rules, and update rules.

## 6. Grill Exit Criteria

Phase 1 exits when all of the following are true:

1. Scope boundary is pinned by user instruction, Task Intake Snapshot, or an answered Ambiguity Register item.
2. No open ambiguity can materially change file selection, behavior, public contract, verification, or risk.
3. Every unresolved non-blocking uncertainty is recorded in the Assumption Ledger with evidence, confidence, and correction path.
4. Assumptions do not contradict approved scope, root `CONTEXT.md` confirmed facts, or nearby scoped `CONTEXT.md` confirmed facts.
5. Success criteria include both command verification and semantic evidence when the task changes workflow behavior or documentation contracts.
6. The sectioned design spec has passed self-review for unresolved placeholders, internal consistency, scope containment, and ambiguous wording.

The workflow should not require exactly four questions. It may ask zero additional questions when the user request and repository evidence already satisfy the exit criteria. It may ask more than four questions when material ambiguities remain.

## 7. Workflow Script Contract Changes

### Shared contract objects

All updated scripts should recognize these shared objects:

```json
{
  "contextSummary": {
    "rootContextPath": "CONTEXT.md",
    "rootContextStatus": "present",
    "nearestContextPaths": [],
    "knowledgePath": ".claude/context/knowledge.md",
    "knowledgeStatus": "fresh",
    "contextWarnings": [],
    "confirmedFacts": [],
    "autoFacts": []
  },
  "taskIntakeSnapshot": {
    "requestSummary": "",
    "repoRoot": "/home/huangzexi/personal/jessy-skills",
    "approvedInScope": [],
    "approvedOutOfScope": [],
    "sourceEvidence": [],
    "constraints": []
  },
  "grillSummary": {
    "ambiguities": [],
    "assumptions": [],
    "exitCriteria": []
  }
}
```

### Script-specific changes

- `.claude/workflows/phase3-consensus.js`:
  - Accept `contextSummary`, `taskIntakeSnapshot`, `grillSummary`, and `tasks` in addition to `planContent`.
  - Warn on missing new fields for backward compatibility.
  - Block contradictions against approved scope and open grill ambiguities.
- `.claude/workflows/phase4-implement.js`:
  - Pass context, intake, grill, expected evidence, forbidden evidence, and patch-back strategy into task prompts.
  - Require patch-back strategy for every mutating task.
  - Report `patchBackStatus`, changed files, and evidence observation fields per task.
- `.claude/workflows/phase5-review.js`:
  - Include context and grill decisions in spec compliance review.
  - Gate pass status on `finalReview.verdict === 'APPROVE'`.
  - Report final review verdict and reasons in structured output.
- `.claude/workflows/phase6-verify.js`:
  - Accept `expectedEvidence` and `forbiddenEvidence` arrays.
  - Evaluate supported semantic evidence types.
  - Treat semantic evidence failures as verification failures even when all commands exit zero.

## 8. Testing / Verification Plan

Update existing repository tests or add focused shell tests under `/home/huangzexi/personal/jessy-skills/tests`. Prefer extending `/home/huangzexi/personal/jessy-skills/tests/test-workflow-changes.sh` if it already covers workflow scripts, to avoid unnecessary test sprawl.

Required checks:

1. `CONTEXT.md` spec exists and is referenced:
   - Assert `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/references/context-md-spec.md` exists.
   - Assert `skills/project-workflow-claude/SKILL.md` references `references/context-md-spec.md`.
   - Assert the reference spec includes `KNOWLEDGE_START`, `KNOWLEDGE_END`, `INSTRUCTION_START`, `INSTRUCTION_END`, `[confirmed]`, and `[auto]`.
2. Phase 1 is no longer fixed four questions:
   - Assert `SKILL.md` includes `Ambiguity Register` and `Assumption Ledger`.
   - Assert `SKILL.md` includes variable-depth exit criteria.
   - Assert fixed wording that requires exactly four dimensions or exactly four questions is absent.
3. Phase 5 final review rejection blocks pass:
   - Add or update a script-level test that simulates `verifiedCritical.length === 0`, `specFailed.length === 0`, and `finalReview.verdict === 'REJECT'`.
   - Assert the resulting `passed` value is false.
4. Phase 3 supports new context fields:
   - Assert `.claude/workflows/phase3-consensus.js` accepts or references `contextSummary`, `taskIntakeSnapshot`, `grillSummary`, and `tasks`.
   - Assert it warns or handles missing new fields for backward compatibility.
5. Phase 4 supports new task fields:
   - Assert `.claude/workflows/phase4-implement.js` references `contextRefs`, `intakeRefs`, `grillRefs`, `expectedEvidence`, `forbiddenEvidence`, and `patchBackStrategy`.
   - Assert mutating task handling requires or validates patch-back strategy.
6. Phase 6 supports semantic evidence:
   - Assert `.claude/workflows/phase6-verify.js` references `expectedEvidence` and `forbiddenEvidence`.
   - Assert supported evidence types include `file-exists`, `text-present`, and `text-absent` at minimum.
   - Assert semantic evidence failures affect `allPassed`.
7. Repository baseline verification:
   - Run `bash /home/huangzexi/personal/jessy-skills/tests/test-workflow-changes.sh`.
   - Run `git -C /home/huangzexi/personal/jessy-skills diff --check`.

## 9. Risks and Mitigations

- Risk: `CONTEXT.md` and `.claude/context/knowledge.md` become duplicate sources of truth.
  - Mitigation: Document root `CONTEXT.md` as the durable contract and `knowledge.md` as generated analysis cache. Phase 0/0.3 output must label both statuses separately.
- Risk: Automatic context refresh overwrites human decisions.
  - Mitigation: Preserve `[confirmed]` entries and only refresh `[auto]` entries. Refuse automatic rewrite on malformed markers.
- Risk: Variable-depth grill becomes too open-ended.
  - Mitigation: Use explicit exit criteria and ask only questions that can materially change files, behavior, verification, or risk.
- Risk: New script contracts break existing callers.
  - Mitigation: Keep `planContent`-only compatibility in Phase 3 and command-only compatibility in Phase 6, with structured warnings for missing richer fields.
- Risk: Worktree isolation hides completed changes.
  - Mitigation: Require `patchBackStrategy` for mutating tasks and report `patchBackStatus` in Phase 4 output.
- Risk: Semantic evidence checks become a second test framework.
  - Mitigation: Support only simple evidence types needed for workflow contract checks: file existence, text presence or absence, and command output presence or absence.
- Risk: Tests overfit to exact prose.
  - Mitigation: Tests should check durable contract phrases and script fields, not large paragraphs or line numbers.

## 10. Acceptance Criteria

The implementation that follows this design is accepted when all of these are true:

1. `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/SKILL.md` describes root and scoped `CONTEXT.md`, `.claude/context/knowledge.md`, Task Intake Snapshot, Ambiguity Register, Assumption Ledger, sectioned design approval, and downstream consumption by Phase 2 through Phase 6.
2. `/home/huangzexi/personal/jessy-skills/skills/project-workflow-claude/references/context-md-spec.md` exists and documents the two-layer `CONTEXT.md` format, marker rules, fields, evidence tags, precedence, and update behavior.
3. Phase 1 documentation no longer requires exactly four questions or a fixed four-question grill.
4. Phase 2 task schema documentation includes `contextRefs`, `intakeRefs`, `grillRefs`, `expectedEvidence`, `forbiddenEvidence`, and `patchBackStrategy`.
5. `.claude/workflows/phase3-consensus.js` accepts the richer Phase 0/1 context contract and blocks plans that contradict approved scope or unresolved material ambiguities.
6. `.claude/workflows/phase4-implement.js` requires patch-back strategy for mutating tasks and reports patch-back status.
7. `.claude/workflows/phase5-review.js` fails when final review verdict is `ITERATE` or `REJECT`, even if critical findings and spec failures are empty.
8. `.claude/workflows/phase6-verify.js` evaluates expected and forbidden semantic evidence in addition to command exit codes.
9. Tests cover the required context spec reference, variable-depth grill language, final review gating, and Phase 3/4/6 new fields.
10. Repository verification passes with fresh evidence from `bash tests/test-workflow-changes.sh` and `git diff --check` after implementation.

## 11. Implementation Notes

- Keep edits surgical and limited to the approved files unless tests reveal an existing workflow test helper must be updated.
- Prefer updating `/home/huangzexi/personal/jessy-skills/tests/test-workflow-changes.sh` before adding a new test file.
- Do not modify other skill directories.
- Do not change `/home/huangzexi/.claude/CLAUDE.md`.
- Do not introduce Superpowers installation, imports, references as a dependency, or runtime requirements. It is acceptable to adapt the interaction ideas of one-question-at-a-time interviewing, scope decomposition, trade-off proposals, and written spec self-review.
- If implementation discovers that `.claude/workflows` scripts are installed from another source path, update only the minimum required install or sync path after confirming the workflow script contract would otherwise diverge.
- When updating prose in `SKILL.md`, remove or rewrite wording that implies the grill is complete only when exactly four fixed dimensions are clear.
- When updating script tests, prefer direct script invocation or small fixture inputs over brittle source-code substring checks when practical.
- Preserve backward compatibility warnings rather than hard-failing old inputs except where the new design explicitly requires a hard gate: mutating Phase 4 tasks without patch-back strategy, Phase 5 non-approve final verdict, and Phase 6 semantic evidence failures when evidence is supplied.
