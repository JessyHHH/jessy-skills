# Graphify and Mem0 Local Integration Design

## Scope

Migrate this Codex development environment and its reusable repository snapshot from `codebase-memory-mcp` and MemPalace to the existing Docker-hosted Graphify MCP and self-hosted Mem0 REST API. The work includes repository instructions, sanitized global configuration, a deterministic Mem0 skill, focused tests, private host credential loading, and installation through the existing global skill symlink. It does not modify either Docker service.

## Requirements and Evidence

1. **Use Graphify as the code graph MCP** -- source: user request; the running service advertises Streamable HTTP at `http://127.0.0.1:8001/mcp`.
2. **Use self-hosted Mem0 for persistent memory** -- source: user request and decision A1; the running service exposes authenticated REST routes on port 8002 and no MCP route.
3. **Keep the latest global Codex configuration otherwise intact** -- source: user request; changes are limited to integration blocks, stale related instructions/hooks, and current repository paths.
4. **Keep credentials outside Git** -- source: user approval of decision A2; the host runtime file is mode 0600 and loaded by `~/.profile`.
5. **Install all repository skills through the standard symlink** -- source: user request and existing `install.sh` contract.
6. **Update both source and live environment** -- source: confirmed requirement echo and decision A3.
7. **Provide fresh behavioral verification** -- source: project workflow and confirmed success criteria.

## Non-Goals

- Add or deploy a Mem0 MCP adapter.
- Use the hosted Mem0 Platform MCP or API.
- Restart, rebuild, or reconfigure Docker services.
- Migrate historical MemPalace data into Mem0.
- Change unrelated Codex providers, MCP servers, plugins, marketplaces, or agents.
- Commit, print, or test against literal credential values.

## Context Summary

This is a Codex-only skills repository at commit `652d7204f090e14ee91fbc81ab5a03056c6dadfe`. `install.sh` copies a snapshot to `~/.jessy-skills-codex` and creates `~/.agents/skills/jessy-skills -> ~/.jessy-skills-codex/skills`. The repository tracks sanitized global Codex snapshots under `codex/global/`. Skills use concise `SKILL.md` files, one-level references, deterministic helpers under `scripts/`, shell regression tests, and skill-creator validation.

## Ambiguity Register

| ID | Question | Status | Impact | Decision |
|----|----------|--------|--------|----------|
| A1 | Mem0 REST skill or new MCP adapter? | answered | Architecture and dependencies | Use the existing REST API through a skill. |
| A2 | Where should runtime credentials live? | answered | Security and startup behavior | Store them in a mode-0600 host file loaded by `~/.profile`. |
| A3 | Live-only or repository plus live installation? | answered | Repeatability and tracked scope | Update both, then install from the repository. |

## Assumption Ledger

| ID | Assumption | Evidence | Confidence | Correction Path |
|----|-----------|----------|------------|-----------------|
| S1 | Current container credentials are intended for this host. | Both authenticated services are running and the user approved deriving the host runtime file from them. | High | Replace the private runtime values and restart Codex. |
| S2 | `codex` is the default Mem0 user scope. | Existing local integration checks used that scope and no different default was requested. | Medium | Pass `--user-id` or change the skill default. |

## Approaches Considered

### Approach 1: Graphify MCP plus Mem0 REST skill

- **Description**: Connect Codex directly to Graphify's Streamable HTTP MCP endpoint and use a repository-owned Python helper for Mem0 REST operations.
- **Pros**: Matches the deployed interfaces, adds no service, stays local, and is easy to test deterministically.
- **Cons**: Mem0 operations are invoked through the skill helper rather than native MCP tools.
- **Risk**: Global memory instructions must point Codex to the helper reliably.

### Approach 2: Graphify MCP plus a new Mem0 MCP adapter

- **Description**: Add and operate a translation service that maps MCP tools to the existing Mem0 REST API.
- **Pros**: Both integrations appear as native MCP tools.
- **Cons**: Adds code, another process, another failure boundary, and deployment lifecycle work.
- **Risk**: The adapter becomes an unsupported local service and expands scope substantially.

## Recommended Approach

Configure `[mcp_servers.graphify]` in the live and sanitized Codex configurations with `url = "http://127.0.0.1:8001/mcp"` and `bearer_token_env_var = "GRAPHIFY_API_KEY"`. Remove the old `codebase-memory-mcp` block and its stale SessionStart hook. Update the global instruction snapshot to describe Graphify's actual tools: `query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `list_prs`, `get_pr_impact`, and `triage_prs`.

Replace `skills/mempalace/` with `skills/mem0/`. Keep `SKILL.md` focused on recall and save behavior. Add `scripts/mem0_client.py`, implemented with Python's standard library, with `status`, `add`, `search`, `list`, `get`, `update`, and `delete` subcommands. Use `MEM0_BASE_URL` with a default of `http://127.0.0.1:8002`, require `MEM0_API_KEY`, send it as `X-API-Key`, emit JSON on stdout, and return non-zero with a concise stderr error for transport, authentication, malformed-response, and HTTP failures. Default entity scope is `user_id=codex`, with an explicit override.

Update `codex/global/AGENTS.md` so recall and save instructions invoke the installed `$mem0` helper and never claim MCP semantics. Do not automatically save transient chatter or credentials. A save must be verified with a focused search or retrieval. Update `skills/mem0/agents/openai.yaml` to describe a local REST dependency rather than an MCP dependency.

For this host only, derive the two active service credentials without printing them and write exports for `GRAPHIFY_API_KEY`, `MEM0_API_KEY`, and `MEM0_BASE_URL` to `~/.config/jessy-skills/runtime.env` with mode 0600. Add one idempotent source block to `~/.profile`. The tracked installer remains generic and does not learn how to inspect Docker or handle secrets.

After repository changes and live configuration are ready, run `bash install.sh`. This refreshes `~/.jessy-skills-codex`, creates the single global discovery symlink, and copies repository-managed Codex agents. No individual skill copies or links are introduced.

Add focused shell tests for old-name removal, Graphify configuration shape, Mem0 skill structure, helper behavior against a local mock HTTP server, and the existing symlink invariant. Extend the local snapshot sync fixture to prove bearer environment variable configuration survives sanitization without a literal secret.

## Verification Strategy

- **Command evidence**: `python3 /root/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/mem0`, `bash tests/test-*.sh`, `git diff --check`, and the cc-switch dry run exit zero.
- **Semantic evidence**: Codex lists `graphify` and omits both legacy integrations; the discovery path resolves to the installed snapshot.
- **Live Graphify evidence**: An authenticated MCP initialize and tools/list exchange returns the Graphify tool catalog.
- **Live Mem0 evidence**: A uniquely named temporary memory is added, found by search, retrieved, and deleted through `mem0_client.py`.
- **Secret evidence**: A targeted diff scan finds no active container credential value or unredacted authentication header.
- **Edge cases**: Tests cover missing credentials, HTTP authentication failure, non-JSON responses, API errors, optional user scope, and safe JSON serialization.

## Risks and Rollback

| Risk | Likelihood | Impact | Mitigation | Rollback |
|------|-----------|--------|------------|----------|
| Codex starts without the Graphify key | Medium | Medium | Load the private file from `~/.profile` and verify in a fresh shell before restarting Codex. | Restore the previous MCP block or fix only the private environment file. |
| Mem0 API payload changes | Low | Medium | Use its current OpenAPI-backed fields and focused mock/live tests. | Restore the previous skill directory from Git while leaving Docker untouched. |
| A test memory persists after failed cleanup | Low | Low | Use a unique marker and a `finally` cleanup path. | Delete the marker by ID through the REST helper. |
| Snapshot sync unintentionally changes unrelated settings | Low | High | Compare focused TOML sections and preserve the current file apart from approved path/integration changes. | Restore `~/.codex/config.toml` from the pre-edit backup and rerun installation only after correction. |
| Private runtime file is exposed by permissions or output | Low | High | Write atomically with mode 0600 and never print values. | Remove the file, rotate service keys, and recreate it securely. |
