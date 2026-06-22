# Codex-Only Workflow Migration Spec

## Goal

Convert the `codex` branch into the Codex-only branch for jessy-skills. The branch should preserve the useful workflow simplifications from the `claude` branch while translating every platform-specific instruction to Codex concepts.

This branch is Codex-only. For Claude Code or Hermes workflows, switch to the corresponding branch before installing or editing skills.

## Locked Decisions

- Modify only the `codex` branch. Treat `claude` and Claude plugin cache files as read-only sources.
- Use `codex` as the base and migrate changes file-by-file. Do not merge `claude` wholesale.
- Remove Claude and Hermes workflow entry points from this branch:
  - root `CLAUDE.md`
  - `.claude/`
  - `skills/project-workflow-claude`
  - `skills/project-workflow`
  - `codex/README.md` after merging useful content into root `README.md`
- Keep common domain skills: Go, Vue, frontend, engineering, methodology, tools, project skills, `ralph`, `ralplan`, `ultrawork`, etc.
- Keep top-level execution skill names aligned with the `claude` branch:
  - `detecting-environment`
  - `designing-solutions`
  - `planning-implementation`
  - `implementing-changes`
  - `reviewing-implementation`
  - `verifying-completion`
  - `finishing-development`
- `project-workflow-codex` is the Codex entry orchestrator. It routes to the seven execution skills and owns state transitions.
- Translate platform terms:
  - `CLAUDE.md` -> `AGENTS.md`
  - `.claude/*` -> `.codex/*`
  - Claude `Agent()` / `Skill()` / `Workflow()` / `AskUserQuestion()` -> Codex skills, subagents, `/agent` inspection/steering, normal user clarification
- Do not create phase Workflow scripts. Flow orchestration lives in skills; scripts only support deterministic helper tasks.
- Follow `$skill-creator` for all modified Codex skills:
  - YAML frontmatter contains only `name` and `description`
  - Keep SKILL.md bodies concise
  - Move detailed procedures to one-level `references/`
  - Put deterministic helpers in `scripts/`
  - Validate changed skill folders with `quick_validate.py`
- Keep Codex skill discovery curated:
  - startup discovery exposes only `project-workflow-codex` and `karpathy-guidelines`
  - full snapshot remains at `~/.jessy-skills-codex/skills`
  - seven execution skills are installed in the full snapshot but not startup discovery
- `install.sh` becomes Codex-only:
  - sync `~/.jessy-skills-codex`
  - link curated discovery to `~/.agents/skills/jessy-skills`
  - install repo-managed `codex/agents/*.toml` to `~/.codex/agents`
  - do not install Hermes or Claude Code skills
  - do not overwrite `~/.codex/AGENTS.md`
- Keep existing `codex/agents/*.toml` models unchanged:
  - execution/test/fix/debug agents use `gpt-5.3-codex`
  - review/verifier agents use `gpt-5.4-mini`
- Sync `grill-me` from the Claude plugin marketplace complete implementation, including `references/` and `scripts/`; do not copy Claude plugin command or persona files.
- Keep `skills/engineering/grill-me` for compatibility. It should point users to top-level `grill-me` or remain a deprecated wrapper.
- Add `sync-ccswitch-config-codex` in the same placement pattern as Claude:
  - `skills/sync-ccswitch-config-codex`
  - `skills/tools/sync-ccswitch-config-codex`
- `sync-ccswitch-config-codex` behavior:
  - read `~/.codex/config.toml`
  - write SQLite `~/.cc-switch/cc-switch.db`, `settings.key='common_config_codex'`
  - target value is TOML text, not JSON
  - add-only merge by default
  - default excludes `[hooks]`
  - `--include-hooks` explicitly includes hooks
  - exclude provider/auth fields such as `model_provider`, `[model_providers]`, `auth`, API keys, tokens, secrets, passwords, provider base URLs

## Expected Files

Expected removals:

- `CLAUDE.md`
- `.claude/`
- `skills/project-workflow-claude/`
- `skills/project-workflow/`
- `codex/README.md`

Expected updates:

- `AGENTS.md`
- `README.md`
- `SETUP.md`
- `install.sh`
- `CONTEXT.md`
- `skills/project-workflow-codex/`
- seven execution skills listed above
- `skills/engineering/grill-me`
- tests that still reference Claude/Hermes workflows

Expected additions:

- `.codex/specs/2026-06-22-codex-only-workflow-migration.md`
- `.codex/plans/2026-06-22-codex-only-workflow-migration-plan.md`
- `skills/grill-me/` with complete `references/` and `scripts/`
- `skills/sync-ccswitch-config-codex/`
- `skills/tools/sync-ccswitch-config-codex/`

## Verification Contract

Run before claiming completion:

- `git diff --check`
- `bash tests/test-*.sh`
- `python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py <changed-skill-dir>` for every changed or added skill folder
- representative `grill-me` script runs
- `python3 skills/sync-ccswitch-config-codex/scripts/sync_config.py --dry-run`
- final `git status --short` and `git diff --stat`

## Non-Goals

- Do not modify the `claude` branch.
- Do not preserve Claude Code or Hermes install behavior in `codex`.
- Do not update Codex agent model choices.
- Do not overwrite user global `~/.codex/AGENTS.md`.
- Do not sync hooks to cc-switch unless `--include-hooks` is passed.
