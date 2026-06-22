# jessy-skills - Codex Instructions

This branch is Codex-only. For Claude Code or Hermes workflows, switch to the corresponding branch before installing or editing skills.

## Project

This repository contains Codex workflow skills and reusable domain skills.

- Codex workflow entry: `project-workflow-codex`
- Root context artifact: `CONTEXT.md`
- Codex state: `.codex/`
- Repo-managed Codex custom agents: `codex/agents/*.toml`

Do not use Claude Code Workflow scripts, Claude Code `CLAUDE.md`, Hermes `project-workflow`, hooks, OMX, or oh-my-codex for this branch.

## Codex Workflow

Use `$project-workflow-codex` for project changes in this repository.

Codex main owns:

- routing and state transitions
- spec and plan integration
- subagent supervision
- final verification and completion claims

Codex subagents own bounded exploration, implementation, review, test, or repair work. Use `/agent` to inspect, steer, stop, or close active subagent threads when needed. Do not trust subagent success reports without fresh local evidence.

## Skill Discovery

Global Codex skill discovery links the full snapshot:

```text
~/.agents/skills/jessy-skills -> ~/.jessy-skills-codex/skills
```

This supports manual `$skill-name` usage. For workflow tasks, still load execution and domain skill bodies only after routing confirms relevance.

## Essential Commands

- Verify all shell tests: `bash tests/test-*.sh`
- Lint diffs: `git diff --check`
- Validate a changed skill: `python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py <skill-dir>`
- Dry-run cc-switch sync: `python3 skills/sync-ccswitch-config-codex/scripts/sync_config.py --dry-run`

## Skill Authoring

When adding or editing skills, follow `$skill-creator`:

- `SKILL.md` frontmatter contains only `name` and `description`.
- Keep `SKILL.md` concise.
- Put detailed workflow material in one-level `references/`.
- Put deterministic helper code in `scripts/`.
- Do not add README, CHANGELOG, or installation docs inside skill folders.
- Run `quick_validate.py` on each changed skill.

## Context7

Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service. Run:

1. `npx ctx7@latest library <name> "<user's question>"`
2. Pick the best `/org/project` match.
3. `npx ctx7@latest docs <libraryId> "<user's question>"`

If Context7 fails with quota errors, tell the user to run `npx ctx7@latest login` or set `CONTEXT7_API_KEY`.

## Firecrawl

For web research, prior search, crawling, page extraction, or site evidence tasks, prefer Firecrawl tools or skills when installed and relevant. Otherwise use available search/browser tools and state the fallback.
