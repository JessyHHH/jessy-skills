<!-- ⚠️ Auto-generated | Commit: 08a4c0f | Date: 2026-06-08 | Skills Repository -->
<!-- Phase 0.3: Agent analysis — full overwrite on change -->

## Architecture
[auto] Monorepo of AI Agent skills (16 top-level dirs, 77 SKILL.md files) under `skills/*/SKILL.md` using agentskills.io YAML frontmatter standard.
[auto] Core workflow: `project-workflow-claude` (v2.3) + `karpathy-guidelines` — 11-phase self-driving pipeline with Hard Gates and Iron Law.
[auto] Workflow automation scripts in `.claude/workflows/` (phase3-consensus, phase4-implement, phase5-review, phase6-verify) — deterministic JS orchestrators.
[auto] Installation via `bash install.sh`; verification via `bash tests/test-*.sh`.

## Entity Map
- **Skill**: A self-contained AI capability defined by `skills/<name>/SKILL.md` with YAML frontmatter (name, description, version) and markdown body of operational instructions.
- **Workflow Script**: Deterministic JS scripts (`.claude/workflows/phase*-*.js`) that drive the project-workflow-claude pipeline phases 3–6.
- **Reference**: Supplementary documentation under `skills/<name>/references/` consumed by skills at runtime.
- **Test**: Shell scripts under `tests/` that verify repository integrity.

## Entities
| Entity | Location | Description |
|--------|----------|-------------|
| Skills (77) | `skills/*/SKILL.md` | AI Agent skill definitions |
| Workflow scripts (4) | `.claude/workflows/phase{3,4,5,6}-*.js` | Pipeline phase automation |
| Install script | `install.sh` | Repository setup/bootstrap |
| Tests | `tests/test-*.sh` | Integrity verification |

## Key Interfaces
[auto] `SKILL.md` files follow the agentskills.io open standard: YAML frontmatter with `name`, `description`, `version` fields, followed by markdown body.
[auto] Workflow scripts use `export const meta = {...}` for registration and consume JSON args from the Workflow tool.
[auto] `install.sh` copies skills to ~/.hermes/skills/ and ~/.claude/skills/, and workflow scripts to ~/.claude/workflows/.

## Package Map
- `skills/` — Skill definitions (flat directory, one subdirectory per skill)
- `.claude/workflows/` — Pipeline phase automation scripts (4 JS files)
- `.claude/skills/` — Symlink to ../skills
- `.claude/context/` — Generated analysis cache (knowledge.md)
- `.claude/plans/` — Implementation plans
- `.claude/specs/` — Design specifications
- `.claude/state/` — Pipeline runtime state (grill-evidence.json)
- `tests/` — Repository-level test scripts
- `shell/` — Shell integration (hermes.sh)

## Confidence
[auto] Architecture and entity structure: High (verified via direct file inspection).
[auto] Workflow script count 4: High (confirmed by directory listing).
[auto] Skill count 16: High (directory listing, confirmed).
