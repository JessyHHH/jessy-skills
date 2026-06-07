# Phase 1：Clarify 澄清需求

## 目标

Phase 1 的目标是把用户的想法变成清楚的边界。

这一阶段不是 Codex 自己脑补答案，而是像 `obra/superpowers` 的 brainstorming 一样：先理解项目，再一题一题追问，直到需求边界被用户确认。

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

Phase 1 必须覆盖这些维度：

```text
goal
scope_boundary
architecture_or_layout_choices
constraints_and_non_goals
acceptance_criteria
execution_approval_boundary
```

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

## 提问规则：一次只问一个 ABCD 问题

Phase 1 的核心规则：

```text
每次只问一个问题
优先使用 A/B/C/D
A 默认放 Codex 推荐选项，并标注 Recommended
每个选项只解释一个取舍
用户回答后，Codex 记录进 clarity packet
没有用户确认，不允许进入 Phase 2 ready contract
```

这意味着 Codex 不应该一次甩出五六个问题，也不应该说“我默认都选推荐项然后继续”。

### 问题格式

建议格式：

```text
Phase 1 / Q1: 你希望这次重构采用哪种顶层目录边界？

A. backend/ + frontend/（Recommended）
   最直接符合“一个后端一个前端”，迁移成本低。
B. services/ + apps/
   更像 monorepo，但会扩大命名和文档调整范围。
C. backend-api/ + backend-renderer/ + frontend/
   更早暴露微服务边界，但这次移动量更大。
D. 先不移动目录，只生成 contract
   最保守，但不能验证目录重构方案。

请选择 A/B/C/D；如果都不合适，也可以直接写你的答案。
```

用户回答后，Codex 应该只确认这一题的记录，然后进入下一题：

```text
已记录：top_level_layout = backend/ + frontend/
下一题只问架构拆分边界。
```

### 推荐问题顺序

不要机械照抄，但通常按这个顺序最稳：

```text
Q1: 最终目标和本次是否只做 planning/contract，还是允许执行改文件？
Q2: 顶层目录边界是什么？
Q3: 后端内部是否只整理目录，还是要设计微服务边界？
Q4: 哪些文件或目录绝对不能动？
Q5: 成功标准是什么，哪些命令或检查算通过？
Q6: Phase 2 contract 是否可以生成 ready 版？
```

每次只问其中一个。用户没有回答前，不进入下一题。

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
- user_confirmations:
  - question:
    selected_option:
    recorded_value:
```

## 进入下一阶段的条件

只有满足下面条件，才能进入 Phase 2：

- 目标一句话能说清楚
- in-scope 和 out-of-scope 都清楚
- 文档结构已经确定
- 用户没有要求先实现自动化
- 成功标准可验证
- 用户已经确认 clarity packet

## 会怎么样

Phase 1 完成后，Codex 应该能说：

```text
我知道这次只是在 codex/ 写中文阶段说明。
我不会改 skills，也不会改 setup/install。
接下来我会把这些边界写成 contract。
```

如果用户还没有确认，Codex 应该停在：

```text
Phase: 1
Status: WAITING_FOR_USER_CONFIRMATION
Evidence:
  - 已完成 Discovery
  - 已提出 Q<n>
Next allowed state:
  - 等待用户选择 A/B/C/D
```

此时即使 Codex 已经能猜到答案，也不能把 Phase 1 标记为 complete。
