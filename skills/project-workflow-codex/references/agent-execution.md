# Codex Subagent Execution

Use Codex subagents as a bounded execution plane. Main Codex owns routing, approvals, integration, state, and final claims.

## Dispatch Rules

- Use only `gpt-5.6-luna` and `gpt-5.6-terra` for subagents. Never dispatch
  `gpt-5.6-sol` or a DeepSeek model. If the live spawn interface exposes a stale
  fixed-model role, use `agent_type="default"`, `fork_turns="none"`, and an
  explicit allowed model, then include the role contract in the task prompt.
  If native spawn does not expose Luna, use a fresh task-local
  `codex exec -m gpt-5.6-luna` session instead of falling back to Sol.
- Dispatch only after Phase 3 preflight and explicit delegation authorization.
- Give each subagent one atomic task and task-local context. Use `fork_turns="none"` when supported.
- Prohibit recursive delegation from execution subagents.
- Prefer parallel subagents for read-only exploration, tests, triage, and review.
- Run writers concurrently only when the Phase 4 guard puts them in the same dependency/resource wave and slots are available.
- Give every writer a unique harness-managed Git worktree and branch.
- Never run concurrent writers in the main worktree or the same linked worktree.
- Preserve unrelated user changes and close integrated threads.

## Role Map

| Need | Agent role | Model |
| --- | --- | --- |
| Read-heavy exploration | `explorer` | `gpt-5.6-luna` |
| Implement a bounded patch | `executor` or `worker` | `gpt-5.6-luna` |
| Improve or assess tests | `test-engineer` | `gpt-5.6-terra` |
| Fix build, lint, typecheck, or toolchain failures | `build-fixer` | `gpt-5.6-terra` |
| Diagnose failing checks or reproductions | `debugger` | `gpt-5.6-terra` |
| Review diff against plan | `code-reviewer` | `gpt-5.6-luna` |
| Validate claims and evidence | `verifier` | `gpt-5.6-luna` |

All repository-managed roles use maximum reasoning effort. Model strength does
not relax task boundaries or evidence requirements. `gpt-5.6-luna` is the
quality-first default for implementation, exploration, review, and verification;
`gpt-5.6-terra` is limited to bounded mechanical build, test, and diagnosis work.

## Direct Writer Protocol

Phase 3 already produced and reviewed the Plan and Spec. Give the writer the exact approved task and tell it to edit immediately in its isolated worktree, run the target acceptance commands, and return concise evidence. Do not add a planning-only turn or a second execution approval.

If an unlisted file, shared resource, behavior, or decision is needed, require `BOUNDARY_BLOCKED`. Stop and revise the approved Plan; never grant implicit scope expansion through a steering message.

## Runtime Controls

- Inspect the completed writer diff directly in its worktree.
- Run the deterministic scope gate after the writer finishes.
- Steer once only toward an exact next action already inside the contract.
- Stop a semantically drifting task even when it is producing output.
- Record `BLOCKED_AGENT` after one unsuccessful in-scope steering prompt.

## Prompt Contract

Every writer prompt includes:

```text
Protocol: direct-phase4 writer
Task ID and atomic outcome
Base commit and unique worktree
Relevant approved Spec and Plan sections
Exact readable and writable files
Shared resources and dependencies
Explicit forbidden behavior
Acceptance commands
No delegation and no scope expansion
Edit immediately and run target tests
Concise changed-file, command, evidence, and blocker report
```

See `skills/implementing-changes/references/task-enrichment.md` for the exact return shapes.

After a writer passes target tests, start one fresh read-only reviewer for that task diff. The reviewer checks the relevant Spec and Plan, correctness, safety, and target-test adequacy in one pass. Independent task reviews may run concurrently. A repair returns to the same writer, and the same reviewer checks only the repair diff.

## Integration Rules

- Treat an agent completion message as a claim, never as evidence.
- Inspect `git status`, changed paths, the diff, and acceptance output locally.
- Integrate approved worktrees one at a time.
- Do not repeat target tests after every integration; Phase 6 owns fresh full verification.
- Do not enter review with unresolved scope drift.
