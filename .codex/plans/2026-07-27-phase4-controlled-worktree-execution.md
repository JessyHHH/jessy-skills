# Codex Plan Contract: Phase 4 Controlled Worktree Execution

## Metadata

- workflow: project-workflow-codex
- version: v1
- base_commit: dc1fcd6
- created_at: 2026-07-27
- status: VERIFIED

## Scope

- goal: Add mechanically checked atomic-task, worktree, boundary, diff, and concurrency controls to Phase 4.
- in_scope: Phase 4 skill and references, planning task schema, execution contract, deterministic guard, focused tests.
- out_of_scope: live global Codex configuration, model selection, automatic commits or destructive worktree cleanup.

## Tasks

```json:tasks
[
  {
    "id": "T1-phase4-guard",
    "prompt": "Implement and test deterministic Phase 4 plan validation, scheduling, and changed-file scope checks.",
    "files": [
      "skills/implementing-changes/scripts/phase4_guard.py",
      "tests/test-phase4-controls.sh"
    ],
    "readFiles": [
      "skills/implementing-changes/SKILL.md",
      "skills/planning-implementation/references/task-schema.md"
    ],
    "resources": ["repo:test-suite"],
    "dependsOn": [],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": [
      "bash tests/test-phase4-controls.sh"
    ],
    "expectedEvidence": [
      "valid plans produce deterministic schedule waves",
      "out-of-scope changes fail the scope gate"
    ],
    "forbiddenEvidence": [
      "no automatic acceptance-command execution",
      "no automatic commit, merge, branch deletion, or forced worktree removal"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T2-phase4-contract-docs",
    "prompt": "Update workflow skills and references to require controlled two-turn writer execution in isolated worktrees with serial integration.",
    "files": [
      "skills/implementing-changes/SKILL.md",
      "skills/implementing-changes/references/task-enrichment.md",
      "skills/implementing-changes/references/worktree-quick-gate.md",
      "skills/planning-implementation/SKILL.md",
      "skills/planning-implementation/references/task-schema.md",
      "skills/project-workflow-codex/references/agent-execution.md",
      "skills/project-workflow-codex/references/contract-template.md",
      "skills/reviewing-implementation/SKILL.md",
      "codex/agents/executor.toml",
      "codex/agents/worker.toml",
      "codex/agents/test-engineer.toml",
      "tests/test-codex-workflow.sh",
      "README.md",
      ".codex/specs/2026-07-27-phase4-controlled-worktree-execution.md",
      ".codex/plans/2026-07-27-phase4-controlled-worktree-execution.md",
      ".codex/state/project-workflow-state.json",
      ".codex/state/phase4-execution-results.json",
      ".codex/state/quick-gate-results.json",
      ".codex/state/review-results.json",
      ".codex/state/verification-results.json"
    ],
    "readFiles": ["AGENTS.md"],
    "resources": ["repo:workflow-contract"],
    "dependsOn": ["T1-phase4-guard"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [],
    "intakeRefs": [],
    "grillRefs": [],
    "acceptanceCommands": [
      "bash tests/test-phase4-controls.sh",
      "bash tests/test-codex-workflow.sh"
    ],
    "expectedEvidence": [
      "Phase 4 requires PLAN_READY before APPROVE_EXECUTION",
      "writer concurrency is capped at two and integration is serial",
      "BOUNDARY_BLOCKED stops scope expansion",
      "Phase 5 consumes Phase 4 execution and diff evidence"
    ],
    "forbiddenEvidence": [
      "no parallel writer execution in the same worktree",
      "no implicit scope expansion"
    ],
    "patchBackStrategy": "no-isolation"
  }
]
```

## Execution Override

The main Codex session owns all edits and verification for this workflow self-change. The task contracts are used as scope and evidence contracts, not as authorization to dispatch writer subagents.

## Verification Contract

- `bash tests/test-phase4-controls.sh`
- `bash tests/test-codex-workflow.sh`
- all `tests/test-*.sh` files individually
- `quick_validate.py` for each changed skill
- `git diff --check`
