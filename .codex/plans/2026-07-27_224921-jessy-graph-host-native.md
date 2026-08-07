# Jessy Graph Host-Native Migration Plan

## Metadata

- workflow: project-workflow-codex
- version: v1
- status: APPROVED_FOR_IMPLEMENTATION
- source_root: /root/hzx_mixlinker/jessy-skills
- target_root: /root/hzx_mixlinker/jessy-graph
- target_base_commit: 5e59c61
- design: .codex/specs/2026-07-27-jessy-graph-host-native-design.md
- execution_mode: main-session serial reconciliation
- escape_hatch: main-session-dirty-pivot-reconciliation

## Goal

Replace the existing Docker runtime with the approved host-native root systemd
service without changing Jessy Graph's domain contracts or durable execution
semantics. The final service uses uv, project-local configuration and data,
authenticated MCP on `0.0.0.0:8003`, and the host Codex CLI plus
`/root/.codex`. It removes Docker code and runtime state, preserves internal Git
worktrees and five-worker scheduling, and proves real end-to-end execution.

## Context

- The target repository already implements contracts, dual SQLite stores,
  LangGraph recovery, MCP, internal mirrors/worktrees, deterministic validation,
  artifacts, approval, retry policy, and a maximum of five workers.
- The target worktree contains uncommitted Docker relay diagnostics. The useful
  `--output-schema` removal and local result validation must be retained; the
  Host-header renderer, container bootstrap, and outer-sandbox experiment must
  be removed.
- `.idea/` is unrelated user state and must not be modified.
- The Docker service is currently healthy but cannot complete a production
  worker because the container sandbox is incompatible. Its resolved container
  and volume names are recorded before deletion.
- `.env` does not currently exist. Operational activation must create it with
  mode `0600` without printing its bearer token.
- This is a dirty-worktree pivot, so writer tasks run serially in the main
  session with `no-isolation`; the exception is recorded in workflow state.

## Approach

1. Change only deployment-sensitive settings and tests to the approved host
   paths, MCP listener, LAN allowlists, host Codex command, and uv environment.
2. Reconcile the partially edited Codex adapter: keep relay-compatible local
   validation, place host approval/sandbox/cwd/MCP controls before the `exec`
   subcommand, fail service startup when the pinned Codex executable or version
   probe is invalid, and remove container-only behavior.
3. Add a versioned systemd unit and its deterministic tests while deleting all
   Docker source, bootstrap, and container tests.
4. Run the complete existing suite and static forbidden-pattern gates before
   changing live services.
5. Create project-local runtime configuration, link and start systemd, run real
   local/LAN MCP and Codex approval/recovery/concurrency evidence, then delete
   the exact old Docker container and volumes.

## Files

All task paths are relative to `/root/hzx_mixlinker/jessy-graph`. Ignored runtime
files `.env` and `data/repositories.json`, the systemd link, processes, and
Docker resources are operational state owned by T5, not Git patches.

## Verification

- `uv lock --check`
- focused settings, Codex runner, MCP security, and systemd configuration tests
- `uv run pytest -q`
- `git diff --check`
- forbidden-pattern searches for Docker runtime references and unsafe Codex flags
- root systemd active state and socket evidence on `0.0.0.0:8003`
- authenticated MCP initialization from localhost and the LAN address
- one real host Codex run through waiting approval and exact-artifact approval
- restart recovery without duplicated effects
- five-worker overlap with serialized conflicts/heavy checks/integration
- unchanged source repository fingerprints and credential-redaction search
- absence of the resolved Jessy Graph Docker container and volumes

## Risks

- Root worker blast radius is higher than the deleted container boundary.
  Preserve repository allowlists, internal worktrees, `workspace-write`, exact
  cwd, command policy, process-group cleanup, and Git scope validation.
- Binding `0.0.0.0` exposes all host IPv4 interfaces. Keep bearer authentication
  and exact Host/Origin allowlists and do not configure public routing.
- The NVM Codex path may change. Fail startup when the absolute executable or
  version probe fails rather than falling back to another binary.
- Docker volume deletion is irreversible. Delete only the pre-resolved Jessy
  Graph container and named volumes after the host service passes its live gate.
- Five workers may exhaust memory on a host without swap. Keep the hard cap and
  serialize heavy checks; lower the runtime setting if pressure is observed.

## Tasks

```json:tasks
[
  {
    "id": "T1-host-settings",
    "prompt": "Convert Jessy Graph settings from container defaults to the approved host-native deployment. Default data and repository registry paths to /root/hzx_mixlinker/jessy-graph/data, sources to /root/hzx_mixlinker, MCP to 0.0.0.0:8003, and exact localhost/LAN Host and Origin allowlists. Add an absolute configurable host Codex command default and remove container relay/CODEX_HOME settings that are no longer application-owned. Preserve bearer validation and the worker limit of at most five. Add focused settings tests and adapt shared test fixtures without introducing credentials or modifying unrelated behavior.",
    "files": [
      "src/jessy_graph/settings.py",
      "tests/conftest.py",
      "tests/unit/test_settings.py"
    ],
    "readFiles": [
      ".gitignore",
      "pyproject.toml",
      "src/jessy_graph/adapters/mcp_server.py"
    ],
    "resources": ["config:host-runtime"],
    "dependsOn": [],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["hostCodex", "hostNativeRuntime"],
    "intakeRefs": ["approvedInScope", "constraints"],
    "grillRefs": ["A1", "A4", "A5", "A7", "A10"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_settings.py -q"
    ],
    "expectedEvidence": [
      "default settings resolve project data and repository registry paths, sources root, 0.0.0.0:8003, exact localhost/LAN allowlists, and the absolute host Codex executable",
      "worker_limit rejects values above five and bearer tokens shorter than 32 characters",
      "container relay, container CODEX_HOME, /sources, /run/jessy-graph, and /var/lib/jessy-graph defaults are absent"
    ],
    "forbiddenEvidence": [
      "no API key, MCP bearer value, auth.json content, or generated .env is committed",
      "no public TLS, multi-user, CLI, domain-contract, or persistence redesign",
      "no modification to .idea"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T2-host-codex-runner",
    "prompt": "Reconcile the in-progress Codex adapter for direct host execution. Preserve output-last-message plus local CodexResultV1 validation and remove output-schema. Invoke the configured absolute host command with approval never, per-process mcp_servers={} override, workspace-write, and the exact internal worktree cwd for new and resumed sessions; place these global controls before the exec subcommand, as required by Codex 0.145.0. Use CODEX_HOME=/root/.codex, HOME=/root, LANG=C.UTF-8, and a controlled PATH. Remove strict-config and every container sandbox bypass. Resume only the exact persisted session ID with the same controls. Add a service-start preflight that fails before MCP admission when the configured command is not absolute/executable or its version probe is unsupported. Pass the configured command from main.py, adapt the fake, and add exact argv/environment/preflight/forbidden-flag tests while preserving redaction, process identity, cancellation, and failure taxonomy.",
    "files": [
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/main.py",
      "tests/fakes/fake_codex.py",
      "tests/integration/test_codex_runner.py",
      "tests/unit/test_codex_runner.py"
    ],
    "readFiles": [
      "src/jessy_graph/settings.py",
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/adapters/artifact_store.py"
    ],
    "resources": ["process:codex", "config:host-runtime"],
    "dependsOn": ["T1-host-settings"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["hostCodex", "diagnosticEvidence"],
    "intakeRefs": ["constraints"],
    "grillRefs": ["A1", "A2", "A8"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_codex_runner.py tests/integration/test_codex_runner.py -q"
    ],
    "expectedEvidence": [
      "new and resumed fake sessions receive approval never, mcp_servers={}, workspace-write, and the exact worktree as global controls before exec, followed by JSONL and output-last-message options, with a controlled host environment",
      "service startup rejects a non-absolute, non-executable, or unsupported configured Codex command before accepting MCP work",
      "relay-compatible final JSON validates locally without output-schema",
      "strict-config, output-schema, ignore-user-config, danger-full-access, and sandbox bypass never appear in worker argv",
      "redacted diagnostics, exact session resume, process identity, cancellation, and transient-only retry behavior remain covered"
    ],
    "forbiddenEvidence": [
      "no container CODEX_HOME, relay URL, Host-header workaround, or outer-container sandbox assumption",
      "no worker MCP tools or additional writable directories",
      "no secret value in test output or artifacts"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T3-systemd-docker-replacement",
    "prompt": "Replace Docker packaging with the approved project-owned root systemd unit. Add systemd/jessy-graph.service with project WorkingDirectory, project .env EnvironmentFile, /root/.local/bin/uv run --frozen python -m jessy_graph.main, restart-on-failure, controlled PATH, process-group cleanup, and bounded graceful stop. Add deterministic unit-file tests. Delete Dockerfile, compose.yaml, .dockerignore, every docker bootstrap/config/health file including the untracked renderer, and the container-only integration test. Preserve .env and data as ignored runtime paths and do not touch .idea or create credentials.",
    "files": [
      ".dockerignore",
      "Dockerfile",
      "compose.yaml",
      "docker/codex-config.toml.template",
      "docker/entrypoint.sh",
      "docker/healthcheck.py",
      "docker/render_codex_config.py",
      "systemd/jessy-graph.service",
      "tests/e2e/test_m1_project_run.py",
      "tests/e2e/test_v1_recovery.py",
      "tests/integration/test_container_config.py",
      "tests/integration/test_host_service_config.py",
      "tests/integration/test_mcp_evidence.py",
      "tests/integration/test_mcp_server.py"
    ],
    "readFiles": [
      ".gitignore",
      "pyproject.toml",
      "src/jessy_graph/main.py",
      "src/jessy_graph/settings.py"
    ],
    "resources": ["service:systemd-unit", "config:host-runtime"],
    "dependsOn": ["T1-host-settings", "T2-host-codex-runner"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": ["hostNativeRuntime", "targetWorktreeStatus"],
    "intakeRefs": ["approvedInScope", "constraints"],
    "grillRefs": ["A3", "A4", "A6", "A7", "A10"],
    "acceptanceCommands": [
      "uv run pytest tests/integration/test_host_service_config.py -q"
    ],
    "expectedEvidence": [
      "versioned unit points only to the project, project .env, absolute uv, frozen environment, and Python module entrypoint",
      "unit restart, kill, timeout, user, working directory, environment, and port assumptions are asserted without starting systemd",
      "all Docker source/bootstrap files and container-only tests are absent"
    ],
    "forbiddenEvidence": [
      "no Docker socket, Compose, container CODEX_HOME, Docker secret, relay renderer, or container healthcheck remains",
      "no actual .env, bearer token, auth.json, repositories.json, systemd link, container, or volume is mutated by this file task",
      "no modification to .idea"
    ],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T4-regression-gate",
    "prompt": "Run the complete deterministic host-native regression gate after T1-T3. Verify the lockfile, all unit/integration/recovery/E2E tests, diff whitespace, exact changed paths, absence of active Docker runtime references, absence of forbidden Codex flags, and preservation of .idea. This task is read-only; report any failure for repair inside the owning task boundary rather than editing files or weakening tests.",
    "files": [],
    "readFiles": [
      ".gitignore",
      "pyproject.toml",
      "uv.lock",
      "src/jessy_graph/settings.py",
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/main.py",
      "systemd/jessy-graph.service",
      "tests/integration/test_host_service_config.py"
    ],
    "resources": ["test-suite:full", "resource:heavy-check", "repo:target-worktree"],
    "dependsOn": ["T3-systemd-docker-replacement"],
    "complexity": "medium",
    "mutatesFiles": false,
    "contextRefs": ["targetBaseCommit"],
    "intakeRefs": ["approvedOutOfScope", "constraints"],
    "grillRefs": ["A6", "A8", "A9"],
    "acceptanceCommands": [
      "uv lock --check",
      "uv run pytest -q",
      "git diff --check"
    ],
    "expectedEvidence": [
      "the full deterministic test suite and lockfile check exit zero",
      "only planned files differ and .idea remains unchanged",
      "active source contains no Docker runtime dependency or forbidden Codex execution flag"
    ],
    "forbiddenEvidence": [
      "no skipped required recovery, MCP security, DAG, five-worker, Git, or credential-redaction test",
      "no test weakening, implementation edit, service activation, or external-state mutation"
    ],
    "patchBackStrategy": "external-report"
  },
  {
    "id": "T5-activate-and-live-verify",
    "prompt": "Perform the approved operational switch after T4 passes. Create project .env and data/repositories.json with mode 0600 without printing secrets, create data with root-only permissions, verify the absolute Codex binary and normal host configuration, link the versioned unit with systemctl link, daemon-reload, enable and start jessy-graph, and prove one listener on 0.0.0.0:8003. Authenticate MCP through both 127.0.0.1 and 192.168.0.126, run one real approved contract through host Codex to waiting_approval and exact-artifact approval, restart and prove recovery without duplicate effects, re-run five-worker and serialization evidence, verify source fingerprints and credential redaction, then delete only container jessy-graph-jessy-graph-1 and volumes jessy-graph_jessy_graph_codex_home and jessy-graph_jessy_graph_data. Report irreversible volume deletion. Do not change tracked files or unrelated containers/volumes.",
    "files": [],
    "readFiles": [
      "systemd/jessy-graph.service",
      "src/jessy_graph/settings.py",
      "src/jessy_graph/main.py",
      "tests/e2e/test_m1_project_run.py",
      "tests/e2e/test_v1_dag.py",
      "tests/e2e/test_v1_recovery.py"
    ],
    "resources": ["service:systemd-live", "port:8003", "runtime:project-data", "process:codex-live", "service:docker-cleanup", "repo:target-worktree"],
    "dependsOn": ["T4-regression-gate"],
    "complexity": "complex",
    "mutatesFiles": false,
    "contextRefs": ["hostCodex", "hostNativeRuntime"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints"],
    "grillRefs": ["A1", "A2", "A3", "A4", "A5", "A6", "A8", "A9", "A10"],
    "acceptanceCommands": [
      "systemctl is-active jessy-graph.service",
      "bash -lc 'set -a; source ./.env; curl --fail --silent --header \"Authorization: Bearer ${JESSY_GRAPH_MCP_BEARER_TOKEN}\" http://127.0.0.1:8003/healthz'",
      "bash -lc 'set -a; source ./.env; curl --fail --silent --header \"Authorization: Bearer ${JESSY_GRAPH_MCP_BEARER_TOKEN}\" http://192.168.0.126:8003/healthz'",
      "uv run pytest tests/e2e/test_m1_project_run.py tests/e2e/test_v1_dag.py tests/e2e/test_v1_recovery.py -q"
    ],
    "expectedEvidence": [
      "root systemd service survives restart and listens once on 0.0.0.0:8003",
      "authenticated official MCP clients initialize locally and through the LAN URL while invalid bearer/Host/Origin requests fail",
      "one real host-relay Codex run modifies only an internal worktree, reaches waiting_approval, approves the exact artifact, and completes without duplicate effects after restart",
      "five conflict-free workers overlap while conflicts, heavy checks, and integration serialize",
      "host source fingerprints remain unchanged and no API key, MCP bearer, or auth.json content appears in logs, databases, artifacts, process diagnostics, or MCP responses",
      "the exact obsolete Jessy Graph container and two named volumes no longer exist"
    ],
    "forbiddenEvidence": [
      "no tracked file, .idea content, host source worktree, unrelated process, container, volume, systemd unit, or public network policy is modified",
      "no secret is printed, copied from auth.json, placed in Git, or passed in command-line arguments",
      "no migration of Docker databases, checkpoints, sessions, or artifacts"
    ],
    "patchBackStrategy": "external-report"
  }
]
```
