# Implementation Plan: Phase 1 Grill Fix

**Date:** 2026-06-01
**Status:** Final — implemented (Phase 4-6 complete)

## Goal

Fix project-workflow-claude Phase 1 to include proper Grill behavior — explore codebase before questioning, ask one question at a time with recommended answers embedded, confirm scope boundary as the mandatory first question, self-check exit when all 4 clarity dimensions are met (intent, boundary, constraints, success criteria), and auto-transition to Phase 2 on approval.

## Context

- Project: jessy-skills Skills Repository (claude branch)
- File: `skills/project-workflow-claude/SKILL.md`
- Source patterns: obra/superpowers brainstorming, Karpathy 5 principles
- Platform: Claude Code + OMC

## Approach

Replace Phase 1 section (lines 162-201) with new Grill-based Phase 1 having 8 steps (was 9, now 8 after merging BOUNDARY into GRILL, adding back Skill Re-Check, and adding yield note + auto-transition):

### New Phase 1 structure (8 steps)

1. **EXPLORE FIRST** (timebox 60 seconds)
   - Read top-level files matching task keywords.
   - Run `git log --oneline -5` for recent changes context.
   - If the codebase already answers a question, skip that question — never re-ask what's in the repo.
   - Hard limit: 60 seconds. Move on when the timer expires.

2. **GRILL** (one question at a time)
   - **Mandatory first question:** Confirm scope boundary — "Here's what I think is in/out of scope based on exploration. Is this correct?" Ask nothing else until boundary is pinned.
   - Then proceed through remaining clarity dimensions: intent (why), constraints (versions/deps/non-negotiables), success criteria (concrete, verifiable).
   - **Each question MUST embed a recommended answer:** "I think X because Y — does that work?" This reduces decision fatigue and surfaces anchoring bias for correction.
   - **Exit condition:** Self-check all 4 dimensions clear before asking the next question. If all 4 hold, yield: "**Grill mode complete** — moving to approach design." Then **auto-transition to PROPOSE**.

3. **PROPOSE** — 2-3 approaches with trade-offs + recommendation.

4. **WRITE SPEC** — `Agent(description='Write design spec', prompt='Write the design spec to .claude/specs/YYYY-MM-DD-<topic>-design.md. Content: [spec_content].', subagent_type='general-purpose')`

5. **SELF-REVIEW** — Check for TBD/TODO, contradictions, ambiguous scope.

6. **SKILL RE-CHECK** (re-added from original Phase 1)
   - Re-scan codebase + task signals against routing table.
   - Diff against Phase 0.5 loaded skills → load missing ones via `Skill(skill='<name>')`.
   - This was incorrectly dropped in the prior revision; restored as step 6.

7. **APPROVAL** — Present spec to user for confirmation. On approval, **auto-transition to Phase 2**.

### Specific SKILL.md changes

Replace lines 162-201 (current Phase 1 section, steps 1-9) with the new 8-step structure (~55 lines).
Keep the HARD-GATE block. Merge the old standalone BOUNDARY step (step 2) into GRILL as the mandatory first question.

## Files

| Action | File | Description |
|--------|------|-------------|
| MODIFY | `skills/project-workflow-claude/SKILL.md` | Replace Phase 1 section (~40 lines changed) |

## Verification

All checks use `skills/project-workflow-claude/SKILL.md` (the file being modified):

1. `grep -c "^## Phase" skills/project-workflow-claude/SKILL.md` — output must be 11 (all phases still present)
2. `grep "EXPLORE FIRST\|GRILL\|PROPOSE" skills/project-workflow-claude/SKILL.md` — all new step labels present
3. `grep "SKILL RE-CHECK" skills/project-workflow-claude/SKILL.md` — step 6 re-added
4. `grep "timebox 60 seconds\|git log --oneline -5" skills/project-workflow-claude/SKILL.md` — EXPLORE FIRST operational specifics present
5. `grep "embedded.*answer\|recommended answer\|does that work" skills/project-workflow-claude/SKILL.md` — GRILL recommended-answer pattern present
6. `grep "self-check.*4.*dimension\|all 4 clarity\|Grill mode complete" skills/project-workflow-claude/SKILL.md` — GRILL exit condition + yield note present
7. `grep "auto-transition to Phase 2\|auto-transition.*Phase 2" skills/project-workflow-claude/SKILL.md` — auto-transition line present
8. `head -10 skills/project-workflow-claude/SKILL.md` — YAML frontmatter unchanged
9. Source reference: superpowers brainstorming pattern (obra/superpowers) correctly attributed

## Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Grill may add too many rounds for simple tasks | LOW | EXPLORE FIRST reduces questions; "simple tasks = shorter design" rule still applies |
| Karpathy "surgical changes" violated | NONE | Only Phase 1 section changes (~40 lines out of ~490) |
| Anchoring bias from recommended answers | MEDIUM | Every recommended answer includes explicit reasoning ("because Y"); explicitly invite disagreement after each recommendation; user can always override |
| Unbounded exploration before questioning | LOW | EXPLORE FIRST hard-capped at 60 seconds; timer enforces the limit |

## Change Log

### Changes from v1 (original plan)

1. **Step order restructured (9 steps -> 8 steps):**
   - Merged standalone BOUNDARY (old step 2) into GRILL (new step 2) as the mandatory first question. Boundary confirmation is now the first action inside GRILL, not a separate step. Reason: the old structure had BOUNDARY as step 2 and GRILL as step 3 with overlapping scope — they asked different dimensions of the same "clarify scope" intent. Merging eliminates duplication while preserving the gate (scope must be confirmed before anything else).

2. **SKILL RE-CHECK restored (step 6):**
   - The old step 8 (Skill Re-Check) was incorrectly dropped in the previous revision. ARCHITECT flagged this. Re-added between SELF-REVIEW (step 5) and APPROVAL (step 7). Reason: after the design is written and reviewed, the codebase context may reveal additional needed skills that were not apparent during Phase 0.5. This step ensures we don't proceed to implementation with missing domain knowledge.

3. **EXPLORE FIRST now has operational specifics:**
   - Added: "Read top-level files matching task keywords + git log -5. Timebox: 60 seconds." Previously just said "explore codebase" with no mechanism. Reason: CRITIC noted lack of concretely actionable scope — without these details, the step was guidance, not a procedure.

4. **GRILL now has operational specifics:**
   - Added: "Embed recommended answer in question text. Exit when all 4 clarity dimensions clear — self-check before each next question." Added yield note: "Grill mode complete — moving to approach design." Added auto-transition to PROPOSE on exit. Reason: ARCHITECT flagged missing yield note + auto-transition line; CRITIC flagged missing operational specifics for GRILL.

5. **Two new risks added:**
   - Anchoring bias (MEDIUM): recommended answers could bias the user. Mitigation: explain reasoning in every recommendation; explicitly invite disagreement.
   - Unbounded exploration (LOW): EXPLORE FIRST could drift into endless research. Mitigation: hard 60-second timebox.

6. **Verification step 4 replaced:**
   - Old: `bash tests/test-workflow-changes.sh` (tests a different file — Hermes version).
   - New: grep-based checks on the actual modified file (`skills/project-workflow-claude/SKILL.md`) for all new operational specifics, exit conditions, and step labels.
   - Reason: CRITIC flagged the old verification command as testing the wrong file. Verification must directly inspect the artifact being changed.
