# Retrospective: Local Codex Snapshot

- Structural parsing and value filtering are necessary but not sufficient for secret-safe snapshots; exact-copy TOML assets also need fail-closed preflight.
- Sensitive-key classification must cover delimiter-separated and camelCase forms while retaining a narrow allowlist for known non-secret configuration keys.
- Atomic replacement avoids mode drift, but non-regular targets must be rejected before reads or writes to prevent symlink side effects.
- `bash tests/test-*.sh` executes only the first expanded path; full verification must iterate over each test file explicitly.

## Graphify and Mem0 Local Integration

- Codex's `bearer_token_env_var` contains an environment variable name, not a credential; snapshot sanitizers need a narrow schema-aware exception so the MCP configuration remains usable.
- A self-hosted Mem0 REST deployment should be integrated as REST unless an MCP route or adapter actually exists; probing `/mcp` prevented a false native-MCP configuration.
- When the user requests main-session-only work, record the execution override immediately and stop further delegation while independently verifying any already-written changes.
- Keep live service keys outside Git in a mode-0600 file and verify them by presence and behavior without printing their values.
