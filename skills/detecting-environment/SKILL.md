---
name: detecting-environment
description: Detect repository type, tooling, Codex context artifacts, optional docs/search tools, and task-specific skill routing for the Codex workflow before design or implementation.
---

# Detecting Environment

Use this for Codex Phase 0, 0.3, and 0.5. Write Codex artifacts only.

## Inputs

- User request.
- Optional `.codex/state/project-workflow-state.json`.
- Repository files such as `AGENTS.md`, `CONTEXT.md`, `go.mod`, `package.json`, and `skills/*/SKILL.md`.

## Procedure

1. Validate state.
   - Required field: `taskIntakePath`.
   - Missing state may be initialized by `project-workflow-codex`.
   - Block if a required field is missing in an existing run.

2. Detect project type.
   - `go.mod` -> Go.
   - `package.json` with Vue/React deps -> Vue/React/Node.
   - `skills/*/SKILL.md` -> skills repository.
   - Otherwise unknown.

3. Detect tools.
   - Check Git and project language tools.
   - Check whether `ctx7` is available for current docs.
   - Check whether Firecrawl CLI, skill, or tool access is available for web research.
   - Check Codex custom agents under `codex/agents/` and `~/.codex/agents/`.

4. Write `.codex/state/task-intake.json`.

```json
{
  "requestSummary": "",
  "repoRoot": "",
  "approvedInScope": [],
  "approvedOutOfScope": [],
  "sourceEvidence": [],
  "constraints": []
}
```

5. Refresh context artifacts when missing or stale.
   - Compare `CONTEXT.md`, `AGENTS.md`, and `.codex/context/knowledge.md` against `git rev-parse HEAD` when they include a commit header.
   - Preserve confirmed human instructions in `CONTEXT.md`.
   - Replace stale auto-generated knowledge.
   - Write `.codex/context/knowledge.md`.
   - Update `AGENTS.md` only for Codex branch instructions, not global `~/.codex/AGENTS.md`.

6. Route skills.
   - Baseline: `project-workflow-codex`, `karpathy-guidelines`.
   - Load the seven execution skills by name as the workflow reaches them.
   - Discover domain skills from the full snapshot or repo when codebase or task signals justify them.
   - Do not load every skill.

7. Write `.codex/state/context-summary.json`.

```json
{
  "rootContextPath": "CONTEXT.md",
  "rootContextStatus": "present",
  "instructionsPath": "AGENTS.md",
  "instructionsStatus": "present",
  "knowledgePath": ".codex/context/knowledge.md",
  "knowledgeStatus": "fresh",
  "projectType": "skills-repo",
  "tooling": {},
  "loadedSkills": [],
  "contextWarnings": []
}
```

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="detecting-environment"`
- `currentSkill="designing-solutions"`
- `nextSkill="planning-implementation"`
- `contextSummaryPath=".codex/state/context-summary.json"`

If `handoffPolicy=auto-continue`, continue to `designing-solutions`.
