# Workflow State Contract

`project-workflow-claude` uses `.claude/state/project-workflow-state.json` as the durable baton between modular skills.

## Required Fields

```json
{
  "workflow": "project-workflow-claude",
  "version": "v2.8",
  "runMode": "full-workflow | standalone-skill | resume",
  "handoffPolicy": "auto-continue | prompt-next-step",
  "currentSkill": "detecting-environment",
  "lastCompletedSkill": null,
  "nextSkill": "designing-solutions",
  "status": "running | waiting-for-user-approval | blocked | complete",
  "taskIntakePath": ".claude/state/task-intake.json",
  "contextSummaryPath": ".claude/state/context-summary.json",
  "grillEvidencePath": ".claude/state/grill-evidence.json",
  "specPath": null,
  "planPath": null,
  "quickGateResultsPath": null,
  "reviewResultsPath": null,
  "verificationResultsPath": null,
  "escapeHatchesUsed": []
}
```

## Ownership

- `project-workflow-claude` initializes `workflow`, `version`, `runMode`, `handoffPolicy`, `currentSkill`, `lastCompletedSkill`, `nextSkill`, and `taskIntakePath`.
- Each child skill updates `lastCompletedSkill` and `currentSkill` in its Exit Contract when handing off to the next skill.
- `detecting-environment` writes `contextSummaryPath`.
- `designing-solutions` writes `grillEvidencePath` and `specPath`.
- `planning-implementation` writes `planPath`.
- `implementing-changes` writes `quickGateResultsPath`.
- `reviewing-implementation` writes `reviewResultsPath`.
- `verifying-completion` writes `verificationResultsPath`.
- `finishing-development` marks `status=complete` after the chosen finish action.

## Resume Behavior

When the user says `/project-workflow-claude continue`, read this file and invoke `currentSkill`. If the file is absent, start from `detecting-environment` and state that no prior workflow state was found.
