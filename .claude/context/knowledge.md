<!-- ⚠️ Auto-generated | Commit: fd32e81a3fb617312a13a59403dd089c51a2e814 | Date: 2026-06-18 | Skills Repository -->

# Skills Repository — Knowledge Layer

## Project Overview

This is a Skills Repository containing 84 AI Agent skills organized across 23 top-level category directories. Skills are defined using the agentskills.io YAML frontmatter open standard (`SKILL.md` files). The repository is a text-only project (no compiled language) with shell-based verification.

- **Repository root**: `/home/huangzexi/personal/jessy-skills`
- **Git branch**: `claude`
- **Core workflow**: `project-workflow-claude` v2.7 — modular orchestrator + 7 execution skills
- **Platform**: Claude Code v2.4+

## Architecture

```
jessy-skills/
├── skills/                        # 84 skill definitions (23 category dirs)
│   ├── analyze/                   # 1 skill
│   ├── code-review/               # 1 skill
│   ├── deep-interview/            # 1 skill
│   ├── designing-solutions/       # 1 skill (v2.7 modular — Phase 1)
│   ├── detecting-environment/     # 1 skill (v2.7 modular — Phase 0)
│   ├── engineering/               # 15 skills
│   ├── finishing-development/     # 1 skill (v2.7 modular — Phase 7/8)
│   ├── frontend/                  # 3 skills
│   ├── go/                        # 34 skills
│   ├── implementing-changes/      # 1 skill (v2.7 modular — Phase 4)
│   ├── karpathy-guidelines/       # 1 skill
│   ├── methodology/               # 4 skills
│   ├── planning-implementation/   # 1 skill (v2.7 modular — Phase 2/3)
│   ├── project/                   # 2 skills
│   ├── project-workflow/          # 1 skill (shared base)
│   ├── project-workflow-claude/   # 1 skill (v2.7 modular orchestrator) + references/
│   ├── ralph/                     # 1 skill
│   ├── ralplan/                   # 1 skill
│   ├── reviewing-implementation/  # 1 skill (v2.7 modular — Phase 5)
│   ├── tools/                     # 2 skills
│   ├── ultrawork/                 # 1 skill
│   ├── verifying-completion/      # 1 skill (v2.7 modular — Phase 6)
│   └── vue/                       # 8 skills
├── .claude/
│   ├── context/knowledge.md       # Generated analysis cache (this file)
│   ├── state/                     # Pipeline state files (workflow-state.json, task-intake.json, etc.)
│   ├── plans/                     # Phase 2 implementation plans
│   └── specs/                     # Phase 1 design specs
├── ~/.claude/workflows/           # Pipeline scripts (installed by install.sh)
│   ├── phase3-consensus.js        # Judge Panel: 3-angle parallel review
│   ├── phase4-implement.js        # Parallel implementation pipeline
│   ├── phase5-review.js           # Per-task two-stage review pipeline
│   └── phase6-verify.js           # Iron Law verification loop
├── tests/                         # Repository-level test scripts
├── CONTEXT.md                     # Durable context contract (2-layer markers)
├── CLAUDE.md                      # Project Claude Code config (AUTO blocks)
├── SETUP.md                       # AI agent install guide
└── install.sh                     # Bootstrap/install script
```

## Skill Categories (84 total, 23 directories)

| # | Category | Skills | Type |
|---|----------|--------|------|
| 1 | analyze | 1 | Engineering |
| 2 | code-review | 1 | Engineering |
| 3 | deep-interview | 1 | Engineering |
| 4 | designing-solutions | 1 | Workflow (v2.7 modular) |
| 5 | detecting-environment | 1 | Workflow (v2.7 modular) |
| 6 | engineering | 15 | Engineering |
| 7 | finishing-development | 1 | Workflow (v2.7 modular) |
| 8 | frontend | 3 | Frontend |
| 9 | go | 34 | Language (Go) |
| 10 | implementing-changes | 1 | Workflow (v2.7 modular) |
| 11 | karpathy-guidelines | 1 | Behavioral |
| 12 | methodology | 4 | Methodology |
| 13 | planning-implementation | 1 | Workflow (v2.7 modular) |
| 14 | project | 2 | Project-specific |
| 15 | project-workflow | 1 | Workflow (base) |
| 16 | project-workflow-claude | 1 | Workflow (orchestrator) |
| 17 | ralph | 1 | Agent mode |
| 18 | ralplan | 1 | Planning mode |
| 19 | reviewing-implementation | 1 | Workflow (v2.7 modular) |
| 20 | tools | 2 | Tool integration |
| 21 | ultrawork | 1 | Execution engine |
| 22 | verifying-completion | 1 | Workflow (v2.7 modular) |
| 23 | vue | 8 | Language (Vue) |

### Go skills (34) — Full Inventory

**Core Language & Patterns (12):** golang-benchmark, golang-cli, golang-code-style, golang-concurrency, golang-context, golang-data-structures, golang-design-patterns, golang-error-handling, golang-naming, golang-safety, golang-structs-interfaces, golang-testing

**Ecosystem & Libraries (8):** golang-database, golang-dependency-injection, golang-dependency-management, golang-documentation, golang-grpc, golang-observability, golang-popular-libraries, golang-project-layout

**samber Libraries (7):** golang-samber-do, golang-samber-hot, golang-samber-lo, golang-samber-mo, golang-samber-oops, golang-samber-ro, golang-samber-slog

**Quality & CI (4):** golang-continuous-integration, golang-modernize, golang-security, golang-stretchr-testify

**Operations & Learning (3):** golang-performance, golang-stay-updated, golang-troubleshooting

### Vue skills (8) — Full Inventory

vue-best-practices, vue-debug-guides, vue-jsx-best-practices, vue-options-api-best-practices, vue-pinia-best-practices, vue-router-best-practices, vue-testing-best-practices, create-adaptable-composable

### Engineering skills (15) — Full Inventory

caveman (simplicity), diagnose (troubleshooting), grill-me (requirements), grill-with-docs (doc-augmented grill), handoff (task handoff), improve-codebase-architecture, prototype, setup-matt-pocock-skills, strategic-thinking, tdd, to-issues, to-prd, triage, write-pr-description, zoom-out

### Methodology skills (4) — Full Inventory

api-design-first, data-model-first, error-taxonomy, prior-research

### Tool skills (2) — Full Inventory

context7-docs (Context7 MCP integration), firecrawl-web (Firecrawl MCP integration)

## Reference Dependencies

The `project-workflow-claude` skill has 7 reference files:

| Reference | Role |
|-----------|------|
| `references/claude-routing.md` | Claude Code platform-specific signal-to-action/skill routing overlay |
| `references/iron-law.md` | Verification discipline: Gate Function, Red Flags, Rationalization Prevention, TDD Red-Green, Agent Delegation Verification |
| `references/context-md-spec.md` | Canonical CONTEXT.md format specification v1.0 (two-layer markers, evidence tags, update rules) |
| `references/workflow-state-contract.md` | State file schema, field ownership, resume behavior |
| `references/transition-rules.md` | Skill pipeline order, legacy phase mapping, auto-transition conditions, escape hatches |
| `references/handoff-contract.md` | Full workflow vs standalone mode, handoff table with next-step recommendations |
| `references/setup.md` | Recommended MCP servers (Context7, Firecrawl), fallback behavior, DeepSeek API notes |

## Workflow Script Architecture

### phase3-consensus.js
- **Role**: Judge Panel — 3-angle parallel plan review (architecture, risk, feasibility)
- **Input**: `{planContent, contextSummary?, taskIntakeSnapshot?, grillSummary?, tasks?}`
- **Output**: `{verdict: APPROVE|ITERATE|REJECT, score, findings, contextWarnings, taskContractWarnings}`
- **Key logic**: Parallel 3-judge review with JUDGE_SCHEMA (score 1-10, findings, verdict). Pre-check rejection for task contract violations (mutating tasks without patchBackStrategy), scope contradictions, unresolved ambiguities. Synthesis agent merges reviews.

### phase4-implement.js
- **Role**: Parallel implementation via `pipeline()` — one agent per task
- **Input**: `{tasks: [{id, prompt, files, complexity, mutatesFiles, contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, patchBackStrategy}]}`
- **Output**: `{total, passed, failed, selfReviewStatus: [{taskId, status, concerns, changedFiles, ...}]}`
- **Key logic**: 3-stage pipeline — Stage 1 (Implement: agent per task with isolation strategy), Stage 2 (Quick Verify: build + affected tests per task), Stage 3 (Self-Review: DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED). Budget-aware task prioritization. Strategy-driven isolation (worktree/no-isolation/external-report).

### phase5-review.js
- **Role**: Per-task independent pipeline with 5-layer review model, tiered models, context injection, and anti-exploration guardrails (657 lines, 6 new functions)
- **Input**: `{planPath, planText, changedFiles, tasks, selfReviewStatuses, fastGateResults, quickGateResults, grillEvidence}`
- **Output**: `{stage, passed, findings, criticalCount, highCount, finalVerdict, layersApplied, layersSkipped, estimatedTokensSaved}`
- **Key logic**: Per-task independent pipeline — each task flows independently through spec review → code review → adversarial verify. Layer 1 Fast Gate (master bash checks), Layer 2 Spec Review (complexity-gated: simple skips; Haiku default, Sonnet for high-risk), Layer 3 Code Review (complexity-gated: simple skips, medium=correctness-only 1 agent, complex=3-agent parallel; tiered models: correctness=Sonnet, safety=Sonnet, simplicity=Haiku), Layer 4 Adversarial Verify (complexity-gated: simple=auto-confirm, medium=1 skeptic, complex=3 skeptics; all Haiku), Layer 5 Final Review (conditional: skip when <2 tasks or no shared files; Haiku synthesis). Anti-exploration guardrails injected into every review prompt: max 5 file reads, no same file twice, forbidden bash/grep exploration, max 3 thinking blocks. Context injection: spec sections, file contents, grill decisions pre-extracted and injected — agents never read source files. Diff-only code review: pre-computed git diff per task, reviewers only examine changed lines. ~60-70% token savings vs uniform full Sonnet review. Expected wall clock ~8-14min.

### phase6-verify.js
- **Role**: Iron Law verification — analyze failures, fix one pass, return dry-round state
- **Input**: `{projectType, checkResults, dryRounds, evidenceChecks?, quickGateEvidence?, grillEvidencePath?}`
- **Output**: `{allPassed, dryRounds, shouldContinue, phase, remainingFailures}`
- **Key logic**: Filter failures by exitCode !== 0. Two consecutive clean rounds (dryRounds >= 2) = verification complete. Fix pass: pipeline over failures with minimal-change agents. Evidence layer validates file-exists, text-present, text-absent, command-output checks.

## Phase 5 Optimization (v2.6)

Phase 5 was rearchitected from a serial two-stage pipeline into a per-task independent pipeline with tiered model selection, context injection, and anti-exploration guardrails to minimize wall clock time and token consumption.

### Key Optimizations

- **Per-task independent pipeline**: Each task flows independently through spec review → code review → adversarial verify. Task A can complete full review while Task B is still in spec review. Wall clock = max(single task full review time), not sum of all stages.
- **Tiered model selection**: Haiku handles checklist reviews (spec compliance, simplicity, adversarial skeptics, final review). Sonnet handles deep reasoning (correctness analysis, safety review). No Opus usage.
- **Context injection**: Spec sections, file contents, and grill decisions are pre-extracted by the master agent and injected directly into review prompts. Agents never read source files or explore the codebase independently.
- **Anti-exploration guardrails**: Every review prompt injects hard limits — max 5 file reads, no reading same file twice, forbidden bash/grep exploration, max 3 thinking blocks.

### 5-Layer Review Model

| Layer | Name | Gates | Model | Agent Calls |
|-------|------|-------|-------|-------------|
| Layer 1 | Fast Gate | Strongly Recommended: master bash checks | N/A (bash) | 0 |
| Layer 2 | Spec Review | simple skips, medium/complex runs | Haiku (default) / Sonnet (high-risk) | 0-1 per task |
| Layer 3 | Code Review | simple skips, medium=correctness-only, complex=full 3-agent | Correctness/Safety: Sonnet, Simplicity: Haiku | 0-3 per task |
| Layer 4 | Adversarial Verify | simple=auto-confirm, medium=1 skeptic, complex=3 skeptics | Haiku | 0-3 per CRITICAL finding |
| Layer 5 | Final Review | skip when <2 tasks or no shared files | Haiku | 0-1 |

**Token savings**: ~60-70% vs uniform full Sonnet review. **Wall clock**: ~8-14min (down from ~39min).

### phase5-review.js Architecture (657 lines, 6 new functions)

New functions introduced in v2.6:
- `runPerTaskPipeline()` — orchestrates independent per-task review flow
- `buildSpecReviewPrompt()` — constructs spec compliance prompt with injected context
- `buildCodeReviewPrompt()` — constructs code quality prompt with pre-computed diff
- `buildAdversarialPrompt()` — constructs skeptic verification prompt
- `injectAntiExplorationGuardrails()` — adds hard limits to every review prompt
- `synthesizeFinalReview()` — cross-task consistency synthesis (Haiku only)



```
detecting-environment (Phase 0/0.3/0.5) → designing-solutions (Phase 1) → planning-implementation (Phase 2/3) → implementing-changes (Phase 4/4.5/4.6) → reviewing-implementation (Phase 5) → verifying-completion (Phase 6) → finishing-development (Phase 7/8)
```

## v2.7 Modular Architecture

project-workflow-claude v2.7 uses a thin orchestrator (227 lines) + 7 independent execution skills (125-191 lines each). The master agent is a supervisor — it routes, monitors, and transitions, but never implements directly.

| Plane | Role | What Lives Here |
|-------|------|----------------|
| **Control Plane** | Route, supervise, transition | `skills/project-workflow-claude/SKILL.md` — routing logic, delegation rules, global rules, escape hatches |
| **Execution Plane** | Do the work | 7 child skills — detect, design, plan, implement, review, verify, finish |

All 7 child skills support two modes: full workflow (`handoffPolicy=auto-continue`, auto-transition to next) and standalone (`handoffPolicy=prompt-next-step`, prompt user for next action).

## Delegation Model

Master agent is a SUPERVISOR only. All file modifications MUST be delegated to subagents:
- Read, search, plan, design → Master agent
- Skill loading → Master agent
- Shell commands (Bash) → Master agent
- CRITICAL: File writing → Subagent ONLY (Agent, general-purpose)
- Multi-file implementation → Subagent pipeline
- Knowledge/spec/plan file write → Subagent

## Verification Patterns

- **Skills Repository checks**: Phase count verification, YAML frontmatter spot-check, TODO/FIXME scan, git whitespace check, reference file existence verification
- **Iron Law**: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE. Gate Function: IDENTIFY → RUN → READ → VERIFY → ONLY THEN claim.
- **Dry-round loop**: Two consecutive clean rounds required for Phase 6 completion. Safety cap: 10 invocations.

## Confidence

| Claim | Confidence | Basis |
|-------|-----------|-------|
| Skill count: 84 | High | `find skills -name "SKILL.md" -type f | wc -l` |
| Category count: 23 | High | `ls -d skills/*/` |
| Go skills: 34 | High | Directory listing of skills/go/ |
| Vue skills: 8 | High | Directory listing of skills/vue/ |
| Engineering skills: 15 | High | Directory listing of skills/engineering/ |
| Modular execution skills: 7 | High | Directory listing of skills/{detecting-environment,designing-solutions,planning-implementation,implementing-changes,reviewing-implementation,verifying-completion,finishing-development}/ |
| Workflow scripts: 4 | High | `ls ~/.claude/workflows/phase*.js` |
| Reference files: 7 | High | Directory listing of skills/project-workflow-claude/references/ |
| Orchestrator: v2.7 thin control plane (227 lines) | High | `wc -l skills/project-workflow-claude/SKILL.md` |
| No compiled language | High | No go.mod, package.json, or other language markers found |
| AUTO markers in CLAUDE.md: well-formed | High | Verified by direct inspection of CLAUDE.md |
