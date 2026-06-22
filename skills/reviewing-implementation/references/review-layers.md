# Review Layers (P1 Optimization)

Phase 5 uses a five-layer review model with tiered models to minimize wall-clock time and token consumption. The `complexity` field from the Phase 2 task schema drives gating.

## Layer Summary

| Layer | Name | Gates | Model | Agent Calls |
|-------|------|-------|-------|-------------|
| 1 | Fast Gate | Strongly recommended: main Codex runs `git diff --stat`, `git diff --check`, files-exist, and import checks before spawning reviewers. | N/A (bash) | 0 agent calls |
| 2 | Spec Review | Gated by complexity: `simple` skips, `medium`/`complex` runs. Context is injected directly; reviewer does not rediscover the plan. | verifier or code-reviewer | 0-1 subagent per task |
| 3 | Code Review | Gated by complexity: `simple` skips entirely, `medium` gets correctness-only, `complex` gets correctness/safety/simplicity review. Reviewers receive `git diff` output and inspect only scoped files. | code-reviewer | 0-3 subagents per task |
| 4 | Adversarial Verify | Gated by complexity: `simple` auto-confirms, `medium` gets 1 skeptic, `complex` gets up to 3 skeptics. Runs per-task inline. | verifier | 0-3 subagents per critical finding |
| 5 | Final Review | Conditional: skip when <2 tasks OR no shared files. Summary-based synthesis; do not re-read unrelated files. | code-reviewer or main Codex | 0-1 subagent |

## Expected Wall Clock

Approximately 8-14 minutes (down from ~39 minutes) with per-task independent pipeline.

## Token Savings

Approximately 60-70% vs. uniform full Sonnet review.

## Layer Details

### Layer 1: Fast Gate

Main Codex runs bash checks before spawning review subagents:

```bash
git diff --stat          # Confirm scope of changes
git diff --check         # Whitespace errors
# For each task: test -f <file> for each task.files entry
# For Go: check imports are resolvable
```

Record missing Fast Gate evidence as review risk, but anti-exploration guardrails still apply in all subagent prompts.

### Layer 2: Spec Review

Per-task spec compliance check. Agent receives pre-injected spec sections directly in its prompt — does NOT read the plan file.

- **simple tasks:** skip this layer.
- **medium/complex tasks:** run one spec reviewer.
- **high-risk tasks** (>=2 missing expectedEvidence from Quick Gate): route to the stronger available review agent.

### Layer 3: Code Review

Per-task code quality review. Reviewers receive pre-computed `git diff` via `diffText` — they only examine changed lines.

Gating:
- **simple:** skip entirely.
- **medium:** correctness-only review (1 reviewer).
- **complex:** full 3-agent parallel when file sets and prompts are bounded.

### Layer 4: Adversarial Verification

Per-task adversarial check. Runs inline (not deferred).

Gating:
- **simple:** auto-confirm.
- **medium:** 1 skeptic.
- **complex:** up to 3 skeptics.

### Layer 5: Final Review

Cross-task synthesis by the main Codex session or one reviewer. Only runs when >=2 tasks exist AND tasks share files. Summary-based; do not re-read unrelated source files.

## Anti-Exploration Guardrails

Injected into every review agent prompt:

```
Maximum 5 file reads. DO NOT read same file twice.
FORBIDDEN: go build, go test, go vet, grep exploration.
Maximum 3 thinking blocks.
```
