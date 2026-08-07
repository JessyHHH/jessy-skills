# Jessy Graph V1 Architecture Design

Status: APPROVED by user on 2026-07-27.

## Scope

This design specifies a new project at `/root/hzx_mixlinker/jessy-graph` that
turns the existing `jessy-skills` task contract into a durable, Dockerized
execution control plane. V1 accepts a main-session-approved project DAG over a
loopback-only Streamable HTTP MCP endpoint, executes atomic tasks with Codex CLI
inside internal Git worktrees, enforces deterministic boundaries and checks,
serially integrates accepted changes, and returns immutable review artifacts.
It does not replace semantic planning in the main Codex session and does not
modify, merge, push, deploy, or migrate the operator's source repositories.

## Requirements and Evidence

1. **Create a separate LangGraph project named `jessy-graph`.** -- source: user request and Grill Q1
2. **Operate as a local single-user service.** -- source: Grill Q2
3. **Use `runtime.db` for application state and `checkpoints.db` for LangGraph recovery.** -- source: Grill Q3
4. **Ship one self-contained Docker image containing MCP, LangGraph, Codex CLI, Git, and verification tools.** -- source: user correction and Grill Q4
5. **Use a dedicated internal integration branch/worktree and never modify the host source worktree.** -- source: Grill Q5
6. **Deliver M1 as a durable single-task vertical slice and M2 as the DAG scheduler; M2 completion defines V1.** -- source: Grill Q6
7. **Expose only a persistent Streamable HTTP MCP endpoint published on host loopback.** -- source: user correction and Grill Q7
8. **Keep command execution language-neutral with built-in Go, Python, and Node.js policies.** -- source: Grill Q8-Q9
9. **Automatically retry only bounded transient infrastructure failures.** -- source: Grill Q10
10. **Allow at most five Codex workers while keeping conflict gates, repository locks, heavy verification limits, and integration serialization.** -- source: user correction and Grill Q11
11. **Keep task-DAG planning and approval in the main Codex session using `jessy-skills`.** -- source: Grill Q12
12. **Treat Git and deterministic validators as evidence authorities.** -- source: `docs/langgraph-codex-cli-orchestration.md` and existing Phase 4 controls
13. **Give container Codex an independent custom-relay `config.toml` and secret-seeded `auth.json`; never mount host `/root/.codex`.** -- source: user clarification after Grill Q12

## Non-Goals

- Remote access, multiple users, tenants, or distributed scheduler nodes.
- A user-facing orchestration CLI.
- Automatic semantic planning, task-DAG expansion, or architecture redesign.
- Running unknown or hostile repositories.
- Automatic merge into the host repository, Git push, pull request creation,
  deployment, infrastructure change, or database migration.
- Arbitrary shell strings, pipelines, redirection, or dynamic executable names.
- PostgreSQL, Kubernetes, a web dashboard, or separate worker services in V1.

## Context Summary

The source project is a Codex-only skills repository at commit
`dc1fcd60662513b708db75af6e9cf19830842df2`. Its Phase 4 task contract already
defines exact `files`, `readFiles`, `resources`, `dependsOn`, complexity,
acceptance commands, expected evidence, forbidden evidence, and patch strategy.
`jessy-graph` executes a versioned form of that contract instead of inventing a
second schema.

The host has Docker 29.6.2, Compose 5.3.1, Python 3.12.3, uv 0.11.31, Node
24.18.0, Go 1.22.2, Codex CLI 0.145.0, 12 CPUs, and 23 GiB RAM with 16 GiB
currently available and no swap. Five workers are a hard ceiling; high-pressure
verification remains separately serialized.

Current LangGraph documentation confirms checkpointed `thread_id` based
interrupt/resume and durable subgraphs. MCP Python SDK v1.12.4 supports
Streamable HTTP, explicit host/port/path, lifespan management, stateful or
stateless sessions, JSON responses, cancellation, and localhost DNS-rebinding
protection. The MCP implementation must use the official SDK rather than a
custom protocol server.

## Ambiguity Register

| ID | Question | Status | Impact | Decision |
|----|----------|--------|--------|----------|
| A1 | V1 trust model | answered | security and deployment | Local single-user, trusted repositories only |
| A2 | Persistence backend | answered | recovery and query model | Separate runtime and checkpoint SQLite databases |
| A3 | Runtime location | answered | image and isolation | Supervisor and workers in one Docker container |
| A4 | Integration strategy | answered | Git safety | Internal mirror, branch, and integration worktree; patch export only |
| A5 | DAG delivery | answered | milestones | M1 single-task; M2 DAG; M2 is V1 |
| A6 | User interface | answered | lifecycle and integration | Streamable HTTP MCP only |
| A7 | Language support | answered | command policy and image | Generic argv policy plus Go/Python/Node.js profiles |
| A8 | Retry policy | answered | drift and recovery | Transient-only automatic retries, maximum three Attempts |
| A9 | Concurrency | answered | scheduler and resources | Five Codex workers maximum; heavy checks and integration serialize |
| A10 | Planning authority | answered | scope ownership | Main Codex owns approved DAG; runtime never expands it |
| A11 | Codex relay authentication | answered | credentials and routing | Independent container CODEX_HOME with custom provider config and secret-seeded auth.json |

## Assumption Ledger

| ID | Assumption | Evidence | Confidence | Correction Path |
|----|------------|----------|------------|-----------------|
| S1 | Repositories are trusted | Single-user decision | High | Add isolated worker containers before untrusted code |
| S2 | Project bases are committed Git SHAs | Immutable base requirement | High | Add an explicit snapshot artifact later |
| S3 | Five workers fit local resources | 12 CPUs, 16 GiB available, no swap | Medium | Lower runtime configuration without schema changes |
| S4 | Existing custom relay is reachable from the container | Host uses custom Responses provider; relay proxy exists | Medium | Verify inside container or add an explicit host-gateway proxy |
| S5 | Loopback plus bearer token is adequate | Local-only service | High | Require TLS and identity authorization before remote binding |

## Approaches Considered

### Approach 1: Graph-Centric Monolith

- **Description**: Put subprocess, Git, SQLite, and validation logic directly in
  LangGraph node functions.
- **Pros**: Fastest prototype and fewest modules.
- **Cons**: Replay semantics become implicit, nodes are hard to unit test, MCP
  and graph state leak into domain rules, and recovery logic becomes fragile.
- **Risk**: High. A tutorial graph can appear durable while duplicating external
  effects after restart.

### Approach 2: Layered Modular Monolith in One Image

- **Description**: Keep contracts and application services independent from
  LangGraph, implement external effects behind ports, and use LangGraph only as
  the durable workflow adapter. Run all components in one container.
- **Pros**: Matches the V1 packaging decision, supports deterministic unit tests,
  and permits later replacement of MCP, SQLite, or worker execution without
  changing contracts.
- **Cons**: More initial interfaces and explicit persistence work.
- **Risk**: Medium-low when vertical slices are implemented before DAG fan-out.

### Approach 3: Separate Supervisor and Worker Services

- **Description**: Run MCP/LangGraph separately from ephemeral worker containers
  with a queue and PostgreSQL.
- **Pros**: Stronger isolation and independent scaling.
- **Cons**: Requires Docker socket or another worker control plane, distributed
  leases, network authentication, and more operations than a single-user V1.
- **Risk**: High delivery complexity and conflicts with the single-image decision.

## Recommended Approach

Use Approach 2: a layered Python 3.12 modular monolith packaged as one Docker
image. Use uv for dependency locking, LangGraph for durable workflows, the
official MCP Python SDK for Streamable HTTP, Pydantic for versioned contracts,
and aiosqlite/sqlite3 repositories without an ORM.

### Repository Layout

```text
jessy-graph/
├── pyproject.toml
├── uv.lock
├── Dockerfile
├── compose.yaml
├── .dockerignore
├── src/jessy_graph/
│   ├── domain/
│   │   ├── contracts.py
│   │   ├── entities.py
│   │   ├── states.py
│   │   └── errors.py
│   ├── application/
│   │   ├── commands.py
│   │   ├── queries.py
│   │   ├── scheduler.py
│   │   ├── recovery.py
│   │   └── ports.py
│   ├── graphs/
│   │   ├── project_graph.py
│   │   ├── task_graph.py
│   │   ├── routing.py
│   │   └── state.py
│   ├── adapters/
│   │   ├── mcp_server.py
│   │   ├── runtime_store.py
│   │   ├── checkpoint_store.py
│   │   ├── artifact_store.py
│   │   ├── git_workspace.py
│   │   ├── codex_runner.py
│   │   └── command_runner.py
│   ├── policies/
│   │   ├── command_policy.py
│   │   ├── go.py
│   │   ├── python.py
│   │   └── node.py
│   └── main.py
├── schemas/
│   ├── project-contract-v1.schema.json
│   └── codex-result-v1.schema.json
├── migrations/
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── recovery/
│   └── e2e/
└── fixtures/
```

No README is required for the initial implementation unless the user requests
documentation beyond the architecture and operations artifacts.

### Container Boundary

The image contains Python, Node.js, Codex CLI, Git, Go, and the minimal tools
needed by the three verification profiles. Versions are pinned in the lockfile
or Docker build arguments. The service binds `0.0.0.0:8000` inside the container;
Compose publishes only `127.0.0.1:8765:8000`. This distinction is required for
Docker reachability without exposing the service remotely.

Persistent paths:

```text
/data/runtime.db
/data/checkpoints.db
/data/artifacts/<sha256>
/data/repositories/<repository-id>.git
/data/worktrees/<project-run-id>/...
/var/lib/jessy-graph/codex-home/
```

Host repositories are mounted read-only under `/sources`. On registration, the
runtime validates a configured repository ID and Git root. On submission it
fetches the immutable base SHA into an internal bare mirror under `/data`; all
task and integration worktrees are created from that mirror. This prevents Git
worktree metadata and file writes from touching the host repository.

The Docker socket is never mounted. The container needs outbound model access
for Codex itself, while model-generated shell commands remain subject to Codex
sandbox network restrictions and the command policy.

Container Codex uses an independent named volume at
`CODEX_HOME=/var/lib/jessy-graph/codex-home`; the host `/root/.codex` directory
is never mounted. The volume contains Codex sessions and state needed by
`codex exec resume`, plus a container-specific `config.toml` and `auth.json`.
Bootstrap renders the non-secret config from an image template and seeds
`auth.json` from a Docker secret with mode `0600`. Neither file is copied from
or synchronized back to the host Codex home.

The initial container config preserves the verified provider semantics without
embedding credentials:

```toml
model = "gpt-5.6-sol"
model_provider = "custom"
cli_auth_credentials_store = "file"

[model_providers.custom]
name = "custom"
base_url = "http://100.73.226.104:18080"
wire_api = "responses"
requires_openai_auth = true

[shell_environment_policy]
inherit = "none"
ignore_default_excludes = false
include_only = ["PATH", "HOME", "LANG"]
```

The host currently routes the same custom provider through
`http://192.168.88.14:8080`, while prior environment evidence indicates Docker
needs the known host relay proxy at `http://100.73.226.104:18080`. Bootstrap
renders this value from `JESSY_GRAPH_CODEX_BASE_URL`, using the proxy as the V1
default. Container startup must test the configured relay endpoint before
accepting work and must fail closed rather than silently fall back to direct
OpenAI routing. Because the container requires its own
`config.toml`, worker invocations use `--strict-config` and explicit sandbox
flags but do not use `--ignore-user-config`.

Credentials are never included in the image, Compose file, logs, SQLite, MCP
data, or repository artifacts. Key rotation replaces the Docker secret and
recreates the container-specific `auth.json`; it never modifies host login
state. The trusted-repository V1 boundary still applies because a same-container
worker is not a hard credential boundary against hostile code.

### MCP Boundary

Use the official Python MCP SDK Streamable HTTP transport with explicit
transport-security allowed hosts/origins, JSON responses where compatible, and
a bearer token supplied only through an environment variable. Do not use MCP
session state as project state; every tool operates on stable application IDs.

Command tools:

```text
submit_project(contract) -> {project_run_id, status}
get_project(project_run_id) -> summary
list_projects(status?, cursor?) -> page
approve_project(project_run_id, artifact_hash) -> status
reject_project(project_run_id, reason) -> status
retry_task(task_id, expected_attempt_id, feedback) -> status
cancel_project(project_run_id, reason) -> status
```

Evidence tools and resources:

```text
list_events(project_run_id, cursor?) -> page
list_artifacts(project_run_id, kind?, cursor?) -> page
get_diff_summary(project_run_id) -> summary + artifact resource link
jessy-graph://projects/{project_run_id}/artifacts/{artifact_id}
```

`submit_project` validates and persists the contract, enqueues execution, and
returns promptly. Long-running graph work is owned by an application lifespan
task group, not by an MCP request. Tool cancellation therefore cancels only the
request unless `cancel_project` is explicitly called. On service startup,
recovery scans nonterminal ProjectRuns and reconciles in-flight Attempts before
resuming their stable LangGraph thread IDs.

### Versioned Contract

The V1 project contract reuses the existing Phase 4 fields and adds project
metadata. All paths are exact repository-relative POSIX paths; directory
allowlists, globs, absolute paths, `..`, NUL, and backslash aliases are rejected.

```text
ProjectContractV1
  version
  repository_id
  base_commit
  objective
  constraints
  tasks[]

TaskContractV1
  id
  prompt
  files[]
  read_files[]
  resources[]
  depends_on[]
  complexity
  context_refs[]
  acceptance_commands[][]
  expected_evidence[]
  forbidden_evidence[]
```

Submission rejects cycles, unknown dependencies, duplicate IDs, overlapping
write ownership without dependency ordering, unsupported command forms, unknown
repository IDs, missing base commits, and contracts above configured task/diff
limits. Submission is idempotent by a client request ID plus canonical contract
hash.

### Runtime Data Model

`runtime.db` is the queryable fact source and contains migrations for:

```text
repositories
project_runs
tasks
task_dependencies
attempts
approvals
artifacts
events
repository_leases
idempotency_keys
```

Every transition uses compare-and-swap on an entity version. Events are
append-only. Attempts are immutable execution histories except for monotonic
status transitions. Artifact bytes live in the content-addressed filesystem;
the database stores SHA-256, size, media type, kind, and ownership. LangGraph
state stores IDs, statuses, hashes, and small summaries only, never full JSONL,
diffs, patches, or command output.

`checkpoints.db` is owned by the LangGraph SQLite checkpointer and is not read
directly by MCP query tools. `thread_id` is the stable ProjectRun ID; Task
subgraphs use stable namespaces derived from ProjectRun, Task, and Attempt IDs.

### Two-Level Graph

ProjectGraph:

```text
validate_contract
  -> acquire_repository_lease
  -> prepare_internal_mirror
  -> prepare_integration_worktree
  -> schedule_ready_tasks
  -> TaskExecutionSubgraph x N
  -> serial_integrate_ready_tasks
  -> combined_verification
  -> create_final_artifacts
  -> final_approval_interrupt
  -> approved | rejected | cancelled
```

TaskExecutionSubgraph:

```text
create_attempt
  -> prepare_task_worktree
  -> codex_plan_only
  -> validate_worker_plan
  -> codex_execute_or_resume
  -> collect_codex_artifacts
  -> validate_git_change_set
  -> run_fixed_checks
  -> task_review
  -> accepted | waiting_for_feedback | blocked | failed
```

The submitted contract is already approved. A worker plan that stays within the
contract may proceed automatically after deterministic validation. Missing
files, resources, behavior, or decisions produce `BOUNDARY_BLOCKED`; the graph
does not silently edit the contract. Semantic retry requires `retry_task` with
feedback from the main Codex session.

### Scheduling and Integration

The scheduler computes readiness from `depends_on` and admits at most five
Codex workers globally. Two tasks may overlap only when:

```text
W1 intersects (R2 union W2) is empty
W2 intersects (R1 union W1) is empty
resources do not overlap
neither task depends on the other
```

Only one ProjectRun per repository may hold the execution lease. Extra runs
remain queued. Verification has separate resource classes; whole-repository Go
build/test and similarly high-pressure commands run serially. A configuration
may lower limits but cannot raise the V1 Codex worker cap above five.

Accepted task patches are applied to the integration worktree one at a time
using the task's exact base/integration parent and artifact hash. After every
apply, focused checks run again. Dependent tasks are prepared from the latest
accepted integration commit. Combined verification runs only after all tasks
are integrated. No V1 path writes back to the mounted source repository.

### Git Evidence

Git status parsing uses NUL-delimited porcelain output and structured parsing,
not line splitting. The validator includes tracked, staged, unstaged, untracked,
deleted, renamed, copied, binary, symlink, executable-bit, and submodule changes.
Patch generation uses a controlled temporary index or equivalent Git-native
mechanism so untracked allowed files are included without trusting worker
staging. Every patch records base commit, parent artifact hashes, changed paths,
diff statistics, and SHA-256.

### Command Policy

Verification commands are arrays of executable and arguments. The repository
manifest selects enabled profiles and exact argument constraints. V1 profiles
cover bounded forms of:

- Go: `go test`, `go test -race`, `go build`, format/static checks, with explicit
  package parallelism policy and serialized whole-repository commands.
- Python: `python -m pytest`, `python -m compileall`, configured lint/typecheck.
- Node.js: `npm` or `pnpm` test, lint, typecheck, and build scripts explicitly
  named in the manifest.

Shell interpreters, `-c`, pipelines, redirection, command substitution,
unresolved environment variables, and destructive Git/deployment commands are
rejected. Codex JSONL command reports are audit evidence, not enforcement.

### Durable Effects and Recovery

LangGraph provides checkpointed replay, not exactly-once external effects. Each
effect therefore has an idempotency key and reconciliation path:

| Effect | Idempotency key | Replay behavior |
|--------|-----------------|-----------------|
| Mirror/base preparation | repository + base SHA | Reuse verified mirror object |
| Worktree creation | Attempt ID | Reuse only if path, branch, and HEAD match |
| Codex execution | Attempt ID + execution phase | Reconcile process/result; never blindly spawn twice |
| Check execution | Attempt ID + command hash | Reuse complete immutable result or create a new result |
| Patch creation | base SHA + content hash | Content-addressed reuse |
| Integration | task artifact hash + integration parent | Compare-and-swap; reject parent drift |

On restart, processes previously marked running cannot be assumed alive. The
recovery service inspects the worktree, result files, process metadata, and
artifacts, then marks the Attempt completed, retryable, orphaned, or failed
before graph resume. Interrupt nodes contain no non-idempotent side effects
before `interrupt()` because resume restarts the node body.

Transient spawn, network, and rate-limit failures receive at most two automatic
retries with exponential backoff and new Attempt IDs. Malformed final JSON gets
one same-thread format-repair turn. Test/review failure waits for MCP feedback.
Boundary, security, and base-drift violations terminate immediately. A Task may
have at most three Attempts.

### Error Taxonomy

Stable machine codes are grouped as:

```text
CONTRACT_INVALID
REPOSITORY_UNAVAILABLE
BASE_COMMIT_MISSING
BOUNDARY_BLOCKED
BOUNDARY_VIOLATION
COMMAND_DENIED
WORKER_TRANSIENT
WORKER_FAILED
WORKER_ORPHANED
CHECK_FAILED
REVIEW_REQUIRED
INTEGRATION_CONFLICT
BASE_DRIFT
CANCELLED
INTERNAL_ERROR
```

Every failure records retryability, owning entity ID, attempt ID when relevant,
artifact links, and a redacted human summary. Secrets and raw environment values
are never persisted.

### Milestones

M1 vertical slice:

- Build the container, MCP lifespan, dual SQLite stores, migrations, artifact
  store, repository registry, and one-task ProjectGraph/TaskExecutionSubgraph.
- Run one real Codex task through internal mirror/worktree, full Git validation,
  fixed checks, final approval, restart recovery, and patch export.

M2 V1 completion:

- Validate and schedule the full task DAG.
- Run up to five conflict-free Codex workers.
- Enforce repository/resource leases and serial integration.
- Run combined verification and expose paginated evidence/resources over MCP.
- Complete crash, cancellation, retry, scope, concurrency, and Docker E2E tests.

## Verification Strategy

- **Command evidence**: `uv run pytest` exits 0 inside the build/test image.
- **Command evidence**: `docker compose build` and `docker compose up -d` exit 0.
- **MCP evidence**: an official SDK client initializes against
  `http://127.0.0.1:8765/mcp`, lists tools, submits a fixture ProjectRun, and
  receives a stable ID.
- **Codex relay evidence**: inside the running container, redacted authentication
  diagnostics and a read-only `codex exec --json` succeed through the configured
  custom Responses relay; a bad relay URL fails closed with no direct fallback.
- **Credential evidence**: host `/root/.codex` is not mounted, container
  `config.toml` contains no secret, `auth.json` is mode `0600`, and worker shell
  environments do not contain API key/token variables.
- **Durability evidence**: restart the container at approval and during a
  reconciliable Attempt; the same ProjectRun resumes without duplicate
  worktrees, Codex executions, integrations, or artifacts.
- **Boundary evidence**: fixtures covering new, deleted, renamed, binary,
  symlink, mode, and submodule changes are classified correctly; an unallowed
  path produces `BOUNDARY_VIOLATION` and cannot integrate.
- **Host safety evidence**: source mount is read-only and its commit, status,
  index, tracked bytes, and untracked set are unchanged after success, failure,
  retry, cancellation, and container restart.
- **DAG evidence**: independent tasks overlap up to five; dependency, read/write,
  resource, and repository conflicts serialize deterministically.
- **Resource evidence**: high-pressure whole-repository verification never runs
  concurrently and worker admission remains bounded at five.
- **Policy evidence**: valid Go/Python/Node.js argv commands run; shell strings,
  unknown tools, pipelines, redirects, and destructive commands are rejected.
- **Integration evidence**: accepted task patches apply in dependency order,
  checks rerun after every integration, and the final patch hash matches the
  reviewed integration tree.
- **Security evidence**: Docker publishes only host loopback, does not mount the
  Docker socket, uses a non-root runtime user, and does not expose credentials in
  image layers, logs, SQLite, events, artifacts, or MCP responses.
- **Semantic evidence**: no final approval is possible when required checks,
  expected evidence, forbidden-evidence checks, or artifact hashes are missing.

## Risks and Rollback

| Risk | Likelihood | Impact | Mitigation | Rollback |
|------|------------|--------|------------|----------|
| SQLite contention with five workers | Medium | Medium | Short transactions, WAL, one writer queue where needed, separate checkpoint DB | Lower worker limit without schema change |
| Container image is large due to three toolchains | High | Low | Multi-stage build, pinned minimal runtimes, layer caching | Drop unused profile in a later image variant |
| Codex subprocess is orphaned on crash | Medium | High | Attempt IDs, process metadata, worktree/result reconciliation | Mark orphaned and require retry rather than duplicate execution |
| Credential exposure to trusted repository commands | Low under V1 trust model | High | Independent CODEX_HOME, Docker secret seeded auth.json, scrubbed shell environment, sandbox, redaction, read-only source | Stop service, rotate the container secret, preserve only redacted artifacts |
| Relay endpoint is unreachable from Docker | Medium | High | Startup probe, configurable container relay URL, known host proxy candidate, fail-closed routing | Stop worker admission and correct the relay/proxy route |
| Git edge case bypasses scope gate | Medium | High | Porcelain `-z`, structured modes, temporary index, adversarial fixtures | Reject affected run and retain source unchanged |
| Five workers exhaust memory because host has no swap | Medium | High | Hard cap, separate heavy-check semaphore, observe RSS, configurable lower limit | Reduce worker limit and restart; durable state resumes |
| MCP client disconnect is mistaken for project cancellation | Medium | Medium | Background lifespan task group and explicit `cancel_project` only | Resume same ProjectRun after reconnect |
| Main contract is incomplete | Medium | Medium | Strict validation and `BOUNDARY_BLOCKED`; no implicit expansion | Correct and resubmit a new versioned contract |

Rollback is operationally simple because host repositories are read-only: stop
the Compose service, retain or back up `/data`, remove the image, and optionally
remove the data volume after artifact export. No rollback path requires resetting
or cleaning a host source repository.
