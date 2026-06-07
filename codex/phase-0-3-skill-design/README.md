# Codex Phase 0-3 如何抽象成 Skill

## 目标

`codex/` 里的文档是方法论说明，最终可执行的 Codex 工作流应该沉淀成：

```text
skills/project-workflow-codex/SKILL.md
```

这个 skill 不是 Claude Code workflow 的复制品。它的职责是：

```text
Codex 负责 Phase 0-3 的发现、澄清、contract 生成、contract 自检。
Claude Code 负责 Review Gate 审核和 Phase 4-6 执行。
Codex 再负责 review triage、replan 和 final audit。
```

## 为什么要写成 skill

写成 skill 后，Codex 可以在任意项目复用同一套流程：

```text
发现项目事实
生成 AGENTS.md / knowledge
匹配 Codex planner skills
推荐 Claude executor skills
生成 Cross-Agent Plan Contract
调用 Claude Review Gate
根据 review 重新计划
最终验收 Claude 执行结果
```

如果只靠 prompt，每次都要重复讲规则；写成 skill 后，Codex 能通过 `$project-workflow-codex` 或隐式匹配加载流程。

## Skill 的边界

`project-workflow-codex` 只做这些事：

```text
Phase 0: Discovery
Phase 0.3: Knowledge + AGENTS.md Bootstrap
Phase 0.5: Skill Routing
Phase 1: Clarify one question at a time
Phase 2: Contract v1
Phase 3: Codex Preflight
Phase 3.5: Claude Review Gate Triage + Replan
Final Audit: Codex 验收
```

它不做：

```text
不替 Claude Code 执行 Phase 4-6
不跳过 Claude Code Review Gate
不绕过用户执行批准
不把一次性任务 contract 写进 skill
不把 Claude workflow 复制成 Codex workflow
```

## Phase 0.3 和 AGENTS.md

`AGENTS.md` 是 Codex 官方的项目说明入口。Codex 会在新 run / 新 TUI session 开始时读取它。

所以 Phase 0.3 应该做：

```text
1. 生成或刷新 .codex/context/knowledge.md
2. 检查根目录 AGENTS.md
3. 如果不存在，生成简洁 AGENTS.md
4. 如果存在，只更新 AUTO block
5. 当前 session 立即读取 AGENTS.md
6. 说明新 AGENTS.md 对下一次 Codex session 自动生效
```

注意：当前 session 生成 `AGENTS.md` 后，不应假设 Codex 系统自动重新加载。skill 必须显式读取刚写出的文件。

## Skill 的文件结构

建议：

```text
skills/project-workflow-codex/
├── SKILL.md
└── references/
    ├── contract-first-workflow.md
    ├── skill-routing.md
    └── validation.md
```

`SKILL.md` 只放核心步骤和硬门槛。更长的说明继续留在 `codex/` 或 references 中，按需读取。

## 和 Claude Code Skill 的关系

两边应该共享根目录 `skills/`：

```text
skills/
  project-workflow-codex/
  project-workflow-claude/
  go/
  vue/
  methodology/
```

Codex 通过 `.agents/skills -> ../skills` symlink 发现同一套 skills。

Claude Code 通过安装脚本把 `skills/` 链接到 `~/.claude/skills`。

这样 skill routing 不需要维护两套目录，也不会出现 Codex 和 Claude Code 使用不同版本的 domain skills。
