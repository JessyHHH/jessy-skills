<!-- ⚠️ Auto-generated | Commit: fd32e81a3fb617312a13a59403dd089c51a2e814 | Date: 2026-06-18 | skills-repository -->

<!-- KNOWLEDGE_START -->
## Architecture
[auto] Monorepo of 86 AI Agent skills, each defined under `skills/*/SKILL.md` using the agentskills.io YAML frontmatter open standard. 23 top-level category directories organize skills by domain.
[confirmed] Core workflow: `project-workflow-claude` v2.9 modular orchestrator + 7 execution skills + `karpathy-guidelines` — a thin control plane that delegates to independent execution skills with Hard Gates and Iron Law. All phases use Agent() direct dispatch (no Workflow scripts); Master supervises all sub-agent dispatch and makes all decisions.
[auto] No Workflow scripts — v2.9 removed all `~/.claude/workflows/phase*.js` files (-1405 lines). Execution skills use Agent() directly: Phase 3 (3 parallel Judge agents + synthesis), Phase 4 (serial implement→verify→self-review), Phase 5 (serial spec→code→adversarial), Phase 6 (Bash + Agent fix loop-until-dry).
[auto] Installation via `bash install.sh` (snapshot to ~/.jessy-skills-claude/ + symlink to ~/.claude/skills/); verification via `bash tests/test-*.sh`.
[auto] Platform overlay: `skills/project-workflow-claude/references/claude-routing.md` maps Claude Code-specific task signals to Skill(skill='...') routing. Two-step intelligent skill selection: mechanical candidate pool (project + global skills) → Master judgment filter.

## Entity Map
- **Skill**: A self-contained AI capability defined by `skills/<name>/SKILL.md` with YAML frontmatter (name, description, version, metadata) and operational instructions in markdown body.
- **Agent Dispatch**: v2.9 execution model — Master dispatches `Agent()` directly (no Workflow scripts). Phase 3: parallel Judge agents. Phase 4/5: serial per-task agents. Phase 6: Bash + Agent fix loop.
- **Reference**: Supplementary documentation under `skills/<name>/references/` consumed by skills at runtime (e.g., `claude-routing.md`, `iron-law.md`, `context-md-spec.md`).
- **Test**: Shell scripts under `tests/` that verify repository integrity (YAML frontmatter compliance, file structure, reference existence).
- **Context Artifact**: Three-tier model — root `CONTEXT.md` (durable, human+machine), `.claude/context/knowledge.md` (machine-generated analysis cache, full overwrite), and optional scoped subdirectory `CONTEXT.md` files.

## Entities
| Entity | Location | Description |
|--------|----------|-------------|
| Skills (85) | `skills/*/SKILL.md` | AI Agent skill definitions across 23 categories |
| Modular execution skills (7) | `skills/{detecting-environment,designing-solutions,planning-implementation,implementing-changes,reviewing-implementation,verifying-completion,finishing-development}/SKILL.md` | v2.9 thin orchestrator delegation targets — all use Agent() direct dispatch |
| State contracts | `skills/project-workflow-claude/references/{workflow-state-contract,transition-rules,handoff-contract}.md` | Modular skill baton-pass contracts |
| Install script | `install.sh` | Repository setup/bootstrap with global sync. Symlink-only to ~/.claude/skills, preserves external plugins. |
| Tests | `tests/test-*.sh` | Integrity verification scripts + regression probes (workflow parse, controlled edit) |
| Context spec | `skills/project-workflow-claude/references/context-md-spec.md` | Canonical CONTEXT.md format specification v1.0 |
| Routing overlay | `skills/project-workflow-claude/references/claude-routing.md` | Claude Code platform-specific signal routing |
| Iron Law | `skills/project-workflow-claude/references/iron-law.md` | Verification discipline (NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE) |
| CLAUDE.md | `CLAUDE.md` | Project-level Claude Code configuration with AUTO blocks |
| Project root | `/home/huangzexi/personal/jessy-skills` | Canonical workspace path |

## Key Interfaces
[auto] `SKILL.md` files follow the agentskills.io open standard: YAML frontmatter with `name`, `description`, `version`, `metadata` fields, followed by markdown body with operational instructions.
[auto] Execution skills use `Agent()` dispatch with JSON Schema for structured output (`JUDGE_SCHEMA`, `REVIEW_SCHEMA`, `SPEC_SCHEMA`, `SKEPTIC_SCHEMA`). Master reads agent results and makes all decisions (APPROVE/ITERATE/REJECT/RETRY/BLOCKED).
[auto] CONTEXT.md uses two-layer marker structure: `<!-- KNOWLEDGE_START -->`/`<!-- KNOWLEDGE_END -->` (machine-managed facts) and `<!-- INSTRUCTION_START -->`/`<!-- INSTRUCTION_END -->` (human-managed guidance). All claims tagged `[confirmed]` or `[auto]`.
[auto] CLAUDE.md uses `<!-- AUTO_START: <Section> -->`/`<!-- AUTO_END: <Section> -->` markers for machine-managed blocks.

## Package Map
- `skills/` — 86 skill definitions in 23 category directories (flat within each category)
- `skills/analyze/` — 1 skill: repository analysis
- `skills/code-review/` — 1 skill: comprehensive code review
- `skills/deep-interview/` — 1 skill: Socratic deep interview
- `skills/engineering/` — 15 skills: caveman, diagnose, grill-me, grill-with-docs, handoff, improve-codebase-architecture, prototype, setup-matt-pocock-skills, strategic-thinking, tdd, to-issues, to-prd, triage, write-pr-description, zoom-out
- `skills/frontend/` — 3 skills: Anthropic frontend design, webapp testing, web artifacts builder
- `skills/go/` — 34 skills: benchmark, cli, code-style, concurrency, context, continuous-integration, database, data-structures, dependency-injection, dependency-management, design-patterns, documentation, error-handling, grpc, modernize, naming, observability, performance, popular-libraries, project-layout, safety, samber-do/hot/lo/mo/oops/ro/slog, security, stay-updated, stretchr-testify, structs-interfaces, testing, troubleshooting
- `skills/karpathy-guidelines/` — 1 skill: behavioral guidelines (Think Before Coding, Surgical Changes, Verify Before Asserting, etc.)
- `skills/methodology/` — 4 skills: api-design-first, data-model-first, error-taxonomy, prior-research
- `skills/project/` — 2 skills: jessy-self-iterate, mixclaw-cron-review
- `skills/project-workflow/` — 1 skill: shared base workflow (language-agnostic)
- `skills/project-workflow-claude/` — 1 skill: Claude Code-specific workflow (v2.9 modular orchestrator + 7 execution skills, Agent() direct dispatch) with 8 references/
- `skills/ralph/` — 1 skill: Ralph agent mode
- `skills/ralplan/` — 1 skill: Ralplan planning mode
- `skills/tools/` — 3 skills: context7-docs, firecrawl-web, sync-ccswitch-config
- `skills/ultrawork/` — 1 skill: parallel execution engine
- `skills/vue/` — 8 skills: create-adaptable-composable, vue-best-practices, vue-debug-guides, vue-jsx-best-practices, vue-options-api-best-practices, vue-pinia-best-practices, vue-router-best-practices, vue-testing-best-practices
- `~/.claude/workflows/` — Pipeline phase automation scripts (installed by install.sh)
- `.claude/context/` — Generated analysis cache (knowledge.md)
- `.claude/state/` — Pipeline runtime state (grill-evidence.json)
- `.claude/plans/` — Implementation plans
- `.claude/specs/` — Design specifications
- `tests/` — Repository-level test scripts

## Confidence
[auto] Architecture and entity structure: High (verified via direct file inspection of 86 SKILL.md files across 23 directories).
[auto] Skill count (85): High (confirmed by `find skills -name "SKILL.md" -type f | wc -l`).
[auto] Workflow script count (0): High — v2.9 removed all `.claude/workflows/phase*.js` files. Execution skills use Agent() direct dispatch.
[auto] Category breakdown: High (verified by directory traversal of skills/ tree).
<!-- KNOWLEDGE_END -->

<!-- INSTRUCTION_START -->
## Build & Test Commands
[confirmed] Verify repository: `bash tests/test-*.sh`
[confirmed] Lint git changes: `git diff --check`
[confirmed] Install/refresh skills: `bash install.sh`

## Code Conventions
[confirmed] All `SKILL.md` files follow the agentskills.io YAML frontmatter open standard.
[confirmed] Design before code, fresh evidence before claims.
[confirmed] Two-Stage Review: spec compliance first, then code quality — never reverse.
[confirmed] Auto-transition pipeline phases; never wait for user prompt.
[confirmed] Phase 1 Grill: variable-depth (Ambiguity Register + Assumption Ledger), Hard Grill Checklist with mandatory PASS/FAIL printout.

## Invariants
[confirmed] Do not update unrelated skills when making changes to `project-workflow-claude`.
[auto] Master agent is a SUPERVISOR and sole decision-maker — all file modifications MUST be delegated to subagents. All APPROVE/ITERATE/REJECT/RETRY/BLOCKED verdicts come from Master.
[auto] Intelligent skill selection: two-step routing — mechanical candidate pool (project + global skills) → Master judgment filter to select only task-relevant skills.

## Domain Glossary
- **Iron Law**: No completion claims without fresh verification evidence. Evidence before claims, always.
- **Hard Gates**: Non-negotiable quality checkpoints in the 11-phase pipeline (Phase 0.3 freshness check, Phase 1 design approval, Phase 5 two-stage review, Phase 6 Iron Law verification).
- **Phase**: A discrete step in the project-workflow-claude pipeline. Modular skills: detecting-environment (Phase 0/0.3/0.5), designing-solutions (Phase 1), planning-implementation (Phase 2/3), implementing-changes (Phase 4/4.5/4.6), reviewing-implementation (Phase 5), verifying-completion (Phase 6), finishing-development (Phase 7/8).
- **Agent Dispatch**: v2.9 execution model — Master dispatches Agent() directly. Phase 3: 3 parallel Judge agents + synthesis. Phase 4: serial implement→verify→self-review. Phase 5: serial spec→code→adversarial. Phase 6: Bash + Agent fix loop-until-dry.
- **Ambiguity Register**: Live list of unresolved questions during Phase 1 Grill, each with status (open/answered/assumed/deferred-out-of-scope), impact, recommended answer, and decision.
- **Assumption Ledger**: Tracked list of allowed assumptions during Phase 1, each with evidence, confidence (High/Medium/Low), and correction/rollback path.
- **Grill**: Variable-depth requirements crystallization process in Phase 1 with mandatory Hard Grill Checklist before exit.
<!-- INSTRUCTION_END -->
