# Codex Workflow

This directory documents the Codex-native workflow branch for this repository.

The Claude Code workflow uses `Skill(...)` plus `Workflow(...)` JavaScript scripts. The Codex workflow uses the same shared skills root but replaces Claude Workflow scripts with Codex agents:

```text
Control plane: main Codex agent
Execution plane: Codex executor/reviewer/verifier agents
State: .codex/state/
Plans: .codex/plans/
```

Entry point: `skills/project-workflow-codex/SKILL.md`.

## Phase Map

| Phase | Codex-native action |
| --- | --- |
| 0 | Discover branch, dirty files, project shape |
| 0.3 | Refresh `.codex/context/knowledge.md` when needed |
| 0.5 | Route Codex skills and optional domain skills |
| 1 | Clarify scope only where local evidence is insufficient |
| 2 | Write `.codex/plans/*-codex-plan-*.md` |
| 3 | Preflight the plan contract |
| 4 | Spawn Codex agents for bounded execution tasks |
| 5 | Review spec compliance, then code quality |
| 6 | Verify with fresh commands and semantic checks |
| Final | Audit diff and report `PASS`, `PASS_WITH_RISK`, or `FAIL` |

## Install

`install.sh` first copies this repository into a Codex snapshot, then links the snapshot for Codex discovery:

```text
~/.jessy-skills-codex/skills
~/.agents/skills/jessy-skills -> ~/.jessy-skills-codex/skills
~/.codex/agents/*.toml
```

That keeps global Codex skills stable when the working repo switches branches. Re-running `install.sh` overwrites the snapshot, refreshes only the managed skill symlink, and overwrites only the repo-managed Codex agent templates.

## Agent Templates

This repository ships native Codex agent templates in `codex/agents/`. `install.sh` copies them to `~/.codex/agents/` when the `codex` CLI is available.

| Agent | Purpose | Model |
| --- | --- | --- |
| `executor`, `worker`, `test-engineer`, `build-fixer`, `debugger` | Execution, implementation, documentation edits, tests, build fixes, debugging | `gpt-5.3-codex` |
| `code-reviewer`, `verifier` | Code review and plan/completion verification | `gpt-5.4-mini` |

These templates do not depend on hooks, OMX, or oh-my-codex. They only control spawned Codex agents. Keep the main Codex session model in your own `~/.codex/config.toml`; this workflow expects the main model to be `gpt-5.5`.

## Skill Compatibility

Codex loads skills from the shared `skills/` repository, but its workflow entry point is `project-workflow-codex`. `project-workflow` remains the Hermes workflow and is not automatically used by Codex unless explicitly invoked.

Keep Codex-facing `SKILL.md` frontmatter simple:

```yaml
---
name: example-skill
description: "Use when Codex should ..."
---
```

Run the validator after changing a skill:

```bash
python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py <skill-dir>
```
