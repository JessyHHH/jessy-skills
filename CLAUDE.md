<!-- ⚠️ Auto-generated | Commit: 81e2b8debd28eed74b25c1c548b3574c4fb5b41f | Date: 2026-06-10 | Skills Repository -->

# jessy-skills — Claude Code Configuration

## Project
<!-- AUTO_START: Project -->
Skills Repository — 77 AI Agent skills (Go/Vue/Engineering/…)
Core workflow: `project-workflow-claude` v2.6 + `karpathy-guidelines`
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
- Workflow scripts: harness-managed isolation; no-impossible-patch-back

## Project Knowledge
Architecture analysis: [.claude/context/knowledge.md](.claude/context/knowledge.md)
Full workflow: load `project-workflow-claude` skill
