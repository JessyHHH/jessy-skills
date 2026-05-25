---
name: strategic-thinking
description: "思维模式切换框架。4 种模式：Zoom-Out（提升抽象看全景）、Grill（苏格拉底式追问设计）、Handoff（压缩上下文移交）、Caveman（极简通信省 token）。Agent 根据用户消息自动匹配模式，有明确决策树和默认出口（正常模式）。触发词：'zoom out', 'grill', 'handoff', 'caveman', '全景', '压力测试', '交接', '省 token', 'brief', '怎么放', '设计有问题', '这个方案'。"
version: "1.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [thinking, modes, zoom-out, grill, handoff, caveman]
    auto_load: false
    absorbs: [zoom-out, grill-me, grill-with-docs, handoff, caveman]
---

# Strategic Thinking — 思维模式切换框架

**核心理念：** 这不是"学一个新命令"，而是"知道什么时候切换什么思维模式"。

Agent 大多数时候在**正常模式**下按 project-workflow 走。只有用户明确触发（或 Agent 高度怀疑需要）时才进入特殊模式。

---

## 什么时候跑决策树

| 跑 | 不跑 |
|----|------|
| 用户消息包含触发词 | "这个变量名改成 `userCount`" |
| 用户消息像设计/计划/移交/全景请求但用非标准措辞 | "跑一下 go test" |
| | "为什么这个函数返回 nil" |

---

## 模式判断决策树

```
用户消息
  │
  ├── 匹配 "caveman" / "省 token" / "brief" / "精简"？
  │   └── YES → Caveman 模式（持久）
  │
  ├── 匹配 "zoom out" / "全景" / "big picture" / "怎么放" / "在哪"？
  │   └── YES → Zoom-Out 模式（单次）
  │
  ├── 匹配 "grill" / "压力测试" / "方案行不行" / "这个设计" / "这个计划"？
  │   └── YES → Grill 模式
  │        └── 检查项目有无 CONTEXT.md 或 docs/adr/
  │             ├── 有 → Grill (with-docs)
  │             └── 无 → Grill (basic)
  │
  ├── 匹配 "handoff" / "交接" / "换 agent" / "移交"？
  │   └── YES → Handoff 模式（单次，终结性）
  │
  └── NO MATCH
        │
        ├── Agent 怀疑用户可能需要某种模式但措辞模糊？
        │   └── YES → 一次性列出 4 个选项：
        │        "你想让我切换哪种模式？
        │         1. zoom-out — 往上抽象一层，看模块全景
        │         2. grill — 苏格拉底式追问你的设计
        │         3. handoff — 压缩上下文发给下一个 agent
        │         4. caveman — 极简模式，砍 75% token
        │         如果没有，我就继续正常流程。"
        │
        └── Agent 确定只是一般性对话？
            └── YES → 正常模式。不激活任何子模式。
```

---

## 模式互斥规则

| 场景 | 规则 |
|------|------|
| 多个触发词同时命中 | Caveman > Zoom-Out > Grill > Handoff |
| Caveman 激活时进入其他模式 | 暂停 Caveman，退出其他模式后恢复 |
| Grill 期间不能同时 Zoom-Out | 目的相反（深入追问 vs 拉高抽象） |
| Handoff 激活 | 终结性：执行后当前话题结束 |

---

## 模式 1: Zoom-Out（提升抽象层次）

**何时用：** 你不熟悉这段代码领域，需要理解它在更大图景中的位置。

**行为：**
- 不深入代码实现细节
- 画出相关模块和调用者的地图
- 使用项目的领域词汇表（CONTEXT.md 中定义的术语，如果有的话）
- 指出"这个模块是 X 领域的一部分，被 Y 调用，依赖 Z"
- 用 Mermaid 图或其他可视化方式呈现关系

**输出格式：**
```
模块全景：
├── 入口层：<谁调用这个模块>
├── 核心层：<模块本身做什么>
├── 依赖层：<这个模块依赖什么>
└── 影响层：<这个模块的修改影响谁>
```

**退出条件：** 用户说 "got it" / "明白了" / "够了" 或开始讨论具体实现。

---

## 模式 2: Grill（苏格拉底式追问）

**何时用：** 用户提出了设计、计划、方案，需要压力测试。

### 子模式选择

- **Grill (basic)**：项目无 CONTEXT.md 或 docs/adr/
- **Grill (with-docs)**：项目有 CONTEXT.md 或 docs/adr/

### 通用行为（两种子模式共用）

- 逐个决策树分支追问，一次一个问题
- 每个问题给出推荐答案
- 等用户反馈后再继续下一个问题
- 优先探索代码而非追问（如果问题能通过读代码回答）

### Grill (basic) 追问框架

```
决策树结构：
1. 边界：涉及/不涉及哪些模块？
2. 数据：数据怎么流转？状态在哪？
3. 错误：失败模式有哪些？怎么处理？
4. 测试：怎么验证？成功标准是什么？
5. 风险：最可能出问题的地方？
```

### Grill (with-docs) 额外行为

**领域文档意识：**

1. **检查术语一致性：** 当用户使用的术语与 CONTEXT.md 冲突时，立即指出。
   > "你的 CONTEXT.md 定义了 'cancellation' 为 X，但你似乎说的是 Y——到底是哪个？"

2. **精准化模糊语言：** 当用户用模糊或重载的术语时，提出精确术语。
   > "你说 'account'——是指 Customer 还是 User？这是两个不同的概念。"

3. **用场景压力测试：** 发明场景来探测边界情况。
   > "假设一个订单同时被两个用户取消——你的方案怎么处理？"

4. **代码交叉验证：** 当用户陈述某个行为时，检查代码是否一致。
   > "你的代码对整个 Order 做取消，但你刚说支持部分取消——哪个是对的？"

5. **即时更新 CONTEXT.md：** 术语确定后立刻更新，不攒到后面批量改。

6. **ADR 创建条件（三条全满足才创建）：**
   - 难以逆转 — 改主意的代价有意义
   - 无上下文会令人惊讶 — 未来读者会疑惑"为什么这么做"
   - 真正权衡的结果 — 有真正的替代方案，选了其中一个
   - 三条缺一就不创建

**文件结构参考：**
```
/
├── CONTEXT.md              ← 领域术语表
├── CONTEXT-MAP.md          ← 多上下文时指向各 CONTEXT.md
├── docs/
│   └── adr/                ← 架构决策记录
│       ├── 0001-xxx.md
│       └── 0002-xxx.md
└── src/
    └── <domain>/
        ├── CONTEXT.md
        └── docs/adr/
```

**退出条件：** 所有决策分支解决，或用户说 "开始" / "够了" / "执行"。

---

## 模式 3: Handoff（上下文压缩移交）

**何时用：** 对话上下文太长，想换个 Agent 继续。或显式说 "handoff"。

**行为：**
- 生成压缩交接文档
- 保存到 `mktemp -t handoff-XXXXXX.md`
- 不重复已有制品的内容（PRD、plan、ADR、issue、commit、diff）——引用路径或 URL
- 推荐下一个 Agent 应加载的 skills
- 如果用户给了参数（如 "下一个 session 做 X"），以此为焦点定制文档

**输出格式：**
```markdown
# Handoff: <topic>

## Current State
<2-3 句话概括当前进度>

## Key Decisions
<已做的关键决策>

## Next Steps
<下一步要做什么>

## References
- Plan: .hermes/plans/xxx.md
- Spec: .hermes/specs/xxx.md
- Issue: #123

## Recommended Skills
<下一个 agent 应加载的 skills>
```

**退出条件：** 文档生成完毕，当前话题结束。

---

## 模式 4: Caveman（极简通信）

**何时用：** 用户说 "caveman" / "省 token" / "brief" / "精简"。

**行为规则：**
- 砍掉：冠词(a/an/the)、填充词(just/really/basically/actually)、客套话(sure/certainly/of course)、hedging
- 允许：碎片句、短同义词(big 不用 extensive)、缩写(DB/auth/config/req/res/fn/impl)
- 保留：技术术语原样、代码块不变、错误消息原样引用
- 用箭头表因果：X -> Y
- 一个词够用就不多说

**模式：** `[事物] [动作] [原因]. [下一步].`

**对比：**
> ❌ "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
>
> ✓ "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

**更多示例：**
> 问："Why React component re-render?"
>
> ✓ "Inline obj prop -> new ref -> re-render. `useMemo`."

> 问："Explain database connection pooling."
>
> ✓ "Pool = reuse DB conn. Skip handshake -> fast under load."

### 持久性

**一旦激活，持续生效**直到用户说 "stop caveman" / "normal mode" / "正常模式"。
不因多轮对话而自动退出。不确定时仍保持 caveman。

### 自动退出例外（暂时退出 caveman 说完后退回）

| 场景 | 行为 |
|------|------|
| 安全警告 | 用完整句子说明风险 |
| 不可逆操作确认 | 用完整句子要求确认 |
| 多步序列可能因碎片顺序误读 | 用完整句子列出步骤 |
| 用户说 "没懂" / "clarify" / 重复问题 | 用完整句子解释，然后退回 |

**示例——危险操作：**
> **Warning:** This will permanently delete all rows in the `users` table and cannot be undone.
>
> ```sql
> DROP TABLE users;
> ```
>
> Caveman resume. Verify backup exist first.

### 退出条件

用户说 "stop caveman" / "normal mode" / "正常模式"。

---

## Pitfalls

- ❌ **每条消息都跑决策树** — 只在匹配触发词或可疑时才跑
- ❌ **同时进入两个互斥模式** — Grill 和 Zoom-Out 不能同时
- ❌ **Grill 时一次问多个问题** — 一次一个问题，等用户反馈
- ❌ **Handoff 重复写已有制品内容** — 引用路径，不复制
- ❌ **Caveman 砍掉技术术语** — 技术术语和代码块必须完整保留
- ❌ **不确定模式时逐轮猜测用户意图** — 一次性列出 4 个选项
- ❌ **在一般对话中强行插入模式判断** — "改个变量名"不需要问模式
