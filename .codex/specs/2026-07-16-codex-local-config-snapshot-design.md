# Codex Local Configuration Snapshot Design

## Scope

Add a deterministic, local-to-repository sync path for reusable Codex configuration. The repository will store an exact global instruction snapshot, a sanitized TOML configuration snapshot, and additive custom-agent template copies. Volatile Codex runtime data and all source credential values remain outside the repository.

## Requirements and Evidence

1. **Sync current computer configuration into this repository** -- source: user request and approval on 2026-07-16.
2. **Include the latest global Codex AGENTS.md** -- source: user explicitly identified the global file as authoritative.
3. **Do not overwrite project-specific root instructions** -- source: approved layered snapshot design and existing Codex workflow architecture.
4. **Do not commit credentials or volatile state** -- source: approved recommendation and observed sensitive MCP environment fields.
5. **Make future refreshes repeatable and verifiable** -- source: approved recommendation to add a deterministic helper.

## Non-Goals

- Installing the repository snapshots back into `~/.codex`.
- Synchronizing Codex authentication, sessions, history, databases, logs, caches, or plugin binaries.
- Changing agent model policy or unrelated prior-research work.

## Context Summary

This is a Codex-only skills repository at commit `29963182621d27f83aed2cc6ab4b6877776ce3f5`. Repo-managed custom agents live under `codex/agents/`, and `install.sh` already installs those templates without modifying global `~/.codex/AGENTS.md`. The source config is TOML and Python provides `tomllib` for parsing but no standard TOML writer.

## Ambiguity Register

| ID | Question | Status | Impact | Decision |
|----|----------|--------|--------|----------|
| A1 | Global AGENTS location | answered | Avoid duplicated active instructions | Store at `codex/global/AGENTS.md`; preserve root `AGENTS.md` |
| A2 | Sensitive values | answered | Prevent credential disclosure | Exclude provider config and substitute environment-style placeholders |

## Assumption Ledger

| ID | Assumption | Evidence | Confidence | Correction Path |
|----|-----------|----------|------------|-----------------|
| S1 | Direction is local-to-repo only | User wording and approved design | High | Add an explicit restore workflow later if requested |

## Approaches Considered

### Approach 1: Raw directory copy

- **Description**: Copy selected `~/.codex` files directly.
- **Pros**: Minimal code and byte-for-byte config fidelity.
- **Cons**: Would commit credentials and makes safe exclusions fragile.
- **Risk**: High.

### Approach 2: Layered sanitized snapshot

- **Description**: Copy AGENTS and agent templates, parse/sanitize config structurally, and write deterministic TOML.
- **Pros**: Repeatable, reviewable, secret-aware, and preserves project instructions.
- **Cons**: Requires a small TOML serializer for supported config value types.
- **Risk**: Low with parser round-trip tests.

### Approach 3: Documentation-only manual procedure

- **Description**: Document shell copy commands without adding automation.
- **Pros**: No helper code.
- **Cons**: Easy to leak secrets or let snapshots drift.
- **Risk**: Medium.

## Recommended Approach

Create `codex/scripts/sync_from_local.py`. It reads `~/.codex/config.toml` using `tomllib`, recursively replaces sensitive-key values with `${KEY}` placeholders, rejects credential-like scalar values under non-sensitive keys, excludes top-level provider selection/configuration, and serializes supported TOML types deterministically. It copies `~/.codex/AGENTS.md` byte-for-byte to `codex/global/AGENTS.md`. Before copying `*.toml` agent templates additively to `codex/agents/`, it parses and scans every agent file and fails before the first write if any credential-bearing path is found. A `--check` mode compares generated content without writing. Non-regular repository targets are rejected. A focused shell test uses temporary fixtures and proves exact AGENTS copying, valid TOML output, secret removal, agent preflight, symlink rejection, and drift detection.

## Verification Strategy

- **Command evidence**: `python3 codex/scripts/sync_from_local.py --check` exits 0 after synchronization.
- **Command evidence**: `bash tests/test-codex-local-sync.sh` exits 0.
- **Command evidence**: `bash tests/test-*.sh` and `git diff --check` exit 0.
- **Semantic evidence**: `cmp ~/.codex/AGENTS.md codex/global/AGENTS.md` succeeds.
- **Semantic evidence**: the generated config parses with `tomllib`, contains placeholders, and contains none of the original secret values.
- **Edge cases**: nested tables, arrays of tables, quoted keys, multiline strings, missing inputs, and check-mode drift.

## Risks and Rollback

| Risk | Likelihood | Impact | Mitigation | Rollback |
|------|-----------|--------|------------|----------|
| Serializer emits invalid TOML | Low | High | Parse generated output before every write and test nested fixtures | Remove generated files and helper |
| Credential value evades key filter | Low | High | Value-pattern rejection plus semantic source-secret comparison | Remove snapshot and tighten filter |
| Existing user changes are overwritten | Low | High | Do not edit root AGENTS or prior-research files | Revert only task-owned files |
