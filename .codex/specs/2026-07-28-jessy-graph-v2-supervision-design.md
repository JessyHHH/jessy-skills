# Jessy Graph V2 Supervision Design

Status: AWAITING COMBINED SPEC AND PLAN APPROVAL.

## Scope

Upgrade `/root/hzx_mixlinker/jessy-graph` from its unused host-native V1 into a strict V2 execution supervisor. V2 accepts a main-Codex-authored project/task DAG over authenticated MCP, runs a read-only task planner, resumes that exact Codex session for implementation, derives patches from immutable Git bases, verifies and reviews them in fresh worktrees, and serially integrates accepted patches. It preserves the root systemd service, uv environment, project-local state, host Codex provider/authentication, `0.0.0.0:8003`, trusted-LAN operation, five-process global cap, durable recovery, and the rule that orchestrated runs never write back to operator source repositories.

This is a single-user trusted-host supervisor, not an OS security boundary. No container, VM, or separate worker UID is introduced. Unrelated `.idea/` state is never read as an input or modified.

## Requirements

1. Accept only `ProjectContractV2` at the MCP boundary. V1 has no submission, migration, query, resume, or compatibility path after cutover.
2. Human involvement ends after Phase 1 clarification and one combined spec/plan approval. Submission authorizes execution; main Codex owns later dispatch, repair scope, integration, review, verification, and completion decisions.
3. Main Codex remains semantic authority. Jessy Graph validates exact tasks, skills, evidence, repair contracts, and dependency closure without inventing them.
4. Every planner and every task/combined reviewer uses `gpt-5.6-luna`. Every implementer and repair worker uses `deepseek-v4-flash`. `deepseek-v4-pro` is forbidden for all V2 runtime roles.
5. One service-global semaphore caps all planner, implementer, repair, task-review, and combined-review Codex child processes at five.
6. Planner execution is read-only. Implementation resumes the exact planner session in the task worktree with a role-specific implementation bundle. Every Codex child receives `--disable multi_agent`.
7. Main-selected worker-safe skills are immutable, role-scoped run inputs. `project-workflow-codex` is forbidden in workers.
8. Worker summaries and self-reported evidence are advisory. Controlled Git operations, immutable manifests, supervised process records, fresh verifier results, and structured reviewer findings are authoritative in their domains; mismatches fail closed.
9. Every patch task is verified and then independently reviewed. The final integrated patch is independently combined-reviewed. Reviewers and verifiers never edit.
10. Repairs require main-authored bounded contracts. Jessy Graph validates those contracts and deterministic rerun closure; it never selects affected tasks or writes repair instructions.
11. The runtime SQLite database is the sole canonical workflow/application state. The LangGraph checkpoint database is a disposable cursor/cache reconstructed from runtime state.
12. V1 has no user data. Cold rollout discards the one smoke row and old checkpoints only after exact backups and rollback metadata exist.
13. Release has no `PASS_WITH_RISK`: the full deterministic hostile-worker suite and a real authenticated MCP lifecycle canary must pass.

## Non-Goals

- Public Internet, multi-user, container, VM, or separate-UID operation.
- OS-level containment of a malicious same-UID/root Codex process.
- Credential confidentiality from a worker that must use the host provider authentication.
- Autonomous project decomposition, skill inference, repair-scope selection, or semantic acceptance by Jessy Graph.
- Automatic merge, push, deployment, or writeback into repositories submitted to Jessy Graph.
- V1 compatibility, history migration, or checkpoint recovery.
- Treating JSONL, prompt text, execpolicy, or reviewer judgment as the sole authorization boundary.

## Trust and Credential Boundary

The host-native constraint means a Codex child can read host files allowed by its sandbox, including authentication it needs to call the configured relay. A controlled run-specific `CODEX_HOME` provides deterministic configuration, rules, sessions, and audit ownership; it does not provide credential isolation.

For each run the service:

- parses host `config.toml` and emits a minimal role config containing only approved provider/model/runtime fields;
- removes all host MCP server sections and unrelated inline credentials;
- links the host `auth.json` rather than copying it and records only path, ownership/mode checks, and hashes that cannot reveal content;
- fails preflight if the selected provider requires an unapproved inline secret outside `auth.json`;
- never places auth/config secrets in task/review/verifier worktrees, prompts, runtime rows, artifacts, MCP responses, or command arguments;
- streams output through known-secret and structural redaction, fails a role attempt on detected leakage, and retains only redacted audit data.

These controls reduce accidental disclosure and make recorded output testable. They cannot prove that a malicious same-UID worker did not read or transmit a credential. Stronger credential isolation requires a container, separate UID, or credential broker and is explicitly deferred.

## Contract and Manifest Model

`ProjectContractV2` is frozen and extra-forbid. It contains the immutable repository/base fingerprint, task DAG, exact read/write/resource boundaries, role skill selections, evidence predicates, repository quality-profile ID, process/retry/repair caps, and project verification commands.

`TaskPlanV2` is planner output. It must be a subset of its task contract and contains exact planned paths, inspected argv commands, risks, and evidence expectations. Planning is turn-scoped: the planner receives the immutable planner skill bundle; the implementation resume receives the immutable implementer bundle in a new approved prompt even though both turns share the exact session ID.

`TaskRepairContractV2` contains the current task ID, task-review input hash, exact finding IDs, accepted candidate patch hash, repair round, subset path boundary, bounded instructions, and evidence to rerun.

`TaskRepairContractV2` also fixes the repair materialization tuple: immutable task base tree, rejected candidate patch/hash, expected rejected tree hash, and repair epoch. It does not predict the repair result. A repair never reuses the rejected writer's mutable worktree. It creates a fresh detached task-base worktree, applies exactly the rejected candidate patch, verifies the complete rejected tree hash, then launches the bounded repair. Patch guard re-extracts the complete replacement patch from the immutable task base, derives and persists the authoritative repaired tree hash, and a separate fresh verifier reconstructs the base-plus-replacement tree and must reproduce that hash before any verification command runs.

`ProjectRepairContractV2` contains the combined-review input hash, exact finding IDs, main-selected target task IDs, one bounded task repair per target, an explicit dependency/resource-impact-closed rerun set, invalidated patch IDs, integration base/hash/order, and the expected unaffected patch replay set. The service validates hashes, ownership boundaries, downstream dependency and ordered file/resource conflict closure, ordering, and budgets. It reconstructs a fresh integration tree from the immutable project base, replays each unaffected patch in original order, and verifies every expected prefix tree hash. Before rerun, all prior attempts, bases, patches, verifier/reviewer inputs, findings, evidence, intents, and statuses for the explicit affected set are marked superseded by a new repair epoch and can never satisfy a current gate. New task bases are the verified replay-prefix trees. The service never chooses targets.

`RunManifestV2` is canonical JSON with a stable SHA-256. It owns the project contract hash, immutable repository/base fingerprint, quality profile and policy/harness hashes, per-role model/sandbox mapping, per-role skill-bundle hashes, aggregate bundle-manifest hash, process limit, retry/repair caps, and service/Codex versions. Every role attempt references the manifest hash; immutable fields cannot change on resume or repair.

## Skills and Quality Profiles

The main session supplies exact `required_skills` and required reference paths per role. Jessy Graph validates them against project-owned worker-safe allowlists and a repository quality profile. It rejects missing mandatory skills, forbidden skills, unexpected references, or silent substitutions.

Each role bundle contains complete selected `SKILL.md` bytes, explicitly selected one-level references, source paths, individual SHA-256 values, and a canonical bundle manifest. Bundles are promoted into immutable run artifacts before the first role launch. Resume uses the role-appropriate hash recorded in `RunManifestV2`; the aggregate hash proves the complete run-scoped set. Workers never browse the global skill catalog.

## Role Execution

| Role | Model | Sandbox | Session rule |
| --- | --- | --- | --- |
| planner | `gpt-5.6-luna` | read-only | creates task session |
| implementer | `deepseek-v4-flash` | workspace-write | resumes exact planner session |
| task repair | `deepseek-v4-flash` | workspace-write | bounded new repair session |
| task reviewer | `gpt-5.6-luna` | read-only | independent fresh session |
| combined reviewer | `gpt-5.6-luna` | read-only | independent fresh session |

Every invocation uses the verified absolute Codex binary, approval `never`, empty MCP configuration, `--disable multi_agent`, JSONL streaming, exact cwd, explicit model and sandbox, and local strict result validation. `--strict-config`, `--output-schema`, `--ignore-user-config`, danger-full-access, and sandbox bypass are forbidden. Command policy rejects nested Codex, worker commits/ref mutation, policy mutation, and disallowed shells/wrappers. JSONL supports audit and emergency termination but never authorizes a transition.

Across all admitted runs, ready roles enter one durable FIFO queue ordered by `(project_admission_sequence, task_topological_index, task_id, role_order)`. File conflicts use write/write and write/read intersection; identical resource tokens conflict and `unknown` conflicts with everything. Each planner, implementer, repair, or reviewer acquires one global slot only while its Codex child is live; a task never reserves a slot across phases. Waiting roles hold no slot. A monotonic lease/fence reconstructs the five-slot pool after restart. Cancellation fences new launches, terminates recorded live process groups, reconciles their intents, and preserves evidence. Heavy verifier commands and serial integration use separate service-global locks and consume no Codex slot.

## Worktrees, Patches, Verification, and Review

Each task starts from an immutable task base. Before and after each writer phase, controlled Git checks require task worktree HEAD/refs to equal that base. A temporary index initialized from the base derives changed paths and a binary patch covering staged, unstaged, untracked, deleted, renamed, and attempted committed changes. Commit/ref drift fails closed.

Authoritative verification uses a fresh detached verifier worktree containing only the immutable task base plus candidate patch. It validates manifest/profile/policy/harness/input hashes and runs inspected argv under `unshare --net` with a sanitized environment. Worker-authored tests are diagnostic; immutable external checks are authoritative.

Task review uses another fresh detached worktree containing only the task base plus the verified candidate patch. Combined review uses a fresh detached worktree containing only the immutable project integration base plus the final integrated patch. Review inputs include the exact tree, patch, contract, plan, verification, profile, skill-bundle, and harness hashes. Review worktrees are destroyed after immutable structured findings are promoted. Reviewers cannot see or depend on the mutable implementation/integration worktree.

Serial integration uses an intent that records parent tree/head, candidate patch hash, task/order, expected resulting tree hash, and final patch prefix hash. No orchestrated run writes this patch into the submitted operator source repository; it is returned as an immutable artifact.

## State Machines

Task flow:

```text
queued -> planning -> plan_guard -> implementing -> patch_guard
       -> verifying -> reviewing -> accepted -> integrating -> integrated
                                   -> needs_repair
                                      -> repairing -> patch_guard -> verifying -> reviewing
       -> failed | cancelled
```

Project flow:

```text
submitted -> running -> project_verifying -> combined_reviewing -> completed
                                             -> needs_repair
                                                -> replaying -> running
          -> failed | cancelled
```

Query-only tasks that produce no patch skip semantic task review but still produce deterministic evidence. A maximum of three rejected repair rounds is enforced per task/project contract. Exceeding the approved budget fails closed.

## Persistence and Crash Consistency

`runtime.db` is the only canonical source for contracts, manifests, phases, attempts, process identities, session IDs, skill bundles, patches, verifier runs, findings, repair contracts, evidence, and integration order. `checkpoints.db` is only a LangGraph scheduling cursor/cache. Every graph node begins with `reconcile_runtime`; a missing, stale, or corrupt checkpoint is discarded and rebuilt from canonical runtime rows.

Every external side effect follows the same transaction protocol:

1. Persist a side-effect intent with immutable input hashes, phase/version, idempotency key, owner instance, monotonic fence, and lease expiry. A compare-and-swap claim permits only the highest live fence to act or commit.
2. For process effects, launch a service-owned child wrapper with the intent ID/fence/start nonce. Before `exec` of Codex, the wrapper atomically writes and directory-fsyncs a launch receipt containing PID, process group, boot ID, `/proc` start ticks, argv hash, spool paths, and exec-started marker. The first streamed session event adds the exact provider session ID. Then execute or reattach to the supervised effect.
3. Write output into a run-local spool and atomically promote an immutable artifact.
4. In one runtime transaction, and only under the current fence, commit result hashes, close the intent/lease, and advance the canonical phase/version.
5. Return the graph update. A graph update never precedes the runtime commit.

Integration intents additionally persist parent head/tree, patch hash, expected resulting tree, task order, and accepted patch-prefix hash.

### Crash Recovery Matrix

| Phase/effect | Canonical recovery |
| --- | --- |
| planner launch | Reconcile the fenced intent and fsynced wrapper receipt. Reattach only when PID/process-group/boot/start/argv/fence all match; promote a complete matching spool. Retry only when the receipt proves Codex `exec` never started. A started process with neither session ID nor complete result is `AMBIGUOUS_LAUNCH` and fails closed rather than creating a second session. |
| implementation resume | Reattach when live. If dead without a complete result, verify exact session ID, immutable worktree base, and boundary-valid partial tree, then resume that same session/attempt; ambiguity or drift fails closed. |
| patch extraction | Recompute deterministically from base/worktree or promote a matching spool; any hash mismatch fails closed. |
| verifier | Destroy partial verifier worktree and rerun from immutable patch/input hashes; never infer success from partial output. |
| task/combined reviewer | Destroy partial review worktree and rerun a fresh independent session from immutable review-input hashes; never reuse mutable review state. |
| serial integration | If tree equals parent, reapply once; if it equals expected result, commit the recorded result; any third tree state fails closed. |
| needs-repair wait | Remain paused until the exact main-authored task/project repair contract is durably admitted; never infer scope. |
| repair worker | Apply the same supervised writer recovery rules with its repair contract and round hashes. |
| missing/stale checkpoint | Rebuild graph cursor from runtime phase/version and open intents; checkpoint content never advances runtime. |

Concurrent reconciliation is harmless: only the current intent fence may launch, promote, close, or advance. Stale supervisors and stale child results are retained as evidence but rejected.

Only declared transient provider/process failures retry automatically, at most twice. Semantic, boundary, policy, hash, evidence, review, and ambiguous recovery failures never auto-retry.

## MCP Surface

Authenticated Streamable HTTP MCP on `0.0.0.0:8003` accepts V2 submission, task/project repair submission, cancellation, and status/evidence/finding/artifact queries. Submission is the only execution authorization gate after combined user approval. Repair admission requires the exact current phase, input/finding hashes, remaining budget, and compare-and-swap version. There is no approve/final-approval tool.

## Cold Rollout and Rollback

The rollout manifest is content-addressed and CAS-binds the approved plan-consensus hash and exact T9 evidence hash. It records:

- approved synthetic baseline fingerprint and tracked-diff SHA;
- final V2 patch SHA, changed-path list, expected applied tree/fingerprint, and retained patch artifact;
- the canonical absolute allowlist, active systemd unit symlink/target and hashes (the rollout validates but never changes that symlink/unit);
- exact runtime/checkpoint DB and rollback DB paths and hashes;
- pre/post schema versions, rollout ID, allowed V1 smoke row fingerprint, service target, and retained V2 patch changed-path allowlist.

After the deterministic gate passes, stop `jessy-graph.service`, assert no nonterminal or user-owned V1 data, checkpoint both SQLite WALs with the service stopped, and use SQLite backup APIs to create exact project-local rollback databases. Sidecar `-wal`/`-shm` files are never copied as backups; their exact paths are checked and removed only after successful checkpoint/close. Initialize clean V2 databases, restart the project-owned service, and run the live canary.

Before destructive reset, the service must be inactive, no external file descriptor may reference either database, resolved paths must equal the absolute allowlist, and V1 rows must exactly match the recorded smoke fingerprint with no attempts, leases, nonterminal rows, or user-added records.

If the canary fails, keep the service stopped and preserve evidence. Rollback first acquires an exclusive project rollout `flock`, fences launches, terminates and waits for every recorded or discovered canary child/process group, proves the service inactive, and proves no external file descriptor references either database. It prepares and hash-verifies the reversed source tree and restored database images without mutating live paths. Under the lock it then performs one final ordered three-domain CAS: (1) current source equals the recorded V2 fingerprint and the retained patch's changed paths are a subset of the rollout allowlist; (2) both live databases resolve to the recorded paths, carry the rollout ID/V2 schema and only canary-owned rows, and their stopped failure hashes match; (3) the installed systemd symlink/target/content hashes still equal the recorded unchanged values.

After the final CAS, a directory-fsynced rollback journal drives idempotent phases: atomically install the prepared baseline source result, atomically install and hash-check both prepared V1 database images while removing only their exact sidecars, verify the unchanged unit, restart the prior service, and record completion. Recovery under the same lock resumes from observed fingerprints plus the journal; it never repeats a completed phase. Any pre-mutation mismatch changes nothing and leaves the service stopped. Any crash after mutation resumes the journal before the service may start. Rollback artifacts are deleted only after full V2 success; the V2 patch artifact remains recoverable.

## Verification Strategy

- Contract/schema parity tests run shared valid and invalid corpora: both Pydantic and generated JSON Schema must accept every valid case, reject every invalid case, and preserve identical canonical JSON/hash after model -> JSON -> schema -> model round trips. They cover V1 rejection, extras, wrong role models, cyclic/conflicting DAGs, invalid skills/evidence, and malformed task/project repairs.
- Manifest tests prove canonicalization, per-role bundle hashes, aggregate manifest hash, and immutable resume inputs.
- A cross-role lifecycle test proves planner, exact-session implementation, task/project repair, task review, and combined review all reference one immutable `RunManifestV2` and the correct role bundle hash.
- Host execution tests prove exact argv/session/model/sandbox/pool behavior, nested-Codex/commit denial, streaming redaction, and the documented credential limitation.
- Git/verifier/reviewer tests use worker commits, ref drift, untracked/deleted/renamed files, tampered tests, mutable implementation worktrees, and immutable fresh detached worktrees.
- Persistence tests cover every crash-matrix row, stale/missing checkpoints, concurrent reconciler fences, wrapper-receipt crash windows, intent replay, CAS conflicts, pool-lease recovery, cancellation, and duplicate-effect prevention.
- Scheduler tests cover deterministic multi-run FIFO ordering, exact file/resource conflicts, no cross-phase slot reservation, the global five-child limit, cancellation, restart lease recovery, heavy-gate serialization, and serial integration.
- Cutover inventory tests parse/import every package module and assert the generated V1 consumer inventory is empty before V1 files are deleted.
- Hostile-worker tests cover the audited planning/implementation deviations, recursive delegation, scope drift, evidence mismatch, model/skill substitution, and policy/profile/harness mutation.
- Full tests run with `uv lock --check`, `uv run pytest -q`, schema/config checks, `git diff --check`, exact changed-path checks, and no skipped mandatory gate.
- Live gate proves a real Luna planner -> exact-session Flash implementer -> isolated verifier -> Luna task/combined review lifecycle, restart recovery, five-process pressure, immutable hashes, redaction, final patch, and unchanged submitted source fingerprint.

## Risks

| Risk | Mitigation | Release response |
| --- | --- | --- |
| Same-UID worker can read host credentials | Explicit trust boundary, minimal config, no secrets in worktrees/argv, redaction/leak detection | Do not claim adversarial credential isolation; require container/UID/broker for that threat model. |
| Relay/model/resume behavior differs live | Exact argv tests and real role-transition canary | Keep V2 unreleased and execute recorded rollback. |
| Runtime/checkpoint divergence | Runtime-only authority, transactional intents, reconciliation-first nodes | Rebuild checkpoint; fail closed on runtime ambiguity. |
| Combined repair expands scope | Main-selected task/project repair contracts and deterministic closure validation | Reject contract or fail after bounded rounds. |
| Live rollout partially mutates code/DB/service | Fingerprinted V2 patch, SQLite backups, unit target record, exact rollback ordering | Reverse only when fingerprint matches; otherwise leave stopped. |

## Approval Boundary

This design and its implementation plan are presented together once consensus review returns `APPROVE`. User approval then authorizes all Phase 4 implementation, task review, repair, testing, combined review, verification, and rollout decisions by the main Codex session without further human gates.
