# Hard Grill Checklist

Print this checklist before exiting the Grill phase. If any item fails, continue grilling.

1. Ambiguity Register printed, or explain why no ambiguity remains.
2. Assumption Ledger printed, or explain why no assumptions are needed.
3. Every open ambiguity is answered, assumed with a ledger entry, or deferred out of scope.
4. Success criteria are observable.
5. Constraints are documented.
6. Self-grade passes: a competent implementer can build from the spec without basic follow-up questions.

## Evidence File

Persist to `.codex/state/grill-evidence.json`.

```json
{
  "timestamp": "<ISO 8601>",
  "session": "<session-id>",
  "ambiguityRegister": [
    {
      "id": "A1",
      "question": "",
      "status": "answered | assumed | deferred-out-of-scope",
      "impact": "",
      "recommendedAnswer": "",
      "decision": ""
    }
  ],
  "assumptionLedger": [
    {
      "id": "S1",
      "assumption": "",
      "evidence": "",
      "confidence": "high | medium | low",
      "correctionPath": ""
    }
  ],
  "checklistResults": {
    "ambiguityRegisterPrinted": true,
    "assumptionLedgerPrinted": true,
    "openAmbiguitiesAddressed": true,
    "successCriteriaObservable": true,
    "constraintsDocumented": true,
    "selfGrade": "PASS"
  },
  "requirementEcho": [],
  "scopeStatement": "",
  "successCriteria": []
}
```
