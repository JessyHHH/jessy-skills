# Review Layers (P1 Optimization)

Phase 5 uses a five-layer review model with tiered models to minimize wall-clock time and token consumption. The `complexity` field from the Phase 2 task schema drives gating.

## Layer Summary

| Layer | Name | Gates | Model | Agent Calls |
|-------|------|-------|-------|-------------|
| 1 | Fast Gate | Strongly Recommended: Master bash checks (`git diff --stat`, `git diff --check`, files-exist, import check) — runs BEFORE phase5-review.js script. Script logs advisory warning if missing. | N/A (bash) | 0 agent calls |
| 2 | Spec Review | Gated by complexity: `simple` skips, `medium`/`complex` runs. Context injected directly — agent does NOT read plan file. | Haiku (default) / Sonnet (high-risk: >=2 missing expectedEvidence from Quick Gate) | 0-1 agent per task |
| 3 | Code Review | Gated by complexity: `simple` skips entirely, `medium` gets correctness-only (1 agent), `complex` gets full 3-agent parallel. Reviewers receive `git diff` output — only review changed lines. | Correctness: Sonnet, Safety: Sonnet, Simplicity: Haiku | 0-3 agents per task |
| 4 | Adversarial Verify | Gated by complexity: `simple` auto-confirms, `medium` gets 1 skeptic, `complex` gets 3 skeptics. Runs per-task inline (not deferred). | Haiku | 0-3 agents per CRITICAL finding |
| 5 | Final Review | Conditional: skip when <2 tasks OR no shared files. Summary-based synthesis — does NOT re-read files. | Haiku | 0-1 agent |

## Expected Wall Clock

Approximately 8-14 minutes (down from ~39 minutes) with per-task independent pipeline.

## Token Savings

Approximately 60-70% vs. uniform full Sonnet review.

## Layer Details

### Layer 1: Fast Gate

Master agent runs bash checks before invoking `phase5-review.js`:

```bash
git diff --stat          # Confirm scope of changes
git diff --check         # Whitespace errors
# For each task: test -f <file> for each task.files entry
# For Go: check imports are resolvable
```

Script logs advisory warning if Fast Gate results are missing, but anti-exploration guardrails still apply in all subagent prompts.

### Layer 2: Spec Review

Per-task spec compliance check. Agent receives pre-injected spec sections directly in its prompt — does NOT read the plan file.

- **simple tasks:** skip this layer.
- **medium/complex tasks:** run one spec reviewer.
- **high-risk tasks** (>=2 missing expectedEvidence from Quick Gate): upgrade model to Sonnet instead of Haiku.

### Layer 3: Code Review

Per-task code quality review. Reviewers receive pre-computed `git diff` via `diffText` — they only examine changed lines.

Gating:
- **simple:** skip entirely.
- **medium:** correctness-only review (1 Sonnet agent).
- **complex:** full 3-agent parallel (correctness=Sonnet, safety=Sonnet, simplicity=Haiku).

### Layer 4: Adversarial Verification

Per-task adversarial check. Runs inline (not deferred).

Gating:
- **simple:** auto-confirm.
- **medium:** 1 skeptic (Haiku).
- **complex:** 3 skeptics (all Haiku).

### Layer 5: Final Review

Cross-task synthesis using Haiku. Only runs when >=2 tasks exist AND tasks share files. Summary-based — does not re-read source files.

## Anti-Exploration Guardrails

Injected into every review agent prompt:

```
Maximum 5 file reads. DO NOT read same file twice.
FORBIDDEN: go build, go test, go vet, grep exploration.
Maximum 3 thinking blocks.
```
