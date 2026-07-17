# Codex Local Configuration Snapshot Plan

## Goal

Create and verify a safe, repeatable snapshot of the current machine's reusable Codex configuration inside this repository.

## Context

The approved design is `.codex/specs/2026-07-16-codex-local-config-snapshot-design.md`. Existing unrelated changes in root `AGENTS.md`, `skills/methodology/prior-research/SKILL.md`, and `tests/test-prior-research.sh` must be preserved.

## Approach

1. Add a standalone Python sync helper with structural TOML sanitization and `--check` support.
2. Add a temporary-fixture shell test covering copying, sanitization, parsing, and drift detection.
3. Run the helper against the current machine to produce repository snapshots.
4. Document snapshot semantics and rerun commands in README.
5. Review security and correctness, then run focused and full verification.

## Files

- `codex/scripts/sync_from_local.py`
- `codex/global/AGENTS.md`
- `codex/global/config.toml`
- `codex/agents/*.toml` (additive sync; currently expected unchanged)
- `tests/test-codex-local-sync.sh`
- `README.md`

## Verification

- `python3 codex/scripts/sync_from_local.py --check`
- `cmp ~/.codex/AGENTS.md codex/global/AGENTS.md`
- `bash tests/test-codex-local-sync.sh`
- secret-value comparison against the source config
- `bash tests/test-*.sh`
- `git diff --check`

## Risks

- Custom TOML serialization errors are controlled by parsing before write and nested-fixture tests.
- Credential leakage is controlled by sensitive-key substitution, credential-like value rejection, and explicit source-secret absence checks.
- Snapshot content is reference-only; no restore/install behavior is added.

```json:tasks
[
  {
    "id": "T1-sync-helper",
    "prompt": "Create codex/scripts/sync_from_local.py. Read a configurable Codex source directory, copy AGENTS.md exactly, sanitize config.toml structurally into valid deterministic TOML, additively copy agent TOML templates, and support --check without writing. Exclude provider configuration, substitute sensitive scalar values with environment-style placeholders, reject credential-like non-sensitive scalar values, and never inspect or copy unrelated runtime files.",
    "files": ["codex/scripts/sync_from_local.py"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["contextSummary.projectType"],
    "intakeRefs": ["taskIntake.approvedInScope", "taskIntake.approvedOutOfScope", "taskIntake.constraints"],
    "grillRefs": ["A1-global-agents-location", "A2-secret-policy"],
    "expectedEvidence": ["Generated config parses with tomllib", "--check detects drift without writing"],
    "forbiddenEvidence": ["No credential value copied", "No writes outside repository outputs"],
    "patchBackStrategy": "no-isolation",
    "fileContents": [],
    "grillDecisions": [],
    "planSections": "Approach steps 1 and 3; verification parser and secret checks"
  },
  {
    "id": "T2-sync-tests-docs",
    "prompt": "Add tests/test-codex-local-sync.sh with isolated temporary fixtures that test exact AGENTS copying, valid sanitized TOML, sensitive placeholder behavior, provider exclusion, agent copying, and --check drift detection. Document the repository snapshot layout and refresh/check commands in README.md without changing install behavior.",
    "files": ["tests/test-codex-local-sync.sh", "README.md"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["contextSummary.projectType"],
    "intakeRefs": ["taskIntake.approvedInScope", "taskIntake.approvedOutOfScope"],
    "grillRefs": ["S1-snapshot-direction"],
    "expectedEvidence": ["Focused shell test exits 0", "README identifies snapshots as reference-only"],
    "forbiddenEvidence": ["No install.sh behavior change", "No root AGENTS.md edit from this task"],
    "patchBackStrategy": "no-isolation",
    "fileContents": [],
    "grillDecisions": [],
    "planSections": "Approach steps 2 and 4; focused and full verification"
  }
]
```
