# Session Retrospective

## 7.1 Session-End Retrospective

After verification is confirmed complete, optionally run a bounded retrospective before branch finish. The main Codex session owns the decision and output. A read-only subagent may help summarize when the session is long.

Scan:
- Errors encountered during implementation and their root causes.
- User corrections — what the user asked to change and why.
- Skill misses — tasks that could have benefitted from a skill that was not loaded.
- Repeated patterns — conventions or preferences the user applied consistently.

Write only task-local artifacts unless the user explicitly asks to update durable instructions or skills.

## 7.2 Self-Learning Triggers (Inline)

The main Codex session evaluates these triggers AFTER verification completes and BEFORE branch finish:

| Trigger | Action |
|---------|--------|
| Phase 6 failed >3 times on the same issue | Load `diagnose` skill (if available) to investigate systemic cause. |
| Phase 5 found >5 CRITICAL/HIGH findings | Re-examine Phase 1 design assumptions — the design may have structural issues. |
| User corrected the same pattern >=2 times | Save to memory as a durable preference with the pattern name, the correction, and the session context. |
| Plan missed a relevant skill | Update Codex skill routing guidance if the pattern repeats across sessions. Add or adjust trigger words. |

## 7.3 Durable Learning

When the user explicitly asks to preserve lessons, prefer one of these durable locations:

- Repository guidance: `AGENTS.md`, `CONTEXT.md`, or `.codex/context/knowledge.md`.
- Reusable workflow guidance: the relevant `skills/<skill>/SKILL.md` or one-level `references/` file.
- Personal Codex skill: `~/.codex/skills/<skill>/SKILL.md` when it is not project-specific.

Follow `skill-creator` when creating or updating skills: only `name` and `description` in frontmatter, concise `SKILL.md`, details in `references/`, helpers in `scripts/`, and run `quick_validate.py`.

## 7.4 Retrospective Output

```text
Retrospective:
- Repeated issue:
- Root cause:
- Skill or instruction update needed:
- Durable artifact updated:
- Verification:
```
