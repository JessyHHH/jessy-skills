# Quick Gate

Run before Phase 5 review.

## Checks

1. `git diff --stat` - changed files match planned task files.
2. Expected evidence - expected text, files, or behavior are present.
3. Forbidden evidence - forbidden text or files are absent.
4. Unexpected files - every changed file is justified by the plan.

## Output

Persist to `.codex/state/quick-gate-results.json`.

```json
{
  "passed": true,
  "perTask": {
    "<taskId>": {
      "expectedPassed": true,
      "forbiddenClean": true,
      "filesMatch": true,
      "unexpectedFiles": [],
      "missingEvidence": [],
      "forbiddenFound": []
    }
  }
}
```

Phase 5 consumes this file for risk classification.
