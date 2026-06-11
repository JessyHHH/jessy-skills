---
name: designing-solutions
description: Use when a user request or project-workflow-claude run needs an approved design before planning or implementation. Performs requirement echo, scope boundary confirmation, Grill, Ambiguity Register, Assumption Ledger, approach proposal, design spec writing, and design approval. In full-workflow mode, hands off to planning-implementation.
version: "v2.7"
---

# Designing Solutions

## Purpose

Turn the request and context summary into an approved design before any implementation plan or code changes. Adapted from the brainstorming-ideas pattern and Karpathy 5 principles. The Grill is a variable-depth requirements crystallization process: its depth scales with task complexity, from 0 questions for well-specified tight-scope tasks to many rounds for ambiguous ones.

## Hard Gate

Before writing or editing any file, present approach and get user approval. Simple projects get shorter design, but design still comes first.

## Inputs

- `.claude/state/task-intake.json` -- request summary, scope, constraints
- `.claude/state/context-summary.json` -- project type, context freshness, loaded skills
- User request and clarification answers from the current conversation

## Procedure

### Step 0: State Validation

Read `.claude/state/project-workflow-state.json`.

Verify required fields per `skills/project-workflow-claude/references/state-validation.md`.

**Required for this phase:** `contextSummaryPath`

- If any required field is missing or null: BLOCK. Report exactly what's missing.
- If `escapeHatchesUsed` is missing from state file: default to `[]` (backward compat).
- If all required fields present: continue to Step 1.

[Step 0/9] State Validation — state validated

### Step 1: Explore First (Timebox 60 Seconds)

- Read top-level files matching task keywords.
- `Bash(command='git log --oneline -5', description='Recent changes context')`
- If the codebase already answers a question, skip that question -- never re-ask what's in the repo.
- Hard limit: 60 seconds. Move on when the timer expires.

[Step 1/9] Explore First — exploration complete

Print a structured restatement of every requirement extracted from:
- User's original message
- Task Intake Snapshot (`.claude/state/task-intake.json`)
- Files read during EXPLORE
- Any relevant CONTEXT.md or knowledge.md facts

Format:
```
"Requirements extracted:
  1. [requirement] -- source: [user message / intake snapshot / file X]
  2. [requirement] -- source: [user message / intake snapshot / file X]
  ...

Complete and correct? (yes/no)"
```

Ask the user: "Complete and correct?" before proceeding to the first Grill question.
- If the user says no: update the requirements list.
- If the user says yes: the echoed requirements become the authoritative scope baseline.

[Step 2/9] Requirement Echo — requirements confirmed

### Step 3: Grill -- Variable-Depth Requirements Crystallization

The Grill is one question at a time with recommended answers. Depth is driven by the Ambiguity Register, not by a preset count.

**Mandatory first question:** Confirm scope boundary -- "Here's what I think is in/out of scope based on exploration. Is this correct?" Ask nothing else until boundary is pinned.

**Ambiguity Register** -- maintain a live list of unresolved questions that could change files, behavior, verification, or risk. Each entry includes:
- **Question**: the unresolved item
- **Status**: `open` | `answered` | `assumed` | `deferred-out-of-scope`
- **Impact**: what would change based on the answer (files, behavior, verification, risk)
- **Recommended answer**: "I think X because Y -- does that work?"
- **Decision**: the final resolved answer

**Assumption Ledger** -- maintain a list of allowed assumptions. Each entry includes:
- **Assumption**: what is being assumed
- **Evidence**: what supports this assumption
- **Confidence**: High | Medium | Low
- **Correction/rollback path**: what to do if the assumption proves wrong

**Each question MUST embed a recommended answer:** "I think X because Y -- does that work?" This reduces decision fatigue. Explain reasoning and explicitly invite disagreement to avoid anchoring bias.

**No fixed question count.** Well-specified tasks with clear scope may complete the Grill with 0 additional questions. Ambiguous tasks may require many rounds.

**Exit criteria:** The Grill exits when the Hard Grill Checklist in `references/grill-checklist.md` passes. ALL checklist items must be PASS before proceeding.

[Step 3/9] Grill — requirements crystallized (N resolved, M assumed)

### Step 4: Persist Grill Evidence

After ALL checklist items pass and before writing the spec, delegate writing `.claude/state/grill-evidence.json` to a subagent. The required JSON shape is defined in `references/grill-checklist.md`.

[Step 4/9] Persist Grill Evidence — grill evidence saved

### Step 5: Propose Approaches

Propose 2-3 approaches with trade-offs and a clear recommendation.

[Step 5/9] Propose Approaches — approaches presented

### Step 6: Write Design Spec

Delegate writing the design spec to a subagent:
`Agent(description='Write design spec', prompt='Write the design spec to .claude/specs/YYYY-MM-DD-<topic>-design.md following the template in skills/designing-solutions/references/design-spec-template.md. Content: [spec content from Grill and approach proposal].', subagent_type='general-purpose')`

[Step 6/9] Write Design Spec — spec written

### Step 7: Self-Review (Before User Review)

Fix all issues inline BEFORE presenting to the user:

a. **PLACEHOLDER SCAN** -- "TBD", "TODO", incomplete sections, vague requirements
b. **INTERNAL CONSISTENCY** -- Contradictions between sections? Inconsistent assumptions?
c. **SCOPE CHECK** -- Focused enough for a single implementation plan? Needs decomposition?
d. **AMBIGUITY CHECK** -- Requirements with two interpretations: pick one, make it explicit

Never show an unreviewed spec to the user.

[Step 7/9] Self-Review — spec self-reviewed, no issues found

### Step 8: Skill Re-Check (After Design Approved)

- Re-scan codebase + task signals against routing tables.
- Diff against Phase 0.5 loaded skills (from context-summary.json).
- Load missing ones via `Skill(skill='<name>')`.
- Post-design codebase context may surface additional needed skills.

[Step 8/9] Skill Re-Check — skills up to date

### Step 9: Approval

Present spec to the user for confirmation using sectioned design approval: present section-by-section, get user confirmation per section. This ensures each design section (scope, approach, verification, risks) receives explicit user sign-off.

On approval: auto-transition per Exit Contract.

[Step 9/9] Approval — design approved

```
"Grill mode complete:
  Scope: [statement]
  Ambiguity Register: N resolved (M assumed, K deferred-out-of-scope)
  Assumption Ledger: M assumptions tracked
  Success criteria: [command evidence] + [semantic evidence]
  --> Moving to approach design."
```

## Output Contract

- `.claude/state/grill-evidence.json` -- structured Grill evidence (ambiguity register + assumption ledger + checklist results)
- `.claude/specs/YYYY-MM-DD-<topic>-design.md` -- approved design spec
- Updated `.claude/state/project-workflow-state.json`

## Exit Contract

1. On design approval, update `.claude/state/project-workflow-state.json`:
   - `lastCompletedSkill="designing-solutions"`
   - `currentSkill="planning-implementation"`
   - `nextSkill="implementing-changes"`
   - `grillEvidencePath=".claude/state/grill-evidence.json"`
   - `specPath=".claude/specs/<actual-file>.md"`

2. If `handoffPolicy=auto-continue`, announce and invoke `Skill(skill='planning-implementation')`:
   ```
   "Design approved and saved to `.claude/specs/<actual-file>.md`.
   --> Continuing full workflow: invoking /planning-implementation."
   ```

3. If standalone (invoked directly by user), print:

```text
Design approved and saved to `.claude/specs/<actual-file>.md`.

Recommended next step:
1. /planning-implementation (Recommended) -- create a concrete task plan and run consensus review.
2. Revise design -- if scope or assumptions changed.
3. Stop here -- keep design only.
```
