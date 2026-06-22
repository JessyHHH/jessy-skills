<!-- Auto-generated | Commit: pending | Date: 2026-06-22 | skills-repository -->

<!-- KNOWLEDGE_START -->
## Architecture
[confirmed] This branch is Codex-only. Claude Code and Hermes workflows live on their corresponding branches.
[confirmed] Codex workflow entry is `skills/project-workflow-codex/SKILL.md`.
[confirmed] The Codex workflow uses seven top-level execution skills: `detecting-environment`, `designing-solutions`, `planning-implementation`, `implementing-changes`, `reviewing-implementation`, `verifying-completion`, and `finishing-development`.
[confirmed] Codex runtime artifacts live under `.codex/`: state, context, specs, and plans.
[confirmed] Root `AGENTS.md` is the Codex instruction file. Root `CLAUDE.md` is not used on this branch.
[confirmed] `CONTEXT.md` is the durable repository context contract. `.codex/context/knowledge.md` is the generated machine cache.
[auto] `install.sh` installs only Codex assets: `~/.jessy-skills-codex`, global `~/.agents/skills/jessy-skills`, and repo-managed `~/.codex/agents/*.toml`.
[auto] Startup skill discovery links the full skill snapshot: `~/.agents/skills/jessy-skills -> ~/.jessy-skills-codex/skills`, so users can manually invoke any installed skill.

## Entity Map
- **Project Workflow Codex**: Thin Codex orchestrator that initializes state, routes to execution skills, supervises subagents, and owns final verification claims.
- **Execution Skills**: Top-level workflow phase skills that keep the same names as the Claude branch but use Codex-only paths and subagent semantics.
- **Codex Subagents**: Custom agents configured in `codex/agents/*.toml` and installed to `~/.codex/agents/`.
- **cc-switch Codex Sync**: `sync-ccswitch-config-codex` syncs safe shared TOML from `~/.codex/config.toml` into SQLite `settings.common_config_codex`.
- **Grill Me**: Top-level `skills/grill-me` provides one-question-at-a-time requirements interrogation with scripts and references.

## Package Map
- `skills/project-workflow-codex/` - Codex workflow entry skill and references.
- `skills/{detecting-environment,designing-solutions,planning-implementation,implementing-changes,reviewing-implementation,verifying-completion,finishing-development}/` - Codex execution skills.
- `skills/grill-me/` - Full grill-me implementation with `references/` and `scripts/`.
- `skills/sync-ccswitch-config-codex/` and `skills/tools/sync-ccswitch-config-codex/` - Codex cc-switch common config sync.
- `codex/agents/` - Repo-managed Codex custom agent templates.
- `tests/` - Shell validation scripts.
<!-- KNOWLEDGE_END -->

<!-- INSTRUCTION_START -->
## Build & Test Commands
[confirmed] Verify repository: `bash tests/test-*.sh`
[confirmed] Lint diff whitespace: `git diff --check`
[confirmed] Validate changed skills: `python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py <skill-dir>`
[confirmed] Dry-run Codex cc-switch sync: `python3 skills/sync-ccswitch-config-codex/scripts/sync_config.py --dry-run`

## Code Conventions
[confirmed] Follow `$skill-creator` for changed skills: frontmatter contains only `name` and `description`.
[confirmed] Keep SKILL.md concise and move details to one-level `references/`.
[confirmed] Deterministic helper code belongs in `scripts/`.
[confirmed] Do not add Claude Code or Hermes platform files on this branch.
[confirmed] Fresh evidence is required before completion claims.

## Invariants
[confirmed] Do not overwrite user global `~/.codex/AGENTS.md`.
[confirmed] Do not sync hooks to cc-switch unless `--include-hooks` is explicitly passed.
[confirmed] Do not change `codex/agents/*.toml` model policy unless explicitly requested.
<!-- INSTRUCTION_END -->
