---
name: project-workflow-claude
description: "Use when starting any development task — auto-detects project type, loads matching skills, drives 11-phase pipeline from design through verified completion. Hard Gates + Iron Law."
version: "v2.8"
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
---

# Project Workflow Claude v2.8 — Modular Orchestrator

**Core design:** Thin orchestrator that delegates each phase to a dedicated modular execution skill. The master agent is a supervisor — it routes, monitors, and transitions, but never implements directly. All heavy lifting (environment detection, design, planning, implementation, review, verification, finishing) lives in child skills.

**Platform:** Claude Code v2.4+. Uses `Skill`, `Agent`, `Workflow`, `Read`, `Glob`, `Grep`, `Bash`, `AskUserQuestion`.

---

## Core Model: Control Plane vs Execution Plane

| Plane | Role | What Lives Here |
|-------|------|----------------|
| **Control Plane** (this SKILL.md) | Route, supervise, transition | Routing logic, delegation rules, global rules, escape hatches |
| **Execution Plane** (7 child skills) | Do the work | Detect, design, plan, implement, review, verify, finish |

The control plane reads the workflow state file, determines which skill to invoke next, configures run mode and handoff policy, then invokes the skill. The execution plane writes outputs to shared state files and signals completion. The control plane reads the signal and transitions.

---

## Execution Skills (in pipeline order)

1. `detecting-environment` — Project type, language version, tooling, MCP availability, context artifacts, smart skill selection. Covers legacy Phases 0, 0.3, 0.5.
2. `designing-solutions` — Requirement echo, variable-depth Grill (Ambiguity Register + Assumption Ledger), approach proposal, spec writing. Covers legacy Phase 1.
3. `planning-implementation` — Concrete plan with expanded task schema, consensus review via Judge Panel. Covers legacy Phases 2, 3.
4. `implementing-changes` — Parallel task execution, worktree review, quick gate. Covers legacy Phases 4, 4.5, 4.6.
5. `reviewing-implementation` — Per-task independent pipeline: spec compliance, code quality, adversarial verification, final review. Covers legacy Phase 5.
6. `verifying-completion` — Iron Law enforcement: build, test, lint, security, loop-until-dry. Covers legacy Phase 6.
7. `finishing-development` — Retrospective, learning, branch finish, PR/push. Covers legacy Phases 7, 8.

All 7 skills support two modes: full workflow (`handoffPolicy=auto-continue`, auto-transition to next) and standalone (`handoffPolicy=prompt-next-step`, prompt user for next action). See `references/handoff-contract.md` for the complete handoff table.

---

## Workflow Scripts

Six deterministic JS scripts power Phases 1-6. They run via the `Workflow` tool and are installed to `~/.claude/workflows/` by `install.sh`:

| Script | Purpose |
|--------|---------|
| `phase1-detect-knowledge` | Detect project environment, analyze context artifacts, smart skill selection |
| `phase2-plan-generate` | Generate concrete implementation plan with expanded task schema |
| `phase3-consensus` | Judge Panel review (architecture, risk, feasibility) |
| `phase4-implement` | Parallel task pipeline (implement + quick verify + self-review) |
| `phase5-review` | Per-task independent review pipeline (spec → code → adversarial → final) |
| `phase6-verify` | Loop-until-dry verification with 2-consecutive-dry-round exit |

Workflow scripts are pure orchestrators — they dispatch subagents but do no file I/O themselves. See `references/transition-rules.md` for when each script is invoked.

---

## Workflow Script Authoring Rules

Workflow scripts are **plain JavaScript ONLY**. TypeScript syntax (type annotations, interfaces, generics) will cause parse errors. See `skills/reviewing-implementation/SKILL.md` for the full **Workflow Script Rules (HARD — Plain JavaScript Only)**.

Key points:
- Type constraints must use JSON Schema objects, not TS type annotations.
- Run `node --check <scriptPath>` before submitting to `Workflow()`.
- On parse error: inspect reported line, remove all TS syntax, retry.

---

## Global Rules

1. **Design before code.** No file is edited before design is approved.
2. **Delegate file writes to subagents.** The master agent reads, searches, plans, and coordinates. File modifications go to `Agent(general-purpose)` subagents.
3. **Spec compliance before code quality.** Never review code quality before confirming spec compliance.
4. **Iron Law.** NO completion claims without fresh verification evidence. The full Iron Law (Gate Function, Red Flags, Rationalization Prevention, TDD Verification, Agent Delegation Verification, Evidence Standard) is in `references/iron-law.md`.
5. **Lazy loading.** No skills pre-loaded except `karpathy-guidelines`. Skills are loaded on signal match by the detecting-environment skill.
6. **Auto-transition.** When `handoffPolicy=auto-continue`, proceed to the next skill without waiting for the user.
7. **Task Completion Guarantee.** No task transitions without fresh state validation. Each skill must validate required state fields before proceeding.

---

## Delegation Rules (MANDATORY)

The master agent is a SUPERVISOR, not an implementer. ALL file modifications MUST be delegated to subagents.

| Operation | Who | Tool |
|-----------|-----|------|
| Read, search, plan, design | Master agent | Read, Glob, Grep, AskUserQuestion |
| Skill loading | Master agent | Skill |
| Shell commands (Bash) | Master agent | Bash |
| File writing (CRITICAL) | Subagent ONLY | Agent(general-purpose) |
| Multi-file implementation | Subagent pipeline | Agent(general-purpose) |
| Knowledge/spec/plan file write | Subagent | Agent(general-purpose) |

SELF-CHECK before every Write/Edit call: "If I am the master agent → STOP. Delegate to Agent subagent instead."

---

## Karpathy Enforcement (ALL skills, ALWAYS)

1. **Think Before Coding** — Assumptions stated. Tradeoffs surfaced. Confusion named.
2. **Simplicity First** — Minimum code. No speculative abstractions.
3. **Surgical Changes** — Only requested files. Match existing style.
4. **Goal-Driven Execution** — Success criteria defined BEFORE implementation. Verify with fresh evidence.
5. **Verify Before Asserting** — Use priority chain: Context7 MCP (docs) → WebFetch → WebSearch. Do not guess.

---

## Start or Resume

When the user triggers this skill:

1. **Read state file:** `Read('.claude/state/project-workflow-state.json')`
   - If it exists and `runMode=resume` or `status=running`: invoke `Skill(skill='<currentSkill>')` to continue.
   - If it exists and `status=complete`: announce completion and ask if the user wants to restart.
   - If it does not exist: proceed to step 2.

2. **Initialize state:** Write `.claude/state/project-workflow-state.json` (delegate to subagent) with:
   ```json
   {
     "workflow": "project-workflow-claude",
     "version": "v2.8",
     "runMode": "full-workflow",
     "handoffPolicy": "auto-continue",
     "currentSkill": "detecting-environment",
     "lastCompletedSkill": null,
     "nextSkill": "designing-solutions",
     "status": "running",
     "taskIntakePath": ".claude/state/task-intake.json",
     "contextSummaryPath": null,
     "grillEvidencePath": null,
     "specPath": null,
     "planPath": null,
     "quickGateResultsPath": null,
     "reviewResultsPath": null,
     "verificationResultsPath": null,
     "escapeHatchesUsed": []
   }
   ```
   The full state contract is documented in `references/workflow-state-contract.md`.

3. **Invoke first skill:** `Skill(skill='detecting-environment')` — this loads the environment detection and context setup skill. It will handle project type detection, context artifacts, and skill selection, then auto-transition per the handoff policy.

---

## Direct Routing

When the user asks for a specific phase or action without going through the full pipeline:

1. **Read or create** `.claude/state/project-workflow-state.json` with `runMode="standalone-skill"` and `handoffPolicy="prompt-next-step"`.
2. **Map user intent** to the appropriate child skill (see Legacy Phase Mapping below).
3. **Invoke** the matched skill: `Skill(skill='<skill-name>')`.
4. After the skill completes, print the recommended next step (per `references/handoff-contract.md`) and stop — do not auto-continue.

### Direct Routing by User Intent

| User says | Route to |
|-----------|----------|
| "detect", "what project is this", "setup environment" | `detecting-environment` |
| "design", "brainstorm", "how should I", "spec" | `designing-solutions` |
| "plan", "create tasks", "review plan" | `planning-implementation` |
| "implement", "build", "write code", "fix" | `implementing-changes` |
| "review", "code review", "check my code" | `reviewing-implementation` |
| "verify", "test", "check if it works" | `verifying-completion` |
| "finish", "commit", "push", "PR", "merge" | `finishing-development` |

---

## Legacy Phase Mapping

For users familiar with the monolithic v2.6 phase numbering:

| Legacy Phase | Modular Skill |
|-------------|---------------|
| Phase 0 / 0.3 / 0.5 (Environment, Analysis, Skills) | `detecting-environment` |
| Phase 1 (Design First) | `designing-solutions` |
| Phase 2 / 3 (Plan, Consensus) | `planning-implementation` |
| Phase 4 / 4.5 / 4.6 (Implement, Worktree, Quick Gate) | `implementing-changes` |
| Phase 5 (Two-Stage Review) | `reviewing-implementation` |
| Phase 6 (Verified Completion) | `verifying-completion` |
| Phase 7 / 8 (Retrospective, Finish) | `finishing-development` |

Full transition rules and auto-transition conditions are in `references/transition-rules.md`.

---

## Escape Hatches

| Command | Effect |
|---------|--------|
| `quick` / `fast` | Reduce interview/review depth but keep verification gates |
| `deep` / `careful` | Full-depth review and verification |
| `skip design` | Route to `planning-implementation` (user provides approved requirements) |
| `skip plan` | Route to `implementing-changes` (tasks already explicit) |
| `no review` | Skip `reviewing-implementation` (DANGEROUS — warn user) |
| `I'll test` | Skip `verifying-completion` (user owns verification) |
| `skip branch` | Skip `finishing-development` branch actions |
| `skip workflow` | Use manual Agent parallelism instead of Workflow scripts |

When an escape hatch is matched, set `runMode="standalone-skill"` and `handoffPolicy="prompt-next-step"` in the state file, then route directly to the corresponding child skill.

---

## Anti-Patterns (NEVER)

1. Skip environment detection — leads to wrong tool choices
2. Skip design presentation — even simple projects need a plan
3. Skip review for non-trivial changes
4. Skip Iron Law verification — "should work" is lying
5. Load all possible skills "just in case" — select based on signals
6. Present plan inline without saving to `.claude/plans/`
7. Start code quality review before spec compliance passes
8. Claim completion without running verification commands THIS turn
9. Use parallel() when pipeline() works
10. Pass incomplete prompt to a task — subagent starts with blank context; tasks must be enriched with fileContents, grillDecisions, and planSections

---

## Reference Documents

All references live under `skills/project-workflow-claude/references/`:

| Document | Purpose |
|----------|---------|
| `workflow-state-contract.md` | State file schema, field ownership, resume behavior |
| `transition-rules.md` | Skill pipeline order, legacy phase mapping, auto-transition conditions, escape hatches |
| `handoff-contract.md` | Full workflow vs standalone mode, handoff table with next-step recommendations |
| `iron-law.md` | Complete Iron Law: Gate Function, Red Flags, Rationalization Prevention, TDD Verification, Agent Delegation Verification, Evidence Standard |
| `context-md-spec.md` | CONTEXT.md format specification — two-layer marker structure, evidence tags, update rules |
| `claude-routing.md` | Claude Code platform routing overlay (task signals and codebase signals to skill mapping) |
| `setup.md` | Recommended MCP servers (Context7, Firecrawl), fallback behavior, DeepSeek API notes |
| `state-validation.md` | State file validation rules, required fields, type constraints, cross-field invariants |
