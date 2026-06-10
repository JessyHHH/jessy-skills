# Project Workflow Claude Modular Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `project-workflow-claude` from a 991-line monolithic skill into a thin orchestrator plus seven function-named child skills, while preserving one-command full workflow execution and adding Superpowers-style next-step handoff for direct child-skill usage.

**Architecture:** Use a two-layer model. `skills/project-workflow-claude/SKILL.md` becomes the Control Plane: entrypoint, global gates, run-mode routing, legacy phase mapping, escape hatches, and lazy skill chaining. Seven child skills become the Execution Plane: each owns one coherent workflow segment, persists outputs to `.claude/state/`, and either auto-invokes the next skill in full-workflow mode or prints a next-step handoff in standalone mode.

**Tech Stack:** Claude Code Skills (`SKILL.md` with YAML frontmatter), existing Workflow JS scripts in `.claude/workflows/`, shell-based structural tests in `tests/test-workflow-changes.sh`, repository docs in `README.md` and `CLAUDE.md`.

---

## Evidence and Constraints

- Official Claude Code skill docs recommend keeping `SKILL.md` under 500 lines and moving details to bundled resources.
- Current `skills/project-workflow-claude/SKILL.md` is 991 lines.
- Current `skills/project-workflow/SKILL.md` is 865 lines.
- Superpowers uses multiple small skills with explicit handoffs, for example `writing-plans` recommends `subagent-driven-development` or `executing-plans` after saving a plan.
- Superpowers 5.1.0 has no Claude Code Workflow JS scripts. Its orchestration is skill-to-skill handoff plus subagent dispatch through `SKILL.md` instructions and prompt templates. This migration should copy the handoff pattern, not replace existing `.claude/workflows/*.js` with Superpowers-style scripts.
- Current workflow already has four deterministic scripts:
  - `.claude/workflows/phase3-consensus.js`
  - `.claude/workflows/phase4-implement.js`
  - `.claude/workflows/phase5-review.js`
  - `.claude/workflows/phase6-verify.js`
- Do not rename Workflow JS scripts in this implementation. Keep `phase3-consensus`, `phase4-implement`, `phase5-review`, and `phase6-verify` for compatibility.
- Do not change runtime behavior beyond modularizing skills, adding state/handoff contracts, and updating docs/tests.

## Workflow Script Integration Notes

Keep the existing Workflow JS scripts as execution kernels. The modular skills are wrappers/control-plane logic around those kernels.

| Child Skill | Workflow Script | Wrapper Responsibility |
|---|---|---|
| `planning-implementation` | `Workflow(name='phase3-consensus')` | Read plan/context/grill/intake state, parse tasks, pass content objects/strings expected by the script. |
| `implementing-changes` | `Workflow(name='phase4-implement')` | Parse `json:tasks`, enrich tasks, invoke the script, then perform worktree review and Quick Gate outside the script. |
| `reviewing-implementation` | `Workflow(name='phase5-review')` | Build review args from state and implementation outputs, including `diffText`, `quickGateResults`, `fastGateResults`, and grill/context/intake summaries. |
| `verifying-completion` | `Workflow(name='phase6-verify')` | Run Bash checks, compute evidence checks, pass Quick Gate evidence, loop dry rounds, and persist verification results. |

### Workflow Argument Normalization

Canonical plan task schema keeps `expectedEvidence` and `forbiddenEvidence` as string arrays. Before passing tasks into prompt-oriented Workflow calls, wrapper skills normalize them for display:

```javascript
expectedEvidenceText = expectedEvidence.map(e => `- ${e}`).join('\n')
forbiddenEvidenceText = forbiddenEvidence.map(e => `- ${e}`).join('\n')
```

Do not edit Workflow JS for this normalization unless a later dedicated hardening task is approved. Prefer wrapper-side normalization to preserve runtime behavior.

Use `diffText` as the canonical field for Phase 5 review diffs. Do not introduce a new `diff` field unless it is only a backward-compatible alias.

For `phase6-verify`, pass the richer supported argument set whenever available:

```javascript
Workflow(
  name='phase6-verify',
  args={
    projectType,
    checkResults,
    dryRounds,
    evidenceChecks,
    quickGateEvidence,
    grillEvidencePath
  }
)
```



```text
skills/
├── project-workflow-claude/
│   ├── SKILL.md
│   └── references/
│       ├── claude-routing.md
│       ├── context-md-spec.md
│       ├── iron-law.md
│       ├── setup.md
│       ├── workflow-state-contract.md
│       ├── transition-rules.md
│       └── handoff-contract.md
├── detecting-environment/
│   ├── SKILL.md
│   └── references/
│       ├── context-artifact-model.md
│       └── skill-routing.md
├── designing-solutions/
│   ├── SKILL.md
│   └── references/
│       ├── grill-checklist.md
│       └── design-spec-template.md
├── planning-implementation/
│   ├── SKILL.md
│   └── references/
│       ├── task-schema.md
│       └── consensus-review-contract.md
├── implementing-changes/
│   ├── SKILL.md
│   └── references/
│       ├── task-enrichment.md
│       └── worktree-quick-gate.md
├── reviewing-implementation/
│   ├── SKILL.md
│   └── references/
│       ├── review-layers.md
│       └── review-prompt-guardrails.md
├── verifying-completion/
│   ├── SKILL.md
│   └── references/
│       └── verification-commands.md
└── finishing-development/
    ├── SKILL.md
    └── references/
        ├── retrospective.md
        └── branch-finish.md
```

## Skill Name Mapping

| Legacy Phase | New Skill | Responsibility |
|---|---|---|
| Phase 0 / 0.3 / 0.5 | `detecting-environment` | Environment detection, context artifacts, skill routing |
| Phase 1 | `designing-solutions` | Requirement echo, Grill, design spec, design approval |
| Phase 2 / 3 | `planning-implementation` | Implementation plan, task schema, consensus review |
| Phase 4 / 4.5 / 4.6 | `implementing-changes` | Task enrichment, implementation workflow, worktree review, quick gate |
| Phase 5 | `reviewing-implementation` | Two-stage review and adversarial verification |
| Phase 6 | `verifying-completion` | Iron Law verification loop |
| Phase 7 / 8 | `finishing-development` | Retrospective, memory cron prompt, branch finish |

## Run Modes

Every child skill must support two modes:

```json
{
  "runMode": "full-workflow | standalone-skill | resume",
  "handoffPolicy": "auto-continue | prompt-next-step",
  "currentSkill": "detecting-environment",
  "nextSkill": "designing-solutions"
}
```

Rules:

| runMode | handoffPolicy | Behavior |
|---|---|---|
| `full-workflow` | `auto-continue` | Exit gate passes, then invoke the next skill automatically. |
| `standalone-skill` | `prompt-next-step` | Print completed outputs and recommended next skill. Do not auto-invoke. |
| `resume` | state-driven | Continue from `currentSkill`; preserve the original `handoffPolicy`. |

## State Contract

Persist workflow state to:

```text
.claude/state/project-workflow-state.json
```

Required shape:

```json
{
  "workflow": "project-workflow-claude",
  "version": "v2.7-modular-skills",
  "runMode": "full-workflow",
  "handoffPolicy": "auto-continue",
  "currentSkill": "designing-solutions",
  "lastCompletedSkill": "detecting-environment",
  "nextSkill": "planning-implementation",
  "status": "running | waiting-for-user-approval | blocked | complete",
  "taskIntakePath": ".claude/state/task-intake.json",
  "contextSummaryPath": ".claude/state/context-summary.json",
  "grillEvidencePath": ".claude/state/grill-evidence.json",
  "specPath": null,
  "planPath": null,
  "quickGateResultsPath": null,
  "reviewResultsPath": null,
  "verificationResultsPath": null
}
```

Do not require the JSON file to exist before the first run. `project-workflow-claude` creates the initial state. Child skills update the fields they own.

## Next-Step Handoff Contract

Every child skill must end with an `## Exit Contract` section containing this logic:

```markdown
## Exit Contract

Before exiting:
1. Persist this skill's outputs to `.claude/state/` or the relevant `.claude/specs/` / `.claude/plans/` path.
2. Update `.claude/state/project-workflow-state.json` with `lastCompletedSkill`, `currentSkill`, `nextSkill`, and output paths.
3. If `runMode=full-workflow` and the exit gate passed, announce and invoke the next skill.
4. If `runMode=standalone-skill`, print a Next Step Handoff with the recommended next skill and valid alternatives.
```

Standalone handoff messages:

| Current Skill | Recommended Next Step | Alternatives |
|---|---|---|
| `detecting-environment` | `/designing-solutions` | `/project-workflow-claude continue`, stop here |
| `designing-solutions` | `/planning-implementation` | revise design, stop here |
| `planning-implementation` | `/implementing-changes` | stop here, implement manually |
| `implementing-changes` | `/reviewing-implementation` | return to `/implementing-changes` if quick gate failed, `/verifying-completion` only if review explicitly skipped |
| `reviewing-implementation` | `/verifying-completion` | `/implementing-changes` if findings need fixes |
| `verifying-completion` | `/finishing-development` | stop here and keep branch as-is |
| `finishing-development` | done | no next skill |

---

## Task 1: Add Shared Contracts for State, Transitions, and Handoffs

**Files:**
- Create: `skills/project-workflow-claude/references/workflow-state-contract.md`
- Create: `skills/project-workflow-claude/references/transition-rules.md`
- Create: `skills/project-workflow-claude/references/handoff-contract.md`

- [ ] **Step 1: Create workflow state contract reference**

Create `skills/project-workflow-claude/references/workflow-state-contract.md` with this content:

```markdown
# Workflow State Contract

`project-workflow-claude` uses `.claude/state/project-workflow-state.json` as the durable baton between modular skills.

## Required Fields

```json
{
  "workflow": "project-workflow-claude",
  "version": "v2.7-modular-skills",
  "runMode": "full-workflow | standalone-skill | resume",
  "handoffPolicy": "auto-continue | prompt-next-step",
  "currentSkill": "detecting-environment",
  "lastCompletedSkill": null,
  "nextSkill": "designing-solutions",
  "status": "running | waiting-for-user-approval | blocked | complete",
  "taskIntakePath": ".claude/state/task-intake.json",
  "contextSummaryPath": ".claude/state/context-summary.json",
  "grillEvidencePath": ".claude/state/grill-evidence.json",
  "specPath": null,
  "planPath": null,
  "quickGateResultsPath": null,
  "reviewResultsPath": null,
  "verificationResultsPath": null
}
```

## Ownership

- `project-workflow-claude` initializes `workflow`, `version`, `runMode`, `handoffPolicy`, `currentSkill`, `nextSkill`, and `taskIntakePath`.
- `detecting-environment` writes `contextSummaryPath`.
- `designing-solutions` writes `grillEvidencePath` and `specPath`.
- `planning-implementation` writes `planPath`.
- `implementing-changes` writes `quickGateResultsPath`.
- `reviewing-implementation` writes `reviewResultsPath`.
- `verifying-completion` writes `verificationResultsPath`.
- `finishing-development` marks `status=complete` after the chosen finish action.

## Resume Behavior

When the user says `/project-workflow-claude continue`, read this file and invoke `currentSkill`. If the file is absent, start from `detecting-environment` and state that no prior workflow state was found.
```

- [ ] **Step 2: Create transition rules reference**

Create `skills/project-workflow-claude/references/transition-rules.md` with this content:

```markdown
# Transition Rules

## Skill Pipeline

1. `detecting-environment`
2. `designing-solutions`
3. `planning-implementation`
4. `implementing-changes`
5. `reviewing-implementation`
6. `verifying-completion`
7. `finishing-development`

## Legacy Phase Mapping

- Phase 0 / 0.3 / 0.5 → `detecting-environment`
- Phase 1 → `designing-solutions`
- Phase 2 / 3 → `planning-implementation`
- Phase 4 / 4.5 / 4.6 → `implementing-changes`
- Phase 5 → `reviewing-implementation`
- Phase 6 → `verifying-completion`
- Phase 7 / 8 → `finishing-development`

## Auto-Transition Conditions

Auto-transition only when the current skill's exit gate has passed and `handoffPolicy=auto-continue`.

Stop and ask the user when:
- requirement echo needs confirmation,
- a Grill ambiguity cannot be safely assumed,
- design approval is required,
- plan approval is required,
- review finds critical issues,
- verification fails after the configured fix loop,
- branch finish requires a user choice.

## Escape Hatches

- `quick` or `fast`: reduce interview/review depth but keep verification gates.
- `deep` or `careful`: use full-depth review and verification.
- `skip design`: route to `planning-implementation` only when the user provides approved requirements or a spec.
- `skip plan`: route to `implementing-changes` only when tasks are already explicit.
- `no review`: skip `reviewing-implementation` only after warning the user.
- `I'll test`: skip `verifying-completion` only after recording that the user owns verification.
- `skip branch`: skip `finishing-development` branch actions.
- `skip workflow`: use manual Agent parallelism instead of Workflow scripts.
```

- [ ] **Step 3: Create handoff contract reference**

Create `skills/project-workflow-claude/references/handoff-contract.md` with this content:

```markdown
# Next-Step Handoff Contract

Every execution skill supports two usage modes.

## Full Workflow Mode

If `.claude/state/project-workflow-state.json` has `handoffPolicy=auto-continue`, announce the next skill and invoke it after the exit gate passes.

Example:

```text
Environment/context setup complete.
→ Continuing full workflow: invoking /designing-solutions.
```

## Standalone Skill Mode

If invoked directly by the user, do not silently stop. Print what was completed, the saved outputs, and the recommended next skill.

Example:

```text
Design approved and saved to `.claude/specs/2026-06-10-example-design.md`.

Recommended next step:
1. /planning-implementation (Recommended) — create a concrete task plan and run consensus review.
2. Revise design — if scope or assumptions changed.
3. Stop here — keep design only.
```

## Handoff Table

| Current Skill | Recommended Next Step | Alternatives |
|---|---|---|
| `detecting-environment` | `/designing-solutions` | `/project-workflow-claude continue`, stop here |
| `designing-solutions` | `/planning-implementation` | revise design, stop here |
| `planning-implementation` | `/implementing-changes` | stop here, implement manually |
| `implementing-changes` | `/reviewing-implementation` | return to `/implementing-changes` if quick gate failed, `/verifying-completion` only if review explicitly skipped |
| `reviewing-implementation` | `/verifying-completion` | `/implementing-changes` if findings need fixes |
| `verifying-completion` | `/finishing-development` | stop here and keep branch as-is |
| `finishing-development` | done | no next skill |
```

- [ ] **Step 4: Verify created references**

Run:

```bash
test -f skills/project-workflow-claude/references/workflow-state-contract.md \
  && test -f skills/project-workflow-claude/references/transition-rules.md \
  && test -f skills/project-workflow-claude/references/handoff-contract.md
```

Expected: exit code 0.

---

## Task 2: Create `detecting-environment` Skill

**Files:**
- Create: `skills/detecting-environment/SKILL.md`
- Create: `skills/detecting-environment/references/context-artifact-model.md`
- Create: `skills/detecting-environment/references/skill-routing.md`

- [ ] **Step 1: Create skill directory**

Run:

```bash
mkdir -p skills/detecting-environment/references
```

Expected: `skills/detecting-environment/references` exists.

- [ ] **Step 2: Write `skills/detecting-environment/SKILL.md`**

Create the file with this structure and content adapted from current `skills/project-workflow-claude/SKILL.md` Phase 0, Phase 0.3, and Phase 0.5:

```markdown
---
name: detecting-environment
description: Use when starting or resuming project-workflow-claude, or when the user asks to inspect a repository before design or implementation. Detects project type, language/tooling, MCP availability, context artifact freshness, and task-specific skill routing. In full-workflow mode, hands off to designing-solutions.
version: "v2.7"
---

# Detecting Environment

## Purpose

Detect project type, tooling, context artifacts, and task-specific skills before any design or implementation work.

## Inputs

- User request from the current conversation.
- Optional `.claude/state/project-workflow-state.json`.
- Repository files including `go.mod`, `package.json`, `skills/*/SKILL.md`, `CLAUDE.md`, `CONTEXT.md`, and `.claude/context/knowledge.md`.

## Procedure

1. Detect project type in this order: Go, Vue/React/Node, Skills Repository, Unknown.
2. Detect language/tooling versions with the commands already documented in `project-workflow-claude` v2.6.
3. Detect Context7 and Firecrawl MCP availability from available tool names.
4. Create or update `.claude/state/task-intake.json` with request summary, repo root, in-scope items, out-of-scope items, evidence, and constraints.
5. Check context artifact freshness for `CONTEXT.md`, `.claude/context/knowledge.md`, and `CLAUDE.md` against `git rev-parse HEAD`.
6. If stale or missing, delegate analysis and artifact writes to a subagent.
7. Load `references/skill-routing.md` and `skills/project-workflow-claude/references/claude-routing.md` to select task-relevant skills.
8. Load matched skills with the Skill tool. Do not load every skill.
9. Persist `.claude/state/context-summary.json`.

## Output Contract

Write `.claude/state/context-summary.json` with:

```json
{
  "rootContextPath": "CONTEXT.md",
  "rootContextStatus": "present | missing | created | updated",
  "nearestContextPaths": [],
  "knowledgePath": ".claude/context/knowledge.md",
  "knowledgeStatus": "fresh | stale | generated",
  "contextWarnings": [],
  "confirmedFacts": [],
  "autoFacts": [],
  "projectType": "go | vue | node | skills-repo | unknown",
  "loadedSkills": []
}
```

## Exit Contract

1. Update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="detecting-environment"`
   - `currentSkill="designing-solutions"`
   - `nextSkill="planning-implementation"`
   - `contextSummaryPath=".claude/state/context-summary.json"`
2. If `handoffPolicy=auto-continue`, announce and invoke `Skill(skill='designing-solutions')`.
3. If standalone, print:

```text
Environment/context setup complete.

Recommended next step:
1. /designing-solutions (Recommended) — turn the request into an approved design before planning or code.
2. /project-workflow-claude continue — resume the full workflow from this point.
3. Stop here — keep the environment/context artifacts only.
```
```

- [ ] **Step 3: Write context artifact reference**

Create `skills/detecting-environment/references/context-artifact-model.md` by moving the context artifact model currently in `skills/project-workflow-claude/SKILL.md` Phase 0.3, including:

- Root `CONTEXT.md` role.
- Scoped `CONTEXT.md` role.
- `.claude/context/knowledge.md` role.
- Freshness checks against `git rev-parse HEAD`.
- Preservation of `[confirmed]` sections and refresh of `[auto]` sections.

- [ ] **Step 4: Write skill routing reference**

Create `skills/detecting-environment/references/skill-routing.md` with:

- Instruction to read `skills/project-workflow/references/full-skill-routing.md` for shared routing.
- Instruction to read `skills/project-workflow-claude/references/claude-routing.md` for Claude Code overlay routing.
- Deduplication rule by skill name.
- Memory trigger rule for `加载 skill <name>` patterns.
- Rule to prefer Context7 for docs/library queries when available.

- [ ] **Step 5: Verify `detecting-environment`**

Run:

```bash
head -15 skills/detecting-environment/SKILL.md
grep -q '^name: detecting-environment' skills/detecting-environment/SKILL.md
grep -q 'Skill(skill=.designing-solutions.)' skills/detecting-environment/SKILL.md
test $(wc -l < skills/detecting-environment/SKILL.md) -le 500
```

Expected: all commands exit 0.

---

## Task 3: Create `designing-solutions` Skill

**Files:**
- Create: `skills/designing-solutions/SKILL.md`
- Create: `skills/designing-solutions/references/grill-checklist.md`
- Create: `skills/designing-solutions/references/design-spec-template.md`

- [ ] **Step 1: Create skill directory**

Run:

```bash
mkdir -p skills/designing-solutions/references
```

Expected: `skills/designing-solutions/references` exists.

- [ ] **Step 2: Write `skills/designing-solutions/SKILL.md`**

Create the file with this structure and content adapted from current Phase 1:

```markdown
---
name: designing-solutions
description: Use when a user request or project-workflow-claude run needs an approved design before planning or implementation. Performs requirement echo, scope boundary confirmation, Grill, Ambiguity Register, Assumption Ledger, approach proposal, design spec writing, and design approval. In full-workflow mode, hands off to planning-implementation.
version: "v2.7"
---

# Designing Solutions

## Purpose

Turn the request and context summary into an approved design before any implementation plan or code changes.

## Inputs

- `.claude/state/task-intake.json`
- `.claude/state/context-summary.json`
- User request and clarification answers

## Procedure

1. Explore files relevant to the request for up to 60 seconds.
2. Print a requirement echo with source evidence and ask `Complete and correct?`.
3. Confirm scope boundary before any other Grill question.
4. Maintain an Ambiguity Register and Assumption Ledger.
5. Continue Grill until the checklist in `references/grill-checklist.md` passes.
6. Delegate writing `.claude/state/grill-evidence.json` to a subagent.
7. Propose 2-3 approaches with trade-offs and a recommendation.
8. Delegate writing the design spec to `.claude/specs/YYYY-MM-DD-<topic>-design.md`.
9. Self-review the spec for placeholders, contradictions, scope drift, and ambiguity.
10. Ask user approval section-by-section before planning.

## Output Contract

- `.claude/state/grill-evidence.json`
- `.claude/specs/YYYY-MM-DD-<topic>-design.md`
- Updated `.claude/state/project-workflow-state.json`

## Exit Contract

1. On design approval, update state:
   - `lastCompletedSkill="designing-solutions"`
   - `currentSkill="planning-implementation"`
   - `nextSkill="implementing-changes"`
   - `grillEvidencePath=".claude/state/grill-evidence.json"`
   - `specPath=".claude/specs/<actual-file>.md"`
2. If `handoffPolicy=auto-continue`, announce and invoke `Skill(skill='planning-implementation')`.
3. If standalone, print:

```text
Design approved and saved to `.claude/specs/<actual-file>.md`.

Recommended next step:
1. /planning-implementation (Recommended) — create a concrete task plan and run consensus review.
2. Revise design — if scope or assumptions changed.
3. Stop here — keep design only.
```
```

- [ ] **Step 3: Write Grill checklist reference**

Create `skills/designing-solutions/references/grill-checklist.md` containing the existing Hard Grill Checklist from Phase 1, including:

- Ambiguity Register printed.
- Assumption Ledger printed.
- Open ambiguities addressed.
- Success criteria observable.
- Constraints documented.
- Self-grade that someone can implement from the spec without asking basic questions.
- Required JSON shape for `.claude/state/grill-evidence.json`.

- [ ] **Step 4: Write design spec template reference**

Create `skills/designing-solutions/references/design-spec-template.md` with sections:

```markdown
# <Topic> Design

## Scope
## Requirements and Evidence
## Non-Goals
## Context Summary
## Ambiguity Register
## Assumption Ledger
## Approaches Considered
## Recommended Approach
## Verification Strategy
## Risks and Rollback
```

- [ ] **Step 5: Verify `designing-solutions`**

Run:

```bash
head -15 skills/designing-solutions/SKILL.md
grep -q '^name: designing-solutions' skills/designing-solutions/SKILL.md
grep -q 'Ambiguity Register' skills/designing-solutions/SKILL.md
grep -q 'Skill(skill=.planning-implementation.)' skills/designing-solutions/SKILL.md
test $(wc -l < skills/designing-solutions/SKILL.md) -le 500
```

Expected: all commands exit 0.

---

## Task 4: Create `planning-implementation` Skill

**Files:**
- Create: `skills/planning-implementation/SKILL.md`
- Create: `skills/planning-implementation/references/task-schema.md`
- Create: `skills/planning-implementation/references/consensus-review-contract.md`

- [ ] **Step 1: Create skill directory**

Run:

```bash
mkdir -p skills/planning-implementation/references
```

Expected: `skills/planning-implementation/references` exists.

- [ ] **Step 2: Write `skills/planning-implementation/SKILL.md`**

Create the file with this structure and content adapted from current Phase 2 and Phase 3:

```markdown
---
name: planning-implementation
description: Use when an approved design or clear requirements must become a concrete implementation plan. Writes `.claude/plans/`, defines expanded json:tasks, runs consensus review with Workflow(name='phase3-consensus'), and hands off to implementing-changes in full-workflow mode.
version: "v2.7"
---

# Planning Implementation

## Purpose

Convert the approved design into a concrete implementation plan and validate it with consensus review before any file changes.

## Inputs

- `.claude/state/task-intake.json`
- `.claude/state/context-summary.json`
- `.claude/state/grill-evidence.json`
- `.claude/specs/<design>.md`

## Procedure

1. Read the approved design spec.
2. Write `.claude/plans/YYYY-MM-DD_HHMMSS-<slug>.md`.
3. Include Goal, Context, Approach, Files, Verification, Risks, and a fenced `json:tasks` block.
4. Ensure each task follows `references/task-schema.md`.
5. Collect context summary, grill summary, task intake snapshot, and parsed tasks.
6. Invoke `Workflow(name='phase3-consensus')` with those values.
7. If verdict is `ITERATE`, revise and re-run up to 3 times.
8. If verdict is `REJECT`, stop and report reasons.
9. If verdict is `APPROVE`, ask user approval before implementation.

## Exit Contract

1. After plan approval, update state:
   - `lastCompletedSkill="planning-implementation"`
   - `currentSkill="implementing-changes"`
   - `nextSkill="reviewing-implementation"`
   - `planPath=".claude/plans/<actual-file>.md"`
2. If `handoffPolicy=auto-continue`, announce and invoke `Skill(skill='implementing-changes')`.
3. If standalone, print:

```text
Plan complete and saved to `.claude/plans/<actual-file>.md`.

Execution options:
1. /implementing-changes (Recommended) — run the deterministic implementation workflow with task enrichment.
2. /project-workflow-claude continue — resume the full workflow.
3. Stop here — implement manually later.
```
```

- [ ] **Step 3: Write task schema reference**

Create `skills/planning-implementation/references/task-schema.md` with the expanded task fields from current Phase 2:

```json
{
  "id": "T1-short-name",
  "prompt": "Self-contained implementation instruction for a subagent starting with blank context.",
  "files": ["exact/path"],
  "complexity": "simple | medium | complex",
  "mutatesFiles": true,
  "contextRefs": [],
  "intakeRefs": [],
  "grillRefs": [],
  "expectedEvidence": [],
  "forbiddenEvidence": [],
  "patchBackStrategy": "no-isolation | harness-managed | external-report",
  "fileContents": [],
  "grillDecisions": [],
  "planSections": ""
}
```

Include the field descriptions currently in Phase 2.

- [ ] **Step 4: Write consensus review contract**

Create `skills/planning-implementation/references/consensus-review-contract.md` with the current Phase 3 Workflow call:

```javascript
Workflow(
  name='phase3-consensus',
  args={
    planContent: '<full plan text>',
    contextSummary: '<Phase 0.3 output contextSummary>',
    grillSummary: '<Phase 1 grill evidence>',
    taskIntakeSnapshot: '<Phase 0 task intake snapshot>',
    tasks: '<parsed tasks array from plan>'
  }
)
```

State that the script reviews architecture, risk, and feasibility in parallel and returns `APPROVE`, `ITERATE`, or `REJECT`.

- [ ] **Step 5: Verify `planning-implementation`**

Run:

```bash
head -15 skills/planning-implementation/SKILL.md
grep -q '^name: planning-implementation' skills/planning-implementation/SKILL.md
grep -q "Workflow(name='phase3-consensus')" skills/planning-implementation/SKILL.md
grep -q 'Skill(skill=.implementing-changes.)' skills/planning-implementation/SKILL.md
test $(wc -l < skills/planning-implementation/SKILL.md) -le 500
```

Expected: all commands exit 0.

---

## Task 5: Create Implementation, Review, Verification, and Finish Skills

**Files:**
- Create: `skills/implementing-changes/SKILL.md`
- Create: `skills/implementing-changes/references/task-enrichment.md`
- Create: `skills/implementing-changes/references/worktree-quick-gate.md`
- Create: `skills/reviewing-implementation/SKILL.md`
- Create: `skills/reviewing-implementation/references/review-layers.md`
- Create: `skills/reviewing-implementation/references/review-prompt-guardrails.md`
- Create: `skills/verifying-completion/SKILL.md`
- Create: `skills/verifying-completion/references/verification-commands.md`
- Create: `skills/finishing-development/SKILL.md`
- Create: `skills/finishing-development/references/retrospective.md`
- Create: `skills/finishing-development/references/branch-finish.md`

- [ ] **Step 1: Create directories**

Run:

```bash
mkdir -p \
  skills/implementing-changes/references \
  skills/reviewing-implementation/references \
  skills/verifying-completion/references \
  skills/finishing-development/references
```

Expected: all four reference directories exist.

- [ ] **Step 2: Write `implementing-changes` skill**

Create `skills/implementing-changes/SKILL.md` from current Phase 4, Phase 4.5, and Phase 4.6. Required content:

```markdown
---
name: implementing-changes
description: Use when an approved implementation plan with json:tasks is ready to execute. Enriches tasks with file contents, grill decisions, plan sections, and diffs; invokes Workflow(name='phase4-implement'); performs worktree review and quick gate; hands off to reviewing-implementation in full-workflow mode.
version: "v2.7"
---
```

The procedure must include:

- Read plan path from `.claude/state/project-workflow-state.json`.
- Parse `json:tasks`.
- Enrich each task with `fileContents`, `grillDecisions`, `planSections`, and `diffText`.
- Normalize `expectedEvidence` and `forbiddenEvidence` arrays into readable text fields for prompt-oriented workflow calls, while preserving the canonical arrays in the task object.
- Invoke `Workflow(name='phase4-implement', args={tasks: enrichedTasks})`.
- Review harness-managed worktree diffs before merging.
- Run quick gate and persist `.claude/state/quick-gate-results.json`.
- Exit by invoking `Skill(skill='reviewing-implementation')` in full-workflow mode.

Standalone handoff must recommend `/reviewing-implementation`.

- [ ] **Step 3: Write implementing references**

Create `skills/implementing-changes/references/task-enrichment.md` with the exact enrichment algorithm from current Phase 4 step 3.

Create `skills/implementing-changes/references/worktree-quick-gate.md` with:

- Worktree review rules for `harness-managed`, `no-isolation`, and `external-report`.
- Quick Gate checks: `git diff --stat`, expected evidence checks, forbidden evidence checks, unexpected file checks.
- Requirement to pass `quickGateResults` to `reviewing-implementation`.

- [ ] **Step 4: Write `reviewing-implementation` skill**

Create `skills/reviewing-implementation/SKILL.md` from current Phase 5. Required content:

```markdown
---
name: reviewing-implementation
description: Use after implementation changes exist and before final verification. Runs two-stage review in the required order: spec compliance first, code quality second, with per-task pipeline, tiered models, context injection, quick-gate risk handling, and Workflow(name='phase5-review'). Hands off to verifying-completion in full-workflow mode.
version: "v2.7"
---
```

The procedure must include:

- Context injection before review.
- Diff generation before review.
- Fast Gate checks.
- `Workflow(name='phase5-review')` with `planPath`, `planText`, `changedFiles`, enriched tasks, `selfReviewStatuses`, `fastGateResults`, `quickGateResults`, and `grillEvidence`.
- Fix-and-retry loop for critical findings and spec failures.
- Exit by invoking `Skill(skill='verifying-completion')` in full-workflow mode.

Standalone handoff must recommend `/verifying-completion`.

- [ ] **Step 5: Write reviewing references**

Create `skills/reviewing-implementation/references/review-layers.md` with the current five-layer review table.

Create `skills/reviewing-implementation/references/review-prompt-guardrails.md` with:

```text
Maximum 5 file reads. DO NOT read same file twice.
FORBIDDEN: go build, go test, go vet, grep exploration.
Maximum 3 thinking blocks.
```

- [ ] **Step 6: Write `verifying-completion` skill**

Create `skills/verifying-completion/SKILL.md` from current Phase 6. Required content:

```markdown
---
name: verifying-completion
description: Use before claiming work is complete, fixed, passing, ready, committed, or mergeable. Enforces the Iron Law with fresh verification evidence, project-specific commands, Workflow(name='phase6-verify'), and loop-until-dry fixes. Hands off to finishing-development in full-workflow mode.
version: "v2.7"
---
```

The procedure must include:

- Read `skills/project-workflow-claude/references/iron-law.md`.
- Run all project-type verification commands with Bash.
- Invoke `Workflow(name='phase6-verify')` with `projectType`, `checkResults`, `dryRounds`, `evidenceChecks`, `quickGateEvidence`, and `grillEvidencePath`.
- Loop until `allPassed=true` and dry rounds complete, or report failure at the cap.
- Persist `.claude/state/verification-results.json`.
- Exit by invoking `Skill(skill='finishing-development')` in full-workflow mode.

Standalone handoff must recommend `/finishing-development`.

- [ ] **Step 7: Write verification commands reference**

Create `skills/verifying-completion/references/verification-commands.md` containing the command sets currently in Phase 6 for:

- Go
- Vue / Node
- Skills Repository

For Skills Repository, include modular structure checks instead of the old Phase-count check:

```bash
for skill in project-workflow-claude detecting-environment designing-solutions planning-implementation implementing-changes reviewing-implementation verifying-completion finishing-development; do
  test -f "skills/$skill/SKILL.md"
  grep -q "^name: $skill" "skills/$skill/SKILL.md"
  grep -q "^description:" "skills/$skill/SKILL.md"
done
grep -q "Modular Skill Orchestrator" skills/project-workflow-claude/SKILL.md
grep -q "Skill(skill='detecting-environment')" skills/project-workflow-claude/SKILL.md
head -15 skills/*/SKILL.md | head -30
grep -rn "TODO\|FIXME" skills/
git diff --check
for ref in $(grep -oE 'references/[a-z0-9-]+\.md' skills/project-workflow-claude/SKILL.md); do test -f "skills/project-workflow-claude/$ref" && echo "✓ $ref" || echo "✗ ref not found: $ref"; done
```

- [ ] **Step 8: Write `finishing-development` skill**

Create `skills/finishing-development/SKILL.md` from current Phase 7 and Phase 8. Required content:

```markdown
---
name: finishing-development
description: Use after verified completion to run retrospective learning, optionally configure memory compression cron, and choose how to finish the development branch. Presents merge, PR, keep, or discard options after verification evidence is current.
version: "v2.7"
---
```

The procedure must include:

- Verify Phase 6 results are still current before outward-facing or destructive actions.
- Session retrospective via background Agent.
- Phase 7.2 self-learning triggers.
- Optional Phase 7.3 memory cron prompt with default skip.
- Branch finish menu: merge locally, push and create PR, keep branch as-is, discard work.
- Mark state `status="complete"` after user choice or skip.

Standalone handoff must state no next skill is required.

- [ ] **Step 9: Verify these four skills**

Run:

```bash
for skill in implementing-changes reviewing-implementation verifying-completion finishing-development; do
  head -15 "skills/$skill/SKILL.md" >/dev/null
  grep -q "^name: $skill" "skills/$skill/SKILL.md"
  grep -q 'Exit Contract' "skills/$skill/SKILL.md"
  test $(wc -l < "skills/$skill/SKILL.md") -le 500
done
grep -q "Workflow(name='phase4-implement')" skills/implementing-changes/SKILL.md
grep -q "Workflow(name='phase5-review')" skills/reviewing-implementation/SKILL.md
grep -q "Workflow(name='phase6-verify')" skills/verifying-completion/SKILL.md
```

Expected: all commands exit 0.

---

## Task 6: Convert `project-workflow-claude` into Thin Orchestrator

**Files:**
- Modify: `skills/project-workflow-claude/SKILL.md`

- [ ] **Step 1: Replace monolithic body with thin orchestrator**

Rewrite `skills/project-workflow-claude/SKILL.md` to keep frontmatter name and triggers, update version to `v2.7`, and reduce the body to these sections:

```markdown
---
name: project-workflow-claude
description: Use when starting any Claude Code development task, resuming a project workflow, or routing directly to design, planning, implementation, review, verification, or finish. Thin orchestrator that lazy-loads modular workflow skills: detecting-environment, designing-solutions, planning-implementation, implementing-changes, reviewing-implementation, verifying-completion, and finishing-development.
version: "v2.7"
author: "jessyhuang"
metadata:
  standalone: true
triggers:
  - "start task"
  - "implement"
  - "build"
  - "develop"
  - "add feature"
  - "fix bug"
  - "refactor"
  - "code change"
  - "write code"
  - "continue workflow"
  - "resume workflow"
---

# Project Workflow Claude v2.7 — Modular Skill Orchestrator

## Core Model

`project-workflow-claude` is the Control Plane. It starts or resumes the workflow, initializes state, applies global gates and escape hatches, and lazy-loads execution skills. It does not preload every phase.

Execution skills:
1. `detecting-environment`
2. `designing-solutions`
3. `planning-implementation`
4. `implementing-changes`
5. `reviewing-implementation`
6. `verifying-completion`
7. `finishing-development`

Workflow scripts remain named:
- `phase3-consensus`
- `phase4-implement`
- `phase5-review`
- `phase6-verify`

## Global Rules

- Design before code.
- Delegate file modifications to subagents when running the full workflow.
- Spec compliance review before code quality review.
- Iron Law: no completion claims without fresh verification evidence.
- Use lazy skill loading. Do not load all child skills upfront.
- Preserve user decision gates for requirements, design approval, plan approval, verification failures, and branch finish.

## Start or Resume

If the user says `continue` or `resume`, read `.claude/state/project-workflow-state.json`.

- If state exists, invoke `Skill(skill='<currentSkill>')` from the state file.
- If state does not exist, initialize a new state and invoke `Skill(skill='detecting-environment')`.

If the user asks for a full development task, initialize:

```json
{
  "workflow": "project-workflow-claude",
  "version": "v2.7-modular-skills",
  "runMode": "full-workflow",
  "handoffPolicy": "auto-continue",
  "currentSkill": "detecting-environment",
  "lastCompletedSkill": null,
  "nextSkill": "designing-solutions",
  "status": "running",
  "taskIntakePath": ".claude/state/task-intake.json",
  "contextSummaryPath": ".claude/state/context-summary.json",
  "grillEvidencePath": ".claude/state/grill-evidence.json",
  "specPath": null,
  "planPath": null,
  "quickGateResultsPath": null,
  "reviewResultsPath": null,
  "verificationResultsPath": null
}
```

Then invoke `Skill(skill='detecting-environment')`.

## Direct Routing

If the user asks for a specific stage, route by intent:

- environment, context, skill routing, phase 0 → `detecting-environment`
- design, grill, spec, phase 1 → `designing-solutions`
- plan, consensus, phase 2, phase 3 → `planning-implementation`
- implement, worktree, quick gate, phase 4 → `implementing-changes`
- review, spec compliance, code quality, phase 5 → `reviewing-implementation`
- verify, iron law, tests, phase 6 → `verifying-completion`
- finish, branch, PR, retrospective, phase 7, phase 8 → `finishing-development`

For direct routing, set `runMode="standalone-skill"` and `handoffPolicy="prompt-next-step"`, then invoke the selected skill.

## References

- `references/workflow-state-contract.md`
- `references/transition-rules.md`
- `references/handoff-contract.md`
- `references/iron-law.md`
- `references/context-md-spec.md`
- `references/claude-routing.md`
```

- [ ] **Step 2: Preserve compatibility references**

Keep existing files in `skills/project-workflow-claude/references/`:

```bash
test -f skills/project-workflow-claude/references/iron-law.md
test -f skills/project-workflow-claude/references/context-md-spec.md
test -f skills/project-workflow-claude/references/setup.md
test -f skills/project-workflow-claude/references/claude-routing.md
```

Expected: all commands exit 0.

- [ ] **Step 3: Verify orchestrator size and routing**

Run:

```bash
test $(wc -l < skills/project-workflow-claude/SKILL.md) -le 500
grep -q 'Skill(skill=.detecting-environment.)' skills/project-workflow-claude/SKILL.md
grep -q 'runMode' skills/project-workflow-claude/SKILL.md
grep -q 'standalone-skill' skills/project-workflow-claude/SKILL.md
grep -q 'Legacy' skills/project-workflow-claude/references/transition-rules.md
```

Expected: all commands exit 0.

---

## Task 7: Update Docs and Structural Tests

**Files:**
- Modify: `README.md`
- Modify: `install.sh`
- Modify: `CLAUDE.md`
- Modify: `tests/test-workflow-changes.sh`

- [ ] **Step 1: Update README workflow description**

Update README sections that currently describe `project-workflow-claude` as a single 11-phase skill. Replace with:

```markdown
- `project-workflow-claude` — Claude Code modular workflow orchestrator (v2.7). One entrypoint lazy-loads seven execution skills: `detecting-environment`, `designing-solutions`, `planning-implementation`, `implementing-changes`, `reviewing-implementation`, `verifying-completion`, and `finishing-development`. Four Workflow scripts remain installed globally for deterministic orchestration.
```

Update the repository tree section to mention the new child skills under `skills/`.

- [ ] **Step 2: Update install message**

In `install.sh`, replace the current message:

```bash
echo "  ℹ project-workflow-claude v2.6 is fully standalone"
echo "  → 4 Workflow scripts included (.claude/workflows/)"
echo "  → Auto-detects Context7/Firecrawl MCP (falls back to WebFetch/WebSearch)"
echo "  → Iron Law: references/iron-law.md"
```

with:

```bash
echo "  ℹ project-workflow-claude v2.7 uses modular execution skills"
echo "  → 1 orchestrator + 7 execution skills"
echo "  → 4 Workflow scripts included (.claude/workflows/)"
echo "  → Auto-detects Context7/Firecrawl MCP (falls back to WebFetch/WebSearch)"
echo "  → Iron Law: skills/project-workflow-claude/references/iron-law.md"
```

- [ ] **Step 3: Update project CLAUDE.md**

Update the `Core workflow` line in `CLAUDE.md` from v2.6 wording to:

```markdown
Core workflow: `project-workflow-claude` v2.7 modular orchestrator + 7 execution skills + `karpathy-guidelines`
```

- [ ] **Step 4: Add structural tests**

Append checks to `tests/test-workflow-changes.sh`:

```bash
# ── Modular project-workflow-claude skills ──
echo "Modular workflow skills exist and have handoffs"
MODULAR_SKILLS="detecting-environment designing-solutions planning-implementation implementing-changes reviewing-implementation verifying-completion finishing-development"
for skill in $MODULAR_SKILLS; do
  f="$ROOT/skills/$skill/SKILL.md"
  if [ -f "$f" ] && grep -q "^name: $skill" "$f" && grep -q 'Exit Contract' "$f"; then
    green "$skill: SKILL.md + Exit Contract OK"
  else
    red "$skill: SKILL.md or Exit Contract invalid"
  fi
  lines=$(wc -l < "$f" 2>/dev/null || echo 9999)
  if [ "$lines" -le 500 ]; then
    green "$skill: under 500 lines ($lines)"
  else
    red "$skill: over 500 lines ($lines)"
  fi
done

# ── Thin orchestrator ──
echo "project-workflow-claude thin orchestrator"
WFC="$ROOT/skills/project-workflow-claude/SKILL.md"
if grep -q 'Modular Skill Orchestrator' "$WFC" && grep -q 'detecting-environment' "$WFC" && grep -q 'handoffPolicy' "$WFC"; then
  green "orchestrator routing markers found"
else
  red "orchestrator routing markers not found"
fi
```

- [ ] **Step 5: Verify docs and tests**

Run:

```bash
grep -q 'v2.7 uses modular execution skills' install.sh
grep -q 'modular workflow orchestrator' README.md
grep -q 'v2.7 modular orchestrator' CLAUDE.md
bash tests/test-workflow-changes.sh
git diff --check
```

Expected:

- First three `grep` commands exit 0.
- `bash tests/test-workflow-changes.sh` exits 0.
- `git diff --check` exits 0.

---

## Task 8: Run Final Skill Repository Verification

**Files:**
- No source edits in this task.

- [ ] **Step 1: Verify all new skill frontmatter**

Run:

```bash
for skill in project-workflow-claude detecting-environment designing-solutions planning-implementation implementing-changes reviewing-implementation verifying-completion finishing-development; do
  head -15 "skills/$skill/SKILL.md"
  grep -q '^---$' "skills/$skill/SKILL.md"
  grep -q "^name: $skill" "skills/$skill/SKILL.md"
  grep -q '^description:' "skills/$skill/SKILL.md"
done
```

Expected: exit code 0.

- [ ] **Step 2: Verify child skills are not oversized**

Run:

```bash
for skill in project-workflow-claude detecting-environment designing-solutions planning-implementation implementing-changes reviewing-implementation verifying-completion finishing-development; do
  lines=$(wc -l < "skills/$skill/SKILL.md")
  if [ "$lines" -gt 500 ]; then
    echo "$skill too long: $lines"
    exit 1
  fi
done
```

Expected: exit code 0.

- [ ] **Step 3: Verify no broken references in project-workflow-claude references**

Run:

```bash
for ref in $(grep -oE 'references/[a-z0-9-]+\.md' skills/project-workflow-claude/SKILL.md); do
  test -f "skills/project-workflow-claude/$ref" || { echo "reference not found: $ref"; exit 1; }
done
```

Expected: exit code 0.

- [ ] **Step 4: Run existing repo checks**

Run:

```bash
bash tests/test-*.sh
git diff --check
```

Expected:

- `bash tests/test-*.sh` exits 0.
- `git diff --check` exits 0.

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Skill chaining loads too much context | Lazy-load only the next skill; keep each SKILL.md under 500 lines. |
| Child skill invoked directly lacks inputs | Each child skill checks state file and prints missing-input guidance instead of guessing. |
| Old Phase terminology appears in user docs | Keep legacy mapping for compatibility, but use function names in user-facing descriptions. |
| Workflow scripts still use phase names | Keep script names unchanged for this implementation. Rename scripts only in a later dedicated migration. |
| Tests assume old monolithic content | Update structural tests to validate modular skills and references. |
| `project-workflow-claude` no longer contains detailed commands | Move details into child skills and references; orchestrator links to references. |

---

## Self-Review

**Spec coverage:** The plan covers all confirmed design decisions: option B seven-skill decomposition, P1 function-oriented naming, thin orchestrator, lazy skill chaining, full-workflow auto-continue, standalone next-step handoff, state persistence, no Workflow script renaming, Superpowers-style handoff behavior, docs updates, and structural tests.

**Placeholder scan:** No `TBD`, `TODO`, `implement later`, or empty sections are present. All created files have exact paths and explicit required content.

**Type consistency:** Skill names are consistent across mapping, state contract, handoff table, and task instructions:
`detecting-environment`, `designing-solutions`, `planning-implementation`, `implementing-changes`, `reviewing-implementation`, `verifying-completion`, `finishing-development`.

**Scope check:** This plan is focused on modularizing `project-workflow-claude` skills and does not rename Workflow JS scripts or redesign the underlying deterministic scripts.

---

## json:tasks

```json
[
  {
    "id": "T1-shared-contracts",
    "prompt": "Create shared contract reference files for project-workflow-claude modularization: workflow-state-contract.md, transition-rules.md, and handoff-contract.md. Use the exact file paths and content described in Task 1 of the plan. Do not modify runtime skill behavior in this task.",
    "files": [
      "skills/project-workflow-claude/references/workflow-state-contract.md",
      "skills/project-workflow-claude/references/transition-rules.md",
      "skills/project-workflow-claude/references/handoff-contract.md"
    ],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [".claude/plans/2026-06-10_150000-project-workflow-claude-modular-skills.md"],
    "intakeRefs": ["User requested modular skills with full workflow auto-run and standalone handoff"],
    "grillRefs": [],
    "expectedEvidence": [
      "workflow-state-contract.md exists",
      "transition-rules.md exists",
      "handoff-contract.md exists",
      "handoff-contract.md contains Next-Step Handoff Contract"
    ],
    "forbiddenEvidence": ["TBD", "TODO", "FIXME"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T2-environment-design-plan-skills",
    "prompt": "Create detecting-environment, designing-solutions, and planning-implementation skills plus their references. Extract and adapt content from the current project-workflow-claude SKILL.md Phase 0/0.3/0.5, Phase 1, and Phase 2/3. Keep each SKILL.md under 500 lines and include Exit Contract sections with auto-continue and standalone handoff behavior.",
    "files": [
      "skills/detecting-environment/SKILL.md",
      "skills/detecting-environment/references/context-artifact-model.md",
      "skills/detecting-environment/references/skill-routing.md",
      "skills/designing-solutions/SKILL.md",
      "skills/designing-solutions/references/grill-checklist.md",
      "skills/designing-solutions/references/design-spec-template.md",
      "skills/planning-implementation/SKILL.md",
      "skills/planning-implementation/references/task-schema.md",
      "skills/planning-implementation/references/consensus-review-contract.md"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      "skills/project-workflow-claude/SKILL.md",
      ".claude/plans/2026-06-10_150000-project-workflow-claude-modular-skills.md"
    ],
    "intakeRefs": ["Use P1 function-oriented naming", "Standalone child skill should recommend next skill"],
    "grillRefs": [],
    "expectedEvidence": [
      "name: detecting-environment",
      "name: designing-solutions",
      "name: planning-implementation",
      "Skill(skill='designing-solutions')",
      "Skill(skill='planning-implementation')",
      "Skill(skill='implementing-changes')"
    ],
    "forbiddenEvidence": ["TBD", "TODO", "FIXME"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T3-execution-review-verify-finish-skills",
    "prompt": "Create implementing-changes, reviewing-implementation, verifying-completion, and finishing-development skills plus their references. Extract and adapt content from current project-workflow-claude Phase 4/4.5/4.6, Phase 5, Phase 6, and Phase 7/8. Keep Workflow script names unchanged and include Exit Contract sections with auto-continue and standalone handoff behavior. Integration notes: (1) implementing-changes must enrich tasks with diffText (canonical field for Phase 5), not 'diff'. (2) verifying-completion must pass evidenceChecks, quickGateEvidence, and grillEvidencePath to Workflow(name='phase6-verify') — these are richer args the script already supports. (3) Normalize expectedEvidence/forbiddenEvidence arrays into readable strings before prompt-oriented workflow calls; keep canonical arrays in the task object. Do NOT edit Workflow JS files.",
    "files": [
      "skills/implementing-changes/SKILL.md",
      "skills/implementing-changes/references/task-enrichment.md",
      "skills/implementing-changes/references/worktree-quick-gate.md",
      "skills/reviewing-implementation/SKILL.md",
      "skills/reviewing-implementation/references/review-layers.md",
      "skills/reviewing-implementation/references/review-prompt-guardrails.md",
      "skills/verifying-completion/SKILL.md",
      "skills/verifying-completion/references/verification-commands.md",
      "skills/finishing-development/SKILL.md",
      "skills/finishing-development/references/retrospective.md",
      "skills/finishing-development/references/branch-finish.md"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      "skills/project-workflow-claude/SKILL.md",
      ".claude/plans/2026-06-10_150000-project-workflow-claude-modular-skills.md"
    ],
    "intakeRefs": ["Keep four Workflow scripts unchanged", "Full workflow should auto-run from one entrypoint"],
    "grillRefs": [],
    "expectedEvidence": [
      "Workflow(name='phase4-implement')",
      "Workflow(name='phase5-review')",
      "Workflow(name='phase6-verify')",
      "Skill(skill='reviewing-implementation')",
      "Skill(skill='verifying-completion')",
      "Skill(skill='finishing-development')"
    ],
    "forbiddenEvidence": ["TBD", "TODO", "FIXME"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T4-thin-orchestrator",
    "prompt": "Rewrite skills/project-workflow-claude/SKILL.md into a thin v2.7 modular orchestrator. Preserve the name, core triggers, and Claude Code positioning. Remove detailed phase bodies. Add core model, global rules, start/resume routing, direct routing, legacy phase mapping via references, and links to shared contracts. Include Skill(skill='detecting-environment') and direct routing to all seven child skills.",
    "files": ["skills/project-workflow-claude/SKILL.md"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      "skills/project-workflow-claude/SKILL.md",
      "skills/project-workflow-claude/references/workflow-state-contract.md",
      "skills/project-workflow-claude/references/transition-rules.md",
      "skills/project-workflow-claude/references/handoff-contract.md",
      ".claude/plans/2026-06-10_150000-project-workflow-claude-modular-skills.md"
    ],
    "intakeRefs": ["project-workflow-claude remains the one-command entrypoint", "Do not preload all phase skills"],
    "grillRefs": [],
    "expectedEvidence": [
      "Project Workflow Claude v2.7 — Modular Skill Orchestrator",
      "Skill(skill='detecting-environment')",
      "handoffPolicy",
      "standalone-skill"
    ],
    "forbiddenEvidence": ["## Phase 1: Design First", "## Phase 5: Two-Stage Review", "TBD", "TODO", "FIXME"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T5-docs-tests-verification",
    "prompt": "Update README.md, install.sh, CLAUDE.md, and tests/test-workflow-changes.sh for the v2.7 modular skill architecture. Add structural tests that require seven child skills, Exit Contract sections, under-500-line SKILL.md files, orchestrator routing markers, and successful existing repo checks.",
    "files": ["README.md", "install.sh", "CLAUDE.md", "tests/test-workflow-changes.sh"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      "README.md",
      "install.sh",
      "CLAUDE.md",
      "tests/test-workflow-changes.sh",
      ".claude/plans/2026-06-10_150000-project-workflow-claude-modular-skills.md"
    ],
    "intakeRefs": ["Use project documentation to reflect new usage after modification"],
    "grillRefs": [],
    "expectedEvidence": [
      "v2.7 uses modular execution skills",
      "modular workflow orchestrator",
      "v2.7 modular orchestrator",
      "Modular workflow skills exist and have handoffs"
    ],
    "forbiddenEvidence": ["v2.6 is fully standalone", "v2.3 亮点", "TBD", "TODO", "FIXME"],
    "patchBackStrategy": "no-isolation"
  }
]
```
