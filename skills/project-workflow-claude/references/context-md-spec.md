# CONTEXT.md Specification v1.0

Canonical format specification for `CONTEXT.md` — the durable repository context contract used in the `project-workflow-claude` ecosystem.

---

## Purpose

`CONTEXT.md` is a machine-readable yet human-authored repository context file. It serves as the primary, durable interface between automated tooling and human maintainers. Unlike generated analysis caches, `CONTEXT.md` is designed to survive tooling upgrades, be meaningful to anyone reading the repository, and preserve human-verified knowledge across automated refreshes.

---

## File Placement

- **Root CONTEXT.md** — Lives at the repository root (`./CONTEXT.md`). This is the canonical entry point and the only required file.
- **Subdirectory CONTEXT.md** (optional) — May exist in any subdirectory. Loaded from broadest path to nearest path (root first, then `foo/`, then `foo/bar/`). Each refines and specializes the root context for its scope. Later files take precedence for overlapping fields.
- **Contradiction warnings** — If two files assert contradictory confirmed facts (same field, same subject, opposing values), tooling MUST surface a warning. Example: root says `[confirmed] Language: Go 1.21`, but `src/legacy/CONTEXT.md` says `[confirmed] Language: Go 1.19` — warn about the mismatch rather than silently picking one.

---

## Two-Layer Marker Structure

The file content is divided into two layers separated by HTML comment markers. Markers MUST appear exactly as shown, on their own lines. Tooling MUST parse these markers to determine which sections to manage.

```text
<!-- KNOWLEDGE_START -->
...codebase facts (machine-managed)...
<!-- KNOWLEDGE_END -->

<!-- INSTRUCTION_START -->
...operational guidance (human-managed, append-only)...
<!-- INSTRUCTION_END -->
```

### Knowledge Layer (`<!-- KNOWLEDGE_START -->` to `<!-- KNOWLEDGE_END -->`)

Machine-managed facts about the codebase. Tooling MAY update `[auto]` entries in this layer. Tooling MUST NOT remove `[confirmed]` entries from this layer.

#### Required Fields

| Field | Description |
|-------|-------------|
| **Architecture** | High-level system design, component relationships, data flow direction |
| **Entity Map** | Narrative description of domain concepts and how they relate |
| **Entities** | Table of concrete entities (files, modules, services) with locations and descriptions |
| **Key Interfaces** | Public APIs, function signatures, module boundaries, protocol contracts |
| **Package Map** | Directory tree with descriptions of what each package/directory contains |
| **Confidence** | Per-claim or per-section confidence ratings (High/Medium/Low) with rationale |

### Instruction Layer (`<!-- INSTRUCTION_START -->` to `<!-- INSTRUCTION_END -->`)

Human-managed operational guidance. Tooling MUST NOT remove entries from this layer. Tooling MAY append new entries to the end of existing sections. Human edits are always authoritative.

#### Required Fields

| Field | Description |
|-------|-------------|
| **Build & Test Commands** | Exact shell commands to build, test, lint, and verify the project |
| **Code Conventions** | Style, formatting, naming, and structural rules that contributors must follow |
| **Invariants** | Non-negotiable constraints that must hold true at all times |
| **Domain Glossary** | Project-specific terminology with definitions |

---

## Evidence Tags

Every claim in both layers MUST be prefixed with exactly one evidence tag, placed at the start of the line (or start of the text after the heading).

| Tag | Meaning | Managed By | Lifecycle |
|-----|---------|------------|-----------|
| `[confirmed]` | Human-verified fact | Humans only | Never auto-removed. Survives all automated refreshes. |
| `[auto]` | Machine-generated fact | Tooling | May be replaced by automated refreshes. Subject to staleness. |

**Line format:** `[tag] <claim text>`

Examples:
```
[confirmed] Core workflow: project-workflow-claude + karpathy-guidelines.
[auto] Skill count: ~76 (from directory listing, subject to change).
```

---

## Header

Every CONTEXT.md MUST begin with a single-line header:

```text
⚠️ Auto-generated | Commit: <sha> | Date: <iso> | <project-type>
```

| Component | Value |
|-----------|-------|
| `⚠️ Auto-generated` | Literal prefix, signals machine involvement |
| `Commit: <sha>` | Full (preferred) or short git commit SHA at time of generation |
| `Date: <iso>` | ISO 8601 datetime (e.g., `2026-06-08T14:17:58+08:00`) |
| `<project-type>` | Short descriptor: `skills-repository`, `go-service`, `vue-app`, `monorepo`, etc. |

---

## Update Rules

1. **Preserve `[confirmed]`** — Automated tools MUST NOT remove or alter any line tagged `[confirmed]`. These represent human-verified knowledge that outranks any machine inference.

2. **Replace `[auto]`** — Automated tools MAY replace `[auto]` entries within recognized sections (Architecture, Entity Map, Entities, Key Interfaces, Package Map, Confidence). Replacement should be scoped: replace entire lines or blocks that the tool authored previously, not arbitrary `[auto]` lines from unknown sources.

3. **Malformed marker handling** — If the markers (`KNOWLEDGE_START`, `KNOWLEDGE_END`, `INSTRUCTION_START`, `INSTRUCTION_END`) are missing, misplaced, duplicated, or nested, tooling MUST NOT blindly rewrite the file. Instead, surface a warning describing the malformation and refuse to overwrite until a human fixes the markers.

4. **Section ordering** — The Knowledge layer MUST appear before the Instruction layer. Within each layer, field ordering is conventional but not enforced. Tooling SHOULD preserve existing field order when updating.

5. **Idempotency** — Refreshing a `CONTEXT.md` that has no changes since the last refresh SHOULD produce an identical file (excluding the Date field in the header).

---

## Differences from `.claude/context/knowledge.md`

| Aspect | `CONTEXT.md` | `.claude/context/knowledge.md` |
|--------|-------------|-------------------------------|
| **Role** | Durable repository context contract | Generated analysis cache |
| **Audience** | Humans AND machines | Machines primarily |
| **Authoring** | Human-authored with machine assistance | Fully machine-generated |
| **Update model** | Selective refresh (respects `[confirmed]` tags) | Full overwrite on every run |
| **Layers** | Knowledge + Instruction (two-layer marker structure) | Single flat analysis output |
| **Evidence tags** | `[confirmed]` + `[auto]` | None (all content is implicitly `[auto]`) |
| **Human management** | Instruction layer is append-only human territory | None — entire file is overwritten |
| **Survival** | Survives tooling upgrades and re-runs | Not designed to survive across runs |
| **Primary for** | Human readers, onboarding, architectural decisions | Tooling runtime, analysis context injection |

Both files coexist: `CONTEXT.md` is primary for human understanding and durable knowledge; `knowledge.md` is the runtime cache that tooling regenerates freely. Neither replaces the other.
