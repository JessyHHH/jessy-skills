# Jessy Graph Host-Native Pivot Grill Seed

## Requirement Echo

Revise `jessy-graph` from a Dockerized runtime to a host-native, local,
single-user LangGraph service. The host Codex main session continues to call a
loopback-only Streamable HTTP MCP endpoint. Jessy Graph starts Codex CLI worker
processes directly on the host and reuses the host Codex authentication and
custom Responses provider configuration under `/root/.codex`.

The pivot must preserve the existing execution-control properties:

- main Codex plus `jessy-skills` owns semantic planning and the approved DAG;
- Jessy Graph validates and executes without expanding task scope;
- repository work happens in internal mirrors and worktrees, not the operator's
  source worktree;
- up to five conflict-free Codex workers may run concurrently;
- integration and high-pressure repository verification remain serialized;
- runtime state, LangGraph checkpoints, attempts, logs, diffs, and patches
  remain durable and restart-safe;
- MCP remains loopback-only and bearer-authenticated;
- no automatic merge into the host repository, push, deploy, or migration.

Docker, Compose, container-only `CODEX_HOME`, Docker secrets, relay forwarding,
and container sandbox workarounds must leave the active runtime path. Existing
Docker artifacts and uncommitted diagnostic changes must be handled explicitly
after the replacement design is approved; unrelated `.idea/` content is not in
scope.

## Evidence Already Established

- Host Codex CLI 0.145.0 can call the configured custom Responses provider.
- The host Codex configuration lives under `/root/.codex`; credentials must
  never be copied into project files, logs, state databases, or artifacts.
- The host configuration contains an unknown field, so `--strict-config` fails
  while normal Codex execution succeeds by ignoring it.
- The relay rejects Codex `--output-schema`; Jessy Graph must instead consume
  `--output-last-message` and validate the result locally with `CodexResultV1`.
- Codex `workspace-write` permits writes only beneath the selected cwd and
  configured writable roots.
- A worker that loads the full host config may also load the Jessy Graph MCP
  registration; worker-side MCP visibility needs an explicit recursion policy.

## Open Decisions

1. Choice: run the persistent host service as root through systemd, or use a
   dedicated Unix service account that cannot directly reuse `/root/.codex`?
2. Choice: let workers inherit every host MCP server, or keep the same
   `CODEX_HOME` while disabling worker MCP servers through per-process config
   overrides?
3. Choice: install as a persistent systemd service, or require manual foreground
   startup for V1?
4. Choice: store durable data under `/root/.local/share/jessy-graph`, or retain
   paths shaped around the Docker `/data` layout?
5. Choice: migrate useful state and artifacts from the Docker volume, or start a
   clean host-native runtime while retaining the volume for rollback?
6. Choice: remove Docker artifacts during the pivot, or first leave them as an
   inactive compatibility path until host-native acceptance passes?
7. Open question: which exact Codex invocation flags and environment variables
   are fixed by Jessy Graph rather than inherited from host config?
8. Open question: what end-to-end evidence is required before the old container
   is stopped and the host-native service becomes authoritative?

## Recommended Direction

Use a root-owned systemd service bound to `127.0.0.1:8765`, with
`CODEX_HOME=/root/.codex`, an explicit absolute Codex binary, normal
non-strict config loading, `workspace-write`, non-interactive approval policy,
and per-worker MCP suppression to prevent recursive orchestration. Persist new
runtime data under `/root/.local/share/jessy-graph`. Preserve the Docker volume
and inactive Docker files until a real MCP-to-worker run, restart recovery, and
five-worker acceptance all pass; then remove the obsolete runtime path in a
separate, reviewable cleanup.
