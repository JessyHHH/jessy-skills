# Design Spec Template

Template for `.claude/specs/YYYY-MM-DD-<topic>-design.md`. All sections are required. Remove placeholder text and replace with concrete content.

---

## Scope

One paragraph defining the boundary of this design. What is included and explicitly what is not.

## Requirements and Evidence

Numbered list of requirements with source evidence:

1. **<Requirement>** -- source: <user message / intake snapshot / file X / Grill decision A#>
2. ...

## Non-Goals

Explicitly excluded items to prevent scope creep:

- <Non-goal 1>
- <Non-goal 2>

## Context Summary

Project type, language version, key dependencies, relevant patterns from CONTEXT.md and knowledge.md. Include the commit SHA this design is based on.

## Ambiguity Register

| ID | Question | Status | Impact | Decision |
|----|----------|--------|--------|----------|
| A1 | ... | answered/assumed/deferred-out-of-scope | <files/behavior/verification/risk> | <final decision> |

## Assumption Ledger

| ID | Assumption | Evidence | Confidence | Correction Path |
|----|-----------|----------|------------|-----------------|
| S1 | ... | ... | High/Medium/Low | <what to do if wrong> |

## Approaches Considered

### Approach 1: <Name>

- **Description**: ...
- **Pros**: ...
- **Cons**: ...
- **Risk**: ...

### Approach 2: <Name>

- **Description**: ...
- **Pros**: ...
- **Cons**: ...
- **Risk**: ...

(Include 2-3 approaches)

## Recommended Approach

Detailed description of the chosen approach with enough specificity that someone can implement it without asking basic questions. Include:

- Architecture decisions
- File and module boundaries
- Data flow / component interactions
- Key interfaces or API signatures
- Error handling strategy
- Testing approach

## Verification Strategy

How we will verify this implementation:

- **Command evidence**: `<specific command>` exits 0
- **Semantic evidence**: `<observable behavior>`
- **Test coverage**: What tests will be added or modified
- **Edge cases**: How edge cases are covered

## Risks and Rollback

| Risk | Likelihood | Impact | Mitigation | Rollback |
|------|-----------|--------|------------|----------|
| ... | High/Medium/Low | High/Medium/Low | ... | ... |
