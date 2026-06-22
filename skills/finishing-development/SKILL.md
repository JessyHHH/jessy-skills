---
name: finishing-development
description: Finish a verified Codex workflow run with retrospective notes, optional memory work, and user-approved branch, commit, PR, or keep-as-is actions.
---

# Finishing Development

Use this for Codex Phase 7 and 8 after verification passes.

## Inputs

- `.codex/state/project-workflow-state.json`
- `.codex/state/verification-results.json`

## Procedure

1. Validate state.
   - Required field: `verificationResultsPath`.
   - Block if missing.

2. Reconfirm freshness.
   - Run `git status --short`.
   - If unverified changes exist after Phase 6, return to `verifying-completion`.

3. Retrospective.
   - Record lessons, missed skills, repeated user corrections, and verification issues in `.codex/state/retrospective.md` when useful.
   - Do not start automatic cron jobs.

4. Optional memory work.
   - Only update memory if explicitly requested or if the active Codex memory settings allow it and the lesson is durable.

5. Branch finish.
   - Present options:
     - keep branch as-is
     - commit locally
     - push / create PR
     - discard generated work
   - Require explicit user approval before commit, push, merge, or discard.

6. Mark state complete when finish action is done or skipped.

## Exit

Update `.codex/state/project-workflow-state.json`:

- `lastCompletedSkill="finishing-development"`
- `currentSkill=null`
- `nextSkill=null`
- `status="complete"`
