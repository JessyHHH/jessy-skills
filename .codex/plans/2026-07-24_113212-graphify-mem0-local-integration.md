# Graphify and Mem0 Local Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:test-driven-development` for executable behavior. Work directly in the current tree only within the assigned file set; the main Codex session owns integration, workflow state, live host configuration, and final verification.

**Goal:** Replace the repository and current Codex environment's legacy code graph and memory integrations with Docker-hosted Graphify MCP and a self-hosted Mem0 REST skill, then install and prove the result.

**Architecture:** Codex connects directly to Graphify's authenticated Streamable HTTP endpoint. Mem0 remains an authenticated REST service and is accessed by a small Python standard-library CLI bundled with a concise skill. Repository snapshots contain no secrets; this host loads its service keys from a private environment file.

**Tech Stack:** Bash tests, Python 3 standard library (`argparse`, `json`, `urllib`), TOML configuration, Docker-hosted Graphify and Mem0, Codex CLI.

---

## Execution Override

The user directed that implementation, review, and verification continue entirely in the main Codex session. The main session independently inspected and reran Task 1 after its initial RED/GREEN work, performed all remaining edits, and did not dispatch any further subagents. The task contracts below remain as file and evidence contracts rather than delegation instructions.

## File Map

- `skills/mem0/SKILL.md`: agent-facing save, recall, and safety workflow for self-hosted Mem0.
- `skills/mem0/scripts/mem0_client.py`: deterministic REST CLI with `status`, `add`, `search`, `list`, `get`, `update`, and `delete`.
- `skills/mem0/agents/openai.yaml`: UI metadata without an MCP dependency declaration.
- `skills/mempalace/SKILL.md`: removed legacy skill body.
- `skills/mempalace/agents/openai.yaml`: removed legacy metadata.
- `tests/test-mem0.sh`: mock-server behavioral tests for the REST CLI and skill structure.
- `tests/test-codex-integrations.sh`: tracked snapshot and legacy-removal assertions.
- `tests/test-codex-local-sync.sh`: sanitized Graphify bearer environment variable round-trip assertion.
- `codex/global/config.toml`: sanitized global configuration snapshot with Graphify and without legacy integrations.
- `codex/global/AGENTS.md`: Graphify discovery and Mem0 persistence instructions.
- `/root/.codex/config.toml`: live equivalent of the approved integration changes; preserve unrelated settings.
- `/root/.codex/AGENTS.md`: live equivalent of the approved instruction changes.
- `/root/.config/jessy-skills/runtime.env`: private mode-0600 exports for the two service keys and Mem0 URL.
- `/root/.profile`: one idempotent source block for the private environment file.

## Task 1: Mem0 REST Skill and Client

**Files:**

- Create: `tests/test-mem0.sh`
- Create: `skills/mem0/SKILL.md`
- Create: `skills/mem0/scripts/mem0_client.py`
- Create: `skills/mem0/agents/openai.yaml`
- Delete: `skills/mempalace/SKILL.md`
- Delete: `skills/mempalace/agents/openai.yaml`

- [ ] **Step 1: Write the failing behavioral test**

Create a shell test that starts a temporary Python `ThreadingHTTPServer` on an ephemeral loopback port, records authenticated requests, and implements the exact Mem0 routes used by the client. Assert:

```bash
MEM0_BASE_URL="http://127.0.0.1:$PORT" MEM0_API_KEY=test-key \
  python3 "$CLIENT" status
MEM0_BASE_URL="http://127.0.0.1:$PORT" MEM0_API_KEY=test-key \
  python3 "$CLIENT" add "Remember the verified integration" --user-id codex
MEM0_BASE_URL="http://127.0.0.1:$PORT" MEM0_API_KEY=test-key \
  python3 "$CLIENT" search "verified integration" --user-id codex --top-k 3
MEM0_BASE_URL="http://127.0.0.1:$PORT" MEM0_API_KEY=test-key \
  python3 "$CLIENT" list --user-id codex --top-k 3
MEM0_BASE_URL="http://127.0.0.1:$PORT" MEM0_API_KEY=test-key \
  python3 "$CLIENT" get memory-1
MEM0_BASE_URL="http://127.0.0.1:$PORT" MEM0_API_KEY=test-key \
  python3 "$CLIENT" update memory-1 "Updated memory"
MEM0_BASE_URL="http://127.0.0.1:$PORT" MEM0_API_KEY=test-key \
  python3 "$CLIENT" delete memory-1
```

The server must reject any request missing `X-API-Key: test-key`. The test must also prove a missing `MEM0_API_KEY` exits non-zero without a traceback, an HTTP 401 exits non-zero with a concise error, all successful stdout parses as JSON, the default `add` message uses role `user`, search scopes with `filters.user_id`, and `SKILL.md` frontmatter contains only `name` and `description`.

- [ ] **Step 2: Run the test and verify RED**

Run: `bash tests/test-mem0.sh`

Expected: non-zero because `skills/mem0/scripts/mem0_client.py` does not exist.

- [ ] **Step 3: Implement the minimal client and skill**

The client interface is:

```text
mem0_client.py status
mem0_client.py add TEXT [--user-id ID] [--agent-id ID] [--run-id ID] [--metadata JSON]
mem0_client.py search QUERY [--user-id ID] [--top-k N] [--threshold FLOAT]
mem0_client.py list [--user-id ID] [--top-k N]
mem0_client.py get MEMORY_ID
mem0_client.py update MEMORY_ID TEXT [--metadata JSON]
mem0_client.py delete MEMORY_ID
```

Use `MEM0_BASE_URL` or `http://127.0.0.1:8002`, require `MEM0_API_KEY`, join paths without duplicate slashes, send `Accept: application/json`, `Content-Type: application/json` when a body exists, and `X-API-Key`. `status` performs authenticated `GET /memories?user_id=codex&top_k=0`. Parse every response as JSON. Print a single JSON value on success. Catch `HTTPError`, `URLError`, `JSONDecodeError`, invalid metadata, and missing credentials; print `mem0: <message>` to stderr and exit 1 without a traceback.

The skill must tell Codex to call the helper by resolving its own installed directory, default durable memory to `user_id=codex`, search before answering questions about past work, add only durable context, never store credentials, and verify a save with search. Remove the legacy MemPalace files rather than leaving a compatibility alias.

- [ ] **Step 4: Run the test and verify GREEN**

Run: `bash tests/test-mem0.sh`

Expected: `PASS: Mem0 REST skill and client`.

- [ ] **Step 5: Validate the changed skill**

Run: `python3 /root/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/mem0`

Expected: skill validation succeeds.

## Task 2: Repository Snapshot Migration

**Files:**

- Create: `tests/test-codex-integrations.sh`
- Modify: `tests/test-codex-local-sync.sh`
- Modify: `codex/global/config.toml`
- Modify: `codex/global/AGENTS.md`

- [ ] **Step 1: Write failing migration assertions**

Assert the tracked configuration parses with `tomllib` and has exactly this relevant shape:

```python
graphify = data["mcp_servers"]["graphify"]
assert graphify["url"] == "http://127.0.0.1:8001/mcp"
assert graphify["bearer_token_env_var"] == "GRAPHIFY_API_KEY"
assert "codebase-memory-mcp" not in data["mcp_servers"]
assert "mempalace" not in data["mcp_servers"]
assert "SessionStart" not in data.get("hooks", {})
```

Also assert `codex/global/AGENTS.md` contains Graphify, `$mem0`, and `mem0_client.py`, contains neither `codebase-memory-mcp` nor MemPalace identifiers, and that `skills/mempalace` is absent while `skills/mem0` exists. Extend the local sync fixture with:

```toml
[mcp_servers.graphify]
url = "http://127.0.0.1:8001/mcp"
bearer_token_env_var = "GRAPHIFY_API_KEY"
```

and assert those non-secret values survive the sanitizer unchanged.

- [ ] **Step 2: Run the migration test and verify RED**

Run: `bash tests/test-codex-integrations.sh`

Expected: non-zero because the tracked snapshot still contains both legacy integrations.

- [ ] **Step 3: Apply the minimal tracked migration**

Remove the old MCP tables and related tool approval tables from `codex/global/config.toml`. Add only the Graphify URL and bearer environment variable. Remove the stale SessionStart hook block that names the old service. Preserve every unrelated global setting verbatim.

Replace only the two bounded instruction sections in `codex/global/AGENTS.md`. The Graphify section names its actual tools and requires filesystem verification. The Mem0 section calls the installed helper for recall/save, uses `user_id=codex`, filters durable content, never stores secrets, and verifies writes. Preserve Context7, Firecrawl, Go resource safety, and all unrelated instructions verbatim.

- [ ] **Step 4: Run migration and sync tests and verify GREEN**

Run: `bash tests/test-codex-integrations.sh && bash tests/test-codex-local-sync.sh`

Expected: both print PASS lines and exit zero.

## Task 3: Live Host Integration and Installation

**Owned by:** main Codex session because it changes private files outside the repository and integrates both repository tasks.

- [ ] **Step 1: Back up live files without exposing content**

Create timestamped mode-preserving backups of `/root/.codex/config.toml`, `/root/.codex/AGENTS.md`, and `/root/.profile` under `/root/.config/jessy-skills/backups/`. Do not print or add them to Git.

- [ ] **Step 2: Install private runtime credentials**

Read the active Graphify API key and Mem0 admin API key from Docker container configuration without emitting values. Atomically create `/root/.config/jessy-skills/runtime.env` with shell-quoted exports for `GRAPHIFY_API_KEY`, `MEM0_API_KEY`, and `MEM0_BASE_URL=http://127.0.0.1:8002`; set mode 0600. Add an idempotent guarded source block to `/root/.profile`.

- [ ] **Step 3: Migrate live Codex files**

Apply the same bounded MCP and instruction changes as Task 2 to `/root/.codex/config.toml` and `/root/.codex/AGENTS.md`. Update the repository-specific developer instruction paths to `/root/hzx_mixlinker/jessy-skills` and `/root/.jessy-skills-codex/skills`. Preserve all unrelated live values, including private provider and unrelated MCP credentials, without printing them.

- [ ] **Step 4: Install the repository snapshot**

Run: `bash install.sh`

Expected: `/root/.jessy-skills-codex` exists, `/root/.agents/skills/jessy-skills` is a symlink to `/root/.jessy-skills-codex/skills`, and the installed Mem0 skill exists while MemPalace does not.

- [ ] **Step 5: Verify live Graphify and Mem0**

In a fresh shell that sources `/root/.profile`, verify `GRAPHIFY_API_KEY`, `MEM0_API_KEY`, and `MEM0_BASE_URL` are set without printing values. Perform an authenticated MCP `initialize`, `notifications/initialized`, and `tools/list` exchange with Graphify and assert its documented tools are returned. Use the installed Mem0 helper to add a unique temporary memory under `user_id=codex`, search it, get it by ID, and delete it in a guaranteed cleanup path.

## Task 4: Full Verification and Workflow Handoff

- [ ] **Step 1: Run focused validation**

Run:

```bash
python3 /root/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/mem0
bash tests/test-mem0.sh
bash tests/test-codex-integrations.sh
bash tests/test-codex-local-sync.sh
python3 skills/sync-ccswitch-config-codex/scripts/sync_config.py --dry-run
```

- [ ] **Step 2: Run the repository suite and lint**

Run:

```bash
bash tests/test-*.sh
git diff --check
```

- [ ] **Step 3: Audit scope and secrets**

Review `git status --short`, `git diff --stat`, and the full diff. Confirm all changed files map to the plan, no Docker state changed, no legacy integration name remains outside historical workflow artifacts, and no active service credential value appears in tracked files or diff output.

## Task Contracts

```json:tasks
[
  {
    "id": "T1-mem0-rest-skill",
    "prompt": "Using strict test-driven development, replace the legacy skills/mempalace skill with a self-hosted Mem0 REST skill. First create tests/test-mem0.sh with a real temporary loopback HTTP server and run it to observe the expected missing-client failure. Then create skills/mem0/scripts/mem0_client.py using only Python standard library, skills/mem0/SKILL.md with only name and description frontmatter, and skills/mem0/agents/openai.yaml; remove both legacy MemPalace files. Support status, add, search, list, get, update, and delete exactly as specified in the approved plan. Preserve unrelated dirty changes. Do not edit any file outside the listed ownership set. First update after the RED test is observed. Return changed_files, commands_run, red/green evidence, and risks_or_blockers.",
    "files": [
      "tests/test-mem0.sh",
      "skills/mem0/SKILL.md",
      "skills/mem0/scripts/mem0_client.py",
      "skills/mem0/agents/openai.yaml",
      "skills/mempalace/SKILL.md",
      "skills/mempalace/agents/openai.yaml"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["contextSummary.projectType", "knowledgePath"],
    "intakeRefs": ["taskIntake.approvedInScope", "taskIntake.constraints"],
    "grillRefs": ["A1", "S2"],
    "expectedEvidence": [
      "bash tests/test-mem0.sh first fails because the client is absent and later passes",
      "quick_validate.py skills/mem0 exits 0",
      "skills/mempalace no longer exists"
    ],
    "forbiddenEvidence": [
      "no third-party Python dependency",
      "no literal credential",
      "no traceback for expected user or HTTP errors",
      "no edits outside owned files"
    ],
    "patchBackStrategy": "no-isolation",
    "grillDecisions": [
      {"key": "A1", "decision": "Use a REST-backed Mem0 skill, not an MCP adapter."},
      {"key": "S2", "decision": "Default durable memory scope to user_id=codex."}
    ],
    "planSections": "Task 1: Mem0 REST Skill and Client"
  },
  {
    "id": "T2-repository-snapshot-migration",
    "prompt": "Using test-first migration assertions, update the tracked Codex snapshots from codebase-memory-mcp and MemPalace to Graphify MCP and the Mem0 REST skill. First create tests/test-codex-integrations.sh and extend tests/test-codex-local-sync.sh, run the integration test to observe failure on legacy content, then minimally update codex/global/config.toml and codex/global/AGENTS.md. Graphify must use http://127.0.0.1:8001/mcp with bearer_token_env_var GRAPHIFY_API_KEY; remove the old two MCP blocks and stale SessionStart hook. Preserve every unrelated setting and instruction. Do not edit the skill files or any file outside the ownership set. First update after the RED test is observed. Return changed_files, commands_run, red/green evidence, and risks_or_blockers.",
    "files": [
      "tests/test-codex-integrations.sh",
      "tests/test-codex-local-sync.sh",
      "codex/global/config.toml",
      "codex/global/AGENTS.md"
    ],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["contextSummary.projectType", "knowledgePath"],
    "intakeRefs": ["taskIntake.approvedInScope", "taskIntake.constraints"],
    "grillRefs": ["A1", "A3"],
    "expectedEvidence": [
      "bash tests/test-codex-integrations.sh first fails on legacy content and later passes",
      "bash tests/test-codex-local-sync.sh exits 0",
      "tracked TOML parses and contains only graphify among the requested integrations"
    ],
    "forbiddenEvidence": [
      "no literal credential",
      "no hosted Mem0 MCP URL",
      "no unrelated global setting or instruction change",
      "no edits outside owned files"
    ],
    "patchBackStrategy": "no-isolation",
    "grillDecisions": [
      {"key": "A1", "decision": "Mem0 is documented as a REST skill, not an MCP server."},
      {"key": "A3", "decision": "Update the tracked repository snapshot and then install it live."}
    ],
    "planSections": "Task 2: Repository Snapshot Migration"
  }
]
```

## Consensus Review

- Architecture: APPROVE. The selected interfaces match the two deployed services and avoid an unnecessary adapter.
- Risk: APPROVE_WITH_CONTROLS. Credentials remain outside Git, live files are backed up, and runtime values are never printed.
- Feasibility: APPROVE. Both tasks have disjoint write sets and observable RED/GREEN evidence; live integration remains with the main session.
- Scope: APPROVE. No task modifies Docker services, uses hosted Mem0, migrates MemPalace data, or changes unrelated Codex components.

## Verification Contract

- `bash tests/test-*.sh` exits 0.
- `git diff --check` exits 0.
- `quick_validate.py skills/mem0` exits 0.
- Codex MCP listing contains Graphify and omits both legacy integrations.
- Live Graphify returns its MCP tool catalog with authentication.
- Live Mem0 completes add/search/get/delete for a temporary marker.
- Installed skill discovery is one symlink to the snapshot skills directory.
- No active service credential appears in tracked content or diff.

## Self-Review

- Spec coverage: every approved requirement maps to Tasks 1-4.
- Placeholder scan: no deferred implementation marker remains.
- Interface consistency: CLI command names, environment variables, URLs, headers, and default user scope match across design, tasks, tests, and live verification.
- File overlap: T1 and T2 write sets are disjoint; only the main session touches live host files and workflow artifacts.
- Verdict: `APPROVED_FOR_EXECUTION`.
