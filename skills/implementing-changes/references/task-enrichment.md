# Task Enrichment And Prompt Contract

Enrich and dispatch exactly one approved Plan task per writer subagent.

## Enrichment

1. Read every `files` and `readFiles` path fresh.
2. Resolve `contextRefs`, `intakeRefs`, and `grillRefs` to actual task-local values.
3. Extract only the relevant approved Spec and Plan sections.
4. Preserve canonical `acceptanceCommands`, `expectedEvidence`, and `forbiddenEvidence` arrays.
5. Record the base commit, unique worktree path, branch, shared resources, and dependency results.
6. Do not inject unrelated conversation history or tasks.

## Direct Writer Turn

Use this contract for the writer's execution turn:

```text
Protocol: direct-phase4 writer
Task ID: <id>
Atomic outcome: <prompt>
Base commit: <sha>
Worktree: <absolute linked-worktree path>
Approved Spec: <spec path and relevant section>
Approved Plan: <plan path and exact task>
You may read: <readFiles plus files>
You may modify only: <files>
Shared resources: <resources>
Forbidden: <forbiddenEvidence and explicit non-goals>
Acceptance commands: <acceptanceCommands>
Constraints: preserve unrelated changes; do not delegate; do not leave the worktree.

Implement the approved task directly, then run only the listed acceptance commands.
Stop before expanding the approved files, resources, behavior, or design.
Return:
  status: DONE | DONE_WITH_CONCERNS | BOUNDARY_BLOCKED | BLOCKED
  changed_files:
  commands_run:
  acceptance_evidence:
  diff_stat:
  risks_or_blockers:
```

Codex main reads the diff directly from the worktree. The writer must stop with `BOUNDARY_BLOCKED` before touching an unlisted file or resource.

## Focused Reviewer Turn

After target tests pass, dispatch one fresh read-only reviewer:

```text
Protocol: phase4 focused diff review
Task ID: <id>
Approved Spec and Plan sections: <exact references>
Diff: <base commit to writer worktree>
Review only this task diff for Spec/Plan compliance, correctness, safety, and target-test adequacy.
Do not edit files, explore unrelated code, run unrelated tests, or create separate review layers.
Return:
  verdict: APPROVE | CHANGES_REQUIRED
  findings:
  residual_risks:
```

When a repair is needed, return it to the same writer. The same reviewer checks only the resulting repair diff.
