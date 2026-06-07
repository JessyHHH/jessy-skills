# Phase 1：Clarify 澄清需求

## 目标

Phase 1 的目标是把用户的想法变成清楚的边界。

用户可能会说：

```text
我要 Codex 目录
我要写每个阶段怎么做
我要后续调用 Claude Code
不要先写成 skill
```

Codex 要把这些转成可执行约束：

```text
要新增中文文档
要按阶段拆目录
不修改 skills
不实现自动调用脚本
先解释阶段方法论
```

## Codex 应该澄清什么

### 1. 目标

Codex 要确认最终想得到什么。

例如：

```text
目标：在根目录新增 codex/，用中文文档说明 Codex Phase 0-3 如何工作，以及如何把 contract 交给 Claude Code 执行。
```

### 2. 边界

Codex 要明确这次不做什么。

本阶段建议的 non-goals：

```text
不修改 skills/project-workflow-claude/SKILL.md
不修改 install.sh
不修改 SETUP.md
不安装插件
不真实调用 Claude Code
不生成一次性任务 contract
不把文档写成 Codex skill
```

### 3. 读者

这个文档的读者不是 agent，而是用户本人。

所以写法应该是：

```text
中文
解释为什么
解释每一步做什么
解释做完会怎样
解释失败时停在哪里
```

不应该写成：

```text
Tool(...)
Agent(...)
Workflow(...)
```

除非是在说明未来怎么调用。

### 4. 成功标准

Phase 1 要定义验收标准：

```text
codex/ 目录存在
每个阶段有独立子目录
每个子目录有 README.md
Phase 0-3 都详细说明
后续 Claude Code 执行也有独立说明
包含 contract 模板
不新增 SKILL.md
不触碰现有 workflow 实现
```

## 产出

Phase 1 的产出是一份 clarity packet：

```text
Clarity Packet
- goal:
- audience:
- in_scope:
- out_of_scope:
- expected_files:
- success_criteria:
- user_approval_needed:
```

## 进入下一阶段的条件

只有满足下面条件，才能进入 Phase 2：

- 目标一句话能说清楚
- in-scope 和 out-of-scope 都清楚
- 文档结构已经确定
- 用户没有要求先实现自动化
- 成功标准可验证

## 会怎么样

Phase 1 完成后，Codex 应该能说：

```text
我知道这次只是在 codex/ 写中文阶段说明。
我不会改 skills，也不会改 setup/install。
接下来我会把这些边界写成 contract。
```

