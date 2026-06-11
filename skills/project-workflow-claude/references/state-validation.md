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

---

## Graceful Degradation for Missing Context Summaries

Some project states may have `contextSummaryPath` pointing to a file that does not exist (e.g., after a partial run or branch switch). The state validator must handle this gracefully:

1. If `contextSummaryPath` is set but the file does not exist:
   - Log a warning: "Context summary not found at <path>. Proceeding without cached context."
   - Set `contextSummaryPath` to `null` in the state object.
   - Continue execution — do NOT block.
2. If `contextSummaryPath` is `null` or unset:
   - Continue execution. The detecting-environment skill will regenerate context.
3. If `status` is not `"idle"` AND any of these staleness conditions are met:
   a. `currentSkill` is set but the file at the path it references (e.g., `specPath`, `planPath`, `quickGateResultsPath`) does not exist, OR
   b. `lastCompletedSkill` was set more than 30 minutes ago (based on user assessment of session inactivity), OR
   c. The state file references project files that have been externally modified (different git branch checked out).
   Then the state is stale:
   - Backup state file as `.claude/state/project-workflow-state-<ISO-timestamp>.json.bak` to prevent overwrites from concurrent sessions.
   - Reset `status` to `"idle"`, clear `currentSkill` and `lastCompletedSkill` and `nextSkill` to `null`.
   - Set `contextSummaryPath` to `null` if the pointed file does not exist.
   - If state file JSON is corrupted (cannot be parsed): backup as `.claude/state/project-workflow-state-corrupted-<ISO-timestamp>.json`, then write fresh idle state.
   - Log a warning detailing which staleness condition was triggered and what was reset.
