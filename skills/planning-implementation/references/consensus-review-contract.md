# Consensus Review Contract

The `phase3-consensus` Workflow script reviews the implementation plan from 3 angles in parallel (architecture, risk, feasibility), scores 1-10 each, and synthesizes one verdict.

## Workflow Invocation

```javascript
Workflow(
  name='phase3-consensus',
  args={
    planContent: '<full plan text>',
    contextSummary: '<Phase 0.3 output contextSummary>',
    grillSummary: '<Phase 1 grill evidence>',
    taskIntakeSnapshot: '<Phase 0 task intake snapshot>',
    tasks: '<parsed tasks array from plan>'
  }
)
```

## Argument Descriptions

| Argument | Source | Description |
|----------|--------|-------------|
| `planContent` | `.claude/plans/<file>.md` | Full text of the implementation plan |
| `contextSummary` | `.claude/state/context-summary.json` | Structured JSON from Phase 0.3 with projectType, knowledgeStatus, confirmedFacts, etc. |
| `grillSummary` | `.claude/state/grill-evidence.json` | Ambiguity register + assumption ledger + checklist results. May be `null` for simple tasks that skipped Grill. |
| `taskIntakeSnapshot` | `.claude/state/task-intake.json` | Structured snapshot of the original request, scope, constraints |
| `tasks` | Parsed from plan's `json:tasks` block | Array of task objects following the expanded schema |

## Review Angles

The script dispatches 3 parallel review agents:

| Angle | Focus | Score Range |
|-------|-------|-------------|
| **Architecture** | Design coherence, modularity, pattern quality, interface contracts | 1-10 |
| **Risk** | Failure modes, rollback paths, data safety, compatibility | 1-10 |
| **Feasibility** | Task granularity, dependency clarity, execution order, verifiability | 1-10 |

## Verdicts

| Verdict | Meaning | Action |
|---------|---------|--------|
| `APPROVE` | Plan passes all 3 angles. Ready for implementation. | Proceed to user approval and then Phase 4. |
| `ITERATE` | Plan has addressable issues. Findings provided. | Fix issues and re-run (max 3 iterations). |
| `REJECT` | Plan has fundamental problems that cannot be fixed by iteration. | Stop. Present reasons to user. Do NOT proceed. |

## Pre-Check Validation (Master Agent)

Before invoking the workflow, the master agent performs these pre-checks:

1. **Scope contradiction detection:** Compare `planContent` against `taskIntakeSnapshot.approvedOutOfScope`. Flag any overlap.
2. **Ambiguity resolution:** For each `grillRefs` in tasks, verify a matching entry exists in `grillSummary.ambiguityRegister` with `status != "open"`.
3. **Task contract validation:** Every mutating task has a `patchBackStrategy`. Every task has `expectedEvidence` or a verification explanation.

## Output

The script returns:

```json
{
  "verdict": "APPROVE | ITERATE | REJECT",
  "scores": {
    "architecture": <1-10>,
    "risk": <1-10>,
    "feasibility": <1-10>
  },
  "findings": [
    {
      "angle": "architecture | risk | feasibility",
      "severity": "critical | high | medium | low",
      "description": "<finding description>"
    }
  ],
  "synthesis": "<narrative synthesis of the 3 reviews>"
}
```

## Iteration Limit

Maximum 3 `ITERATE` cycles. On the 3rd failure, report findings to the user and let them decide: proceed with documented concerns, revise the design, or abandon.
