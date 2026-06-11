# State Validation Contract

Required state fields for each phase in the `project-workflow-claude` modular pipeline. This document defines what fields must be present in `.claude/state/project-workflow-state.json` before each phase executes.

## Required Fields per Phase

| Phase (Skill) | Required Fields | Optional Fields | Blocking Condition |
|---|---|---|---|
| detecting-environment | taskIntakePath | — | None (first phase) |
| designing-solutions | contextSummaryPath | — | None |
| planning-implementation | contextSummaryPath | specPath, grillEvidencePath | BOTH specPath AND grillEvidencePath null AND "skip design" NOT in escapeHatchesUsed |
| implementing-changes | planPath | — | None |
| reviewing-implementation | quickGateResultsPath | — | None |
| verifying-completion | reviewResultsPath | — | None |
| finishing-development | verificationResultsPath | — | None |

## Skip-Design Escape Hatch

When the user says "skip design":

1. Record `"skip design"` in `state.json` `escapeHatchesUsed` array.
2. `planning-implementation` Step 0 allows null `specPath` + `grillEvidencePath`.
3. `planning-implementation` uses `task-intake.json` as the sole requirements source.
4. The plan document MUST include the following note:

```
⚠️ Design Phase Skipped -- requirements from task-intake.json only
```

## Backward Compatibility

- `escapeHatchesUsed` defaults to `[]` when missing from state file.
- State files from v2.7 (missing new fields introduced in later versions) are auto-upgraded on first load.
