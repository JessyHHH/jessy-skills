# jessy-skills — Claude Code Configuration

## Project
Skills Repository — 76 AI Agent skills (Go/Vue/Engineering/…)
Core workflow: `project-workflow-claude` + `karpathy-guidelines`

## Essential Commands
- Verify: `bash tests/test-*.sh`
- Lint: `git diff --check`
- Skill check: `head -15 skills/*/SKILL.md` (YAML frontmatter)

## Conventions
- SKILL.md follows agentskills.io open standard
- Design before code, fresh evidence before claims
- Two-Stage Review: spec compliance → code quality (never reverse)
- Auto-transition phases, never wait for user prompt

## Project Knowledge
Architecture analysis: [.claude/context/knowledge.md](.claude/context/knowledge.md)
Full workflow: load `project-workflow-claude` skill
