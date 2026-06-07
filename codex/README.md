# Codex 调用 Claude Code 工作流说明

这个目录不是 Codex skill，也不是 Claude Code skill。它是给人看的中文设计文档，用来说明：

- Codex 在阶段 0 到阶段 3 应该怎么做
- Codex 产出的 contract 应该长什么样
- Claude Code 如何接收 contract 并执行 Phase 3 到 Phase 6
- Claude Code 完成后 Codex 还要怎么验收

核心思想：

```text
Codex 负责想清楚、写清楚、交接清楚。
Claude Code 负责审查 contract、执行实现、review、verify。
Codex 最后再独立验收，不能只相信 Claude Code 的完成声明。
```

这不是“Codex 硬编码调用 Claude workflow 的每一步”。更稳的做法是：

```text
User 需求
  ↓
Codex Phase 0: Discovery
  ↓
Codex Phase 1: Clarify (one question at a time)
  ↓
Codex Phase 2: Plan Contract
  ↓
Codex Phase 3: Contract Preflight
  ↓
Claude Code: Review Gate
  ↓
Codex Phase 3.5: Replan / Contract Revision
  ↓
Claude Code: Phase 4-6 Execution
  ↓
Codex Phase 5: Final Audit
  ↓
DONE / REWORK
```

## 文档结构

```text
codex/
├── 00-overview/
│   └── README.md
├── phase-0-discovery/
│   └── README.md
├── phase-0-3-skill-design/
│   └── README.md
├── phase-1-clarify/
│   └── README.md
├── phase-2-contract/
│   └── README.md
├── phase-3-preflight/
│   └── README.md
├── phase-3-review-replan/
│   └── README.md
├── phase-4-claude-execution/
│   └── README.md
├── phase-5-codex-audit/
│   └── README.md
├── validation/
│   └── README.md
├── skill-routing/
│   └── README.md
└── templates/
    └── cross-agent-plan-contract.md
```

## 状态机

整个流程应该按状态推进：

```text
REQUEST_RECEIVED
DISCOVERY_DONE
WAITING_FOR_USER_CLARIFICATION
CLARITY_CONFIRMED_BY_USER
CONTRACT_DRAFTED
CODEX_CONTRACT_PREFLIGHT_PASSED
CLAUDE_REVIEW_GATE_STARTED
CLAUDE_REVIEW_GATE_APPROVED
CODEX_REPLAN_DONE
CONTRACT_APPROVED_FOR_EXECUTION
USER_APPROVED_EXECUTION
CLAUDE_PHASE4_DONE
CLAUDE_PHASE5_PASSED
CLAUDE_PHASE6_PASSED
CODEX_AUDIT_PASSED
DONE
```

如果任何状态缺少证据，不能跳到后面的状态。例如：

- Phase 1 没有用户确认，contract 只能是 DRAFT_PENDING_USER_CLARIFICATION
- 没有 Codex contract preflight 结果，不能交给 Claude Code
- Claude Review Gate 没有结构化 review，Codex 不能 replan
- Codex 没有判断 Claude review 建议是否采纳，不能进入 Phase 4
- contract 没有最终 APPROVE，不能进入 Phase 4
- 用户没有批准执行，Claude Code 不能改文件
- Claude Phase 6 没有通过，Codex 不能宣布完成
- Codex 没有 final audit，整个流程不能算 DONE

## 谁负责验证

用户不需要人工监督每一步。默认责任划分是：

```text
Codex:
  负责验证流程有没有按状态机走完
  负责 Phase 1 逐题澄清，并记录用户选择
  负责判断 Claude Review Gate 的建议是否值得采纳
  负责生成 contract 新版本
  负责最终 audit

Claude Code:
  负责 Review Gate 审 contract
  负责 Phase 4-6 执行、review、verify
  负责返回结构化证据

User:
  只负责关键授权
  特别是是否批准进入会改文件的执行阶段
```

如果用户提前授权某个小范围任务自动执行，Codex 仍然必须保留证据链，不能因为用户不监督就跳过审核。

## 文件放置原则

建议区分三类文件：

```text
codex/
  人类可读的方法论、阶段说明、模板

.codex/
  Codex 运行时生成的本项目 context、plans、audit 记录

.claude/plans/
  交给 Claude Code 执行的具体 contract 文件
```

也就是说：

- `codex/` 是长期文档资产
- `.codex/` 是 Codex 自己的运行记录
- `.claude/plans/` 是 Claude Code 要执行的交接文件

contract 是给 Claude Code 消费的，所以最终执行版应该放在 `.claude/plans/`，而不是只放在 `codex/`。

## Skills 根目录

Codex 和 Claude Code 应该共用根目录 `skills/`：

```text
skills/
  project-workflow-codex/
  project-workflow-claude/
  go/
  vue/
  methodology/
```

Codex 本项目通过 symlink 发现：

```text
.agents/skills -> ../skills
```

全局安装后，Codex 通过：

```text
~/.agents/skills/jessy-skills -> <repo>/skills
```

Claude Code 通过：

```text
~/.claude/skills/<skill> -> <repo>/skills/<skill>
```

这样 contract 里的 skill routing 可以同时推荐 Codex planner skills 和 Claude executor skills，而不需要维护两套 skill 目录。
