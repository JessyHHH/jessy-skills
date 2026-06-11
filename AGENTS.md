# jessy-skills - Codex Instructions

## Project

Skills repository for Hermes, Claude Code, and Codex.

- Hermes workflow: `project-workflow`
- Claude Code workflow: `project-workflow-claude`
- Codex workflow: `project-workflow-codex`
- Shared skills root: `skills/`

## Codex Workflow

Use `project-workflow-codex` for project changes that should run through Codex agents instead of Claude Code `Workflow(...)` scripts.

Codex owns planning, agent orchestration, integration, and final audit. Spawned Codex agents own bounded implementation, review, or verification tasks. Do not trust agent success reports without fresh local evidence.

## Essential Commands

- Verify all shell tests: `bash tests/test-*.sh`
- Lint diffs: `git diff --check`
- Validate Codex skill: `python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/project-workflow-codex`
- Check workflow scripts: `bash tests/test-regression-workflow-parse.sh`

## Context7

Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service. Run:

1. `npx ctx7@latest library <name> "<user's question>"`
2. Pick the best `/org/project` match.
3. `npx ctx7@latest docs <libraryId> "<user's question>"`

Run Context7 CLI requests outside Codex's default sandbox when network access is required. If a Context7 command fails with quota errors, tell the user to run `npx ctx7@latest login` or set `CONTEXT7_API_KEY`.
