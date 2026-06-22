# SETUP — Codex Branch

This branch is Codex-only. For Claude Code or Hermes workflows, switch to the corresponding branch before installing or editing skills.

## Prerequisites

- Codex installed: `which codex`
- Git installed: `which git`
- Python 3 available for helper scripts
- Node.js + npm for optional documentation tools

## Install

```bash
git switch codex
bash install.sh
```

The installer:

- syncs this repository to `~/.jessy-skills-codex`
- links curated startup skills at `~/.agents/skills/jessy-skills`
- keeps the full skill snapshot at `~/.jessy-skills-codex/skills`
- copies `codex/agents/*.toml` to `~/.codex/agents`
- does not overwrite `~/.codex/AGENTS.md`
- does not install Claude Code or Hermes skills

Restart Codex after install.

## Optional Tool CLIs

Context7 is recommended because repository instructions require current documentation for library, SDK, API, CLI, and cloud-service questions.

```bash
npm install -g ctx7@latest
ctx7 login
ctx7 whoami
```

Firecrawl is optional for web research:

```bash
npm install -g firecrawl-cli@latest
firecrawl login
firecrawl --status
```

## Verify Install

```bash
ls ~/.jessy-skills-codex/skills/project-workflow-codex/SKILL.md
ls ~/.agents/skills/jessy-skills/project-workflow-codex/SKILL.md
ls ~/.codex/agents/executor.toml
```

In Codex, use `$project-workflow-codex` or `/skills` to start the workflow.

## Update

```bash
cd /path/to/jessy-skills
git switch codex
git pull
bash install.sh
```

Restart Codex after updating.

## Validation For Contributors

```bash
git diff --check
bash tests/test-*.sh
python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/project-workflow-codex
```

Run `quick_validate.py` on every changed or added skill folder.
