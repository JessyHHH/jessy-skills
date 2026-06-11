# Transition Rules

## Skill Pipeline

1. `detecting-environment`
2. `designing-solutions`
3. `planning-implementation`
4. `implementing-changes`
5. `reviewing-implementation`
6. `verifying-completion`
7. `finishing-development`

## Legacy Phase Mapping

- Phase 0 / 0.3 / 0.5 → `detecting-environment`
- Phase 1 → `designing-solutions`
- Phase 2 / 3 → `planning-implementation`
- Phase 4 / 4.5 / 4.6 → `implementing-changes`
- Phase 5 → `reviewing-implementation`
- Phase 6 → `verifying-completion`
- Phase 7 / 8 → `finishing-development`

## Auto-Transition Conditions

Auto-transition only when the current skill's exit gate has passed and `handoffPolicy=auto-continue`.

Stop and ask the user when:
- requirement echo needs confirmation,
- a Grill ambiguity cannot be safely assumed,
- design approval is required,
- plan approval is required,
- review finds critical issues,
- verification fails after the configured fix loop,
- branch finish requires a user choice.

## Escape Hatches

- `quick` or `fast`: reduce interview/review depth but keep verification gates.
- `deep` or `careful`: use full-depth review and verification.
- `skip design`: route to `planning-implementation` when the user provides approved requirements or a spec. Records `"skip design"` in `escapeHatchesUsed` in the state file.
- `skip plan`: route to `implementing-changes` only when tasks are already explicit.
- `no review`: skip `reviewing-implementation` only after warning the user.
- `I'll test`: skip `verifying-completion` only after recording that the user owns verification.
- `skip branch`: skip `finishing-development` branch actions.
- `skip workflow`: use manual Agent parallelism instead of Workflow scripts.
