# Skill Routing

Rules and references for task-specific and codebase-specific skill loading during environment detection.

## Layered Routing Architecture

Skill routing uses a two-layer architecture:

| Layer | File | Role |
|-------|------|------|
| Base (shared) | `skills/project-workflow/references/full-skill-routing.md` | Language-agnostic and Go/Vue/Engineering skill mappings shared across workflows |
| Overlay (Claude Code) | `skills/project-workflow-claude/references/claude-routing.md` | Claude Code platform-specific action mappings and supplemental codebase signal routing |

**Resolution order:** Load base layer first, then overlay. Overlay supplements and overrides the base layer.

## Conflict Resolution

| Rule | Description |
|------|-------------|
| **Precedence** | Overlay (claude-routing.md) takes precedence over base layer (full-skill-routing.md) |
| **Deduplication** | Skip any skill name already loaded (de-duplicate by exact skill name) |
| **Collision logging** | If both layers match the same skill name, log the collision and use overlay |

## Codebase Signal Matching

From the dependency scan in Step 2:

- **Go:** Read `go.mod` and scan imports against both routing tables. Match signals like `samber/lo`, `grpc`, `testify`, etc.
- **Vue:** Read `package.json` and scan dependencies against routing tables. Match signals like `vue`, `pinia`, `vitest`.
- **Node:** Read `package.json` and scan for framework-specific patterns.

For EVERY match, load the skill: `Skill(skill='<exact-skill-name>')`.

## Task Signal Matching

Match keywords from the user's request and task intake snapshot against the task signal columns in both routing tables. Load each matched skill.

## Memory Trigger Detection

Scan project memory files (`~/.claude/projects/<project>/memory/*.md`) for the trigger pattern:

```
<topic>: load skill <skill-name>
```

(The actual arrow character may vary. Match the semantic pattern: a topic label, followed by a directive to load a named skill.)

For each matched trigger:
- Extract the skill name.
- Check if already loaded (skip if so).
- Load via `Skill(skill='<name>')`.

## MCP-Aware Routing

| MCP Available | Prefer For |
|---------------|------------|
| Context7 | Documentation lookups, API references, library queries |
| Firecrawl | Web searches, content extraction, research queries |

When the corresponding MCP is not available, fall back:
- Context7 unavailable: Use WebFetch for documentation lookups
- Firecrawl unavailable: Use WebSearch for search queries

## Skill Load Cap

- Do NOT load every possible skill "just in case".
- Load only skills matched by codebase signals, task signals, or memory triggers.
- Baseline: `karpathy-guidelines` is always internalized (no Skill call needed).
- Iron Law: If the task involves code changes or verification, read `skills/project-workflow-claude/references/iron-law.md`.

## Post-Load Announcement Format

```
"Codebase signals: N skills loaded
Task signals: N skills loaded
Overlay: claude-routing.md loaded
Memory triggers: N skills loaded
Total: N skills"
```
