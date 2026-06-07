# jessy-skills — Codex Configuration

## Project
Skills Repository — 77 AI Agent skills (Go/Vue/Engineering/…)
Core workflow: `project-workflow-codex` + `karpathy-guidelines`

## Essential Commands
- Verify: `bash tests/test-*.sh`
- Lint: `git diff --check`
- Skill check: `head -15 skills/*/SKILL.md` (YAML frontmatter)
- Codex skill link: `test -L .agents/skills && readlink .agents/skills`

## Conventions
- SKILL.md follows agentskills.io open standard
- Design before code, fresh evidence before claims
- Two-Stage Review: spec compliance → code quality (never reverse)
- Auto-transition phases, never wait for user prompt
- Codex contract-first flow lives in `codex/`; concrete Claude handoff contracts go in `.claude/plans/`
- Codex and Claude Code share the same root `skills/`; `.agents/skills` should be a symlink to `../skills`

## Project Knowledge
Architecture analysis: [.codex/context/knowledge.md](.codex/context/knowledge.md)
Full workflow: load `project-workflow-codex` skill
