# Jessy Graph Host-Native Architecture Design

Status: APPROVED by user on 2026-07-27.

This specification supersedes the runtime, credential, deployment, and
verification sections of `2026-07-27-jessy-graph-architecture-design.md`. The
previous Docker specification remains historical evidence only.

## Scope

Convert `/root/hzx_mixlinker/jessy-graph` from a Dockerized runtime into a
host-native Python 3.12 service managed by root systemd. The service exposes an
authenticated Streamable HTTP MCP endpoint on `0.0.0.0:8003`, orchestrates up
to five host Codex CLI workers through LangGraph, reuses `/root/.codex`, and
stores durable state inside the project `data/` directory. Existing domain
contracts, application state, internal Git mirrors/worktrees, deterministic
validation, serial integration, approval flow, and immutable artifacts remain.

The pivot removes Docker/Compose packaging and state. It does not redesign the
task contract, add a user-facing CLI, introduce multi-user authorization, or
allow automatic merge, push, deployment, or migration.

## Requirements and Evidence

1. **Run natively under root systemd.** -- Grill A1
2. **Reuse host Codex configuration and authentication.** -- user request and Grill A1/A8
3. **Hide all MCP tools from workers while retaining main-session MCP.** -- Grill A2
4. **Keep Streamable HTTP MCP as the operator interface.** -- Grill A3
5. **Listen on `0.0.0.0:8003` for localhost and trusted LAN use.** -- Grill A4 revision
6. **Keep bearer authentication and exact Host/Origin allowlists.** -- Grill A4
7. **Use uv, the lockfile, and project `.venv` for Python isolation.** -- Grill A7
8. **Store durable runtime data in project `data/`.** -- Grill A5/A7
9. **Use controlled host Codex flags and locally validate final output.** -- Grill A8
10. **Preserve five-worker scheduling, restart recovery, internal worktrees, and serial integration.** -- prior approved design and Grill A9
11. **Remove Docker code, container, volumes, and state without migration.** -- Grill A6
12. **Keep service config project-local and Codex credentials only under `/root/.codex`.** -- Grill A10

## Non-Goals

- Public Internet exposure, TLS termination, multiple users, tenants, or
  per-user authorization.
- Running unknown or hostile repositories or LAN clients.
- A user-facing Jessy Graph CLI.
- Container, virtual machine, or dedicated Unix-user isolation.
- Copying, templating, or rotating the Codex API key.
- Importing Docker runtime databases, checkpoints, sessions, or artifacts.
- Automatic merge into operator repositories, push, pull request creation,
  deployment, infrastructure change, or database migration.

## Context Summary

The target implementation is based on `jessy-graph` commit `5e59c61` plus
uncommitted Docker diagnostic changes that must be reconciled, not blindly
reverted. The unrelated `.idea/` directory is outside scope. The existing
Python code already separates domain, application, LangGraph, MCP, persistence,
Git, Codex, and command-policy adapters. The pivot is therefore an adapter,
settings, operations, and verification change rather than a domain rewrite.

Host evidence:

- Codex CLI: `/root/.nvm/versions/node/v24.18.0/bin/codex`, version `0.145.0`.
- Codex home: `/root/.codex`; custom provider uses the Responses protocol.
- Normal host Codex execution through the configured relay succeeds.
- `--strict-config` fails because the working host config contains an unknown
  field; normal config loading succeeds.
- The relay rejects `--output-schema`; `--output-last-message` plus local
  Pydantic validation succeeds.
- Current Codex documentation confirms `workspace-write` restricts writes to
  the cwd and configured writable roots, and `-c` applies per-process config
  overrides.
- Host resources allow a hard maximum of five workers, while heavy checks and
  integration must remain separately serialized.

## Ambiguity Register

| ID | Question | Status | Impact | Decision |
|----|----------|--------|--------|----------|
| A1 | Service identity | answered | credentials and host permissions | root systemd service |
| A2 | Worker MCP visibility | answered | recursion and side effects | per-process `mcp_servers={}` |
| A3 | Operator interface | answered | lifecycle and integration | persistent MCP only |
| A4 | Network exposure | answered | LAN access and security | bind `0.0.0.0:8003`, bearer plus allowlists |
| A5 | Runtime data root | answered | persistence and repository hygiene | project `data/`, ignored and root-only |
| A6 | Docker migration | answered | cleanup and rollback | no migration; delete code, container, and volumes |
| A7 | Dependency isolation | answered | reproducibility | uv lockfile and project `.venv` |
| A8 | Codex invocation | answered | auth, sandbox, output contract | host config, controlled flags, local validation |
| A9 | Acceptance | answered | completion claim | real MCP/worker/recovery/concurrency/security evidence |
| A10 | Config placement | answered | secrets and operations | project `.env`, `data/repositories.json`, linked systemd unit |

## Assumption Ledger

| ID | Assumption | Evidence | Confidence | Correction Path |
|----|------------|----------|------------|-----------------|
| S1 | Repositories and LAN clients are trusted | explicit single-user/LAN decisions | High | add TLS, identity authorization, dedicated user, and stronger isolation |
| S2 | Host Codex normal config remains usable | verified host execution | High | fail startup and repair/pin host config before admitting work |
| S3 | Five workers fit available resources | 12 CPUs, about 23 GiB RAM, no swap | Medium | lower configured limit |
| S4 | Project-local `data/` will not interfere with repository tooling | explicit user choice and existing ignore rule | High | move `JESSY_GRAPH_DATA_DIR` while preserving layout |

## Approaches Considered

### Approach 1: Root Systemd Service with Host Codex

- **Description**: Run the existing modular monolith as a root systemd service,
  use uv for Python, reuse `/root/.codex`, and keep internal worktrees.
- **Pros**: Uses the verified relay path, preserves durable background work,
  removes container sandbox incompatibility, and minimizes code churn.
- **Cons**: Workers and supervisor have greater host privilege; host toolchain
  upgrades affect reproducibility.
- **Risk**: Medium under the trusted single-user boundary.

### Approach 2: Foreground Project CLI

- **Description**: Run each project workflow directly from a terminal without a
  persistent service or MCP.
- **Pros**: Minimal operations and no network listener.
- **Cons**: Loses MCP integration, durable background lifecycle, and convenient
  LAN use; process exit interrupts active work.
- **Risk**: Medium operational fragility for complex projects.

### Approach 3: Dedicated User or Container Isolation

- **Description**: Keep a separate identity or container-specific Codex home.
- **Pros**: Stronger credential and filesystem separation.
- **Cons**: Conflicts with direct `/root/.codex` reuse and recreates the relay,
  authentication, and sandbox failures that triggered the pivot.
- **Risk**: High delivery risk for this V1.

## Recommended Approach

Use Approach 1.

### Runtime Topology

```text
Local Codex / trusted LAN Codex
          |
          | Streamable HTTP MCP + Bearer
          v
0.0.0.0:8003/mcp
root systemd service -> uv-managed jessy-graph
          |
          +-> runtime.db / checkpoints.db / artifacts
          +-> internal mirrors and task/integration worktrees
          +-> up to five host codex exec workers
                    |
                    +-> CODEX_HOME=/root/.codex
                    +-> workspace-write in one internal worktree
                    +-> no MCP tools
```

Systemd owns service restart and process cleanup. LangGraph and the canonical
runtime database own durable workflow recovery. An MCP client disconnect does
not cancel a ProjectRun; cancellation remains an explicit MCP command.

### Project Layout

```text
/root/hzx_mixlinker/jessy-graph/
├── .env                         # 0600, ignored, MCP/service settings
├── .venv/                       # ignored, uv-managed Python environment
├── data/                        # 0700, ignored
│   ├── runtime.db
│   ├── checkpoints.db
│   ├── repositories.json       # 0600
│   ├── artifacts/
│   ├── attempts/
│   ├── repositories/
│   └── worktrees/
└── systemd/
    └── jessy-graph.service      # versioned unit source
```

Activate the unit with `systemctl link`; `/etc/systemd/system` contains only the
required symlink. The unit uses the project as `WorkingDirectory`, reads the
project `.env`, runs `uv run --frozen`, restarts on failure, and performs a
bounded graceful stop so process groups and durable reconciliation remain
authoritative.

### MCP Boundary

Bind `0.0.0.0:8003`. Local clients use
`http://127.0.0.1:8003/mcp`; LAN clients use
`http://192.168.0.126:8003/mcp`. Keep a minimum 32-character bearer token in the
root-only project `.env`. Allow only the exact localhost and LAN Host/Origin
values required by configured clients. Reject missing/invalid bearer tokens and
disallowed Host/Origin values before MCP tool or resource dispatch.

Plain HTTP on all host IPv4 interfaces is accepted only because V1 explicitly
trusts the local network. Public exposure is prohibited.

### Codex Worker Boundary

New sessions use the equivalent of:

```text
CODEX_HOME=/root/.codex
HOME=/root
LANG=C.UTF-8
PATH=<controlled-host-path>

/root/.nvm/versions/node/v24.18.0/bin/codex \
  -a never \
  -c 'mcp_servers={}' \
  -s workspace-write \
  -C <attempt-worktree> \
  exec --json --output-last-message <attempt-final.json> -
```

Resume uses the exact persisted session ID and the same approval, sandbox, MCP,
environment, output, and cwd controls. Startup verifies the absolute executable
and supported version before accepting work.

Do not pass `--strict-config`, `--output-schema`, `--ignore-user-config`,
`--ephemeral`, `danger-full-access`, or any sandbox/approval bypass. Do not copy
or parse secret values from `/root/.codex/auth.json`. Worker final output is
untrusted until `CodexResultV1` validates it and Git plus deterministic checks
confirm the actual changes.

### Preserved Execution Controls

- Repository IDs resolve only through root-owned `data/repositories.json`.
- Project bases are immutable Git commits imported into internal mirrors.
- Each Attempt receives its own internal worktree.
- Git, not the worker report, determines tracked, untracked, deleted, renamed,
  binary, symlink, and submodule changes.
- Verification commands remain argv-only and policy-controlled.
- The global worker semaphore permits at most five Codex processes.
- File/resource conflicts, heavy repository checks, and integration serialize.
- External effects remain idempotent or reconciled before replay.
- No integration result writes back to the operator source worktree.

### Docker Removal

Remove `Dockerfile`, `compose.yaml`, `.dockerignore`, Docker bootstrap/config
rendering code, Docker-only fixtures, and container-only tests. Reconcile the
current uncommitted Docker diagnostics: retain only behavior required by this
specification, such as removing `--output-schema` and locally validating the
last message. Do not touch unrelated `.idea/` content.

After the host-native implementation no longer depends on them, stop and delete
the Jessy Graph container and its named volumes. No data migration or volume
backup is required by decision A6. The deletion is irreversible for volume-only
state and must be reported explicitly.

## Verification Strategy

- **Unit/integration evidence**: `uv run pytest -q` passes with host settings,
  runner, systemd, MCP security, persistence, Git, recovery, and scheduler tests.
- **Static evidence**: `git diff --check` exits zero; searches prove forbidden
  Codex flags and Docker runtime references are absent from active code.
- **Service evidence**: the linked root unit is active after restart, reports a
  healthy MCP service, and listens on `0.0.0.0:8003` only once.
- **MCP evidence**: official SDK clients authenticate from localhost and at
  least one LAN client; invalid bearer, Host, and Origin cases fail closed.
- **Real worker evidence**: one real project run uses `/root/.codex` and the
  custom relay, changes only its internal worktree, reaches waiting approval,
  approves the exact artifact hash, and completes.
- **Recovery evidence**: restart during approval and during a recoverable
  attempt resumes the stable ProjectRun without repeating completed effects.
- **Concurrency evidence**: five conflict-free workers overlap; conflicting
  tasks, heavy checks, and integration never overlap.
- **Host-safety evidence**: operator source commit, status, index, untracked set,
  and file fingerprints remain unchanged.
- **Credential evidence**: API key, MCP bearer, and `auth.json` content do not
  appear in logs, databases, JSONL, artifacts, process diagnostics, or MCP
  responses.
- **Removal evidence**: Docker source files, the Jessy Graph container, and its
  volumes no longer exist.

## Risks and Rollback

| Risk | Likelihood | Impact | Mitigation | Rollback |
|------|------------|--------|------------|----------|
| Root worker changes host paths outside its worktree | Medium | High | trusted repos, workspace-write, no extra writable dirs, allowlists, Git scope checks, command policy | stop unit, kill process groups, inspect host, rotate credentials if exposure is suspected |
| Plain HTTP bearer is observed on an untrusted interface | Low under stated LAN trust | High | exact bearer/Host/Origin checks and no public routing | stop unit, rotate MCP bearer, bind to a narrower interface or add TLS |
| Host Codex or NVM path changes | Medium | Medium | absolute path and startup version probe | update project `.env` only after a real read-only probe |
| Five workers exhaust memory | Medium | High | hard cap and serialized heavy checks | lower worker limit and restart; durable state resumes |
| Project-local `data/` interferes with repository operations | Low | Medium | whole-directory ignore and root-only permissions | stop service and move data root with an explicit offline copy |
| Docker volume deletion removes unrecoverable history | Certain | Medium | user explicitly chose no migration; delete only the resolved Jessy Graph targets | Docker source can be restored from Git, but deleted volume-only state cannot be recovered |

Rollback of the host-native code uses Git to restore the pre-pivot implementation
or a corrected host-native revision. Because Docker volumes are intentionally
deleted, rollback starts with clean runtime state rather than restoring old
container runs.
