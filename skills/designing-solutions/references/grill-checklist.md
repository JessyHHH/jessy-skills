# Hard Grill Checklist

Mandatory printed output before exiting the Grill phase. The master agent MUST print this checklist with PASS/FAIL for each item. If any item is FAIL, the Grill is NOT done. Re-open the Ambiguity Register and continue.

## Checklist Items

1. [ ] **Ambiguity Register printed** (minimum 3 items, or explain why fewer than 3)
2. [ ] **Assumption Ledger printed** (minimum 2 entries, or explain why fewer than 2)
3. [ ] **Every "open" ambiguity addressed** (asked user OR moved to "assumed" with a ledger entry)
4. [ ] **Success criteria are observable** (specific commands + expected output)
5. [ ] **Constraints documented** (version, dependency, compatibility)
6. [ ] **Self-grade: "Could someone implement from this spec without asking basic questions?"** If no: Grill NOT done. Re-open and probe.

ALL items MUST pass before proceeding to PROPOSE.

## Grill Evidence JSON Shape

After ALL checklist items pass and before writing the design spec, persist structured evidence to `.claude/state/grill-evidence.json`. Delegate the file write to a subagent.

```json
{
  "timestamp": "<ISO 8601>",
  "session": "<session-id>",
  "ambiguityRegister": [
    {
      "id": "A1",
      "question": "<the unresolved item>",
      "status": "answered | assumed | deferred-out-of-scope",
      "impact": "<what would change based on the answer: files, behavior, verification, risk>",
      "recommendedAnswer": "<I think X because Y>",
      "decision": "<the final resolved answer>"
    }
  ],
  "assumptionLedger": [
    {
      "id": "S1",
      "assumption": "<what is being assumed>",
      "evidence": "<what supports this assumption>",
      "confidence": "high | medium | low",
      "correctionPath": "<what to do if the assumption proves wrong>"
    }
  ],
  "checklistResults": {
    "ambiguityRegisterPrinted": true,
    "assumptionLedgerPrinted": true,
    "openAmbiguitiesAddressed": true,
    "successCriteriaObservable": true,
    "constraintsDocumented": true,
    "selfGrade": "PASS: spec is implementable without basic questions"
  },
  "requirementEcho": ["<req1>", "<req2>"],
  "scopeStatement": "<scope boundary statement>",
  "successCriteria": [
    "cmd: <command> exits 0",
    "semantic: <behavior description>"
  ]
}
```

### Field Descriptions

- **timestamp**: ISO 8601 datetime of Grill completion.
- **session**: Unique session identifier for traceability.
- **ambiguityRegister**: Array of all ambiguities identified during Grill. Each entry tracks the question, its resolution status, impact analysis, the recommended answer, and the final decision.
- **assumptionLedger**: Array of all explicit assumptions made. Each entry tracks what was assumed, the supporting evidence, confidence level, and the correction path if the assumption proves wrong.
- **checklistResults**: Boolean results for each of the 6 Hard Grill Checklist items. All must be `true`.
- **requirementEcho**: The confirmed requirement list from Step 2 of the design procedure.
- **scopeStatement**: The confirmed scope boundary from the mandatory first Grill question.
- **successCriteria**: Observable, verifiable success criteria. At minimum include a command-based criterion (`cmd: ... exits 0`) and a semantic criterion (`semantic: ...`).

## Downstream Consumers

- **Phase 2 (planning-implementation):** References grillRefs in task schema entries.
- **Phase 4 (implementing-changes):** Resolves grillDecisions for task enrichment.
- **Phase 5 (reviewing-implementation):** Cross-references implementation against expected evidence.
- **Phase 6 (verifying-completion):** Validates semantic evidence against success criteria.
