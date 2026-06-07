# Cross-Agent Plan Contract 模板

这是一份模板，不是某一次任务的真实 contract。

真实执行时，Codex 应该基于这个模板生成具体文件，并保存到：

```text
.claude/plans/YYYY-MM-DD_HHMMSS-codex-contract-<slug>.md
```

---

## Metadata

```text
contract_version: 1
source_agent: codex
target_executor: claude-code
project_root:
base_commit:
created_at:
status: CONTRACT_DRAFTED
```

## Phase 0.3 Knowledge + AGENTS.md

```text
knowledge_file:
knowledge_status:
agents_md_status: missing | created | updated | existing | skipped
agents_md_scope:
current_session_loaded_agents_md: true | false
notes:
```

## Skill Routing

### Codex Planner Skills Used

```text
- project-workflow-codex
  required: true
  reason:
- karpathy-guidelines
  required: true
  reason:
```

### Recommended Claude Code Skills

```text
- project-workflow-claude
  required: true
  reason:
- karpathy-guidelines
  required: true
  reason:
```

### Claude Phase 3 Skill Check

```text
Claude Code must verify:
1. recommended skills match the actual task
2. missing required skills are reported
3. unnecessary skills are not loaded blindly
4. skill routing changes are returned as Phase 3 findings
```

## Intent

```text
user_request:
desired_outcome:
non_goals:
assumptions:
```

## Discovery Evidence

```text
files_read:
commands_run:
existing_constraints:
risks_found:
open_questions:
```

## Scope

```text
in_scope:
expected_changed_files:
out_of_scope:
forbidden_changes:
```

## Plan

```text
approach:
directory_structure:
sequencing:
verification:
```

## Tasks

```json
[
  {
    "id": "T1",
    "prompt": "Self-contained task prompt for Claude Code subagent.",
    "files": ["path/to/file.md"],
    "recommendedSkills": ["karpathy-guidelines"],
    "complexity": "simple",
    "mutatesFiles": true,
    "dependsOn": [],
    "verification": ["test -f path/to/file.md"]
  }
]
```

## Preflight Checklist

```text
- base_commit matches current HEAD:
- goal/non_goals clear:
- expected files listed:
- forbidden changes listed:
- every task self-contained:
- every task has verification:
- executor instructions present:
- user approval gate present:
```

## Executor Instructions for Claude Code

```text
1. Load project-workflow-claude.
2. Treat this file as an external Cross-Agent Plan Contract.
3. Do not re-plan from scratch.
4. First run Phase 3 consensus against the full contract.
5. During Phase 3, do not implement. Review only.
6. Return APPROVE / ITERATE / REJECT with structured findings.
7. Wait for Codex to triage findings and provide an approved contract version.
8. If the final contract is approved, ask the user for approval before Phase 4.
9. After user approval, execute Phase 4 using the json tasks.
10. Run Phase 5 review.
11. Run Phase 6 verify.
12. Return structured result for Codex final audit.
```

## Required Claude Phase 3 Review Shape

```text
verdict: APPROVE | ITERATE | REJECT
findings:
  - id:
    severity: critical | high | medium | low
    section:
    issue:
    why_it_matters:
    suggested_contract_change:
missing_questions:
execution_risks:
approval_conditions:
```

## Required Codex Replan Shape

```text
reviewed_contract:
claude_phase3_verdict:
findings_accepted:
findings_deferred:
findings_rejected:
contract_changes:
new_contract_version:
new_status:
```

## Required Claude Result Shape

```text
contract_path:
base_commit:
final_head:
phase3_verdict:
user_approved_execution:
tasks:
  - id:
    status:
    files_changed:
    self_review:
phase5_verdict:
phase6_verdict:
verification_commands:
changed_files:
known_risks:
```
