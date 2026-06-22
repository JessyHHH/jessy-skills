# Skill Routing

Codex keeps startup skill discovery small and loads additional skills only after routing confirms relevance.

## Sources

- Entry skills: `project-workflow-codex`, `karpathy-guidelines`.
- Execution skills: seven top-level workflow skills loaded by phase.
- Domain skills: `skills/go`, `skills/vue`, `skills/frontend`, `skills/engineering`, `skills/methodology`, `skills/tools`, and project-specific skills.
- Full installed snapshot: `~/.jessy-skills-codex/skills`.

## Matching

Use codebase and task signals:

- Go files or `go.mod` -> Go skills.
- Vue/Node package signals -> Vue/frontend skills.
- API/schema/data modeling language -> methodology skills.
- Review/debug/test wording -> review, diagnose, tdd, troubleshooting skills.
- Documentation lookup -> Context7 CLI per `AGENTS.md`.
- Web research -> Firecrawl when available, otherwise available search/browser fallback.

Do not load every matched-looking skill. Choose the smallest set that materially helps the task.

## Announcement

Report:

```text
Phase 0.5: Skill routing
- Entry skills: project-workflow-codex, karpathy-guidelines
- Execution skill next: <skill>
- Domain skills loaded: <list>
- Discarded candidates: <list with reasons>
```
