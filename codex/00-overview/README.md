# 总览：Codex 与 Claude Code 的职责边界

## 为什么要分工

Codex 和 Claude Code 都能写代码，但这套流程不是为了让两个 agent 随机互相帮忙，而是为了把复杂任务拆成两个清晰角色：

```text
Codex = Planner + Auditor
Claude Code = Executor + Reviewer + Verifier
```

Codex 更适合在当前会话里做：

- 读项目结构
- 整理用户意图
- 明确不做什么
- 形成 contract
- 审查 Claude Code 最终结果

Claude Code 更适合用现有 `project-workflow-claude` 做：

- Review Gate 审查 contract
- Phase 4 subagents 实现
- Phase 5 review
- Phase 6 verify
- 输出结构化执行结果

## 这套流程解决什么问题

它主要解决 5 个问题：

1. Codex 计划不清楚，Claude Code 执行跑偏
2. Claude Code 直接实现，用户没有在执行前审 plan
3. 多 agent 之间靠聊天传话，丢失上下文
4. Claude Code 声称完成，但只完成了一部分
5. 任务结束后没有独立验收，质量不可控

所以核心不是“调用 Claude Code”这个动作，而是中间的 contract：

```text
Codex 写 contract
Claude Code 审 contract
用户批准执行
Claude Code 按 contract 做
Codex 按 contract 验收
```

## 阶段关系

Codex 的阶段 0 到阶段 3，不等于 Claude Code 的 Phase 0 到 Phase 3。

更准确地说：

```text
Codex Phase 0: Discovery
  对应 Claude Phase 0 / 0.3 的只读信息收集

Codex Phase 1: Clarify
  对应 Claude Phase 1 的需求澄清，但必须一题一题问用户并确认

Codex Phase 2: Contract
  对应 Claude Phase 2 的 plan，但输出格式更严格

Codex Phase 3: Preflight
  是 Claude Review Gate 之前的 contract 自检

Claude Code Review Gate:
  仍然要运行 contract review，不能跳过

Claude Code Phase 4-6:
  真正执行、review、verify

Codex Phase 5:
  独立 final audit
```

## 成功标准

整个流程成功，不是看 agent 有没有说“完成了”，而是看证据：

- contract 是否有 base commit
- contract 是否有清楚的 goal / non-goals / assumptions
- Phase 1 是否有用户确认记录
- 每个 task 是否 self-contained
- Claude Code 是否跑了 Review Gate 和 Phase 4-6
- 用户是否批准过执行
- git diff 是否在 contract 允许范围内
- 验证命令是否真的跑过
- Codex final audit 是否 PASS

如果这些证据缺失，状态只能是 `PASS_WITH_RISK` 或 `FAIL`，不能是 `DONE`。
