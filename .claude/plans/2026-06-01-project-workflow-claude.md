# Implementation Plan: project-workflow-claude (v2 — Ralplan Iteration 2)

**Date:** 2026-06-01  
**Spec:** `.claude/specs/2026-06-01-project-workflow-claude-design.md`  
**Status:** Final — implemented (Phase 4-6 complete, all verifications passed)  
**Reviewers:** Architect (ITERATE) + Critic (ITERATE) → feedback incorporated

---

## Goal

Create `skills/project-workflow-claude/SKILL.md` — a 9-phase self-driving pipeline for Claude Code, leveraging OMC's ralph/ralplan and Claude Code's Workflow tool. Deploy on `claude` branch while keeping `main` unchanged.

## Context

- **Project:** Skills Repository (76 SKILL.md files)
- **Platform:** Claude Code v2.1.x + OMC v4.14.4 (prerequisite)
- **Branch:** `claude` (reset to main, then build on top)
- **Key decision:** Independent implementation, not universal adapter
- **Existing claude branch:** In-place modified `project-workflow/SKILL.md` (865→358 lines). Rejected — creates merge conflicts with main, prevents independent evolution, makes it unclear which platform a user is on. Separate file is superior.

## Why Not Modify project-workflow/SKILL.md In-Place?

The existing `claude` branch took this approach. We are NOT continuing it because:
1. **Merge conflicts**: Every main-branch update to `project-workflow/SKILL.md` conflicts with Claude Code changes
2. **Independent evolution**: Hermes and Claude Code can each optimize for their platform without stepping on each other
3. **Clear signal**: User sees `project-workflow-claude` skill name and immediately knows which platform
4. **The existing branch proved the friction**: 53 files changed, 4145 lines deleted — mostly from removing Hermes-specific references that should have stayed

## Phase Structure (9 phases, matching Hermes v7.0)

| Phase | Name | Claude Code Implementation |
|-------|------|---------------------------|
| 0 | Environment Detection | Glob + Grep + Bash |
| 0.3 | Codebase Analysis | Agent(Explore) → Write(knowledge.md) |
| 0.5 | Smart Skill Selection | Skill() × N + memory trigger scan |
| 1 | Design First (HARD-GATE) | AskUserQuestion + Write(spec) |
| 2 | Write Plan | Skill("omc-plan") + Write(plan) |
| 3 | Ralplan Consensus | Skill("ralplan") [OMC prerequisite] |
| 4 | Implement | Workflow(pipeline) [KEY UPGRADE] |
| 5 | Two-Stage Review | Agent(spec) → Workflow(parallel reviews) |
| 6 | Verified Completion (Iron Law) | Bash + Skill("ralph") [OMC prerequisite] |
| 7 | Retrospective + Learning | Agent(background) + CronCreate |
| 8 | Finish Branch | Bash(git) + AskUserQuestion |

## CLAUDE.md Design (Revised — Boot Layer Only)

**Max 30 lines.** Does NOT duplicate routing tables. Contains:
1. Project type hint (Skills Repository)
2. Instruction: "For full workflow, load project-workflow-claude"
3. 2-3 project-specific invariants (build/lint commands)
4. Reference to `.claude/context/knowledge.md`

Full routing tables, phase procedures, execution logic → `skills/project-workflow-claude/SKILL.md`.

## Approach

### Step 1: Reset claude branch

```bash
git checkout claude
git reset --hard main
```

### Step 2: Create foundation files

- `CLAUDE.md` (~30 lines, Boot Layer only — no routing tables)
- `.claude/context/knowledge.md` (placeholder)
- `.claude/skills → ../skills` symlink
- `.gitignore` update: `!.claude/context/` (ensure knowledge.md is tracked, not gitignored)

### Step 3: Create project-workflow-claude/SKILL.md

~500 lines covering all 9 phases with Claude Code native APIs.

OMC prerequisite declared in frontmatter:
```yaml
metadata:
  requires: [oh-my-claudecode]
  fallback: "Phase 3/6 use simplified inline consensus/retry without OMC"
```

Skill routing rule (avoids collision with Hermes `project-workflow`):
- `project-workflow` → loads on Hermes (unchanged)
- `project-workflow-claude` → loads on Claude Code (detected via CLAUDE.md presence)

### Step 4: Update install.sh

Additive: installs to BOTH `~/.hermes/skills/` AND `~/.claude/skills/`.
Detects which platform(s) are available:
- `which hermes` → install to `~/.hermes/skills/`
- `which claude` → install to `~/.claude/skills/`
- Both → install to both

### Step 5: Verify on this project + one Go project

1. Phase 0-8 on this Skills Repository
2. Phase 0 at minimum on one Go project (environment detection + skill routing)

## Files

| Action | File | Description |
|--------|------|-------------|
| CREATE | `CLAUDE.md` | Boot Layer (~30 lines), auto-loaded each session |
| CREATE | `.claude/context/knowledge.md` | Knowledge Layer placeholder, Phase 0.3 target |
| CREATE (symlink) | `.claude/skills → ../skills` | Skill discovery |
| CREATE | `skills/project-workflow-claude/SKILL.md` | Core workflow (~500 lines, 9 phases) |
| CREATE (symlink) | `skills/project-workflow-claude/references → ../../project-workflow/references` | Shared references |
| MODIFY | `.gitignore` | Ensure `!.claude/context/` tracked |
| MODIFY | `install.sh` | Add `~/.claude/skills/` target (additive, platform-detected) |

## Verification

### Build & Integrity
1. `git diff main --stat` — only expected files (7 changes), 72 domain skills unchanged
2. `bash tests/test-*.sh` — existing tests still pass
3. `head -15 skills/project-workflow-claude/SKILL.md` — YAML frontmatter valid

### Claude Code Integration
4. **CLAUDE.md auto-load**: Open Claude Code session in this repo → confirm CLAUDE.md content appears in system context
5. **Skill discovery**: `ls ~/.claude/skills/project-workflow-claude/SKILL.md` exists
6. **Phase 0**: `Glob(pattern='skills/*/SKILL.md')` → 76 results; `Grep(pattern='go.mod')` → 0 results (Skills Repo)

### Platform-Specific Tool Tests
7. **Workflow tool**: Invoke `Workflow` with trivial pipeline `parallel([()=>agent("echo ok")])` → returns "ok"
8. **Agent(Explore)**: Run `Agent(description='Quick scan', prompt='List top-level directories', subagent_type='Explore')` → output contains `skills/`, `.claude/`
9. **OMC integration**: `Skill(skill='ralplan')` with trivial prompt → enters Planner phase without error
10. **Install**: Run `bash install.sh` → confirm `~/.claude/skills/project-workflow-claude/SKILL.md` and `~/.hermes/skills/project-workflow/SKILL.md` both exist

### Cross-Project Smoke Test
11. Phase 0 on one Go project: environment detection correctly identifies Go + version from go.mod

## Risks

| Risk | Severity | Proactive Detection Gate | Mitigation |
|------|----------|--------------------------|-----------|
| Workflow tool API changes | MEDIUM | Phase 4 preamble: check Workflow tool exists in current session schema before invoking. If absent, abort with error pointing to Claude Code changelog. | Document expected schema in `references/workflow-schema.md` |
| OMC ralph/ralplan interface mismatch | MEDIUM | Before Phase 3: dry-run `Skill(skill='ralplan')` with trivial prompt. If invocation fails, fall back to simplified inline consensus step. | Fix OMC upstream; skill declares OMC as prerequisite with fallback |
| Dual-branch maintenance | LOW | N/A (only 1 new file, 72 shared) | project-workflow-claude is independent; main continues Hermes-only |
| CLAUDE.md and knowledge.md drift | LOW | Phase 0.3 freshness check: compare knowledge.md header commit SHA with HEAD | CLAUDE.md always references latest knowledge.md; Phase 0.3 runs on mismatch |

## Success Criteria (Concretized)

| # | Criterion | Verification |
|---|-----------|-------------|
| 1 | Phase 0 exits with correct project type detected | Glob/Grep output shows "Skills Repository" |
| 2 | Phase 0.3 generates knowledge.md with commit SHA header | `head -3 .claude/context/knowledge.md` shows `Commit: <sha>` matching `git rev-parse HEAD` |
| 3 | Phase 0.5 loads ≥1 skill matching detected codebase patterns | Skill() invocation count ≥1 in Phase 0.5 output |
| 4 | Phase 1 produces design spec in `.claude/specs/` | `ls .claude/specs/` shows new dated spec file |
| 5 | Phase 2 produces plan in `.claude/plans/` | `ls .claude/plans/` shows new dated plan file |
| 6 | Phase 3 produces consensus verdict (APPROVE/ITERATE/REJECT) | Skill("ralplan") output contains verdict |
| 7 | Phase 4 produces changed files with all tests passing | `git diff --stat` shows expected changes; verification commands exit 0 |
| 8 | Phase 5 produces two-stage review report (spec ✅ then code ✅) | Output contains both stage verdicts in correct order |
| 9 | Phase 6 produces fresh verification evidence | All build/test/lint/security commands show PASS with exit codes |
| 10 | Phase 7 writes memory files + creates cron job | `CronList` shows new job; memory files exist |
| 11 | Phase 8 presents 4-option menu | AskUserQuestion output contains merge/push/keep/discard |
| 12 | 72 domain skills unchanged | `git diff main -- skills/` shows only `skills/project-workflow-claude/` |
| 13 | CLAUDE.md auto-loads | Claude Code session system context contains CLAUDE.md content |
| 14 | OMC integration works | Skill("ralplan") and Skill("ralph") invocations succeed without error |
| 15 | install.sh platform-detected | `which hermes` → installs to Hermes; `which claude` → installs to Claude |

## Ralplan Change Log (Iteration 1 → 2)

| Source | Issue | Fix |
|--------|-------|-----|
| Architect | CLAUDE.md overloaded with routing tables | Thin CLAUDE.md (~30 lines), boot layer only |
| Architect | OMC dependency contradicts "independent" | OMC declared as prerequisite with fallback |
| Architect | Phase numbering mismatch | Explicit 9-phase table matching Hermes v7.0 |
| Architect | Skill naming collision | Routing rule: `project-workflow-claude` loads on Claude Code |
| Architect | Verification monoculture | Add cross-project smoke test (one Go project) |
| Architect | .gitignore undocumented | Add `.gitignore` update to file list |
| Architect | install.sh scope ambiguous | Additive: platform-detected, supports both |
| Critic | OMC version wrong (v4.13.6 vs v4.13.5) | Fixed to v4.13.5 |
| Critic | Phase coverage (0-6 vs 0-8) | All 9 phases (0 through 8) verified |
| Critic | Existing claude branch not evaluated | "Why Not In-Place" section added |
| Critic | Risk 1 mitigation is a truism | Added proactive detection gate (Workflow schema check) |
| Critic | Risk 2 lacks early detection | Added proactive detection gate (ralplan dry-run) |
| Critic | Success criteria too vague | 15 concretized criteria with specific verification steps |
| Critic | Missing verification steps | Added: Workflow, Agent, OMC, install.sh tests |
