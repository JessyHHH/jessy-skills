# Project Workflow Claude Context + Deep Grill Implementation Plan
> For agentic workers... implement only the approved design, keep changes surgical, preserve backward compatibility where specified, and produce fresh verification evidence before claiming completion.

## Goal

Update `project-workflow-claude` and the Claude Code workflow scripts so the workflow restores durable `CONTEXT.md` repository context, captures task-specific intake evidence, uses a variable-depth Phase 1 deep grill, passes Phase 0/1 artifacts through downstream phases, verifies both command success and semantic evidence, and correctly models what workflow scripts can and cannot do within the Claude Code Workflow API.

The implementation must stay within the approved boundary from `/home/huangzexi/personal/jessy-skills/.claude/specs/2026-06-08-project-workflow-claude-context-grill-design.md`: update only the project workflow skill, the project workflow scripts, and focused tests unless tests prove a minimal helper update is unavoidable.

## Context

### Workflow Script API Reality

The Claude Code Workflow script API is limited to these primitives: `meta`, `phase()`, `agent()`, `parallel()`, `pipeline()`, `log()`, `budget`, `resume`. There is **no** `Bash()`, **no** `Read()`, and **no** file I/O in workflow scripts. The `agent()` function accepts options `label`, `schema`, `model`, `isolation` (`worktree` or `none`), and `agentType`.

For `isolation: 'worktree'`, the harness creates a git worktree at `.claude/worktrees/agent-{uuid}/` on a temporary branch. The agent works entirely in the isolated worktree. The harness handles lifecycle via EnterWorktree/ExitWorktree. **Workflow scripts cannot directly apply diffs back** to the main working tree — the script receives only the agent's return value (structured JSON if schema provided). External tools like `clawt` or `wisp-agentdiff` can wrap the merge-back, but the workflow script itself cannot.

For Phase 6, the master agent pre-computes `checkResults` via Bash() commands and passes them as `{name, command, exitCode, stdout, stderr}[]` to the workflow script. The master agent can also pre-compute file/text evidence checks and pass them as `evidenceChecks: [{id, type, passed, details}]`. The script CAN analyze text in stdout/stderr (passed as args), and CAN check `command-output-present/absent` against that text, but CANNOT directly read files.

### Enum Inconsistency Fixed

The existing workflow scripts have inconsistent verdict enums:
- `phase3-consensus.js` line 34: `'APPROVE'/'ITERATE'/'REJECT'` (present tense)
- `phase5-review.js` line 53: `'APPROVED'/'REJECTED'` (past tense)
- `phase5-review.js` line 194: `'APPROVED'/'REJECTED'` (final review, past tense)

These **must be unified** to present tense `'APPROVE'/'ITERATE'/'REJECT'` everywhere.

### Approved In-Scope Changes

- Restore or add `skills/project-workflow-claude/references/context-md-spec.md` with the canonical two-layer `CONTEXT.md` format.
- Create root `CONTEXT.md` if missing (using the restored spec as the format reference).
- Update `skills/project-workflow-claude/SKILL.md` so Phase 0/0.3, Phase 1, Phase 2, Phase 3, Phase 4, Phase 5, and Phase 6 document and consume explicit context, intake, grill, assumption, and evidence artifacts.
- Update `.claude/workflows/phase3-consensus.js`, `.claude/workflows/phase4-implement.js`, `.claude/workflows/phase5-review.js`, and `.claude/workflows/phase6-verify.js` to enforce the new contracts described in the design spec, corrected for actual workflow API capabilities.
- Update `tests/test-workflow-changes.sh` or add one focused test under `tests/` if the existing test file cannot cover the new contracts cleanly.

### Approved Out-of-Scope Changes

- Do not modify user global config such as `/home/huangzexi/.claude/CLAUDE.md`.
- Do not modify other skills.
- Do not add Superpowers as a dependency.
- Do not modify `install.sh` unless tests later prove script installation or sync paths must change to keep workflow contracts aligned.

### Phase 0/1 Artifacts to Preserve in Downstream Contracts

- `contextSummary`: root `CONTEXT.md` status, nearest scoped `CONTEXT.md` paths, `.claude/context/knowledge.md` status, warnings, confirmed facts, and auto facts.
- `taskIntakeSnapshot`: request summary, repo root, approved in-scope items, approved out-of-scope items, source evidence, and constraints.
- `grillSummary`: Ambiguity Register items, Assumption Ledger items, and grill exit criteria.

### Relevant Approved Grill Decisions and Assumptions

- `G1`: Root `CONTEXT.md` is the durable repository context contract; `.claude/context/knowledge.md` remains the generated analysis cache.
- `G2`: Phase 1 exits by ambiguity closure and assumption safety, not by exactly four questions or four fixed dimensions.
- `G3`: Phase 2 tasks must include context, intake, grill, evidence, and isolation-strategy fields so later phases can trace and verify work.
- `G4`: Phase 3 must warn on missing new context fields for backward compatibility but block contradictions against approved out-of-scope items and unresolved material ambiguities.
- `G5`: Phase 4 mutating tasks must declare `patchBackStrategy`; isolated worktree changes must not be silently discarded.
- `G6`: Phase 5 pass status must be gated by `finalReview.verdict === 'APPROVE'` (present tense, unified with Phase 3).
- `G7`: Phase 6 command success is necessary but not sufficient when semantic evidence arrays are supplied.
- `S1`: No subdirectory `CONTEXT.md` needs to be created by this implementation unless existing files or tests require scoped context handling.
- `S2`: The default mutating task isolation strategy for this repository is `harness-managed`: harness creates worktree, agent returns structured result with `changedFiles`, and Phase 4.5 (master agent) reviews worktree diffs and handles merge-back between Phase 4 and 5.
- `S3`: Backward compatibility should be preserved only where the design explicitly allows it: Phase 3 `planContent`-only inputs and Phase 6 command-only inputs, both with warnings.

## Approach

Implement in seven focused steps matching the approved design but corrected for actual workflow script API capabilities:

1. **Restore context-md-spec.md and create root CONTEXT.md.** Restore the `CONTEXT.md` reference spec so `SKILL.md` can link to a concrete standard. If root `CONTEXT.md` is missing at the repository root, create it using the reference spec format so Phase 0/0.3 has a durable context file to discover.

2. **Update SKILL.md.** Update prose and schema documentation, removing fixed four-question grill language and adding Phase 0/1/2/3/4/5/6 artifact flow requirements. Document the actual workflow capability boundaries.

3. **Update Phase 3 consensus.** Input validation and judge context so richer artifacts are accepted, missing fields produce warnings, scope contradictions block approval, mutating tasks require patch-back strategy, and unresolved open ambiguities block approval.

4. **Update Phase 4 task implementation.** Task prompt generation and result contract so context refs, intake refs, grill refs, expected evidence, forbidden evidence, and patch-back strategy are visible to implementers. **Important correction**: workflow scripts CANNOT apply diffs or do file I/O. Use these isolation strategies:
   - `no-isolation`: agent works in current tree (for simple/non-mutating tasks; no worktree created)
   - `harness-managed`: worktree isolation — harness manages lifecycle; agent returns structured result with `changedFiles`; Phase 4.5 (master agent step between Phase 4 and 5) reviews git diffs from worktrees and handles merge-back
   - `external-report`: agent produces change report for manual application (rare; tasks marked `DONE_WITH_CONCERNS`)
   The script requires mutating tasks to declare strategy. The actual worktree merge-back is a **Phase 4.5 master agent step** (between Phase 4 and 5), not inside the script. Script result statuses include `changedFiles`, evidence observation fields, and isolation status.

5. **Update Phase 5 review.** Pass/fail logic so final review is a hard gate and review prompts include context, intake, grill, self-review, scope, and evidence readiness. **Unify verdicts** to `'APPROVE'/'ITERATE'/'REJECT'` (present tense, matching Phase 3 `JUDGE_SCHEMA`). Gate: `passed` is true only when `verifiedCritical.length === 0 && specFailed.length === 0 && finalReview && finalReview.verdict === 'APPROVE'`. `ITERATE` and `REJECT` both block pass.

6. **Update Phase 6 verification.** Split responsibility between master agent and workflow script:
   - **Master agent** (before Workflow call): pre-computes file/text evidence checks via Bash(grep/test -f) and passes `evidenceChecks: [{id, type, passed, details}]`.
   - **Workflow script**: evaluates both `checkResults` command exit codes AND pre-computed `evidenceChecks`. The script CAN check `command-output-present/absent` against stdout/stderr text in checkResults, but CANNOT check `file-exists/text-present/text-absent` directly (those come from pre-computed `evidenceChecks`).
   - `allPassed` is true only when all command checks pass AND all evidence checks pass.
   - Preserve command-only backward compatibility with a warning when `evidenceChecks` is missing.

7. **Update tests.** Cover the durable contracts rather than brittle line numbers, then run the required verification commands.

Keep every edit traceable to the approved design. Do not introduce unrelated refactors, new dependencies, global config changes, or changes to other skills.

## Files

Modify or create only these implementation files unless the test update proves a minimal helper change is necessary:

- `skills/project-workflow-claude/SKILL.md`
- `skills/project-workflow-claude/references/context-md-spec.md`
- `CONTEXT.md` (root, created by T1 if missing)
- `.claude/workflows/phase3-consensus.js`
- `.claude/workflows/phase4-implement.js`
- `.claude/workflows/phase5-review.js`
- `.claude/workflows/phase6-verify.js`
- `tests/test-workflow-changes.sh` or one focused new test under `tests/`

Do not plan or make changes to:

- `/home/huangzexi/.claude/CLAUDE.md`
- other skill directories
- `install.sh`, unless tests later prove it is necessary to preserve script contract installation or sync behavior

## Verification

Required final verification commands after implementation:

- `bash tests/test-workflow-changes.sh`
- `git diff --check`

Implementation should also use focused interim checks where practical, for example direct script invocation with fixture JSON for Phase 3, Phase 5, and Phase 6 if the scripts expose callable behavior. Fresh verification evidence must include command output summaries and any semantic evidence outcomes relevant to the changed contracts.

Expected final evidence:

- `skills/project-workflow-claude/references/context-md-spec.md` exists and contains `KNOWLEDGE_START`, `KNOWLEDGE_END`, `INSTRUCTION_START`, `INSTRUCTION_END`, `[confirmed]`, and `[auto]`.
- `CONTEXT.md` exists at repository root with the two-layer marker structure from the reference spec.
- `skills/project-workflow-claude/SKILL.md` references `references/context-md-spec.md` and documents `contextSummary`, `taskIntakeSnapshot`, `Ambiguity Register`, `Assumption Ledger`, the expanded Phase 2 task schema, Phase 4.5 master merge-back step, and downstream consumption by Phase 3 through Phase 6.
- `.claude/workflows/phase3-consensus.js` references or validates `contextSummary`, `taskIntakeSnapshot`, `grillSummary`, `tasks`, `expectedEvidence`, and `patchBackStrategy`.
- `.claude/workflows/phase4-implement.js` references or validates `contextRefs`, `intakeRefs`, `grillRefs`, `expectedEvidence`, `forbiddenEvidence`, `patchBackStrategy`, `changedFiles`, `expectedEvidenceObserved`, and `forbiddenEvidenceObserved`. Does NOT contain any diff-application or file-I/O logic (that belongs to Phase 4.5 master agent).
- `.claude/workflows/phase5-review.js` computes pass status with `finalReview && finalReview.verdict === 'APPROVE'` (present tense). Blocks `ITERATE` and `REJECT` verdicts. Uses unified enum matching Phase 3.
- `.claude/workflows/phase6-verify.js` evaluates both `checkResults` command exits and pre-computed `evidenceChecks`. The `command-output-present` and `command-output-absent` evidence types are checked against stdout/stderr in checkResults. `file-exists`, `text-present`, and `text-absent` come from pre-computed `evidenceChecks` array passed by master agent.

Forbidden final evidence:

- Wording that Phase 1 must ask exactly four questions or finish only when exactly four fixed dimensions are clear.
- Any new dependency on Superpowers.
- Any change to user global config.
- Any silent success path for mutating Phase 4 tasks without `patchBackStrategy`.
- Any Phase 5 pass result when `finalReview.verdict` is `ITERATE` or `REJECT`.
- Any Phase 6 `allPassed: true` result when supplied `evidenceChecks` contain failures.
- Any workflow script attempting direct file I/O, Bash(), Read(), or diff application.
- Verdict enum mismatch between phases (past tense `APPROVED`/`REJECTED` in Phase 5).

## Risks

- `CONTEXT.md` and `.claude/context/knowledge.md` could become competing sources of truth. Mitigate by documenting `CONTEXT.md` as durable context and `knowledge.md` as generated analysis cache, and by labeling both statuses in `contextSummary`.
- Automatic context refresh could overwrite human-approved facts. Mitigate by preserving `[confirmed]` entries, refreshing only `[auto]` entries, and refusing blind rewrites when markers are malformed.
- Variable-depth grill could become too broad. Mitigate with explicit exit criteria tied to file selection, behavior, contract, verification, and risk impact.
- New script contracts could break existing callers. Mitigate only where approved: Phase 3 warns on missing context fields for `planContent`-only callers, and Phase 6 warns on missing evidence arrays for command-only callers.
- Worktree isolation could hide completed changes. Mitigate by using `harness-managed` strategy where harness manages worktree lifecycle, agents report `changedFiles` in structured returns, and Phase 4.5 (master agent) reviews worktree diffs and handles merge-back. `external-report` tasks are `DONE_WITH_CONCERNS`, not fully implemented.
- Phase 5 verdict enum mismatch with Phase 3 could cause inconsistent pass gating. Mitigate by unifying to present-tense `'APPROVE'/'ITERATE'/'REJECT'` across all phases and explicitly gating pass on `finalReview.verdict === 'APPROVE'`.
- Semantic evidence checks could become overly broad. Mitigate by implementing only the approved simple types and splitting responsibility: file evidence is pre-computed by the master agent; workflow script evaluates pre-computed results alongside command exits.
- Tests could overfit exact prose. Mitigate by checking durable contract terms, schema fields, and observable behavior instead of line numbers or full paragraphs.
- Parallel vs pipeline misuse could cause inefficient task execution. Mitigate by using `parallel()` for barrier concurrency (all complete before proceeding) and `pipeline()` for stage-by-stage streaming where items flow through stages independently.

## Tasks

```json:tasks
[
  {
    "id": "T1",
    "prompt": "Restore or add the reference spec at skills/project-workflow-claude/references/context-md-spec.md AND create root CONTEXT.md if missing.\n\nThe reference spec must define the canonical root and scoped CONTEXT.md contract for project-workflow-claude. Include: root CONTEXT.md lives at project root; optional subdirectory CONTEXT.md files load from broadest to nearest and refine root context; contradictions between confirmed facts are surfaced as warnings; required two-layer marker structure with <!-- KNOWLEDGE_START -->, <!-- KNOWLEDGE_END -->, <!-- INSTRUCTION_START -->, and <!-- INSTRUCTION_END -->; Knowledge sections Architecture, Entity Map, Entities, Key Interfaces, Package Map, and Confidence; Instruction sections Build & Test Commands, Code Conventions, Invariants, and Domain Glossary; allowed evidence tags [confirmed] and [auto]; update rules that automatic refresh never removes [confirmed] entries, may replace [auto] entries inside known sections, and must not blindly rewrite malformed markers.\n\nAdditionally: if root CONTEXT.md does not exist at the repository root (/home/huangzexi/personal/jessy-skills/CONTEXT.md), create it using the two-layer format from the reference spec. Populate it with at minimum the marker structure and one [confirmed] entry per section based on verifiable repository facts (e.g., 'Skills are stored under skills/*/SKILL.md' in Knowledge section, 'bash tests/test-workflow-changes.sh' in Instruction section).\n\nDo not modify SKILL.md or workflow scripts in this task.\n\nVerify with: test -f skills/project-workflow-claude/references/context-md-spec.md; test -f CONTEXT.md; grep -q 'KNOWLEDGE_START' skills/project-workflow-claude/references/context-md-spec.md; grep -q 'INSTRUCTION_START' skills/project-workflow-claude/references/context-md-spec.md; grep -q '\\[confirmed\\]' skills/project-workflow-claude/references/context-md-spec.md; grep -q '\\[auto\\]' skills/project-workflow-claude/references/context-md-spec.md; grep -q 'KNOWLEDGE_START' CONTEXT.md; grep -q 'INSTRUCTION_START' CONTEXT.md; git diff --check.",
    "files": [
      "skills/project-workflow-claude/references/context-md-spec.md",
      "CONTEXT.md"
    ],
    "complexity": "low",
    "mutatesFiles": true,
    "contextRefs": [
      "skills/project-workflow-claude/references/context-md-spec.md",
      "CONTEXT.md",
      ".claude/context/knowledge.md"
    ],
    "intakeRefs": [
      "approvedInScope",
      "approvedOutOfScope",
      "constraints"
    ],
    "grillRefs": [
      "G1",
      "S1"
    ],
    "expectedEvidence": [
      "skills/project-workflow-claude/references/context-md-spec.md exists",
      "CONTEXT.md exists at repository root",
      "Reference spec contains KNOWLEDGE_START and KNOWLEDGE_END markers",
      "Reference spec contains INSTRUCTION_START and INSTRUCTION_END markers",
      "Reference spec documents [confirmed] and [auto] evidence tags",
      "Reference spec documents root and scoped CONTEXT.md precedence and malformed marker handling",
      "Root CONTEXT.md contains two-layer marker structure with at least one [confirmed] entry per section"
    ],
    "forbiddenEvidence": [
      "Reference spec says .claude/context/knowledge.md replaces root CONTEXT.md",
      "Reference spec permits automatic removal of [confirmed] entries",
      "Reference spec introduces a Superpowers dependency"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T2",
    "prompt": "Update skills/project-workflow-claude/SKILL.md to document the approved context and deep grill workflow.\n\nIn Phase 0 and Phase 0.3, distinguish root CONTEXT.md, optional scoped CONTEXT.md, and .claude/context/knowledge.md; reference skills/project-workflow-claude/references/context-md-spec.md; require context discovery output as a contextSummary object with rootContextPath, rootContextStatus, nearestContextPaths, knowledgePath, knowledgeStatus, contextWarnings, confirmedFacts, and autoFacts.\n\nAdd a Phase 0 Task Intake Snapshot with requestSummary, repoRoot, approvedInScope, approvedOutOfScope, sourceEvidence, and constraints.\n\nReplace fixed four-question or four-dimension Phase 1 grill wording with a variable-depth Ambiguity Register and Assumption Ledger. Require one question at a time only when an open ambiguity can materially change files, behavior, public contract, verification, or risk.\n\nRequire sectioned design approval with Goal, Context inputs used, Scope and non-goals, Proposed behavior by phase, Script contract changes, Test and verification plan, Risks and mitigations, and Acceptance criteria.\n\nUpdate Phase 2 task schema docs to include id, prompt, files, complexity, mutatesFiles, contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, and patchBackStrategy with allowed values: 'no-isolation' (agent works in current tree, no worktree), 'harness-managed' (harness creates worktree, agent reports changedFiles in structured return, Phase 4.5 master reviews diffs and handles merge-back), and 'external-report' (agent produces manual change report).\n\nDocument Phase 4.5 as a master agent step between Phase 4 and Phase 5 that reviews worktree git diffs and handles merge-back for harness-managed tasks.\n\nUpdate downstream Phase 3 through Phase 6 docs so they consume contextSummary, taskIntakeSnapshot, grillSummary, assumptions, and evidence requirements.\n\nDocument that workflow scripts cannot apply diffs or perform file I/O directly — the master agent handles all Bash(), file reading, and worktree diff review.\n\nDo not change other skills.\n\nVerify with: grep -q 'references/context-md-spec.md' skills/project-workflow-claude/SKILL.md; grep -q 'Task Intake Snapshot' skills/project-workflow-claude/SKILL.md; grep -q 'Ambiguity Register' skills/project-workflow-claude/SKILL.md; grep -q 'Assumption Ledger' skills/project-workflow-claude/SKILL.md; grep -q 'patchBackStrategy' skills/project-workflow-claude/SKILL.md; grep -q 'expectedEvidence' skills/project-workflow-claude/SKILL.md; grep -q 'forbiddenEvidence' skills/project-workflow-claude/SKILL.md; grep -q 'harness-managed' skills/project-workflow-claude/SKILL.md; grep -q 'Phase 4.5' skills/project-workflow-claude/SKILL.md; ! grep -qi 'exactly four questions' skills/project-workflow-claude/SKILL.md; git diff --check.",
    "files": [
      "skills/project-workflow-claude/SKILL.md"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      "skills/project-workflow-claude/SKILL.md",
      "skills/project-workflow-claude/references/context-md-spec.md",
      "CONTEXT.md",
      ".claude/context/knowledge.md"
    ],
    "intakeRefs": [
      "approvedInScope",
      "approvedOutOfScope",
      "constraints"
    ],
    "grillRefs": [
      "G1",
      "G2",
      "G3",
      "S1",
      "S2"
    ],
    "expectedEvidence": [
      "SKILL.md references references/context-md-spec.md",
      "SKILL.md documents contextSummary and Task Intake Snapshot",
      "SKILL.md documents Ambiguity Register and Assumption Ledger",
      "SKILL.md documents variable-depth Phase 1 exit criteria",
      "SKILL.md documents expanded Phase 2 task schema fields",
      "SKILL.md documents Phase 4.5 master merge-back step",
      "SKILL.md documents patchBackStrategy with no-isolation, harness-managed, external-report",
      "SKILL.md documents downstream Phase 3 through Phase 6 consumption of Phase 0/1 artifacts",
      "SKILL.md notes workflow script API limitations (no Bash/Read/file I/O)"
    ],
    "forbiddenEvidence": [
      "SKILL.md requires exactly four questions",
      "SKILL.md requires exactly four fixed clarity dimensions before Phase 1 can exit",
      "SKILL.md says Superpowers must be installed or used as a dependency",
      "SKILL.md says .claude/context/knowledge.md replaces root CONTEXT.md",
      "SKILL.md claims workflow scripts can apply diffs or perform file I/O",
      "SKILL.md lists apply-diff or merge-commit as patchBackStrategy values"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T3",
    "prompt": "Update .claude/workflows/phase3-consensus.js for the richer Phase 3 contract.\n\nThe script must accept input with planContent plus optional contextSummary, taskIntakeSnapshot, grillSummary, and tasks. Preserve backward compatibility for callers that pass only planContent, but add structured contextWarnings or taskContractWarnings for missing new fields. Keep planContent as the primary input — new fields are optional enhancements with warnings for backward compatibility.\n\nJudge prompts or validation must include contextSummary, taskIntakeSnapshot, grillSummary, and task contract data when present.\n\nAdd validation that rejects or blocks approval for:\n- Plans contradicting taskIntakeSnapshot.approvedOutOfScope\n- Unresolved open grill ambiguities that are not assumed with a ledger entry and not deferred-out-of-scope\n- Mutating tasks missing patchBackStrategy\n- Tasks missing expectedEvidence unless their prompt clearly explains verification\n\nOutput must include verdict ('APPROVE'/'ITERATE'/'REJECT', present tense), score, findings, contextWarnings, and taskContractWarnings.\n\nDo not modify Phase 4, Phase 5, Phase 6, or SKILL.md in this task.\n\nVerify with: grep -q 'contextSummary' .claude/workflows/phase3-consensus.js; grep -q 'taskIntakeSnapshot' .claude/workflows/phase3-consensus.js; grep -q 'grillSummary' .claude/workflows/phase3-consensus.js; grep -q 'taskContractWarnings' .claude/workflows/phase3-consensus.js; grep -q 'patchBackStrategy' .claude/workflows/phase3-consensus.js; grep -q 'expectedEvidence' .claude/workflows/phase3-consensus.js; git diff --check. If the script has direct executable behavior, also run a small fixture where a mutating task omits patchBackStrategy and confirm the result is not APPROVE.",
    "files": [
      ".claude/workflows/phase3-consensus.js"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      ".claude/workflows/phase3-consensus.js",
      "CONTEXT.md",
      ".claude/context/knowledge.md"
    ],
    "intakeRefs": [
      "approvedInScope",
      "approvedOutOfScope",
      "constraints"
    ],
    "grillRefs": [
      "G3",
      "G4",
      "S3"
    ],
    "expectedEvidence": [
      "phase3-consensus.js accepts or reads contextSummary, taskIntakeSnapshot, grillSummary, and tasks",
      "phase3-consensus.js emits contextWarnings and taskContractWarnings",
      "phase3-consensus.js validates patchBackStrategy on mutating tasks",
      "phase3-consensus.js validates expectedEvidence or an explicit verification explanation",
      "phase3-consensus.js blocks approved out-of-scope contradictions and unresolved open ambiguities",
      "phase3-consensus.js keeps planContent as primary input with new fields as optional warnings"
    ],
    "forbiddenEvidence": [
      "phase3-consensus.js hard-fails planContent-only callers without warning compatibility",
      "phase3-consensus.js approves mutating tasks without patchBackStrategy",
      "phase3-consensus.js ignores approvedOutOfScope when determining approval",
      "phase3-consensus.js ignores open ambiguities when determining approval",
      "phase3-consensus.js changes verdict enum to past-tense APPROVED/REJECTED"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T4",
    "prompt": "Update .claude/workflows/phase4-implement.js for the richer Phase 4 implementation contract and isolation strategy handling.\n\nCRITICAL CONSTRAINT: Workflow scripts CANNOT apply diffs, do file I/O, or call Bash()/Read(). Only meta, phase(), agent(), parallel(), pipeline(), log(), budget, resume are available. The agent() function handles isolation when worktree is specified, but the script cannot merge changes back.\n\nEach generated implementer prompt must include relevant contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, and patchBackStrategy from the Phase 2 task object. Mutating tasks must be rejected or marked unable to start when patchBackStrategy is missing.\n\nImplement these isolation strategies:\n- 'no-isolation': agent works in current tree for simple/non-mutating tasks (isolation: undefined or 'none'). No worktree needed.\n- 'harness-managed': agent(isolation:'worktree') where harness manages lifecycle. Agent MUST report changedFiles in its structured return. The actual worktree diff review and merge-back is a PHASE 4.5 master agent step (between Phase 4 and 5), NOT in this script. This script just collects changedFiles and reports them.\n- 'external-report': agent produces change report for manual application. Task result status must be DONE_WITH_CONCERNS rather than DONE, requiring Phase 5 attention.\n\nThe script must not silently discard isolated worktree changes.\n\nPhase 4 task results must include: taskId, status, selfReviewStatus, changedFiles (array of paths, critical for harness-managed tasks), expectedEvidenceObserved, forbiddenEvidenceObserved, and patchBackStatus (strategy used + isolation status).\n\nDo not modify other workflow scripts in this task.\n\nVerify with: grep -q 'contextRefs' .claude/workflows/phase4-implement.js; grep -q 'intakeRefs' .claude/workflows/phase4-implement.js; grep -q 'grillRefs' .claude/workflows/phase4-implement.js; grep -q 'expectedEvidence' .claude/workflows/phase4-implement.js; grep -q 'forbiddenEvidence' .claude/workflows/phase4-implement.js; grep -q 'patchBackStrategy' .claude/workflows/phase4-implement.js; grep -q 'changedFiles' .claude/workflows/phase4-implement.js; grep -q 'harness-managed' .claude/workflows/phase4-implement.js; grep -q 'no-isolation' .claude/workflows/phase4-implement.js; grep -q 'external-report' .claude/workflows/phase4-implement.js; grep -q 'DONE_WITH_CONCERNS' .claude/workflows/phase4-implement.js; ! grep -q 'apply-diff' .claude/workflows/phase4-implement.js; git diff --check. If direct script fixtures are practical, run one mutating task without patchBackStrategy and confirm it does not report DONE.",
    "files": [
      ".claude/workflows/phase4-implement.js"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      ".claude/workflows/phase4-implement.js",
      "CONTEXT.md",
      ".claude/context/knowledge.md"
    ],
    "intakeRefs": [
      "approvedInScope",
      "approvedOutOfScope",
      "constraints"
    ],
    "grillRefs": [
      "G3",
      "G5",
      "S2"
    ],
    "expectedEvidence": [
      "phase4-implement.js includes contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, and patchBackStrategy in implementer context",
      "phase4-implement.js requires patchBackStrategy for mutating tasks",
      "phase4-implement.js distinguishes no-isolation, harness-managed, and external-report",
      "phase4-implement.js collects changedFiles from agent structured returns for harness-managed tasks",
      "phase4-implement.js reports changedFiles, expectedEvidenceObserved, and forbiddenEvidenceObserved",
      "external-report tasks are DONE_WITH_CONCERNS rather than DONE",
      "phase4-implement.js does NOT attempt direct file I/O, diff application, or Bash() calls"
    ],
    "forbiddenEvidence": [
      "phase4-implement.js silently succeeds mutating tasks without patchBackStrategy",
      "phase4-implement.js silently discards worktree changes",
      "phase4-implement.js treats external-report tasks as fully DONE",
      "phase4-implement.js attempts direct diff application or file I/O",
      "phase4-implement.js references apply-diff, merge-commit, or manual-report as strategies"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T5",
    "prompt": "Update .claude/workflows/phase5-review.js so final review is a hard gate and review context is richer.\n\nCRITICAL: Unify verdict enums to present tense 'APPROVE'/'ITERATE'/'REJECT' matching Phase 3 JUDGE_SCHEMA (currently Phase 5 uses past-tense 'APPROVED'/'REJECTED' at lines 53 and 194).\n\nThe pass condition must be equivalent to:\n```js\npassed = verifiedCritical.length === 0 &&\n  specFailed.length === 0 &&\n  finalReview &&\n  finalReview.verdict === 'APPROVE'\n```\n\nITERATE and REJECT must both block pass. REJECT should be reported more prominently as a fundamental final-review failure.\n\nSpec compliance review must compare changed files against the plan plus taskIntakeSnapshot, contextSummary, and grillSummary decisions. Code quality review should run only for tasks that pass spec compliance. Preserve Phase 4 selfReviewStatus visibility in review context.\n\nFinal review must check cross-task consistency, scope compliance, context consistency, and evidence readiness.\n\nStructured output must include passed, criticalCount, highCount, specFailed, and finalReview with verdict ('APPROVE'/'ITERATE'/'REJECT') and reasons.\n\nDo not modify other workflow scripts in this task.\n\nVerify with: grep -q 'finalReview' .claude/workflows/phase5-review.js; grep -q \"verdict === 'APPROVE'\" .claude/workflows/phase5-review.js; grep -q 'ITERATE' .claude/workflows/phase5-review.js; grep -q 'REJECT' .claude/workflows/phase5-review.js; grep -q 'contextSummary' .claude/workflows/phase5-review.js; grep -q 'taskIntakeSnapshot' .claude/workflows/phase5-review.js; grep -q 'grillSummary' .claude/workflows/phase5-review.js; ! grep -q \"'APPROVED'\" .claude/workflows/phase5-review.js; ! grep -q \"'REJECTED'\" .claude/workflows/phase5-review.js; git diff --check. If direct invocation is practical, run a fixture where verifiedCritical is empty, specFailed is empty, and finalReview.verdict is REJECT, then confirm passed is false.",
    "files": [
      ".claude/workflows/phase5-review.js"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [
      ".claude/workflows/phase5-review.js",
      "CONTEXT.md",
      ".claude/context/knowledge.md"
    ],
    "intakeRefs": [
      "approvedInScope",
      "approvedOutOfScope",
      "constraints"
    ],
    "grillRefs": [
      "G6",
      "G3"
    ],
    "expectedEvidence": [
      "phase5-review.js gates passed on finalReview.verdict === 'APPROVE' (present tense)",
      "phase5-review.js blocks ITERATE and REJECT final verdicts",
      "phase5-review.js includes contextSummary, taskIntakeSnapshot, and grillSummary in review context",
      "phase5-review.js preserves Phase 4 selfReviewStatus visibility",
      "phase5-review.js outputs finalReview verdict and reasons",
      "phase5-review.js uses APPROVE/ITERATE/REJECT (present tense) matching Phase 3",
      "phase5-review.js has no APPROVED/REJECTED enums (past tense removed)"
    ],
    "forbiddenEvidence": [
      "phase5-review.js can return passed true when finalReview.verdict is REJECT",
      "phase5-review.js can return passed true when finalReview.verdict is ITERATE",
      "phase5-review.js ignores finalReview in pass calculation",
      "phase5-review.js runs code quality review before spec compliance for failed tasks",
      "phase5-review.js uses past-tense APPROVED or REJECTED enum values"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T6",
    "prompt": "Update .claude/workflows/phase6-verify.js so semantic evidence is supported in addition to command exits.\n\nCRITICAL: File evidence (file-exists, text-present, text-absent) MUST be pre-computed by the MASTER AGENT before the Workflow call and passed as evidenceChecks array: [{id, type, passed, details}]. The workflow script CANNOT directly read files (no Bash/Read/file I/O available).\n\nInput contract:\n- 'checkResults': [{name, command, exitCode, stdout, stderr}] — pre-computed by master agent via Bash()\n- 'evidenceChecks': [{id, description, type, passed, details}] — pre-computed by master agent via Bash(grep/test -f)\n\nThe script evaluates both:\n1. Command exit codes from checkResults (existing behavior)\n2. Pre-computed evidenceChecks pass/fail status (new behavior)\n\nThe script CAN check 'command-output-present' and 'command-output-absent' against stdout/stderr text within checkResults since that data is passed as args.\n\n'allPassed' must be true only when all command checks pass AND all evidenceChecks pass AND dry-round requirements are satisfied.\n\nEvidence failures must be reported separately from command failures and included in fix guidance.\n\n'shouldContinue' should remain true when semantic evidence fails and fixes are possible.\n\nPreserve backward compatibility when no evidenceChecks array is supplied: use command-only behavior AND emit a warning that semantic evidence was not provided.\n\nDo not modify other workflow scripts in this task.\n\nVerify with: grep -q 'evidenceChecks' .claude/workflows/phase6-verify.js; grep -q 'file-exists' .claude/workflows/phase6-verify.js; grep -q 'text-present' .claude/workflows/phase6-verify.js; grep -q 'text-absent' .claude/workflows/phase6-verify.js; grep -q 'command-output-present' .claude/workflows/phase6-verify.js; grep -q 'command-output-absent' .claude/workflows/phase6-verify.js; grep -q 'allPassed' .claude/workflows/phase6-verify.js; ! grep -q 'expectedEvidence' .claude/workflows/phase6-verify.js; ! grep -q 'forbiddenEvidence' .claude/workflows/phase6-verify.js; git diff --check. If direct invocation is practical, run one fixture with passing command checks but failing evidenceChecks and confirm allPassed is false.",
    "files": [
      ".claude/workflows/phase6-verify.js"
    ],
    "complexity": "high",
    "mutatesFiles": true,
    "contextRefs": [
      ".claude/workflows/phase6-verify.js",
      "CONTEXT.md",
      ".claude/context/knowledge.md"
    ],
    "intakeRefs": [
      "approvedInScope",
      "approvedOutOfScope",
      "constraints"
    ],
    "grillRefs": [
      "G7",
      "S3"
    ],
    "expectedEvidence": [
      "phase6-verify.js accepts evidenceChecks array from master agent",
      "phase6-verify.js evaluates file-exists, text-present, text-absent from pre-computed evidenceChecks",
      "phase6-verify.js evaluates command-output-present and command-output-absent against checkResults stdout/stderr",
      "phase6-verify.js fails allPassed when supplied evidenceChecks contain failures even if commands pass",
      "phase6-verify.js reports evidence failures separately from command failures",
      "phase6-verify.js warns when evidenceChecks is absent and command-only compatibility is used",
      "phase6-verify.js does NOT attempt direct file I/O or Bash in script"
    ],
    "forbiddenEvidence": [
      "phase6-verify.js returns allPassed true when supplied evidenceChecks contain failures",
      "phase6-verify.js treats command success alone as sufficient when evidenceChecks is supplied",
      "phase6-verify.js hard-fails old command-only inputs without the approved warning compatibility",
      "phase6-verify.js attempts direct file reading or Bash() for text/file evidence checks",
      "phase6-verify.js uses expectedEvidence/forbiddenEvidence field names instead of evidenceChecks"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T7",
    "prompt": "Update tests to cover all new contracts. Prefer extending tests/test-workflow-changes.sh; add one focused new test under tests/ only if the existing file cannot cover these checks cleanly.\n\nRequired test coverage:\n- context-md-spec.md exists; root CONTEXT.md exists\n- SKILL.md references references/context-md-spec.md\n- The reference spec contains KNOWLEDGE_START, KNOWLEDGE_END, INSTRUCTION_START, INSTRUCTION_END, [confirmed], and [auto]\n- SKILL.md includes Ambiguity Register, Assumption Ledger, variable-depth exit criteria, Task Intake Snapshot, contextSummary, expectedEvidence, forbiddenEvidence, patchBackStrategy, harness-managed, Phase 4.5\n- Fixed wording requiring exactly four questions or exactly four fixed dimensions is absent\n- phase3-consensus.js supports contextSummary, taskIntakeSnapshot, grillSummary, tasks, contextWarnings or taskContractWarnings, expectedEvidence, and patchBackStrategy\n- phase4-implement.js supports contextRefs, intakeRefs, grillRefs, expectedEvidence, forbiddenEvidence, patchBackStrategy, changedFiles, harness-managed, no-isolation, external-report. Does NOT contain apply-diff, merge-commit, or manual-report.\n- phase5-review.js uses APPROVE/ITERATE/REJECT (present tense). Does NOT contain APPROVED or REJECTED enum values. Has a rejected final review case where verifiedCritical and specFailed are empty but passed is false.\n- phase6-verify.js supports evidenceChecks, file-exists, text-present, text-absent, command-output-present, command-output-absent, and evidence failures affecting allPassed. Does NOT use expectedEvidence/forbiddenEvidence field names.\n\nRun final verification: bash tests/test-workflow-changes.sh; git diff --check.\n\nDo not add brittle line-number checks or large exact-paragraph comparisons.",
    "files": [
      "tests/test-workflow-changes.sh",
      "tests/"
    ],
    "complexity": "high",
    "mutatesFiles": true,
    "contextRefs": [
      "tests/test-workflow-changes.sh",
      "skills/project-workflow-claude/SKILL.md",
      "skills/project-workflow-claude/references/context-md-spec.md",
      "CONTEXT.md",
      ".claude/workflows/phase3-consensus.js",
      ".claude/workflows/phase4-implement.js",
      ".claude/workflows/phase5-review.js",
      ".claude/workflows/phase6-verify.js"
    ],
    "intakeRefs": [
      "approvedInScope",
      "approvedOutOfScope",
      "constraints"
    ],
    "grillRefs": [
      "G1",
      "G2",
      "G3",
      "G4",
      "G5",
      "G6",
      "G7",
      "S1",
      "S2",
      "S3"
    ],
    "expectedEvidence": [
      "bash tests/test-workflow-changes.sh passes",
      "git diff --check passes",
      "Tests assert context-md-spec.md exists and has required markers and tags",
      "Tests assert root CONTEXT.md exists with markers",
      "Tests assert SKILL.md variable-depth grill and new task schema docs",
      "Tests assert Phase 5 REJECT final review blocks pass (with APPROVE/ITERATE/REJECT enums)",
      "Tests assert Phase 3, Phase 4, and Phase 6 new contract fields",
      "Tests assert Phase 4 uses harness-managed/no-isolation/external-report (not apply-diff/merge-commit)",
      "Tests assert Phase 5 has no past-tense APPROVED/REJECTED enums",
      "Tests assert Phase 6 uses evidenceChecks (not expectedEvidence/forbiddenEvidence as field names)"
    ],
    "forbiddenEvidence": [
      "Tests depend on exact line numbers from SKILL.md or workflow scripts",
      "Tests pass when Phase 5 finalReview.verdict is REJECT and passed is true",
      "Tests pass when Phase 6 supplied evidence fails and allPassed is true",
      "Tests require changes to other skills or user global config"
    ],
    "patchBackStrategy": "harness-managed"
  }
]
```
