# Jessy Graph V2 Supervision Implementation Plan

## Metadata

- target: `/root/hzx_mixlinker/jessy-graph`
- target HEAD: `5e59c6144b820ab4a5e75858743c5369fa09507b`
- approved tracked-diff SHA-256: `1b13316daabc7e56641f89e7b1665ba576b3ef162b62fffe73d07c36658fe066`
- spec: `.codex/specs/2026-07-28-jessy-graph-v2-supervision-design.md`
- intake: `.codex/state/jessy-graph-v2-supervision-task-intake.json`
- context: `.codex/state/jessy-graph-v2-supervision-context-summary.json`
- grill: `.codex/state/jessy-graph-v2-supervision-grill-evidence.json`
- implementation authority: main Codex after one combined user approval
- live service: unchanged until T10; currently active on `0.0.0.0:8003`
- plan contract: `phase4_guard.py validate-plan` PASS with 10 unique tasks and an acyclic dependency graph
- schedule contract: `phase4_guard.py schedule` PASS; only T3/T4 share a writer wave and integration is serial

## Goal

Replace unused Jessy Graph V1 with a strict V2 LangGraph execution supervisor. V2 must enforce main-authored contracts, role-scoped immutable skills, Luna planning/review, Flash implementation/repair, exact-session resume, five-process global scheduling, immutable-base patches, fresh authoritative verification/review, explicit task/project repairs, runtime-only canonical state, deterministic crash recovery, and a hard live release gate.

## Context and Boundaries

- Preserve the approved host-native dirty baseline and all unrelated `.idea/` content.
- V1 has no user data; its one `approved` row is smoke residue.
- No container, VM, separate UID, public Internet, multi-user feature, CLI surface, automatic merge/push/deploy, or orchestrated source writeback.
- Host-native workers necessarily can read authentication needed by Codex. This plan provides minimal configuration, non-recording, redaction, and leak detection, not adversarial credential isolation.
- T1 stages V2 beside V1 so every intermediate task remains importable. T7 migrates the last consumers and removes V1 in one cutover.
- T3 and T4 are the only parallel writer wave. Every integration is serial.
- T10 is an explicit operational writer: it owns the live source rollback boundary and exact database paths. It is never dispatched to an ordinary isolated worker.

## Approach

1. Add canonical V2 contracts, manifests, repairs, evidence, schemas, and package metadata beside V1.
2. Add exact skill/profile bundles and a minimal run-scoped Codex environment.
3. In parallel, implement role supervision and immutable Git/verifier/reviewer worktrees.
4. Make `runtime.db` canonical, checkpoints disposable, and every side effect intent-driven with a complete recovery matrix.
5. Add real task/project graphs and deterministic task/project repair replay.
6. Cut MCP/application consumers to V2 and delete all V1 contracts, schemas, migrations, approvals, and tests.
7. Add hostile-worker, rollout, rollback, and real MCP canary gates.
8. Run the full deterministic gate, then perform the stateful cold rollout and rollback on any failed live evidence.

## Verification

- Each task runs its focused commands before serial integration and independent task review.
- T9 runs `uv lock --check`, the full test suite, schema/config/static gates, and `git diff --check` from the approved synthetic baseline.
- T10 records baseline/V2 patch/result fingerprints, systemd unit link/target, DB paths/hashes, and live canary evidence.
- No skipped mandatory case and no `PASS_WITH_RISK` is accepted.

## Risks

- Same-UID credential access is an accepted trusted-host limitation, not a security claim.
- Runtime/checkpoint split is controlled by runtime-only authority and reconciliation-first nodes.
- Combined-review repair is bounded by explicit `ProjectRepairContractV2`, dependency closure, invalidation, and deterministic unaffected-patch replay.
- Operational rollback reverses only the recorded V2 patch when the exact V2 fingerprint matches; otherwise the service remains stopped.

## Tasks

```json:tasks
[
  {
    "id": "T1-v2-foundation-contracts",
    "prompt": "Add strict frozen V2 domain foundations beside the existing V1 types so all intermediate imports remain valid. Define ProjectContractV2, TaskContractV2, TaskPlanV2, CodexResultV2, ReviewResultV2, EvidencePredicateV2, RunManifestV2 with canonical JSON/SHA-256, TaskRepairContractV2, and ProjectRepairContractV2. Task repair fixes the immutable task base, rejected patch/tree, and repair epoch but never predicts worker output. Project repair carries the reviewed integration hash, exact findings, main-selected targets, per-task bounded repairs, explicit dependency/resource-impact-closed rerun set, invalidated patch IDs, integration base/order, replay-prefix tree hashes, and unaffected replay set. Add V2 states and schemas, reject extras, wrong versions/models, invalid paths/DAG/resources/closure/budgets, and cap repairs at three. Add shared valid/invalid model-to-JSON-schema parity corpora plus model-JSON-schema-model canonical round-trip/hash checks. Keep V1 only as temporary internal migration scaffolding. Bump to 0.2.0 and synchronize uv.lock. Do not add persistence, execution, MCP, or delete V1 yet.",
    "files": [
      "pyproject.toml",
      "uv.lock",
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/domain/evidence.py",
      "src/jessy_graph/domain/states.py",
      "schemas/project-contract-v2.schema.json",
      "schemas/task-plan-v2.schema.json",
      "schemas/codex-result-v2.schema.json",
      "schemas/review-result-v2.schema.json",
      "schemas/task-repair-contract-v2.schema.json",
      "schemas/project-repair-contract-v2.schema.json",
      "schemas/run-manifest-v2.schema.json",
      "tests/unit/test_contracts.py",
      "tests/unit/test_run_manifest.py",
      "tests/unit/test_schema_parity.py"
    ],
    "readFiles": [
      "src/jessy_graph/domain/entities.py",
      "src/jessy_graph/domain/__init__.py",
      "schemas/project-contract-v1.schema.json",
      "schemas/codex-result-v1.schema.json"
    ],
    "resources": ["contract:v2", "schema:v2", "generated:uv-lock"],
    "dependsOn": [],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["targetBaseCommit", "currentRuntime"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints"],
    "grillRefs": ["D1", "D2", "D3", "D6", "D7", "D8"],
    "acceptanceCommands": [
      "uv lock --check",
      "uv run pytest tests/unit/test_contracts.py tests/unit/test_run_manifest.py tests/unit/test_schema_parity.py -q"
    ],
    "expectedEvidence": [
      "V2 contracts and schemas validate canonical manifests plus task and project repair closure while V1 imports still work internally",
      "Pydantic and JSON Schema accept the same valid corpus, reject the same invalid corpus, and round-trip to identical canonical JSON/hashes",
      "RunManifestV2 owns project/base, policy/profile/harness, per-role bundle, aggregate bundle, model/sandbox, cap, retry, repair, service, and Codex version hashes",
      "package version and uv.lock are synchronized"
    ],
    "forbiddenEvidence": [
      "no V1 file/type deletion before consumer migration",
      "no persistence, graph, runner, MCP, live service, credential, .idea, or compatibility adapter change"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T2-skill-profile-manifests",
    "prompt": "Implement exact main-selected worker-safe skill and quality-profile routing. Add project TOML allowlists/profiles, settings paths, typed loaders, and immutable role bundle resolution. Bundle complete selected SKILL.md bytes plus explicitly selected one-level references, source paths, individual hashes, per-role manifest hash, and one aggregate run bundle hash. Reject missing mandatory, forbidden, substituted, traversing, or unselected content; forbid project-workflow-codex. Promote bundles through the artifact store before launch and prove source changes cannot alter admitted bundles. Do not modify installed skills or host Codex files.",
    "files": [
      "config/worker-safe-skills.toml",
      "config/quality-profiles.toml",
      "src/jessy_graph/settings.py",
      "src/jessy_graph/adapters/skill_bundle.py",
      "src/jessy_graph/adapters/artifact_store.py",
      "tests/unit/test_settings.py",
      "tests/unit/test_skill_bundle.py",
      "tests/integration/test_skill_bundle.py",
      "tests/unit/test_artifact_store.py",
      "tests/integration/test_artifact_store.py"
    ],
    "readFiles": [
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/domain/evidence.py",
      "src/jessy_graph/adapters/runtime_store.py"
    ],
    "resources": ["config:worker-skills", "config:quality-profile", "artifact:immutable-bundles"],
    "dependsOn": ["T1-v2-foundation-contracts"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["loadedSkills", "currentRuntime"],
    "intakeRefs": ["approvedInScope", "constraints"],
    "grillRefs": ["D3", "D4", "D7", "D8"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_settings.py tests/unit/test_skill_bundle.py tests/integration/test_skill_bundle.py tests/unit/test_artifact_store.py tests/integration/test_artifact_store.py -q"
    ],
    "expectedEvidence": [
      "role bundles and aggregate run hash are canonical, immutable, content-addressed, and artifact-backed",
      "planner and implementation bundles are distinct role inputs recorded under one RunManifestV2"
    ],
    "forbiddenEvidence": [
      "no global catalog browsing, automatic skill inference, project-workflow-codex, path traversal, unselected reference, installed-skill mutation, or secret bundle content",
      "no V1 deletion, runner, graph, MCP, or live-state change"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T3-role-codex-supervisor",
    "prompt": "Implement role-aware Codex supervision. Build a root-owned run CODEX_HOME by parsing host config into an approved minimal provider/runtime config, removing MCP sections and unrelated inline credentials, linking host auth.json, installing immutable role rules/sessions, and documenting that this is deterministic configuration rather than credential isolation. Fail if selected-provider secrets appear in unapproved config locations. Add one five-process global pool across all roles. Use a service-owned child wrapper that atomically writes and fsyncs a launch receipt with intent/fence/start nonce, PID/process group/boot ID/start ticks/argv hash/spool paths before exec, then records the first exact provider session ID. Invoke verified Codex 0.145 with approval never, empty MCP config, --disable multi_agent, JSONL streaming, explicit cwd/model/sandbox, and no strict/output-schema/ignore/bypass flags. Route planner/reviewers to Luna read-only and implementer/repairs to Flash workspace-write; implementation resumes the exact planner session with the immutable implementer bundle. Deny nested Codex, commits/ref mutation, rule mutation, and disallowed wrappers. Redact known secrets before persistence/MCP and fail attempts on detected leaks. Add argv, environment, launch-receipt crash windows, exact resume/model transition, session, sandbox, pool, policy, relay, and credential-boundary tests.",
    "files": [
      "config/worker.rules",
      "src/jessy_graph/policies/command_policy.py",
      "src/jessy_graph/adapters/codex_child.py",
      "src/jessy_graph/adapters/codex_runner.py",
      "tests/fakes/fake_codex.py",
      "tests/unit/test_command_policy.py",
      "tests/unit/test_codex_runner.py",
      "tests/integration/test_codex_capabilities.py",
      "tests/integration/test_codex_runner.py",
      "tests/integration/test_command_runner.py"
    ],
    "readFiles": [
      "src/jessy_graph/settings.py",
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/adapters/skill_bundle.py",
      "src/jessy_graph/adapters/artifact_store.py",
      "src/jessy_graph/adapters/command_runner.py"
    ],
    "resources": ["process:codex-global-five", "config:codex-home", "policy:worker-command", "auth:host-codex"],
    "dependsOn": ["T2-skill-profile-manifests"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["verifiedCodexCapabilities", "currentRuntime"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints", "sourceEvidence"],
    "grillRefs": ["D4", "D7", "D8"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_command_policy.py tests/unit/test_codex_runner.py tests/integration/test_codex_capabilities.py tests/integration/test_codex_runner.py tests/integration/test_command_runner.py -q"
    ],
    "expectedEvidence": [
      "all planner/reviewer attempts are Luna read-only, all implementer/repair attempts are Flash workspace-write, and every process disables multi_agent under the shared cap",
      "implementation resumes the exact planner session while receiving the approved implementer role bundle",
      "Codex 0.145 capability tests and the final real canary prove exact-session Luna-to-Flash resume; launch receipts distinguish not-started from ambiguous-started crashes",
      "minimal config, linked auth, output redaction, leak failure, and the lack of same-UID credential isolation are explicit and tested"
    ],
    "forbiddenEvidence": [
      "no deepseek-v4-pro, model-by-complexity, copied auth.json, host rule mutation, worker MCP server, extra writable root, nested Codex, worker commit, or prompt-only enforcement",
      "no claim that CODEX_HOME or Codex sandbox hides host credentials from a malicious same-UID worker"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T4-git-verifier-review-inputs",
    "prompt": "Implement immutable-base Git extraction, typed authoritative evidence evaluation, fresh verifier worktrees, and fresh semantic-review worktrees. Require task HEAD/refs to equal the immutable base and derive paths/binary patches through a temporary index covering staged, unstaged, untracked, deleted, renamed, and worker-created commits; commit/ref drift fails. Verifiers use a fresh detached base-plus-candidate worktree, immutable policy/profile/harness hashes, inspected argv through CommandRunner, sanitized environment, and unshare --net; fail startup if isolation is unavailable. Task reviewers use a separate fresh detached base-plus-verified-patch worktree. Combined reviewers use a fresh detached integration-base-plus-final-patch worktree. Persist immutable review-input hashes; reviewers/verifiers never edit or reuse mutable implementation/integration worktrees.",
    "files": [
      "src/jessy_graph/adapters/git_workspace.py",
      "src/jessy_graph/application/verification.py",
      "src/jessy_graph/application/review.py",
      "tests/fixtures/git_cases.py",
      "tests/integration/test_git_workspace.py",
      "tests/integration/test_git_change_set.py",
      "tests/unit/test_evidence.py",
      "tests/integration/test_verification.py",
      "tests/integration/test_review_worktrees.py"
    ],
    "readFiles": [
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/domain/evidence.py",
      "src/jessy_graph/settings.py",
      "src/jessy_graph/adapters/artifact_store.py",
      "src/jessy_graph/adapters/command_runner.py"
    ],
    "resources": ["git:temporary-index", "worktree:fresh-verifier", "worktree:fresh-reviewer", "namespace:verifier-network"],
    "dependsOn": ["T2-skill-profile-manifests"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["immutableBase", "authoritativeEvidence"],
    "intakeRefs": ["approvedInScope", "constraints", "sourceEvidence"],
    "grillRefs": ["D5", "D6", "D8"],
    "acceptanceCommands": [
      "uv run pytest tests/integration/test_git_workspace.py tests/integration/test_git_change_set.py tests/unit/test_evidence.py tests/integration/test_verification.py tests/integration/test_review_worktrees.py -q"
    ],
    "expectedEvidence": [
      "candidate patches cover every Git state relative to the immutable base and reject commit/ref drift",
      "verifier, task review, and combined review each run in the exact fresh detached tree described by immutable input hashes",
      "verifier commands run without network and reviewer/verifier writes cannot enter candidate patches"
    ],
    "forbiddenEvidence": [
      "no mutable-HEAD patch authority, implementation-worktree acceptance, mutable integration-worktree review, reviewer/verifier repair, shell-string execution, host network, or trusted worker self-report",
      "no write to submitted source, .idea, host policy, or live service"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T5-runtime-authority-recovery",
    "prompt": "Add V2 persistence beside the still-importable V1 surface, then make V2 runtime.db the sole canonical workflow/application authority. Add a clean V2 migration and typed entities/store methods for RunManifestV2, task dependencies/phases, role attempts/process identities/session IDs, per-role bundles, patches, verifier/reviewer inputs/results, evidence, findings, repair epochs/supersessions, integration order/prefix trees, events, idempotency, and transactional side-effect intents. Intents use atomic owner-instance claims, monotonic fencing tokens, leases, launch receipt/session identity, and fenced result commits so concurrent reconcilers cannot duplicate effects. checkpoints.db is a disposable graph cursor/cache. Every graph entry calls reconcile_runtime and rebuilds missing/stale/corrupt checkpoints. Implement the phase crash matrix for planner, exact-session implementation, extraction, verifier, reviewer, integration, repair wait/worker, cancellation, pool-lease recovery, and checkpoint loss. Integration intent owns parent head/tree, patch, expected result tree, order, and accepted prefix. Use CAS and fail closed on ambiguous started launches; retry only when the receipt proves Codex exec never started or a declared transient result exists.",
    "files": [
      "migrations/0001_runtime_v2.sql",
      "src/jessy_graph/domain/entities.py",
      "src/jessy_graph/application/ports.py",
      "src/jessy_graph/adapters/runtime_store.py",
      "src/jessy_graph/adapters/checkpoint_store.py",
      "src/jessy_graph/application/recovery.py",
      "tests/unit/test_entities.py",
      "tests/unit/test_runtime_store.py",
      "tests/integration/test_runtime_store.py",
      "tests/recovery/test_project_recovery.py",
      "tests/recovery/test_task_recovery.py",
      "tests/recovery/test_scheduler_recovery.py",
      "tests/recovery/test_side_effect_intents.py",
      "tests/recovery/test_launch_fencing.py"
    ],
    "readFiles": [
      "migrations/0001_runtime.sql",
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/domain/states.py",
      "src/jessy_graph/domain/evidence.py",
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/adapters/codex_child.py",
      "src/jessy_graph/adapters/git_workspace.py",
      "src/jessy_graph/application/verification.py",
      "src/jessy_graph/application/review.py"
    ],
    "resources": ["db:runtime-v2", "db:checkpoint-cache-v2", "state:side-effect-intents", "state:recovery"],
    "dependsOn": ["T3-role-codex-supervisor", "T4-git-verifier-review-inputs"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["freshV2Database", "durableRecovery"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints"],
    "grillRefs": ["D1", "D2", "D6", "D8", "D9"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_entities.py tests/unit/test_runtime_store.py tests/integration/test_runtime_store.py tests/recovery/test_project_recovery.py tests/recovery/test_task_recovery.py tests/recovery/test_scheduler_recovery.py tests/recovery/test_side_effect_intents.py tests/recovery/test_launch_fencing.py -q"
    ],
    "expectedEvidence": [
      "runtime.db alone owns canonical phases and all immutable/result hashes while checkpoints rebuild from it",
      "every crash-matrix window either reattaches, deterministically reruns from immutable inputs, commits an already-matching result, or fails closed without duplicate effects",
      "concurrent reconcilers, stale fences, wrapper-receipt windows, cancellation, and global pool reconstruction cannot launch or commit twice",
      "integration recovery distinguishes exact parent and expected-result trees and rejects any third state"
    ],
    "forbiddenEvidence": [
      "no graph checkpoint authority, graph-before-runtime transition, semantic auto-retry, inferred success, changed manifest input, duplicated integration, or ambiguous forward guess",
      "no deletion of V1 types/schema/migration or live database/service mutation yet"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T6-v2-role-graphs",
    "prompt": "Replace placeholder graph behavior with V2 task/project state machines using runtime reconciliation as the first operation of every node. Implement planning, plan guard, exact-session implementation, patch guard, verification, fresh task review, task repair, acceptance, serial integration, project verification, fresh combined review, project needs_repair, deterministic unaffected-patch replay, rerun, completion, failure, and cancellation. Task repair always materializes a fresh base-plus-rejected-patch tree and verifies its complete hash. After repair, patch guard re-extracts the complete base-relative replacement, derives and persists the authoritative repaired tree hash, and a separate fresh verifier reconstructs base plus replacement and must reproduce that hash before commands run. Project repair marks every prior affected attempt/base/patch/verifier/reviewer/finding/evidence/intent/status superseded under a new epoch, rebuilds from immutable project base, verifies each unaffected replay prefix, and assigns new task bases. Validate exact hashes, findings, main-selected targets, per-task boundaries, dependency plus ordered file/resource impact closure, invalidated patches, budgets, integration order, and replay. Add durable multi-run FIFO scheduling by project admission/topological index/task/role; exact W/W, W/R, equal-resource and unknown-resource conflicts; no cross-phase slot reservation; global five-child lease recovery/cancellation; separate heavy and serial-integration locks. The service never infers semantic targets or instructions.",
    "files": [
      "src/jessy_graph/graphs/state.py",
      "src/jessy_graph/graphs/routing.py",
      "src/jessy_graph/graphs/task_graph.py",
      "src/jessy_graph/graphs/project_graph.py",
      "src/jessy_graph/application/scheduler.py",
      "src/jessy_graph/application/task_execution.py",
      "tests/unit/test_project_graph.py",
      "tests/unit/test_task_graph.py",
      "tests/unit/test_scheduler.py",
      "tests/integration/test_dag_execution.py",
      "tests/integration/test_review_repair_loop.py",
      "tests/integration/test_project_repair_replay.py",
      "tests/integration/test_multi_project_scheduler.py",
      "tests/integration/test_role_manifest_chain.py"
    ],
    "readFiles": [
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/domain/entities.py",
      "src/jessy_graph/domain/states.py",
      "src/jessy_graph/adapters/runtime_store.py",
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/adapters/git_workspace.py",
      "src/jessy_graph/application/recovery.py",
      "src/jessy_graph/application/verification.py",
      "src/jessy_graph/application/review.py"
    ],
    "resources": ["graph:task-v2", "graph:project-v2", "scheduler:global", "integration:serial", "repair:project-replay"],
    "dependsOn": ["T5-runtime-authority-recovery"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["roleStateMachine", "mainSessionAuthority"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints"],
    "grillRefs": ["D2", "D5", "D6", "D7", "D8"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_project_graph.py tests/unit/test_task_graph.py tests/unit/test_scheduler.py tests/integration/test_dag_execution.py tests/integration/test_review_repair_loop.py tests/integration/test_project_repair_replay.py tests/integration/test_multi_project_scheduler.py tests/integration/test_role_manifest_chain.py -q"
    ],
    "expectedEvidence": [
      "each patch task follows plan-guard-implement-patch-verify-review before serial integration and final combined review",
      "task and combined findings pause for exact main-authored contracts; project repair replays unaffected patches and reruns the explicit dependency-closed set",
      "repair patch guard and fresh verifier independently derive the same authoritative repaired tree hash before repair evidence can satisfy a gate",
      "superseded repair-epoch evidence cannot satisfy current gates, and every lifecycle role binds the same immutable run manifest plus its exact role bundle",
      "multiple runs schedule deterministically and fairly without exceeding five live Codex children or retaining a slot between roles",
      "every node reconciles canonical runtime and checkpoint loss does not change semantics"
    ],
    "forbiddenEvidence": [
      "no direct executor bypass, human execution approval, automatic target/repair selection, scope expansion, reviewer/verifier write, early integration, or completion before combined review",
      "no V1 boundary removal before T7"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T7-v2-cutover-mcp",
    "prompt": "Cut the complete application and authenticated MCP surface to V2, migrate every remaining V1 consumer, then remove V1 contracts/schemas/migration/tests. Accept only ProjectContractV2; submission is execution authorization. Expose durable task/project phase, structured findings, immutable evidence/artifact queries, TaskRepairContractV2 and ProjectRepairContractV2 submission, and cancellation. Remove approve/final-approval and all V1 result/history/recovery semantics. Wire one graph authority, singleton five-process pool, skill/profile services, verifier/reviewer, canonical runtime store, checkpoint cache, and recovery in main.py. Preserve bearer/Host/Origin checks, 0.0.0.0:8003, project-local state, systemd lifecycle, redaction, idempotency, serial final patch export, and no orchestrated source writeback. This task owns all remaining V1 import/test consumers, including domain exports and artifact-store tests already migrated earlier, and must prove repository-wide V1 rejection.",
    "files": [
      "migrations/0001_runtime.sql",
      "schemas/project-contract-v1.schema.json",
      "schemas/codex-result-v1.schema.json",
      "src/jessy_graph/domain/__init__.py",
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/domain/states.py",
      "src/jessy_graph/application/ports.py",
      "src/jessy_graph/application/commands.py",
      "src/jessy_graph/application/queries.py",
      "src/jessy_graph/adapters/mcp_server.py",
      "src/jessy_graph/main.py",
      "tests/conftest.py",
      "tests/unit/test_contracts.py",
      "tests/unit/test_artifact_store.py",
      "tests/integration/test_artifact_store.py",
      "tests/integration/test_mcp_server.py",
      "tests/integration/test_mcp_lifespan.py",
      "tests/integration/test_mcp_evidence.py",
      "tests/integration/test_v2_cutover_inventory.py",
      "tests/integration/test_final_approval.py",
      "tests/e2e/test_m1_project_run.py",
      "tests/e2e/test_v1_dag.py",
      "tests/e2e/test_v1_recovery.py",
      "tests/e2e/test_v1_security.py",
      "tests/e2e/test_v2_project_run.py",
      "tests/e2e/test_v2_recovery.py",
      "tests/e2e/test_v2_security.py"
    ],
    "readFiles": [
      "migrations/0001_runtime_v2.sql",
      "src/jessy_graph/domain/entities.py",
      "src/jessy_graph/adapters/runtime_store.py",
      "src/jessy_graph/adapters/artifact_store.py",
      "src/jessy_graph/adapters/checkpoint_store.py",
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/graphs/project_graph.py",
      "src/jessy_graph/settings.py",
      "systemd/jessy-graph.service"
    ],
    "resources": ["api:mcp-v2", "application:v2-cutover", "schema:v1-removal", "service:startup-wiring", "artifact:final-patch"],
    "dependsOn": ["T6-v2-role-graphs"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["hostNativeRuntime", "trustedLanMcp"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints"],
    "grillRefs": ["D1", "D2", "D6", "D8", "D9"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_contracts.py tests/unit/test_artifact_store.py tests/integration/test_artifact_store.py tests/integration/test_mcp_server.py tests/integration/test_mcp_lifespan.py tests/integration/test_mcp_evidence.py tests/integration/test_v2_cutover_inventory.py tests/e2e/test_v2_project_run.py tests/e2e/test_v2_recovery.py tests/e2e/test_v2_security.py -q",
      "test ! -e schemas/project-contract-v1.schema.json && test ! -e schemas/codex-result-v1.schema.json && test ! -e migrations/0001_runtime.sql",
      "! rg -n 'ProjectContractV1|TaskContractV1|CodexResultV1|waiting_approval|approve_project|final_approval' src tests schemas migrations"
    ],
    "expectedEvidence": [
      "authenticated MCP accepts only V2, exposes exact findings/evidence/artifacts and both repair contract types, and has no human final approval tool",
      "all V1 types, exports, consumers, schemas, migration, approval paths, and V1 tests are gone after all consumers migrate",
      "an AST/import/runtime inventory loads every package module and proves no V1 authority remains before deletion is accepted",
      "one graph/runtime authority resumes without duplicate effects and returns an immutable final patch without submitted-source writes"
    ],
    "forbiddenEvidence": [
      "no V1 submission/result/query/recovery/history, compatibility adapter, approval interrupt, split direct executor, source writeback, push, deploy, public network, or multi-user feature",
      "no auth/API key/control prompt/unredacted diagnostic in MCP output or artifacts and no .idea/.env/data/live-service modification"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T8-hostile-rollout-gates",
    "prompt": "Add mandatory hostile-worker fixtures plus deterministic cold-rollout, rollback, and live-canary helpers. Hostile cases attempt planner/reviewer writes, built-in subagents, direct/wrapped nested Codex, worker commits/ref changes, skill/profile/policy/harness mutation, omitted/substituted skills, wrong models, advisory/actual diff mismatch, mutable-worktree review, test tampering, and submitted-source mutation; all fail before integration. Credential fixtures test non-recording/redaction/leak failure without claiming read isolation. The rollout manifest CAS-binds plan consensus and T9 evidence, canonical absolute allowlists, synthetic baseline, V2 patch/result and changed paths, retained patch, unchanged installed systemd symlink/target/content hashes, exact DB/backup paths/hashes, schema/rollout IDs, and exact allowed V1 smoke rows. Before reset prove service inactive, no DB handles, exact smoke-only rows, closed/checkpointed WAL, and SQLite API backups. Failure rollback acquires exclusive project flock, fences launches, terminates and waits for all recorded/discovered canary children, proves zero DB handles, prepares and hash-verifies reverse source plus restored DB images off live paths, then revalidates the full source/DB/systemd CAS immediately before mutation. A directory-fsynced journal makes atomic source install, both atomic DB installs/sidecar cleanup, unit verification, and service restart idempotently resumable after any crash. Any pre-mutation mismatch leaves stopped. The live helper reads secrets only from environment and validates real role/session/bundle/evidence/recovery/source fingerprints.",
    "files": [
      "ops/cold_v2_rollout.py",
      "ops/v2_live_canary.py",
      "tests/fakes/hostile_codex.py",
      "tests/unit/test_cold_v2_rollout.py",
      "tests/unit/test_live_canary.py",
      "tests/unit/test_rollout_cas.py",
      "tests/e2e/test_v2_supervision.py",
      "tests/integration/test_host_service_config.py"
    ],
    "readFiles": [
      "config/worker.rules",
      "config/worker-safe-skills.toml",
      "config/quality-profiles.toml",
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/adapters/git_workspace.py",
      "src/jessy_graph/application/verification.py",
      "src/jessy_graph/application/review.py",
      "src/jessy_graph/adapters/mcp_server.py",
      "src/jessy_graph/settings.py",
      "systemd/jessy-graph.service"
    ],
    "resources": ["test:hostile-workers", "ops:cold-rollout", "ops:source-rollback", "ops:sqlite-backup", "ops:live-canary"],
    "dependsOn": ["T7-v2-cutover-mcp"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["auditedDeviationPatterns", "releaseGate", "syntheticBaseline"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints", "sourceEvidence"],
    "grillRefs": ["D5", "D6", "D7", "D8", "D9", "D10"],
    "acceptanceCommands": [
      "uv run pytest tests/unit/test_cold_v2_rollout.py tests/unit/test_live_canary.py tests/unit/test_rollout_cas.py tests/e2e/test_v2_supervision.py tests/integration/test_host_service_config.py -q"
    ],
    "expectedEvidence": [
      "every mandatory hostile deviation produces authoritative failure and cannot integrate",
      "rollout manifests bind baseline, V2 patch/result, systemd target, SQLite backups/sidecars, and exact rollback order",
      "exclusive rollback lock, zero live children/DB handles, prepared images, final CAS, and fsynced journal make every partial rollback resumable",
      "rollback touches only the recorded V2 patch and exact DB/unit targets when fingerprints match, otherwise leaves the service stopped"
    ],
    "forbiddenEvidence": [
      "no skipped hostile case, PASS_WITH_RISK, test weakening, fake-only release claim, broad delete, sidecar copy as backup, unresolved path, credential output, or automatic live execution",
      "no claim of same-UID credential secrecy and no modification of .idea, host auth/config, runtime DB, or live service during deterministic tests"
    ],
    "patchBackStrategy": "harness-managed"
  },
  {
    "id": "T9-deterministic-release-gate",
    "prompt": "Run the complete deterministic V2 gate from the integrated approved synthetic baseline. Validate uv.lock, the full unit/integration/recovery/E2E suite, hostile and operations cases, schemas/config, diff whitespace, exact plan-owned paths, V1 absence, fixed role models, process cap, fresh worktrees, recovery matrix, rollout/rollback manifests, and preservation of .idea plus submitted-source fingerprints. This task is read-only. Any failure returns to the owning task under a bounded main-authored repair; never edit, skip, xfail, weaken, or reinterpret a mandatory gate.",
    "files": [],
    "readFiles": [
      "pyproject.toml",
      "uv.lock",
      "config/worker.rules",
      "config/worker-safe-skills.toml",
      "config/quality-profiles.toml",
      "schemas/project-contract-v2.schema.json",
      "schemas/run-manifest-v2.schema.json",
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/adapters/git_workspace.py",
      "src/jessy_graph/adapters/runtime_store.py",
      "src/jessy_graph/application/recovery.py",
      "src/jessy_graph/application/verification.py",
      "src/jessy_graph/application/review.py",
      "src/jessy_graph/graphs/project_graph.py",
      "src/jessy_graph/adapters/mcp_server.py",
      "ops/cold_v2_rollout.py",
      "ops/v2_live_canary.py"
    ],
    "resources": ["test-suite:full-v2", "resource:heavy-check", "repo:integrated-worktree"],
    "dependsOn": ["T8-hostile-rollout-gates"],
    "complexity": "complex",
    "mutatesFiles": false,
    "contextRefs": ["syntheticBaseline", "releaseGate"],
    "intakeRefs": ["approvedOutOfScope", "constraints"],
    "grillRefs": ["D7", "D8", "D10"],
    "acceptanceCommands": [
      "uv lock --check",
      "uv run pytest -q",
      "git diff --check"
    ],
    "expectedEvidence": [
      "the complete suite, lockfile, schema/config/static, diff, recovery, hostile, and rollback gates exit zero with no skipped mandatory case",
      "only plan-owned files differ from the synthetic baseline and .idea plus submitted-source fingerprints are unchanged",
      "static gates find no V1 path, deepseek-v4-pro route, unsafe Codex flag, workflow skill, mutable review input, checkpoint authority, or direct executor bypass"
    ],
    "forbiddenEvidence": [
      "no implementation edit, skip/xfail/weakening, service activation, database reset, provider call, source writeback, external mutation, PASS_WITH_RISK, or worker-self-report acceptance",
      "no increase above five concurrent Jessy Graph Codex children"
    ],
    "patchBackStrategy": "external-report"
  },
  {
    "id": "T10-cold-rollout-live-canary",
    "prompt": "After T9 passes, perform the approved stateful V2 rollout in the main session using a content-addressed manifest that CAS-binds plan-consensus and exact T9 evidence hashes. Record canonical absolute allowlists, synthetic baseline, V2 patch/result/paths, retained patch, unchanged systemd symlink/target/content hashes, exact live/backup DB paths/hashes, schema/rollout IDs, and exact allowed V1 smoke rows. Stop the service and prove no DB handles; abort unless V1 rows exactly match smoke with no attempts, leases, nonterminal, or user-added records. Checkpoint WAL, use SQLite backups, remove only exact DB/sidecars, initialize V2, and restart on 0.0.0.0:8003. Run the real Luna planner -> exact-session Flash implementer -> isolated verifier -> Luna task/combined review canary, restart mid-run, and exercise multi-run five-process pressure. On failure acquire exclusive rollout flock, fence launches, terminate/wait all recorded/discovered canary children, prove service inactive and zero DB handles, and prepare/hash-check reversed source and restored DB images off live paths. Revalidate the full source/DB/systemd CAS immediately before mutation. Then use a directory-fsynced rollback journal for idempotent atomic source install, both atomic DB installs/exact sidecar cleanup, unchanged-unit verification, and V1 restart; recovery resumes any partial journal before service start. Any pre-mutation mismatch leaves stopped. Remove backups only after PASS. Reverse only retained patch paths within the listed allowlist and mutate only exact data paths; never touch .idea, .env, unrelated state, or submitted sources.",
    "files": [
      "pyproject.toml",
      "uv.lock",
      "config/worker-safe-skills.toml",
      "config/quality-profiles.toml",
      "config/worker.rules",
      "migrations/0001_runtime.sql",
      "migrations/0001_runtime_v2.sql",
      "schemas/project-contract-v1.schema.json",
      "schemas/codex-result-v1.schema.json",
      "schemas/project-contract-v2.schema.json",
      "schemas/task-plan-v2.schema.json",
      "schemas/codex-result-v2.schema.json",
      "schemas/review-result-v2.schema.json",
      "schemas/task-repair-contract-v2.schema.json",
      "schemas/project-repair-contract-v2.schema.json",
      "schemas/run-manifest-v2.schema.json",
      "src/jessy_graph/domain/__init__.py",
      "src/jessy_graph/domain/contracts.py",
      "src/jessy_graph/domain/evidence.py",
      "src/jessy_graph/domain/states.py",
      "src/jessy_graph/domain/entities.py",
      "src/jessy_graph/settings.py",
      "src/jessy_graph/policies/command_policy.py",
      "src/jessy_graph/adapters/codex_child.py",
      "src/jessy_graph/adapters/skill_bundle.py",
      "src/jessy_graph/adapters/artifact_store.py",
      "src/jessy_graph/adapters/codex_runner.py",
      "src/jessy_graph/adapters/git_workspace.py",
      "src/jessy_graph/adapters/runtime_store.py",
      "src/jessy_graph/adapters/checkpoint_store.py",
      "src/jessy_graph/adapters/mcp_server.py",
      "src/jessy_graph/application/ports.py",
      "src/jessy_graph/application/recovery.py",
      "src/jessy_graph/application/verification.py",
      "src/jessy_graph/application/review.py",
      "src/jessy_graph/application/scheduler.py",
      "src/jessy_graph/application/task_execution.py",
      "src/jessy_graph/application/commands.py",
      "src/jessy_graph/application/queries.py",
      "src/jessy_graph/graphs/state.py",
      "src/jessy_graph/graphs/routing.py",
      "src/jessy_graph/graphs/task_graph.py",
      "src/jessy_graph/graphs/project_graph.py",
      "src/jessy_graph/main.py",
      "ops/cold_v2_rollout.py",
      "ops/v2_live_canary.py",
      "tests/conftest.py",
      "tests/e2e/test_m1_project_run.py",
      "tests/e2e/test_v1_dag.py",
      "tests/e2e/test_v1_recovery.py",
      "tests/e2e/test_v1_security.py",
      "tests/e2e/test_v2_project_run.py",
      "tests/e2e/test_v2_recovery.py",
      "tests/e2e/test_v2_security.py",
      "tests/e2e/test_v2_supervision.py",
      "tests/fakes/fake_codex.py",
      "tests/fakes/hostile_codex.py",
      "tests/fixtures/git_cases.py",
      "tests/integration/test_artifact_store.py",
      "tests/integration/test_codex_runner.py",
      "tests/integration/test_codex_capabilities.py",
      "tests/integration/test_command_runner.py",
      "tests/integration/test_dag_execution.py",
      "tests/integration/test_final_approval.py",
      "tests/integration/test_git_change_set.py",
      "tests/integration/test_git_workspace.py",
      "tests/integration/test_host_service_config.py",
      "tests/integration/test_mcp_evidence.py",
      "tests/integration/test_mcp_lifespan.py",
      "tests/integration/test_mcp_server.py",
      "tests/integration/test_project_repair_replay.py",
      "tests/integration/test_multi_project_scheduler.py",
      "tests/integration/test_review_repair_loop.py",
      "tests/integration/test_review_worktrees.py",
      "tests/integration/test_role_manifest_chain.py",
      "tests/integration/test_runtime_store.py",
      "tests/integration/test_skill_bundle.py",
      "tests/integration/test_verification.py",
      "tests/integration/test_v2_cutover_inventory.py",
      "tests/recovery/test_project_recovery.py",
      "tests/recovery/test_scheduler_recovery.py",
      "tests/recovery/test_side_effect_intents.py",
      "tests/recovery/test_launch_fencing.py",
      "tests/recovery/test_task_recovery.py",
      "tests/unit/test_artifact_store.py",
      "tests/unit/test_codex_runner.py",
      "tests/unit/test_cold_v2_rollout.py",
      "tests/unit/test_command_policy.py",
      "tests/unit/test_contracts.py",
      "tests/unit/test_entities.py",
      "tests/unit/test_evidence.py",
      "tests/unit/test_live_canary.py",
      "tests/unit/test_rollout_cas.py",
      "tests/unit/test_project_graph.py",
      "tests/unit/test_run_manifest.py",
      "tests/unit/test_schema_parity.py",
      "tests/unit/test_runtime_store.py",
      "tests/unit/test_scheduler.py",
      "tests/unit/test_settings.py",
      "tests/unit/test_skill_bundle.py",
      "tests/unit/test_task_graph.py",
      "data/runtime.db",
      "data/runtime.db-wal",
      "data/runtime.db-shm",
      "data/checkpoints.db",
      "data/checkpoints.db-wal",
      "data/checkpoints.db-shm",
      "data/rollback-v1/runtime.db",
      "data/rollback-v1/checkpoints.db",
      "data/v2-rollout-manifest.json"
    ],
    "readFiles": [
      "systemd/jessy-graph.service",
      "ops/cold_v2_rollout.py",
      "ops/v2_live_canary.py",
      "src/jessy_graph/settings.py",
      "src/jessy_graph/main.py",
      "config/quality-profiles.toml",
      "config/worker.rules"
    ],
    "resources": ["approval:plan-consensus-hash", "evidence:t9-gate-hash", "service:jessy-graph-live", "service-unit:/etc/systemd/system/jessy-graph.service", "port:8003", "db:runtime-live", "db:checkpoints-live", "db:rollback-v1", "process:codex-live", "repo:jessy-graph-v2-patch", "repo:submitted-source"],
    "dependsOn": ["T9-deterministic-release-gate"],
    "complexity": "complex",
    "mutatesFiles": true,
    "contextRefs": ["hostNativeRuntime", "freshV2Database", "releaseGate", "syntheticBaseline"],
    "intakeRefs": ["approvedInScope", "approvedOutOfScope", "constraints"],
    "grillRefs": ["D2", "D7", "D8", "D9", "D10"],
    "acceptanceCommands": [
      "systemctl is-active jessy-graph.service",
      "uv run python ops/v2_live_canary.py --base-url http://127.0.0.1:8003/mcp",
      "uv run python ops/cold_v2_rollout.py verify-manifest --manifest data/v2-rollout-manifest.json --expected-state active-v2"
    ],
    "expectedEvidence": [
      "rollout manifest binds the synthetic baseline, V2 patch/result, systemd link/target, live/backup DB paths/hashes, schema versions, and canary run",
      "fresh V2 stores and authenticated MCP complete the real Luna-plan, exact-session Flash implementation, isolated verification, Luna task/final review, restart, and five-process pressure gates",
      "failure executes the ordered source/database/systemd CAS and either restores exact baseline/DB state under the unchanged unit or leaves stopped without further mutation",
      "failure rollback holds the exclusive lock with zero live children/DB handles and completes or resumes its fsynced journal before any prior-service restart",
      "rollback DB copies disappear only after hard PASS while the V2 patch artifact remains recoverable"
    ],
    "forbiddenEvidence": [
      "no V1 history/migration/resume after successful cutover, PASS_WITH_RISK, skipped live phase, provider fallback, deepseek-v4-pro, human execution approval, or submitted-source writeback",
      "no secret in commands/logs/artifacts/databases/diagnostics/MCP responses and no claim that same-UID worker credential reads are prevented",
      "no unlisted tracked file, .idea, .env, unrelated service/process/database/repository, public network policy, broad filesystem target, or unverified rollback mutation"
    ],
    "patchBackStrategy": "external-report"
  }
]
```
