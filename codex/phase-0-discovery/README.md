# Phase 0：Discovery 项目发现

## 目标

Phase 0 的目标是让 Codex 在不改文件的情况下理解项目现状。

这一阶段只做事实收集，不做方案承诺，不做实现，不写代码。

Codex 要回答这些问题：

- 这是一个什么类型的项目
- 当前在哪个 git 分支
- 当前工作区是否干净
- 用户已有未提交改动有哪些
- 哪些文件和当前需求相关
- Claude Code workflow 的入口在哪里
- 项目里已有的 setup、README、AGENTS、CLAUDE 约定是什么

## Codex 应该做什么

### 1. 检查 git 状态

Codex 应该读取：

```bash
git branch --show-current
git status --short
git rev-parse HEAD
```

然后记录：

```text
current_branch:
base_commit:
dirty_files:
untracked_files:
```

如果工作区有未提交改动，Codex 必须把它们当作用户已有工作，不能回滚。

### 2. 检查项目结构

Codex 应该用 `rg --files` 或类似方式看：

```text
README.md
SETUP.md
install.sh
AGENTS.md
CLAUDE.md
skills/project-workflow-claude/SKILL.md
.claude/workflows/
.agents/skills/
```

重点不是全量读完，而是确认和当前任务相关的入口。

### 3. 识别平台能力

Codex 要确认当前项目已有的平台：

```text
Hermes:
  skills/project-workflow

Claude Code:
  skills/project-workflow-claude
  .claude/workflows/phase3-consensus.js
  .claude/workflows/phase4-implement.js
  .claude/workflows/phase5-review.js
  .claude/workflows/phase6-verify.js

Codex:
  AGENTS.md
  .agents/skills/
  待新增 codex/ 文档目录
```

### 4. 识别风险

Phase 0 必须记录风险，例如：

- 当前工作区已经脏，不能随便切分支或覆盖文件
- `.agents/skills/project-workflow-claude` 可能是临时复制版，命名不稳定
- `project-workflow-claude` 是 Claude Code 的执行核心，Codex 不应该直接大改
- contract 应该最终放到 `.claude/plans/`，否则 Claude Code 不一定会读取

## 产出

Phase 0 的产出不是最终方案，而是一份 discovery packet。

建议结构：

```text
Discovery Packet
- project_root:
- current_branch:
- base_commit:
- dirty_state:
- relevant_files_read:
- existing_platforms:
- claude_workflow_entrypoints:
- setup_install_entrypoints:
- risks:
- open_questions:
```

## 进入下一阶段的条件

只有满足下面条件，才能进入 Phase 1：

- 已确认项目根目录
- 已确认 git 状态
- 已确认当前用户改动不能被回滚
- 已找到 Claude Code workflow 入口
- 已知道本次需求涉及哪些文档或目录

## 会怎么样

Phase 0 完成后，Codex 不应该说“我知道怎么改了，马上改”。正确状态是：

```text
我已经知道当前项目有什么、哪里可能受影响、哪些东西不能碰。
接下来进入 Phase 1，把用户真正想要的边界问清楚。
```

