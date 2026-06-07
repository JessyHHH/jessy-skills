# Phase 4：交给 Claude Code 执行

## 目标

这一阶段不是 Codex 自己实现，而是把已经通过 preflight 的 contract 交给 Claude Code。

Claude Code 的职责是：

```text
读取 contract
运行 Claude Review Gate
请求用户批准
执行 Phase 4 implementation
执行 Phase 5 review
执行 Phase 6 verify
输出结构化结果
```

## contract 如何交给 Claude Code

推荐路径：

```text
.claude/plans/<timestamp>-codex-contract-<slug>.md
```

原因：

- contract 是给 Claude Code 执行的输入
- 当前项目的 Claude workflow 已经围绕 `.claude/plans/` 工作
- 放在 `.claude/plans/` 比放在 `.codex/` 更容易被 Claude Code 接管

默认不要求用户切换到 Claude Code CLI。Codex 应该在当前会话里调用 Claude Code headless：

```text
cd <project_root>
claude -p --output-format=stream-json "<review-or-execution-prompt>"
```

Phase 3 时，Codex 调 Claude Code 只做 Review Gate：

```text
加载 project-workflow-claude 和 karpathy-guidelines。
读取 .claude/plans/<contract>.md。
把它当作 Codex 的 Cross-Agent Plan Contract。
只运行 Claude Review Gate。
优先使用 Workflow(name='phase3-consensus')。
不要实现，不要进入 Phase 4。
返回结构化 review。
```

Phase 4-6 时，必须先满足执行 gate，然后 Codex 再调用 Claude Code：

```text
加载 project-workflow-claude 和 karpathy-guidelines。
读取已批准 contract。
不要重新规划。
使用 Workflow(name='phase4-implement') 执行。
使用 Workflow(name='phase5-review') 审查。
使用 Workflow(name='phase6-verify') 验证。
返回结构化结果给 Codex final audit。
```

不要使用 `--bare` 运行这些命令，因为 `--bare` 会关闭 skill 目录扫描、hooks、plugin sync 等能力，可能让 `project-workflow-claude` 和 Workflow 脚本不可用。

如果 `claude` CLI 不存在、版本过低、或 headless 调用失败，Codex 才把手动交接作为 fallback：

```text
请读取 .claude/plans/<contract>.md。
加载 project-workflow-claude。
先只运行 Claude Review Gate。
```

## Claude Code 接手后的流程

### 1. Contract Intake

Claude Code 首先只读 contract，不改文件。

它要确认：

```text
contract 是否完整
base_commit 是否匹配
json:tasks 是否能解析
expected_files 是否合理
forbidden_changes 是否清楚
```

如果发现 contract 不完整，Claude Code 应该停止并报告 `ITERATE`。

### 2. Claude Review Gate

Claude Code 运行自己的 contract review gate。

它要审查：

```text
计划是否合理
范围是否清楚
任务是否可执行
验证是否充分
有没有遗漏风险
```

可能结果：

```text
APPROVE
  可以进入用户批准 gate

ITERATE
  contract 需要修改，返回 Codex 或用户

REJECT
  contract 方向错误，不能执行
```

### 3. 用户批准 gate

即使 Claude Code Review Gate APPROVE，也不能直接改文件。

必须问用户：

```text
Claude Review Gate 已通过。是否批准进入 Phase 4 执行？
```

用户批准后，Codex 才可以调用 Claude Code 执行 Phase 4-6。

### 4. Phase 4 Implementation

Claude Code 按 contract 里的 `json:tasks` 执行。

默认通过 `project-workflow-claude` 的 Workflow 脚本执行：

```text
Workflow(name='phase4-implement')
```

要求：

```text
每个 task 独立执行
每个 task 只改允许文件
每个 task 做 self-review
遇到 BLOCKED 要停止报告
```

不能：

```text
重新发明计划
擅自扩大 changed files
跳过 task 自检
```

### 5. Phase 5 Review

Claude Code 审查执行结果。

默认通过：

```text
Workflow(name='phase5-review')
```

至少看：

```text
是否满足 contract
是否违反 forbidden changes
是否有明显错误
是否有过度实现
是否有遗漏 task
```

### 6. Phase 6 Verify

Claude Code 运行验证。

默认通过：

```text
Workflow(name='phase6-verify')
```

对于文档任务，可能是：

```text
find codex -maxdepth 2 -type f -name README.md
git diff --check
检查没有新增 SKILL.md
检查每个阶段文档都存在
```

对于代码任务，还要运行项目测试。

## Claude Code 必须返回什么

Claude Code 完成后，要返回结构化结果：

```text
claude_result:
  contract_path:
  base_commit:
  final_commit_or_head:
  claude_review_gate_verdict:
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

## 会怎么样

Claude Code 完成后，流程还没结束。

正确状态是：

```text
Claude Code 已经执行并验证。
但 Codex 还必须独立读取 diff 和验证结果。
只有 Codex final audit 通过，整个任务才算 DONE。
```
