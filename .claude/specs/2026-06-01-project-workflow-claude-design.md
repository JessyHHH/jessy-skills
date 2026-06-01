# Design Spec: project-workflow-claude

**Date:** 2026-06-01  
**Status:** Final — implemented  
**Decision:** Independent Claude Code implementation, 3-layer shared architecture

---

## 1. Architecture Overview

### 1.1 Three-Layer Separation

```
┌──────────────────────────────────────────────┐
│  Layer 1: Domain Skills (72 files) — ZERO changes    │
│  go/* vue/* engineering/* methodology/* frontend/*    │
│  Pure knowledge/patterns, platform-agnostic           │
├──────────────────────────────────────────────┤
│  Layer 2: Shared Core — ONE copy maintained          │
│  references/: full-skill-routing.md, context-md-spec.md │
│  Phase definitions, Hard Gates, Iron Law text         │
├──────────────────────────────────────────────┤
│  Layer 3: Platform Implementations                   │
│  project-workflow/ (Hermes) ← unchanged               │
│  project-workflow-claude/ (Claude Code) ← NEW         │
└──────────────────────────────────────────────┘
```

### 1.2 Key Design Decisions

| Decision | Rationale | Verification |
|----------|-----------|-------------|
| Independent SKILL.md (not universal adapter) | Workflow tool is fundamentally different from delegate_task | ✅ context7 confirms Workflow docs exist at code.claude.com/docs/en/workflows |
| CLAUDE.md + .claude/context/knowledge.md (not CONTEXT.md) | CLAUDE.md auto-loads at session start | ✅ context7: "Loaded at the start of every session, in every project" |
| Phase 4 uses Workflow tool (not ultrawork) | pipeline/parallel/phase > simple parallel dispatch | ✅ Workflow tool schema available in Claude Code |
| Phase 3/6 use OMC ralplan/ralph (not ported versions) | OMC versions more feature-rich, avoid triple maintenance | ✅ OMC v4.13.6 confirmed installed |
| `.hermes/` preserved as history | Zero-cost, git-tracked project evolution record | ✅ 11 plans + 2 specs exist |

---

## 2. CLAUDE.md + Knowledge Layer Design

### 2.1 File Layout

```
jessy-skills/
├── CLAUDE.md                         ← Instruction Layer (~60 lines)
│                                        Auto-loaded EVERY session
│                                        build/test/lint commands
│                                        coding conventions + invariants
│                                        References .claude/context/knowledge.md
│
└── .claude/
    ├── context/
    │   └── knowledge.md              ← Knowledge Layer (~200 lines)
    │                                    Phase 0.3 Agent(Explore) generates
    │                                    Architecture, entities, interfaces
    │                                    Header: Commit SHA + Date + Type
    │                                    Full overwrite on each generation
    │
    ├── specs/                         ← Design specs (this file)
    ├── plans/                         ← Implementation plans
    └── skills → ../../skills          ← Symlink to shared skill pool
```

### 2.2 CLAUDE.md Template

```markdown
# jessy-skills — Claude Code Configuration

## Project Type
Skills Repository — 76 AI Agent skills (Go/Vue/Engineering/...)
Core workflow: project-workflow-claude + karpathy-guidelines

## Essential Commands
- Verify: bash tests/test-*.sh
- Lint: git diff --check
- Skill validation: head -15 skills/*/SKILL.md (YAML frontmatter check)

## Conventions
- SKILL.md follows agentskills.io open standard
- Phase transitions auto-announced (never wait for user prompt)
- Hard Gates: Design-Before-Code, Iron Law (fresh evidence)
- Two-Stage Review: spec compliance → code quality (never reverse)

## Project Knowledge
Deep architecture analysis: [.claude/context/knowledge.md](.claude/context/knowledge.md)
```

### 2.3 Knowledge Layer Header

```markdown
<!-- ⚠️ Auto-generated | Commit: <sha> | Date: <iso> | Skills Repository -->
<!-- Phase 0.3: Agent(Explore) analysis — full overwrite on change -->
```

---

## 3. Phase-by-Phase API Mapping

### 3.1 Complete Tool Translation Table

| Function | Hermes API | Claude Code API | Phase(s) |
|----------|-----------|----------------|----------|
| Sub-agent | `delegate_task(goal, context, toolsets)` | `Agent(description, prompt, subagent_type)` | 0.3, 5, 7 |
| Skill load | `skill_view(name='...')` | `Skill(skill="...")` | 0.5, 1, 2, 3, 5 |
| File find | `search_files(pattern, target='files')` | `Glob(pattern)` | 0 |
| Content search | `search_files(pattern, target='content')` | `Grep(pattern)` | 0 |
| Shell | `terminal('cmd')` | `Bash(command, description)` | 0, 6, 8 |
| Write file | `write_file(path, content)` | `Write(file_path, content)` | 0.3, 2 |
| Read file | `read_file(path)` | `Read(file_path)` | 0, 0.3, 5 |
| User question | `clarify(question, options)` | `AskUserQuestion(questions)` | 1 |
| Memory | `memory(action, target, content)` | `Write` to `~/.claude/projects/.../memory/` | 7.1, 7.2 |
| Cron | `cronjob(action, schedule, ...)` | `CronCreate` / `CronDelete` / `CronList` | 7.3 |
| Multi-agent | `delegate_task(tasks=[])` | `Workflow(script)` | 4 |
| Session search | `session_search(query, limit)` | `CronCreate` + memory files | 7.3 |
| Edit file | `patch(old, new)` | `Edit(file_path, old_string, new_string)` | 4, 6 |

### 3.2 Phase Implementation Details

#### Phase 0: Environment Detection
```
Hermes:  search_files(pattern='go.mod') → Go
         search_files(pattern='package.json') → Node/Vue
         search_files(pattern='SKILL.md', path='skills/') → Skills Repository

Claude:  Glob(pattern='**/go.mod') → Go
         Glob(pattern='**/package.json') → Node/Vue  
         Glob(pattern='skills/*/SKILL.md') → Skills Repository
```

#### Phase 0.3: Codebase Analysis
```
Hermes:  delegate_task(goal="Deep read-only analysis...")
         → write_file('CONTEXT.md', content)

Claude:  Agent(description="Analyze codebase structure",
                prompt="Deep read-only analysis...",
                subagent_type="Explore")
         → Write('.claude/context/knowledge.md', content)
         → Write('CLAUDE.md', instruction_layer) [if new or stale]
```
Freshness check: Compare knowledge.md header commit SHA with `git rev-parse HEAD`.

#### Phase 0.5: Smart Skill Selection
```
Hermes:  skill_view(name='golang-concurrency') × N

Claude:  Skill(skill="golang-concurrency") × N
```
Memory triggers: Scan `.claude/projects/.../memory/` for `→ 加载 skill <name>` pattern.

#### Phase 1: Design First (HARD-GATE)
```
Hermes:  clarify() for boundary check
         write_file('.hermes/specs/...') for design spec

Claude:  AskUserQuestion() for boundary check
         Write('.claude/specs/...') for design spec
```

#### Phase 2: Write Plan
```
Hermes:  skill_view(name='plan')
         write_file('.hermes/plans/...')

Claude:  Skill(skill="omc-plan")  [OMC's plan skill]
         Write('.claude/plans/...')
```

#### Phase 3: Ralplan Consensus
```
Hermes:  skill_view(name='ralplan') → delegate_task

Claude:  Skill(skill="ralplan")  [OMC native v4.13.6]
         OMC version has: Planner→Architect→Critic loop
         --interactive, --deliberate modes
         --architect codex, --critic codex options
```

#### Phase 4: Implement (KEY UPGRADE)
```
Hermes:  delegate_task(tasks=[task1, task2, ...])
         Simple parallel dispatch, wait for all results

Claude:  Workflow(script=`
           export const meta = { name: 'phase4-impl', ... }
           pipeline(tasks,
             task => agent("Implement: " + task, {schema}),
             impl => agent("Review: " + impl.file, {schema}),
             review => agent("Verify: " + review.file, {schema})
           )
         `)
         Pipeline orchestration: each task flows through
         implement→review→verify independently
```
Why Workflow beats delegate_task here:
- Hermes: "Fire all tasks, wait for all, then review all" (3 barriers)
- Claude: "Each task pipelines through implement→review→verify as soon as ready" (no barriers)
- Wall-clock time: same or better, but correctness improves (bugs caught per-task, not in batch)

#### Phase 5: Two-Stage Review
```
Hermes:  Stage 1: delegate_task(spec-compliance)
         Stage 2: delegate_task(code-review)

Claude:  Stage 1: Agent(spec-compliance, subagent_type="general-purpose")
         Stage 2: Workflow(parallel review dimensions)
           parallel([
             () => agent("Security review: " + files, {schema}),
             () => agent("Performance review: " + files, {schema}),
             () => agent("Style review: " + files, {schema}),
           ])
         LSP tool available for automated type-error detection
```
Stage order enforced: spec ✅ before code quality (same as Hermes).

#### Phase 6: Verified Completion (Iron Law)
```
Hermes:  terminal('go build ./...') → terminal('go test -race ./...') → ...
         Ralph loop on failure

Claude:  Bash('go build ./...') → Bash('go test -race ./...') → ...
         Skill("ralph") for verify→fix→re-verify loop
         LSP type diagnostics run BEFORE build (catch issues early)
```

#### Phase 7: Retrospective + Learning
```
Hermes:  delegate_task(retrospective)
         memory(action='add', ...)
         cronjob(action='create', schedule='every 2h')

Claude:  Agent(retrospective, run_in_background=true)
         Write(memory files with frontmatter)
         CronCreate(cron, prompt, durable=true)
```

#### Phase 8: Finish Branch
```
Hermes:  terminal('git merge-base HEAD main')
         4-option menu (merge/push/keep/discard)

Claude:  Bash('git merge-base HEAD main')
         AskUserQuestion for 4-option menu
         Bash native git operations
```

---

## 4. OMC Integration

### 4.1 Dependencies

| project-workflow Phase | OMC Skill Used | Invocation |
|------------------------|---------------|------------|
| Phase 2 (Plan) | omc-plan | `Skill(skill="omc-plan")` |
| Phase 3 (Ralplan) | ralplan | `Skill(skill="ralplan")` |
| Phase 6 (Verify loop) | ralph | `Skill(skill="ralph")` |

### 4.2 What We DON'T Duplicate

OMC already provides these. project-workflow-claude references them, does not re-implement:
- `ralph` — PRD-driven persistence loop (238 lines in OMC v4.13.6)
- `ralplan` — Planner→Architect→Critic consensus (136 lines in OMC v4.13.6)
- `ultrawork` — NOT used; Workflow tool replaces it for Phase 4

### 4.3 OMC Compatibility Note

If OMC's ralph/ralplan behavior differs from what project-workflow expects:
- Fix in OMC upstream (benefits all OMC users)
- Do NOT create shadow copies in jessy-skills
- project-workflow-claude documents the expected interface in its SKILL.md

---

## 5. Git Workflow

### 5.1 Branch Strategy

```
main (Hermes version, UNCHANGED)
  │
  └── claude (Claude Code version, ACTIVE DEVELOPMENT)
        ├── Reset to main (clean up old single-commit divergence)
        ├── New: skills/project-workflow-claude/
        ├── New: CLAUDE.md
        ├── New: .claude/specs/ + .claude/plans/ + .claude/context/
        ├── Modify: install.sh (add ~/.claude/skills/ target)
        ├── Keep: .claude/skills → ../skills symlink (reuse)
        └── Keep: .hermes/ (historical reference)
```

### 5.2 Claude Branch Reset

```bash
git checkout claude
git reset --hard main          # Clean up old divergence
# Then build project-workflow-claude on clean base
```

### 5.3 What Stays, What Changes

| Path | Action | Reason |
|------|--------|--------|
| `skills/project-workflow/` | UNCHANGED | Hermes version, active on main |
| `skills/project-workflow-claude/` | NEW | Claude Code implementation |
| `skills/go/*`, `skills/vue/*`, ... (72 dirs) | UNCHANGED | Platform-agnostic, shared |
| `CLAUDE.md` | NEW | Instruction Layer, auto-loaded |
| `.claude/context/knowledge.md` | NEW | Knowledge Layer, Phase 0.3 generated |
| `.claude/specs/` | NEW | Design specs |
| `.claude/plans/` | NEW | Implementation plans |
| `.claude/skills → ../skills` | KEEP | Symlink for skill discovery |
| `.hermes/` | KEEP | Historical reference |
| `shell/hermes.sh` | UNCHANGED | Hermes shell integration |
| `install.sh` | MODIFY | Add ~/.claude/skills/ target |

---

## 6. Verification Confidence

| Claim | Source | Confidence |
|-------|--------|-----------|
| CLAUDE.md auto-loads at session start | context7: code.claude.com "Loaded at the start of every session" | ✅ HIGH |
| CLAUDE.md limit ~200 lines recommended | context7: "keep CLAUDE.md under 200 lines" | ✅ HIGH |
| Skills use progressive disclosure | context7: "move reference material to skills, which load on-demand" | ✅ HIGH |
| Skill frontmatter `allowed-tools` | context7: SKILL.md examples show `allowed-tools: Bash(*)` | ✅ HIGH |
| Dynamic Workflows exist at code.claude.com/docs/en/workflows | firecrawl: confirmed page exists, "Orchestrate subagents at scale" | ✅ HIGH |
| Workflow tool: pipeline/parallel/phase/agent | Claude Code built-in tool schema (available in this session) | ✅ HIGH |
| OMC ralph/ralplan exist at v4.13.6 | Filesystem: `~/.claude/plugins/cache/omc/oh-my-claudecode/4.11.6/skills/` | ✅ HIGH |
| agentskills.io is the bridge standard | WebSearch: 27+ platforms, both Claude Code and Hermes support it | ✅ HIGH |
| Token cost ratios (1.75x subagent, 3.5x team) | WebSearch: community benchmarks, not official Anthropic data | ⚠️ MEDIUM |
| Hermes v0.13 delegate_task toolset list | GitHub PR #8231: dynamic toolset list confirmed | ✅ HIGH |

---

## 7. Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Workflow tool API changes in future Claude Code versions | MEDIUM | project-workflow-claude is a skill, can be updated independently |
| OMC ralph/ralplan interface mismatch with project-workflow expectations | MEDIUM | First implementation uses OMC directly; if gaps found, fix OMC upstream |
| Dual-branch maintenance (claude vs main) | LOW | Only 1 new file (~500 lines); 72 domain skills shared |
| CLAUDE.md token budget (recommended <200 lines) | LOW | Instruction Layer kept to ~60 lines; Knowledge in separate file |

---

## 8. Success Criteria

1. `project-workflow-claude/SKILL.md` passes Phase 0-8 on this Skills Repository project
2. All 72 existing domain skills unchanged (git diff skills/ shows only new project-workflow-claude/)
3. CLAUDE.md auto-loads and correctly references knowledge.md
4. OMC ralph/ralplan invocations work within the workflow
5. Git history: claude branch cleanly rebased on main, only new files added
6. install.sh installs to both `~/.hermes/skills/` and `~/.claude/skills/`
