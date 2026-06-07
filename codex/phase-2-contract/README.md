# Phase 2：Plan Contract 计划契约

## 目标

Phase 2 的目标是把前两阶段的发现和澄清，写成一份可交接、可审查、可执行的 contract。

contract 不是普通计划。它必须做到：

- Claude Code 拿到后能理解任务
- 用户能看懂要做什么
- 每个 task 都能单独执行
- 后续能根据 contract 审计有没有跑偏

## contract 应该包含什么

### 1. Metadata

记录 contract 身份：

```text
contract_version:
source_agent: codex
target_executor: claude-code
project_root:
base_commit:
created_at:
```

这里最重要的是 `base_commit`。如果 Claude Code 执行时 HEAD 已经变化，就必须重新检查。

### 1.5 Phase 1 User Confirmations

contract 必须记录 Phase 1 的逐题确认。

```text
clarity_status: CONFIRMED_BY_USER
questions:
  - id:
    question:
    options:
    recommended_option:
    selected_option:
    recorded_value:
confirmed_by_user: true
```

如果用户还没有确认，只能生成草稿：

```text
status: DRAFT_PENDING_USER_CLARIFICATION
```

这种草稿不能进入 Codex Phase 3 PASS，也不能交给 Claude Code 执行。

### 2. Intent

记录用户真正想要什么：

```text
user_request:
desired_outcome:
non_goals:
assumptions:
```

`non_goals` 很重要。它防止 Claude Code 自己扩展范围。

### 3. Evidence

记录 Codex 看过什么：

```text
files_read:
commands_run:
existing_constraints:
risks_found:
```

这让 Claude Code 能判断 Codex 的计划是不是有证据，而不是凭空猜。

### 4. Plan

写清楚怎么做：

```text
approach:
expected_files:
directory_structure:
phase_docs:
verification:
```

对于这类文档任务，task 可以是：

```text
T1: 创建 codex/README.md，总览状态机和目录结构
T2: 创建 Phase 0-3 文档
T3: 创建 Claude Code 执行和 Codex audit 文档
T4: 创建 contract 模板
```

### 5. json:tasks

contract 末尾应该有结构化 tasks：

```json
[
  {
    "id": "T1",
    "prompt": "Create codex/README.md in Chinese. Explain the overall Codex planner -> Claude Code executor -> Codex auditor workflow. Do not create SKILL.md files.",
    "files": ["codex/README.md"],
    "complexity": "simple",
    "mutatesFiles": true,
    "verification": ["test -f codex/README.md"]
  }
]
```

每个 task 都必须 self-contained。也就是说，Claude Code 的 subagent 只看这个 task，也知道该怎么做。

### 6. Executor Instructions

明确告诉 Claude Code 怎么接手：

```text
1. Load project-workflow-claude.
2. Treat this contract as external plan input.
3. Do not re-plan from scratch.
4. Run Claude Review Gate against this contract.
5. If APPROVE, ask user approval before Phase 4.
6. If ITERATE or REJECT, stop and report.
7. After user approval, execute Phase 4-6.
8. Return structured result for Codex final audit.
```

## contract 应该放哪里

有两个位置：

```text
codex/templates/cross-agent-plan-contract.md
  长期模板，给人看和复用

.claude/plans/<timestamp>-codex-contract-<slug>.md
  某一次任务真正交给 Claude Code 执行的 contract
```

本目录里的模板不是执行文件。真正执行时，要从模板生成具体 contract，然后放到 `.claude/plans/`。

## 进入下一阶段的条件

只有满足下面条件，才能进入 Phase 3：

- contract 有 metadata
- contract 有 base_commit
- Phase 1 有用户确认记录
- goal / non-goals / assumptions 清楚
- expected_files 清楚
- 每个 task 有 files、prompt、verification
- executor instructions 清楚
- 有失败时的停机条件

## 会怎么样

Phase 2 完成后，Codex 不应该直接把任务丢给 Claude Code。

正确状态是：

```text
contract 已经写好，但还没有证明它是好 contract。
接下来进入 Phase 3，由 Codex 先做 preflight 自检。
```
