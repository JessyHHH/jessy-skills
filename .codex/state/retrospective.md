# Retrospective: Local Codex Snapshot

- Structural parsing and value filtering are necessary but not sufficient for secret-safe snapshots; exact-copy TOML assets also need fail-closed preflight.
- Sensitive-key classification must cover delimiter-separated and camelCase forms while retaining a narrow allowlist for known non-secret configuration keys.
- Atomic replacement avoids mode drift, but non-regular targets must be rejected before reads or writes to prevent symlink side effects.
- `bash tests/test-*.sh` executes only the first expanded path; full verification must iterate over each test file explicitly.
