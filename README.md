# jessy-skills — Multi-Language AI Engineering Skills

![Version](https://img.shields.io/badge/version-v2.8-blue)

一个支持 [Claude Code](https://code.claude.com/) + [Hermes Agent](https://github.com/NousResearch/hermes-agent) + Codex 的多语言工作流技能集合。模块化流水线 — Claude Code 使用 Workflow+Skills，Codex 使用 Codex agents+Skills（含 HARD-GATE / Iron Law / Two-Stage Review），85 个技能覆盖 Go/Vue/前端/工程/方法论全流程。

**v2.8.1 修复：**
- **Codex skill 加载修复**: 修复 `reviewing-implementation`、`context7-docs`、`firecrawl-web` 的 YAML frontmatter，避免 Codex 启动时跳过加载。
- **Skill frontmatter 收敛**: 新增/更新的 Codex skill frontmatter 优先只保留 `name` 和 `description`；详细版本、作者、平台信息放正文或引用文件。
- **Codex 原生 agents 模型路由**: 仓库托管 `codex/agents/*.toml`，安装到 `~/.codex/agents`；执行/测试/修复类 agent 使用 `gpt-5.3-codex`，审查/计划验证类 agent 使用 `gpt-5.4-mini`，不依赖 hooks/OMX/oh-my-codex。
- **Codex/Hermes 边界澄清**: Codex 主入口是 `project-workflow-codex`，Hermes 主入口是 `project-workflow`；Codex 共享同一 `skills/` 仓库和 domain skills，但不自动运行 Hermes workflow。

**v2.8 新特性：**
- **Workflow 精简**: 只保留 4 个活跃 Workflow 脚本（phase3-consensus / phase4-implement / phase5-review / phase6-verify），Phase 0-2 使用 Skill+Agent 直接执行（无 Harness 开销）
- **Phase 4 任务完成保证**: Stage 4 Completion Guarantee — 未完成任务自动重试（最多3轮），STUCK 任务明确返回原因
- **阶段边界状态验证**: 7 个执行技能统一添加 Step 0 状态验证，`planning-implementation` 启动 skip-design 入口守卫
- **错误硬化**: Edit Tool 安全规则 + Workflow Plain-JS 守卫 + Phase4 context enrichment 对齐 + 状态优雅降级 + 回归探针
- **Codex agents 分支**: 新增 `project-workflow-codex`，用 Codex executor/reviewer/verifier agents 替代 Claude Code `Workflow(...)` 脚本执行
- **install.sh 安全**: 先覆盖同步平台快照 `~/.jessy-skills-claude` / `~/.jessy-skills-codex`，再从快照软链接到 `~/.claude/skills/` 和 `~/.agents/skills/`；Codex agent 模板复制到 `~/.codex/agents/`，不覆盖外部插件 skill（superpowers/omc 等）或用户自定义 agent

**v2.4 新特性：**
- **全面移除 Opus**: 所有 Workflow subagent 使用 Sonnet/Haiku，复杂任务不再使用 Opus，大幅降低成本
- **Phase 7.3 可选启动**: 后台记忆压缩定时任务改为 opt-in（默认跳过），不再自动创建 durable cron job
- **模型显式声明**: 4 个 Workflow 脚本的 17 个 subagent 全部显式指定 model 参数，不再隐式继承主会话模型

**v2.3 新特性：**
- **Phase 1 Hard Grill Checklist**: 6 项强制自查清单（PASS/FAIL），退出前必须逐条确认，杜绝"0 问即过"
- **REQUIREMENT ECHO**: 需求回放确认步骤，在 Grill 前回显所有需求给用户确认
- **Phase 5 Layered Review**: 4 层复杂度门控审阅 — 简单任务跳过，中等仅正确性检查（1 agent），复杂全量（3 agents），预计节省 50-60% token
- **Phase 4.6 Quick Gate**: Phase 4 和 5 之间的 fail-fast 快速门（git diff + grep expectedEvidence/forbiddenEvidence）
- **Grill Evidence Persistence**: `.claude/state/grill-evidence.json` 持久化 Ambiguity Register + Assumption Ledger，下游 Phase 可审计

**v2.2 新特性：**
- **CONTEXT.md 双层上下文**：Knowledge Layer（机器管理）+ Instruction Layer（人工维护），`[confirmed]`/`[auto]` 证据标签，子目录就近覆盖
- **Phase 1 深度 Grill**：Ambiguity Register（模糊性登记表）+ Assumption Ledger（假设台账），可变深度退出条件，不再固定四问
- **Phase 0 Task Intake Snapshot**：在 Phase 0 就锁定 in/out scope，从源头防范围蔓延
- **Phase 4.5 Worktree Review**：harness-managed 隔离策略 + master agent merge-back
- **Phase 5/3 统一裁定**：`APPROVE`/`ITERATE`/`REJECT` 现在时跨 Phase 3 和 Phase 5 一致
- **Phase 6 语义证据**：`evidenceChecks`（master agent 预计算）+ 5 种证据类型

## 快速安装

**AI 自安装（推荐）：** 克隆后在 Claude Code 或 Hermes 里说 "读 SETUP.md 并安装"

**手动安装：**
```bash
git clone https://github.com/JessyHHH/jessy-skills.git
cd jessy-skills
bash install.sh          # 自动检测 Hermes / Claude Code / Codex
source ~/.bashrc         # Linux · macOS 用 ~/.zshrc

# 安装工具 CLI（一步）
npm install -g ctx7@latest firecrawl-cli@latest
ctx7 login && firecrawl login  # 浏览器授权
```

安装后：
- **Hermes** 每次启动自动加载 `project-workflow` + `karpathy-guidelines`
- **Claude Code** 每次启动自动加载 CLAUDE.md，`/reload-skills` 激活技能
- **Codex** 读取 AGENTS.md；通过 `~/.agents/skills/jessy-skills -> ~/.jessy-skills-codex/skills` 发现 Codex 快照 skills；通过 `~/.codex/agents/*.toml` 使用仓库托管的原生 agents，无需 hooks/OMX/oh-my-codex
- 自动识别 Go/Vue/Node/Skills Repository 项目

## 工作流概览

| Phase | Hermes (`project-workflow`) | Claude Code (`project-workflow-claude`) | Codex (`project-workflow-codex`) |
|-------|---------------------------|----------------------------------------|----------------------------------------|
| 0 | `search_files` 检测项目类型 | `Glob` + `Grep` 检测项目类型 + **Task Intake Snapshot** | 读 branch/status/HEAD/AGENTS.md |
| 0.3 | `delegate_task` 分析 → CONTEXT.md | `Agent` 分析 → **CONTEXT.md (两层) + contextSummary** | 生成 `.codex/context/knowledge.md` |
| 0.5 | `skill_view()` 加载技能 | `Skill()` 加载技能 | 路由 Codex skills + domain skills |
| 1 | `clarify()` 设计对话 ⚡ | `AskUserQuestion()` + **Hard Grill Checklist** ⚡ | 仅澄清无法推断的边界 |
| 2 | `write_file(.hermes/plans/)` | `Write(.claude/plans/)` + **扩展 task schema** | 写 `.codex/plans/*-codex-plan-*.md` |
| 3 | `skill_view(ralplan)` → delegate_task | **Workflow(phase3-consensus)** | Codex plan preflight |
| 4 | `delegate_task(tasks=[])` 并行 | **Workflow(phase4-implement)** | Codex executor/worker agents |
| 5 | `delegate_task` 审查 ⚡ | **Workflow(phase5-review)** | Codex code-reviewer/verifier agents |
| 6 | `terminal()` 验证 ⚡ | `Bash()` + **Workflow(phase6-verify)** | 主 Codex fresh verification + final audit |
| 7 | `memory()` + `cronjob()` | `CronCreate()` + 文件记忆 | Codex state/learning notes |
| 8 | 4-option 收尾菜单 ★ | 4-option 收尾菜单 ★ | 分支/提交/PR 由用户授权后执行 |

**出口可见性：** 每个 Phase 结束时输出 `Phase X complete. [skill] verified. → Phase Y`，Skill Expected 列在转换规则表中。

### Codex Agent 模型路由

`install.sh` 会把仓库内 `codex/agents/*.toml` 安装到 `~/.codex/agents/`。这些是 Codex 原生 agents，不依赖 hooks、OMX 或 oh-my-codex。

| Agent | 用途 | 模型 |
|-------|------|------|
| `executor`, `worker`, `test-engineer`, `build-fixer`, `debugger` | 执行、代码/文档修改、测试、构建修复、调试 | `gpt-5.3-codex` |
| `code-reviewer`, `verifier` | 代码审查、计划/完成度验证 | `gpt-5.4-mini` |

主 Codex 会话模型不由这些 agent 模板设置，建议在 `~/.codex/config.toml` 中配置为 `gpt-5.5`。

### project-workflow-claude v2.8 模块化架构
- **Modular Skill Orchestrator**: 1 个 thin orchestrator + 7 个独立 execution skills，每个 <500 行
- **Exit Contract**: 每个 execution skill 定义明确的入口/出口合同，上下游技能独立验证
- **Step 0 状态验证**: 7 个执行技能统一添加状态检查，`planning-implementation` 启动 skip-design 入口守卫
- **Hard Grill Checklist**: 6 项强制自查（PASS/FAIL），逐条确认才能退出 Phase 1
- **REQUIREMENT ECHO**: 需求回放确认步骤，在 Grill 前回显所有需求给用户确认
- **Phase 5 Layered Review**: 4 层复杂度门控 — 简单跳过→中等仅正确性→复杂全量，预计节省 50-60% token
- **Phase 4.6 Quick Gate**: fail-fast 快速门（git diff + grep expectedEvidence + grep forbiddenEvidence）
- **Phase 4 Completion Guarantee**: 未完成任务自动重试（最多 3 轮），STUCK 任务明确返回原因
- **Phase 4→5 上下文去重**: perTaskDiffs + fileContentsSnapshots，Phase 5 直接消费，消除磁盘重读
- **Phase 6 Loop Contract**: mandatoryNextAction 枚举 + totalIterations 追踪 + max 10 迭代硬上限 + EXHAUSTED 裁决
- **Grill Evidence Persistence**: `.claude/state/grill-evidence.json` 持久化，Phase 4.6/6 可审计
- **CONTEXT.md 双层上下文**: Knowledge Layer（架构/实体/接口）+ Instruction Layer（约定/命令/不变量），`[confirmed]`/`[auto]` 标签
- **Phase 1 深度 Grill**: Ambiguity Register + Assumption Ledger，可变深度退出条件，不固定四问
- **Phase 0 快照**: Task Intake Snapshot 从源头锁定 scope
- **Workflow 脚本驱动**: 4 个确定性 JS 脚本 (phase3-6 only, Phase 0-2 使用 Skill+Agent 直接执行)
- **Phase 4.5 工作树审查**: harness-managed 隔离 → master agent merge-back
- **Phase 5 Hard Gate**: finalReview APPROVE/ITERATE/REJECT 统一裁定
- **Phase 6 语义证据**: evidenceChecks (5 种类型: file-exists/text-present/text-absent/command-output-present/command-output-absent)
- **推荐 MCP**: Context7 (文档查询) + Firecrawl (网页搜索)，自动检测 fallback

## 核心设计

- **三平台支持**：`project-workflow`（Hermes）+ `project-workflow-claude`（Claude Code，v2.8 modular orchestrator）+ `project-workflow-codex`（Codex agents），共享根目录 `skills/`
- **Codex 分支支持**：`project-workflow-codex` 用 Codex agents 执行实现、审阅和验证，不调用 Claude Code Workflow 脚本
- **Codex 模型边界**：主会话模型由用户 Codex 配置管理，推荐 `gpt-5.5`；仓库托管子 agents 只允许 `gpt-5.3-codex` 和 `gpt-5.4-mini`
- **平台边界清晰**：Codex 不自动运行 Hermes 的 `project-workflow`；只在显式调用或文档兼容性检查时读取它
- **零硬编码**：项目类型从 go.mod/package.json/skills/SKILL.md 自动检测，skill 自动路由
- **自驱动顺序**：Phase 0.3 先分析代码库生成项目知识，Phase 0.5 再加载技能
- **CONTEXT.md 双层结构**（Knowledge + Instruction）：`[confirmed]`/`[auto]` 标签，子目录就近覆盖
- **Claude Code**: CLAUDE.md Boot Layer + `.claude/context/knowledge.md` 分析缓存
- **自学习**：Phase 7.1 后台反省 → 保存 memory；7.3 cron 每 2h 跨 session 反思
- **Hard Gates**：HARD-GATE（设计先于编码）、Iron Law（新鲜证据先于声称）、Two-Stage Review（spec→code）
- **Ralph 循环**：任何验证失败 → 自动修复 → 重新验证，直到全部通过
- **Phase 出口可见**：每个 Phase 宣告用了什么 skill（`Phase X complete. [skill] verified. → Phase Y`）

## v2.8 Modular Architecture

project-workflow-claude v2.8 uses a thin orchestrator + 7 independent execution skills.

| Skill | Role | Key Deliverable |
|------|------|-----------------|
| **project-workflow-claude** | Thin orchestrator | Routes to execution skills, manages shared state |
| **detecting-environment** | Phase 0-0.5 | Project type detection, skill loading, CONTEXT.md |
| **designing-solutions** | Phase 1 | Hard Grill Checklist, REQUIREMENT ECHO, design docs |
| **planning-implementation** | Phase 2-3 | Implementation plan, Judge Panel consensus |
| **implementing-changes** | Phase 4-4.6 | Parallel implementation, isolation strategies, Quick Gate |
| **reviewing-implementation** | Phase 5 | Layered review, per-task pipeline, tiered models |
| **verifying-completion** | Phase 6 | Loop Until Dry verification, evidenceChecks |
| **finishing-development** | Phase 7-8 | Retrospective, memory compression, branch cleanup |

**4 Workflow Scripts (phase3-6 only):**
- `phase3-consensus.js` — Judge Panel (3 angles parallel) + context/task contract validation + scope/ambiguity blocking
- `phase4-implement.js` — Pipeline implement + isolation strategies (no-isolation/harness-managed/external-report) + changedFiles threading + Completion Guarantee (max 3 retries, STUCK reason)
- `phase5-review.js` — **4-layer complexity-gated review**: Layer 1 Fast Gate (bash) → Layer 2 Standard (spec, gated) → Layer 3 Deep (code quality, gated) → Layer 4 Final (cross-task, conditional). Outputs layersApplied, layersSkipped, estimatedTokensSaved.
- `phase6-verify.js` — Loop Until Dry verification + evidenceChecks evaluation (5 types) + Quick Gate audit trail + grill evidence cross-reference + mandatoryNextAction enum + totalIterations tracking + max 10 iteration hard limit + EXHAUSTED verdict

**Phase 0-2**: Skill+Agent 直接执行（无 Harness 开销）。Phase 0 检测环境，Phase 1 Grill 需求，Phase 2 写 plan，只有 Phase 3 共识审查才首次进入 Workflow。

**Key Properties:**
- Each execution skill is <500 lines with Exit Contract sections
- Step 0 state validation on all 7 execution skills — prevents out-of-order invocation
- Scripts are deterministic — support caching and resume
- Iron Law: `skills/project-workflow-claude/references/iron-law.md` — standalone verification discipline
- Scripts CANNOT do file I/O, Bash, or Read — master agent pre-computes file evidence
- MCP-aware: auto-detects Context7/Firecrawl, falls back to WebFetch/WebSearch
- Verdicts unified: APPROVE/ITERATE/REJECT (present tense) across Phase 3, Phase 5, and Phase 6 (EXHAUSTED)
- Phase 5 layered review: ~50-60% token reduction for mixed-complexity runs
- Phase 4 Completion Guarantee: unfinished tasks auto-retry (max 3 rounds), STUCK tasks return explicit reason
- Phase 6 EXHAUSTED verdict: when max 10 iterations are reached without resolution, the loop exits cleanly with mandatoryNextAction
- Error hardening: Edit safety rules + Plain-JS guardrails + Phase4 enrichment + state graceful degradation
- install.sh: syncs Claude/Codex snapshots under `~/.jessy-skills-claude` and `~/.jessy-skills-codex`, then symlinks managed skills while preserving external plugins (superpowers/omc/etc.)
- Codex agents: installs repo-managed `codex/agents/*.toml` to `~/.codex/agents`; no hooks/OMX/oh-my-codex dependency.
- Regression probes: tests/test-regression-workflow-parse.sh + tests/test-controlled-edit-probe.sh

## 逃逸命令

| 命令 | 效果 |
|------|------|
| `quick` / `fast` | 快速深度（精简 grill + review） |
| `deep` / `careful` | 深度审查（含现代化审计） |
| `skip workflow` | 跳过 Workflow 脚本驱动，退回到 Agent 委托模式 |
| `skip design` | 跳到 Phase 2（保留 Phase 0/0.5） |
| `skip plan` | 跳到 Phase 4 实现（保留 Phase 5+6+7） |
| `no review` | 跳过 Phase 6 代码审查 |
| `skip branch` | 跳过 Phase 8（Finish Branch）|
| `FULL` | 所有 Phase 深深度 |

## 工作流内部规则

- **Karpathy 五条**：先思考再编码 · 极简主义 · 手术式修改 · 目标驱动 · **prior-research 优先级链先搜再断言**
- **Phase 0.3 先行**：环境检测后先跑代码分析 → 生成 CONTEXT.md（两层）+ contextSummary；0.5 在 0.3 完成后执行并 augment
- **Phase 0.3 HARD-GATE 强制**：CONTEXT.md 或 knowledge.md 缺失或 commit SHA 不匹配时必须执行，全项目类型适用
- **Phase 0.3 双层更新**：CONTEXT.md 选择性刷新（保留 `[confirmed]`，替换 `[auto]`）；knowledge.md 全量覆盖
- **Phase 0 Task Intake Snapshot**：在 Phase 0 就锁定 in/out scope，防止范围蔓延
- **Phase 1 Grill 可变深度**：Ambiguity Register + Assumption Ledger，不固定四问 — 简单任务 0 问，复杂任务多问
- **Phase 1 Hard Grill Checklist**：6 项强制自查（PASS/FAIL）— 逐条输出确认后才能退出 Grill，杜绝"0 问即过"
- **Phase 1 REQUIREMENT ECHO**：Grill 前必须回显所有需求给用户确认 — "Complete and correct?"
- **Phase 1 Grill Evidence**：`.claude/state/grill-evidence.json` 持久化 Ambiguity Register + Assumption Ledger + Checklist 结果
- **HARD-GATE**：在用户批准设计前，禁止写任何代码 — 适用于所有项目
- **BOUNDARY-CHECK**：第一轮 clarify 必须确认项目边界 — 涉及/不涉及哪些文件模块
- **MUST-LOAD**：Phase 0.5/1 两个 skill 补漏点强制加载 — 扫描后必须 Skill()，只扫不载 = 不可接受
- **Two-Stage Review**：spec compliance review 必须 ✅ 后才能开始 code quality review
- **Phase 4.5 Worktree Review**：harness-managed 任务必须在 Phase 4 和 Phase 5 之间做 master agent merge-back
- **Phase 4.6 Quick Gate**：Phase 4.5 和 Phase 5 之间的 fail-fast 快速门 — git diff + grep expectedEvidence + grep forbiddenEvidence
- **Phase 5 Layered Review**：4 层复杂度门控 — Fast Gate → Standard (spec,gated) → Deep (code quality,gated) → Final (cross-task,conditional)
- **Phase 5 统一裁定**：`APPROVE`/`ITERATE`/`REJECT`（现在时）跨 Phase 3 和 Phase 5；finalReview Hard Gate 阻断 pass
- **Phase 6 语义证据**：evidenceChecks (5 种类型) — 命令成功是必要不充分条件；dryRounds 融合命令+语义失败
- **Phase 6 审计轨迹**：quickGateAudit + grillEvidenceAvailable 输出，Phase 4.6/Phase 1 证据可追溯
- **Iron Law**：没有新鲜验证证据，不准声称完成 — "should work" = 撒谎
- **Phase 7.1 后台**：反省学习跑在子进程，主 agent 继续干活不阻塞
- **Phase 7.3 后台 cron**：每 2h 跨 session 模式提取；memory ≥90% 自动压缩为 skill，memory 保留触发器自动加载
- **Phase 8 收尾**：结构化分支完成 — 验证→环境检测→4选项菜单→执行→清理

## 包含的技能（85）

### 工作流
- `project-workflow` — 11-Phase 自驱动流水线（核心，v7.0，Hermes）
- `project-workflow-claude` — 模块化流水线（v2.8，Claude Code，1 orchestrator + 7 execution skills + Workflow 脚本驱动 + Hard Grill Checklist + Layered Review + Quick Gate + CONTEXT.md 双层上下文）
- `karpathy-guidelines` — LLM 编码五条纪律
- `deep-interview` — 苏格拉底式需求澄清
- `ralplan` — 多 agent 共识计划
- `ralph` — 错误自修复循环
- `ultrawork` — 并行任务执行
- `jessy-self-iterate` — 项目自迭代（test 分支）

### 方法技能（skills/methodology/）★ NEW
- `prior-research` — 研究方法论（WHEN→HOW→USE），吸收 context7-docs + firecrawl-web
- `api-design-first` — API 设计优先：先定契约（proto/OpenAPI）再写 handler
- `data-model-first` — 数据模型优先：先设计实体关系和索引再写 storage
- `error-taxonomy` — 错误三分法：ValidationError / BusinessError / SystemError

### Go 后端（skills/go/）
- `golang-modernize` — 持续现代化（Go 1.21→1.26+）
- `golang-concurrency` — 并发安全模式
- `golang-testing` / `golang-stretchr-testify` — 测试最佳实践
- `golang-error-handling` — 错误处理
- `golang-context` — Context 模式
- `golang-grpc` — gRPC 服务开发
- `golang-database` — 数据库集成
- `golang-observability` — 可观测性（slog/Prometheus）
- `golang-security` / `golang-safety` — 安全 + 防御编程
- `golang-performance` / `golang-benchmark` — 性能优化
- `golang-design-patterns` / `golang-dependency-injection` — 设计模式
- `golang-cli` / `golang-project-layout` — CLI + 项目结构
- `golang-code-style` / `golang-naming` / `golang-documentation` — 代码规范
- `golang-troubleshooting` — 调试排错
- 21 个专项技能

### Vue 前端（skills/vue/）
- `vue-best-practices` — Composition API 最佳实践
- `vue-router-best-practices` — Vue Router 4 模式
- `vue-pinia-best-practices` — Pinia 状态管理
- `vue-testing-best-practices` — Vitest 测试
- `vue-debug-guides` — 调试排错指南
- `vue-jsx-best-practices` / `vue-options-api-best-practices` — JSX/Options API
- `create-adaptable-composable` — 自适应 Composable

### 前端工具（skills/frontend/）
- `anthropic-frontend-design` — 生产级 UI 设计
- `anthropic-web-artifacts-builder` — React/Tailwind/shadcn 组件
- `anthropic-webapp-testing` — Playwright 自动化测试

### 工程流程（skills/engineering/）
- `strategic-thinking` — 思维模式切换框架（Zoom-Out / Grill / Handoff / Caveman）★ 吸收 5 个旧 skill
- `diagnose` — 调试诊断循环
- `tdd` — 测试驱动开发
- `prototype` — 快速原型验证
- `improve-codebase-architecture` — 架构优化
- `to-issues` / `to-prd` — 任务拆分 + PRD 文档
- `triage` — 问题分类管理
- `write-pr-description` — PR 描述

### 已废弃（保留向后兼容）
- `context7-docs` → 使用 `prior-research`
- `firecrawl-web` → 使用 `prior-research`
- `zoom-out` / `grill-me` / `grill-with-docs` / `handoff` / `caveman` → 使用 `strategic-thinking`

### 通用
- `analyze` — 代码深度分析
- `code-review` — 代码审查

## Shell 集成

安装后 `~/.bashrc`（或 `~/.zshrc`、PowerShell `$PROFILE`）只需一行：

```bash
source ~/.jessy-skills/hermes.sh
```

自动注入 `-s project-workflow,karpathy-guidelines` 到每次 `hermes` 调用。

| 平台 | 配置文件 |
|------|---------|
| bash | `source ~/.bashrc` |
| zsh | `source ~/.zshrc` |
| PowerShell | `. $PROFILE` |

## 更新

```bash
cd ~/path/to/jessy-skills
git pull
bash install.sh
```

或在 Hermes 内：`hermes skills update`

## Skill 维护规范

- `SKILL.md` frontmatter 至少包含 `name` 和 `description`；为了兼容 Codex skill loader，新改动优先只保留这两个字段。
- `description` 遇到冒号、括号、引号或长句时使用双引号包裹，避免 YAML 解析歧义。
- 过长的 `SKILL.md` 应把细节拆到 `references/`，主体保留触发条件、核心流程和按需读取指引。
- 修改后运行：
  ```bash
  python3 /home/huangzexi/.codex/skills/.system/skill-creator/scripts/quick_validate.py <skill-dir>
  git diff --check
  ```

## 目录结构

```
jessy-skills/
├── install.sh              # Install script
├── codex/
│   └── agents/             # Native Codex agent templates copied to ~/.codex/agents/
├── CONTEXT.md              # Durable context contract (Knowledge + Instruction layers)
├── tests/                  # Automated test scripts
│   ├── test-workflow-changes.sh
│   ├── test-strategic-thinking.sh
│   └── test-prior-research.sh
├── shell/
│   └── hermes.sh           # Shell function
└── skills/
    ├── project-workflow/   # Core workflow (v7.0)
    ├── project-workflow-claude/ # Claude Code workflow (v2.8 modular orchestrator)
    │   └── references/
    │       ├── context-md-spec.md   # CONTEXT.md format spec
    │       ├── iron-law.md          # Verification discipline
    │       ├── state-validation.md  # Step 0 state validation spec
    │       ├── claude-routing.md    # Claude Code skill routing overlay
    │       └── setup.md             # MCP setup guide
    ├── project-workflow-codex/  # Codex workflow (Codex agents, no Claude Workflow scripts)
    │   └── references/
    │       ├── agent-execution.md
    │       ├── contract-template.md
    │       └── validation.md
    ├── detecting-environment/  # ★ Phase 0-0.5: project detection, CONTEXT.md
    ├── designing-solutions/    # ★ Phase 1: Hard Grill Checklist, REQUIREMENT ECHO
    ├── planning-implementation/# ★ Phase 2-3: plan, Judge Panel consensus
    ├── implementing-changes/   # ★ Phase 4-4.6: parallel impl, isolation, Quick Gate
    ├── reviewing-implementation/# ★ Phase 5: layered review, tiered models
    ├── verifying-completion/   # ★ Phase 6: Loop Until Dry, evidenceChecks
    ├── finishing-development/  # ★ Phase 7-8: retro, memory, branch cleanup
    ├── karpathy-guidelines/
    ├── methodology/        # ★ Method skills
    │   ├── prior-research/
    │   ├── api-design-first/
    │   ├── data-model-first/
    │   └── error-taxonomy/
    ├── go/                 # 21 Go backend skills
    ├── vue/                #  8 Vue frontend skills
    ├── frontend/           #  3 frontend tools
    ├── engineering/        # 10 engineering workflow skills
    ├── tools/              #  2 tools (deprecated)
    ├── project/            #  2 project-specific
    ├── deep-interview/
    ├── ralplan/
    ├── ralph/
    ├── ultrawork/
    ├── analyze/
    └── code-review/
```
