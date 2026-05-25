# Workflow Self-Testing Patterns

How to test changes to the project-workflow skill itself. Discovered during the v5.0→v5.1 upgrade session.

## Pattern 1: One-Shot Mode (`-z`)

Use `hermes -z "prompt"` for fast verification of individual phases.

```bash
cd /tmp/test-go-project
hermes -z "Phase 0 and Phase 1 complete. Execute Phase 1.5..." -s project-workflow,karpathy-guidelines
```

- **Best for:** Testing a single phase in isolation
- **Pitfall:** `-z` skips interactive `clarify()`. Provide mock Phase 1 results in the prompt.
- **Pitfall:** Long prompts (>300s) need `terminal(background=true, notify_on_complete=true)`

## Pattern 2: PTY Interactive Mode

Use `terminal(pty=true, background=true)` then `process(submit)` to simulate a user.

- **Best for:** Full pipeline end-to-end testing
- **Pitfall:** `clarify()` times out after 120s with no real user. Output is garbled with ANSI codes.
- **Verdict:** Useful for observing Phase output, but can't complete deep interview.

## Pattern 3: Mock Plan File

Create a plan file with known technical signals, then invoke Phase 2 post-plan check.

```bash
mkdir -p .hermes/plans/
cat > .hermes/plans/test-plan.md << 'EOF'
# Plan: Fix Cache
- Use sync.RWMutex
- Add prometheus metrics
- Table-driven tests with testify
EOF

hermes -z "Phase 2 complete. Read plan. Run Phase 2 post-plan check." ...
```

- **Best for:** Testing Phase 2 post-plan signal matching
- **Pitfall:** Plan must use keywords that match the routing table exactly.

## Pattern 4: Delegate-Task Subprocess (Observer Pattern)

**Observer model**: Main agent delegates all work to subagents, observes output, compiles results. Zero execution commands on main agent.

Use `delegate_task` to run parallel verification or self-review in background.

Single subagent:
```bash
delegate_task(
  goal="Phase 8 Retrospective...",
  context="Session summary: ...",
  toolsets=["terminal","file","skills"]
)
```

Parallel subagents (preferred for independent checks):
```bash
delegate_task(tasks=[
  {goal="Static integrity: Phase count, ref files, YAML", context="...", toolsets=["terminal","file"]},
  {goal="Routing table vs skills dir consistency", context="...", toolsets=["terminal","file"]},
  {goal="Residual reference scan", context="...", toolsets=["terminal","file"]},
])
```

- **Best for:** Phase 6 verification, Phase 8 retrospective, code review, any independent parallel checks
- **Pitfall:** Subprocess doesn't have main conversation context — provide detailed summary.
- **Pitfall:** Main agent must re-verify subagent claims. "Subagent said success" ≠ verified (see Phase 6 Iron Law).
- **Validated:** 2026-05-21 — 3 parallel subagents on jessy-skills, 227s wall time, found 2 real issues. See `references/subagent-observation-test-2026-05-21.md` for data.

## Pattern 5: Intentional Bug → Self-Heal Demo

Create a test branch with a deliberate bug, commit, then verify self-review catches it.

```bash
git checkout -b test
sed -i 's/golang-concurrency/golang-concurrencYYY/' references/full-skill-routing.md
git commit -m "BUG: typo"
# Run self-review via delegate_task...
```

- **Best for:** Validating self-healing
- **Result:** Caught 8 mismatches in one run.

## Testing Order

For major workflow changes:
1. Pattern 1: test each new phase via `-z`
2. Pattern 3: test Phase 2 post-plan check with mock plans
3. Pattern 5: test self-healing with intentional bugs
4. Pattern 4: validate retrospective
5. Merge to main

Skip Pattern 2 (PTY) — too fragile for automated testing.
