# jessy-skills — Codex Branch

This branch is Codex-only. For Claude Code or Hermes workflows, switch to the corresponding branch before installing or editing skills.

This repository provides a Codex-native engineering workflow plus reusable domain skills for Go, Vue, frontend work, methodology, reviews, and tool integrations. The Codex workflow uses a thin `project-workflow-codex` entry skill, seven execution skills, and Codex subagents.

## Quick Install

```bash
git clone https://github.com/JessyHHH/jessy-skills.git
cd jessy-skills
git switch codex
bash install.sh
```

Optional tool CLIs:

```bash
npm install -g ctx7@latest firecrawl-cli@latest
ctx7 login
firecrawl login
```

`ctx7` is recommended for current library, SDK, API, CLI, and cloud-service documentation. Firecrawl is optional for web research when available.

## What Install Does

`install.sh` is Codex-only on this branch:

- Syncs this repository snapshot to `~/.jessy-skills-codex`.
- Exposes only the Codex entry skills through `~/.agents/skills/jessy-skills`:
  - `project-workflow-codex`
  - `karpathy-guidelines`
- Keeps the full skill snapshot at `~/.jessy-skills-codex/skills` for explicit workflow loading.
- Installs repo-managed Codex custom agent templates from `codex/agents/*.toml` to `~/.codex/agents`.
- Does not overwrite `~/.codex/AGENTS.md`.
- Does not install Claude Code or Hermes skills.

Restart Codex after install so `AGENTS.md`, skill discovery, and custom agents are reloaded.

## Workflow Shape

| Phase | Codex Skill |
| --- | --- |
| Entry | `project-workflow-codex` |
| 0 / 0.3 / 0.5 | `detecting-environment` |
| 1 | `designing-solutions` |
| 2 / 3 | `planning-implementation` |
| 4 / 4.5 / 4.6 | `implementing-changes` |
| 5 | `reviewing-implementation` |
| 6 | `verifying-completion` |
| 7 / 8 | `finishing-development` |

Codex state lives under `.codex/`:

- `.codex/state/`
- `.codex/context/knowledge.md`
- `.codex/specs/`
- `.codex/plans/`

`CONTEXT.md` remains the root durable context artifact with Knowledge and Instruction layers.

## Codex Subagents

Codex supports subagent workflows with custom agents and `/agent` thread inspection. This branch uses that model directly:

- The main Codex session owns routing, state, integration, and final claims.
- Subagents own bounded exploration, implementation, review, test, or verification work.
- The main session may inspect `/agent`, steer active subagents, stop stuck subagents, and close completed threads.
- Parallel write work is allowed only for disjoint file sets.
- Fresh local verification is required before completion claims.

Repo-managed agent templates:

| Agent | Purpose | Model |
| --- | --- | --- |
| `executor`, `worker`, `test-engineer`, `build-fixer`, `debugger` | execution, tests, repair, debugging | `gpt-5.3-codex` |
| `code-reviewer`, `verifier` | review and completion verification | `gpt-5.4-mini` |

The main Codex model is configured outside this repo, typically in `~/.codex/config.toml`.

## Included Skills

Workflow skills:

- `project-workflow-codex`
- `detecting-environment`
- `designing-solutions`
- `planning-implementation`
- `implementing-changes`
- `reviewing-implementation`
- `verifying-completion`
- `finishing-development`
- `karpathy-guidelines`

Reusable domain skills remain available in the full snapshot and are loaded by workflow routing when relevant:

- Go skills under `skills/go/`
- Vue skills under `skills/vue/`
- frontend skills under `skills/frontend/`
- engineering and methodology skills
- review, analysis, planning, and repair helpers
- tool skills, including `sync-ccswitch-config-codex`

## cc-switch Sync

Use `sync-ccswitch-config-codex` to sync shared Codex configuration from `~/.codex/config.toml` into cc-switch `common_config_codex`.

The Codex sync is add-only by default, excludes provider/auth secrets, and does not sync hooks unless explicitly requested with `--include-hooks`.

## Verification

After changing this repository:

```bash
git diff --check
bash tests/test-*.sh
python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/project-workflow-codex
```

Run `quick_validate.py` on every changed skill folder. For helper scripts, run representative dry-runs such as:

```bash
python3 skills/sync-ccswitch-config-codex/scripts/sync_config.py --dry-run
```
