<!-- ⚠️ Auto-generated | Commit: fd32e81a3fb617312a13a59403dd089c51a2e814 | Date: 2026-06-18 | Skills Repository -->

# jessy-skills — Claude Code Configuration

## Project
<!-- AUTO_START: Project -->
Skills Repository — 85 AI Agent skills (Go/Vue/Engineering/…)
Core workflow: `project-workflow-claude` v2.9 modular orchestrator + 7 execution skills + `karpathy-guidelines`. Agent() direct dispatch — no Workflow scripts.
Context: [CONTEXT.md](CONTEXT.md) — durable context contract (Knowledge + Instruction layers)
Context spec: [context-md-spec.md](skills/project-workflow-claude/references/context-md-spec.md)
<!-- AUTO_END: Project -->

## Essential Commands
<!-- AUTO_START: Commands -->
- Verify: `bash tests/test-*.sh`
- Lint: `git diff --check`
- Skill check: `head -15 skills/*/SKILL.md` (YAML frontmatter)
- Install global sync: `bash install.sh`
<!-- AUTO_END: Commands -->

## Conventions
- SKILL.md follows agentskills.io open standard
- Design before code, fresh evidence before claims
- Two-Stage Review: spec compliance → code quality (never reverse)
- Auto-transition phases, never wait for user prompt
- Phase 1 Grill: variable-depth (Ambiguity Register + Assumption Ledger)
- Agent() direct dispatch: Master supervises all sub-agents, makes all decisions (v2.9)

## Project Knowledge
Architecture analysis: [.claude/context/knowledge.md](.claude/context/knowledge.md)
Full workflow: load `project-workflow-claude` skill
