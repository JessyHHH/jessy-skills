⚠️ Auto-generated | Commit: 768847d | Date: 2026-06-09 | skills-repository

<!-- KNOWLEDGE_START -->
## Architecture
[auto] Monorepo of AI Agent skills, each under `skills/*/SKILL.md` using the agentskills.io YAML frontmatter open standard.
[confirmed] Core workflow: `project-workflow-claude` + `karpathy-guidelines` — an 11-phase self-driving pipeline with Hard Gates and Iron Law.
[auto] Workflow automation scripts reside in `.claude/workflows/` (phase{3,4,5,6}-*.js).
[auto] Installation via `bash install.sh`; verification via `bash tests/test-*.sh`.

## Entity Map
- **Skill**: A self-contained AI capability defined by `skills/<name>/SKILL.md` with YAML frontmatter (name, description, version, metadata) and a body of operational instructions.
- **Workflow Script**: Deterministic JS scripts (`.claude/workflows/phase*-*.js`) that drive the project-workflow-claude pipeline phases.
- **Reference**: Supplementary documentation under `skills/<name>/references/` consumed by skills at runtime.
- **Test**: Shell scripts under `tests/` that verify repository integrity (YAML frontmatter compliance, file structure, etc.).

## Entities
| Entity | Location | Description |
|--------|----------|-------------|
| Skills (77) | `skills/*/SKILL.md` | AI Agent skill definitions |
| Workflow scripts | `.claude/workflows/phase{3,4,5,6}-*.js` | Pipeline phase automation |
| Install script | `install.sh` | Repository setup/bootstrap |
| Tests | `tests/test-*.sh` | Integrity verification |
| Project root | `/Users/jessyhuang/Documents/jessy-skills` | Canonical workspace path |

## Key Interfaces
[auto] `SKILL.md` files follow the agentskills.io open standard: YAML frontmatter with `name`, `description`, `version`, `metadata` fields, followed by markdown body.
[auto] Workflow scripts consume JSON args from the Workflow tool and return structured results for pipeline handoff.

## Package Map
- `skills/` — Skill definitions (flat directory, one subdirectory per skill)
- `.claude/workflows/` — Pipeline phase automation scripts
- `.claude/skills/` — Installed skill copies used at runtime
- `.claude/context/` — Generated analysis cache (knowledge.md)
- `.claude/state/` — Pipeline runtime state (grill-evidence.json)
- `.claude/plans/` — Implementation plans
- `.claude/specs/` — Design specifications
- `tests/` — Repository-level test scripts

## Confidence
[auto] Architecture and entity structure: High (verified via direct file inspection).
[auto] Workflow script count: High (confirmed by directory listing).
[auto] Skill count (77): High (confirmed by directory listing — 16 top-level dirs, 77 SKILL.md files).
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

## Invariants
[confirmed] Do not update unrelated skills when making changes to `project-workflow-claude`.
[auto] Workflow scripts must remain deterministic (no external network calls, no random number generation).

## Domain Glossary
- **Iron Law**: No completion claims without fresh verification evidence.
- **Hard Gates**: Non-negotiable quality checkpoints in the 11-phase pipeline.
- **Phase**: A discrete step in the project-workflow-claude pipeline (Environment Detection, Design, Plan, Judge Panel, Parallel Implement, Per-Task Review, Loop-Until-Dry Verify, etc.).
<!-- INSTRUCTION_END -->
