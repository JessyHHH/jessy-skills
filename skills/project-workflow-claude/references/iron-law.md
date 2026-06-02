# Iron Law

## The Iron Law

NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always. If you haven't run the verification command in this message, you cannot claim it passes.

## Gate Function

BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY — What command proves this claim?
2. RUN — Execute the FULL command (fresh, complete)
3. READ — Full output, check exit code, count failures
4. VERIFY — Does output confirm the claim? If NO: state actual status. If YES: state claim WITH evidence
5. ONLY THEN — Make the claim

Skip any step = lying, not verifying

## Red Flags — STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Trusting subagent success reports
- Relying on partial verification
- Thinking "just this once"
- "I'm tired, just this once"
- ANY wording implying success without having run verification

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Subagent said success" | Verify independently |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |
| "I'm tired, just this once" | Exhaustion ≠ evidence. RUN the command. |
| "Agent said success" | Check the VCS diff. Verify changes. Trust nothing. |

## TDD Red-Green Verification

For regression tests:
1. Write the test → run (passes with fix)
2. Revert the fix → run (MUST fail — proves test catches the bug)
3. Restore the fix → run (passes)

"I've written a regression test" is insufficient without red-green verification.

## Agent Delegation Verification

When an agent reports success:
1. Check the VCS diff — what actually changed?
2. Verify the changes independently — run tests, build, lint yourself
3. Report actual state — not the agent's claim

Trust nothing. Verify everything.

## Evidence Standard

- "Works" = ALL verification commands exit 0, THIS turn
- "Reviewed" = BOTH stages complete WITH fresh output
- "Done" = Iron Law satisfied

## When It Applies

Always before: any success claim, any expression of satisfaction, committing, creating a PR, completing a task, moving to the next task, delegating to agents.

The rule covers exact phrases, paraphrases, synonyms, implications of success, and ANY communication suggesting completion or correctness.
