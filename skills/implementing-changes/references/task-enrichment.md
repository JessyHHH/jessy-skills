# Task Enrichment

Before dispatching Codex subagents, enrich each task so the subagent has enough local context and a bounded ownership set.

For each task:

1. Read target files fresh.
2. Resolve grill decisions from `.codex/state/grill-evidence.json` when present.
3. Extract relevant plan sections from `.codex/plans/<plan>.md`.
4. Add expected and forbidden evidence text for prompt clarity while preserving canonical arrays.
5. Include owned files, forbidden files, first update window, and required return shape.

Return shape for subagents:

```text
changed_files:
commands_run:
evidence:
risks_or_blockers:
```

The main Codex session integrates results and verifies locally.
