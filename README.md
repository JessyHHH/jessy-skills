# jessy-skills — Multi-Language AI Engineering Skills

![Version](https://img.shields.io/badge/version-v2.2-blue)

一个支持 [Claude Code](https://code.claude.com/) + [Hermes Agent](https://github.com/NousResearch/hermes-agent) 的多语言工作流技能集合。11 阶段自驱动并行流水线（含 HARD-GATE / Iron Law / Two-Stage Review），76+ 技能覆盖 Go/Vue/前端/工程/方法论全流程。

**v2.2 新特性：**
- **CONTEXT.md 双层上下文**：Knowledge Layer（机器管理）+ Instruction Layer（人工维护），`[confirmed]`/`[auto]` 证据标签，子目录就近覆盖
- **Phase 1 深度 Grill**：Ambiguity Register（模糊性登记表）+ Assumption Ledger（假设台账），可变深度退出条件，不再固定四问
- **Phase 0 Task Intake Snapshot**：在 Phase 0 就锁定 in/out scope，从源头防范围蔓延
- **Phase 4.5 Worktree Review**：harness-managed 隔离策略 + master agent merge-back
- **Phase 5/3 统一裁定**：`APPROVE`/`ITERATE`/`REJECT` 现在时跨 Phase 3 和 Phase 5 一致
- **Phase 6 语义证据**：`evidenceChecks`（master agent 预计算）+ 5 种证据类型（file-exists/text-present/text-absent/command-output-present/command-output-absent）
- **4 Workflow 脚本能力边界修正**：脚本不能文件 I/O/Bash/Read — 能力正确建模

## 快速安装

**AI 自安装（推荐）：** 克隆后在 Claude Code 或 Hermes 里说 "读 SETUP.md 并安装"

**手动安装：**
```bash
git clone https://github.com/JessyHHH/jessy-skills.git
cd jessy-skills
bash install.sh          # 自动检测 Hermes / Claude Code / 两者
source ~/.bashrc         # Linux · macOS 用 ~/.zshrc

# 安装工具 CLI（一步）
npm install -g ctx7@latest firecrawl-cli@latest
ctx7 login && firecrawl login  # 浏览器授权
```

安装后：
- **Hermes** 每次启动自动加载 `project-workflow` + `karpathy-guidelines`
- **Claude Code** 每次启动自动加载 CLAUDE.md，`/reload-skills` 激活技能
- 自动识别 Go/Vue/Node/Skills Repository 项目

## 工作流概览

| Phase | Hermes (`project-workflow`) | Claude Code (`project-workflow-claude` v2.2) |
|-------|---------------------------|----------------------------------------|
| 0 | `search_files` 检测项目类型 | `Glob` + `Grep` 检测项目类型 + **Task Intake Snapshot** |
| 0.3 | `delegate_task` 分析 → CONTEXT.md | `Agent` 分析 → **CONTEXT.md (两层) + contextSummary** |
| 0.5 | `skill_view()` 加载技能 | `Skill()` 加载技能 |
| 1 | `clarify()` 设计对话 ⚡ | `AskUserQuestion()` + **Ambiguity Register + Assumption Ledger（可变深度）** ⚡ |
| 2 | `write_file(.hermes/plans/)` | `Write(.claude/plans/)` + **扩展 task schema（12 字段）** |
| 3 | `skill_view(ralplan)` → delegate_task | **Workflow(phase3-consensus)**: 3 角度并行 Judge Panel + context/task 合同验证 |
| 4 | `delegate_task(tasks=[])` 并行 | **Workflow(phase4-implement)**: pipeline 实现 + 策略隔离 (no-isolation/harness-managed/external-report) |
| 4.5 | — | ★ **Master agent**: review worktree diff → merge-back |
| 5 | `delegate_task` 审查 ⚡ | **Workflow(phase5-review)**: 逐任务 pipeline 审阅 + Adversarial Verify + **finalReview Hard Gate** (+ APPROVE/ITERATE/REJECT) |
| 6 | `terminal()` 验证 ⚡ | `Bash()` + **Workflow(phase6-verify)**: Loop Until Dry + **evidenceChecks 语义验证** ⚡ |
| 7 | `memory()` + `cronjob()` | `CronCreate()` + 文件记忆 |
| 8 | 4-option 收尾菜单 ★ | 4-option 收尾菜单 ★ |

**出口可见性：** 每个 Phase 结束时输出 `Phase X complete. [skill] verified. → Phase Y`，Skill Expected 列在转换规则表中。

### project-workflow-claude v2.2 亮点
- **CONTEXT.md 双层上下文**: Knowledge Layer（架构/实体/接口）+ Instruction Layer（约定/命令/不变量），`[confirmed]`/`[auto]` 标签
- **Phase 1 深度 Grill**: Ambiguity Register + Assumption Ledger，可变深度退出条件，不固定四问
- **Phase 0 快照**: Task Intake Snapshot 从源头锁定 scope
- **Workflow 脚本驱动**: 4 个确定性 JS 脚本 (pipeline/parallel/loop/adversarial verify)
- **Phase 4.5 工作树审查**: harness-managed 隔离 → master agent merge-back
- **Phase 5 Hard Gate**: finalReview APPROVE/ITERATE/REJECT 统一裁定
- **Phase 6 语义证据**: evidenceChecks (5 种类型: file-exists/text-present/text-absent/command-output-present/command-output-absent)
- **推荐 MCP**: Context7 (文档查询) + Firecrawl (网页搜索)，自动检测 fallback

## 核心设计

- **双平台支持**：`project-workflow`（Hermes）+ `project-workflow-claude`（Claude Code），共享 72 个 domain skills
- **零硬编码**：项目类型从 go.mod/package.json/skills/SKILL.md 自动检测，skill 自动路由
- **自驱动顺序**：Phase 0.3 先分析代码库生成项目知识，Phase 0.5 再加载技能
- **CONTEXT.md 双层结构**（Knowledge + Instruction）：`[confirmed]`/`[auto]` 标签，子目录就近覆盖
- **Claude Code**: CLAUDE.md Boot Layer + `.claude/context/knowledge.md` 分析缓存
- **自学习**：Phase 7.1 后台反省 → 保存 memory；7.3 cron 每 2h 跨 session 反思
- **Hard Gates**：HARD-GATE（设计先于编码）、Iron Law（新鲜证据先于声称）、Two-Stage Review（spec→code）
- **Ralph 循环**：任何验证失败 → 自动修复 → 重新验证，直到全部通过
- **Phase 出口可见**：每个 Phase 宣告用了什么 skill（`Phase X complete. [skill] verified. → Phase Y`）

## v2.2 Standalone Architecture

project-workflow-claude v2.2 is fully standalone — zero external dependencies.

| Role | Responsibility | Tools |
|------|---------------|-------|
| **Master Agent** | Phase 0 detection, Phase 0.3 context, Phase 1 grill, Phase 4.5 worktree review, Phase 6 Bash checks | Glob, Grep, Read, Bash, Skill, AskUserQuestion |
| **Subagent (Agent)** | Phase 0.3 analysis+write, Phase 1.4 spec write, Phase 2 plan write, Phase 4 implement | Write, Edit, Read, Glob, Grep |
| **Workflow Scripts** | Deterministic orchestration (Phase 3 review / Phase 4 implement / Phase 5 review / Phase 6 verify) | 4 JS scripts via Workflow tool |

**4 Workflow Scripts (v2.2):**
- `phase3-consensus.js` — Judge Panel (3 angles parallel) + context/task contract validation + scope/ambiguity blocking
- `phase4-implement.js` — Pipeline implement + isolation strategies (no-isolation/harness-managed/external-report) + changedFiles threading
- `phase5-review.js` — Per-task pipeline review + Adversarial Verification (3 skeptics) + Final Review (APPROVE/ITERATE/REJECT hard gate)
- `phase6-verify.js` — Loop Until Dry verification + evidenceChecks evaluation (5 evidence types) + command + semantic evidence dry-round fusion

**Key Properties:**
- Scripts are deterministic — support caching and resume
- Iron Law: `references/iron-law.md` — standalone verification discipline
- Scripts CANNOT do file I/O, Bash, or Read — master agent pre-computes file evidence
- MCP-aware: auto-detects Context7/Firecrawl, falls back to WebFetch/WebSearch
- Verdicts unified: APPROVE/ITERATE/REJECT (present tense) across Phase 3 and Phase 5

## 逃逸命令

| 命令 | 效果 |
|------|------|
| `quick` / `fast` | 快速深度（精简 grill + review） |
| `deep` / `careful` | 深度审查（含现代化审计） |
| `skip workflow` | 跳过 Workflow 脚本驱动，退回到 Agent 委托模式 |
| `skip design` | 跳到 Phase 2（保留 Phase 0/0.5） |
| `skip plan` | 跳到 Phase 5 实现（保留 Phase 6+7） |
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
- **HARD-GATE**：在用户批准设计前，禁止写任何代码 — 适用于所有项目
- **BOUNDARY-CHECK**：第一轮 clarify 必须确认项目边界 — 涉及/不涉及哪些文件模块
- **MUST-LOAD**：Phase 0.5/1 两个 skill 补漏点强制加载 — 扫描后必须 Skill()，只扫不载 = 不可接受
- **Two-Stage Review**：spec compliance review 必须 ✅ 后才能开始 code quality review
- **Phase 4.5 Worktree Review**：harness-managed 任务必须在 Phase 4 和 Phase 5 之间做 master agent merge-back
- **Phase 5 统一裁定**：`APPROVE`/`ITERATE`/`REJECT`（现在时）跨 Phase 3 和 Phase 5；finalReview Hard Gate 阻断 pass
- **Phase 6 语义证据**：evidenceChecks (5 种类型) — 命令成功是必要不充分条件；dryRounds 融合命令+语义失败
- **Iron Law**：没有新鲜验证证据，不准声称完成 — "should work" = 撒谎
- **Phase 7.1 后台**：反省学习跑在子进程，主 agent 继续干活不阻塞
- **Phase 7.3 后台 cron**：每 2h 跨 session 模式提取；memory ≥90% 自动压缩为 skill，memory 保留触发器自动加载
- **Phase 8 收尾**：结构化分支完成 — 验证→环境检测→4选项菜单→执行→清理

## 包含的技能（55+）

### 工作流
- `project-workflow` — 11-Phase 自驱动流水线（核心，v7.0，Hermes）
- `project-workflow-claude` — 11-Phase 流水线（v2.2，Claude Code，Workflow 脚本驱动 + 独立 Iron Law + Deep Grill + CONTEXT.md 双层上下文）
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

## 目录结构

```
jessy-skills/
├── install.sh              # Install script
├── CONTEXT.md              # Durable context contract (Knowledge + Instruction layers)
├── tests/                  # Automated test scripts
│   ├── test-workflow-changes.sh
│   ├── test-strategic-thinking.sh
│   └── test-prior-research.sh
├── shell/
│   └── hermes.sh           # Shell function
└── skills/
    ├── project-workflow/   # Core workflow (v7.0)
    ├── project-workflow-claude/ # Claude Code workflow (v2.2)
    │   └── references/
    │       ├── context-md-spec.md   # CONTEXT.md format spec
    │       ├── iron-law.md          # Verification discipline
    │       ├── claude-routing.md    # Claude Code skill routing overlay
    │       └── setup.md             # MCP setup guide
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
