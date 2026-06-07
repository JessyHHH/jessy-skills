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

如果使用 Codex 中的 Claude Code 插件，可以用类似方式：

```text
$cc:rescue --background --prompt-file .claude/plans/<contract>.md
```

如果没有插件，也可以人工把 contract 文件路径交给 Claude Code：

```text
请读取 .claude/plans/<contract>.md。
加载 project-workflow-claude。
把它当作 Cross-Agent Plan Contract 处理。
先运行 Claude Review Gate。
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

用户批准后才可以执行。

### 4. Phase 4 Implementation

Claude Code 按 contract 里的 `json:tasks` 执行。

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
