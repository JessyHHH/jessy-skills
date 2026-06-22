# Context Artifact Model

Codex workflow uses three repository context artifacts.

| Artifact | Role | Update Model |
| --- | --- | --- |
| `CONTEXT.md` | Durable human and machine context contract | Preserve `[confirmed]`, refresh `[auto]` |
| Scoped `CONTEXT.md` | Optional subtree-specific context | Nearest file refines broader files |
| `.codex/context/knowledge.md` | Generated machine analysis cache | Full overwrite |

## Root CONTEXT.md

Use `CONTEXT.md` as the durable cross-session context artifact. It has two sections:

- `<!-- KNOWLEDGE_START -->` / `<!-- KNOWLEDGE_END -->`
- `<!-- INSTRUCTION_START -->` / `<!-- INSTRUCTION_END -->`

Use `[confirmed]` for human-confirmed facts and `[auto]` for generated facts.

## AGENTS.md

Use root `AGENTS.md` for Codex project instructions. Do not create or update `CLAUDE.md` on this branch.

If `AGENTS.md` is missing, write a concise Codex-only file with:

- branch notice
- Codex workflow entry
- essential verification commands
- skill authoring rules
- Context7/Firecrawl guidance

Do not overwrite user global `~/.codex/AGENTS.md`.

## Knowledge Cache

Use `.codex/context/knowledge.md` for generated analysis. It may be fully regenerated when stale.

## Freshness

Compare artifact commit headers to `git rev-parse HEAD` when headers exist.

- Stale `CONTEXT.md`: refresh generated facts, preserve confirmed facts.
- Stale `AGENTS.md`: update only machine-owned Codex project guidance when safe.
- Stale `.codex/context/knowledge.md`: regenerate.
- Malformed markers: warn and skip automated overwrite.
