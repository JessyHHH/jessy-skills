# jessy-skills — Multi-Language AI Engineering Skills

一个为 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 定制的多语言工作流技能集合。10 阶段自驱动并行流水线，59 个技能覆盖 Go/Vue/前端/工程全流程。

## 快速安装

**AI 自安装（推荐）：** 克隆后在 Hermes 里说 "读 SETUP.md 并安装"

**手动安装：**
```bash
git clone https://github.com/JessyHHH/jessy-skills.git
cd jessy-skills
bash install.sh          # 自动检测 bash/zsh
source ~/.bashrc         # Linux · macOS 用 ~/.zshrc
```

安装后每次启动 `hermes` 自动加载 `project-workflow` + `karpathy-guidelines`（自动识别 Go/Vue/Node 项目）。

## 工作流概览

```
Phase 0    → Environment Detection     项目类型、语言版本、依赖扫描
Phase 0.3  ∥  Codebase Analysis +      并行执行：delegate_task 分析代码库
Phase 0.5  ∥  Smart Skill Selection    同时匹配 59-skill 路由表加载技能
              ↓ 两者完成后 augment      0.3 成果补全遗漏的代码库模式 skill
Phase 1    → Deep Interview            3 轮 clarify + skill re-check 补漏
Phase 2    → Write Plan                写计划 + post-plan 扫技术信号补漏
Phase 3    → Ralplan Consensus         多 agent 审查计划
Phase 4    → Implement                 并行实现（delegate_task tasks=[]）
Phase 5    → Code Review               安全 + 并发 + 现代化审计（始终执行）
Phase 6    → Verified Completion       Go: build/vet/test · Vue: vitest/lint
Phase 7    → Retro + Learn + Mem Cron  7.1 session反思 │ 7.2 自学习 │ 7.3 2h cron+压缩
```

## 核心设计

- **零硬编码**：项目类型从 go.mod/package.json 自动检测，skill 自动路由
- **自驱动并行**：Phase 0.3 + 0.5 并行启动，Phase 5 delegate_task 并发实现
- **自学习**：Phase 7.1 后台反省 → 保存 memory；7.3 cron 每 2h 跨 session 反思，memory ≥90% 自动压缩为 skill
- **Ralph 循环**：任何验证失败 → 自动修复 → 重新验证，直到全部通过

## 逃逸命令

| 命令 | 效果 |
|------|------|
| `quick` / `fast` | 快速深度（精简 interview + review） |
| `deep` / `careful` | 深度审查（含现代化审计） |
| `skip interview` | 跳到 Phase 2（保留 Phase 0/0.5） |
| `skip plan` | 跳到 Phase 5 实现（保留 Phase 6+7） |
| `no review` | 跳过 Phase 6 代码审查 |
| `FULL` | 所有 Phase 深深度 |

## 工作流内部规则

- **Karpathy 五条**：先思考再编码 · 极简主义 · 手术式修改 · 目标驱动 · **先搜再断言**
- **Phase 0.3 ∥ 0.5**：环境检测后 analyze 和 skill 选择并行启动
- **Phase 0.3 强制**：brownfield 项目任何非问候消息都必须先跑代码分析
- **Phase 2 自动**：plan 写完后全量路由表扫描技术信号，补漏 skill
- **Phase 6 强制**：代码审查始终执行，深度只影响审查范围
- **Phase 7.1 后台**：反省学习跑在子进程，主 agent 继续干活不阻塞
- **Phase 7.3 后台 cron**：每 2h 跨 session 模式提取；memory ≥90% 自动压缩为 skill，memory 保留触发器自动加载

## 包含的技能（59 个）

### 工作流
- `project-workflow` — 10-Phase 自驱动并行流水线（核心）
- `karpathy-guidelines` — LLM 编码五条纪律
- `deep-interview` — 苏格拉底式需求澄清
- `ralplan` — 多 agent 共识计划
- `ralph` — 错误自修复循环
- `ultrawork` — 并行任务执行
- `jessy-self-iterate` — 项目自迭代（test 分支）

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
- `golang-*` — 34 个专项技能

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
- `diagnose` — 调试诊断循环
- `tdd` — 测试驱动开发
- `prototype` — 快速原型验证
- `improve-codebase-architecture` — 架构优化
- `to-issues` / `to-prd` — 任务拆分 + PRD 文档
- `triage` — 问题分类管理
- `zoom-out` — 全局视角分析
- `grill-me` / `grill-with-docs` — 计划拷问
- `handoff` / `caveman` — 交接 + 简化

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
├── install.sh              # 安装脚本
├── shell/
│   └── hermes.sh           # Shell 函数
└── skills/
    ├── project-workflow/   # 核心工作流 (10 Phase)
    ├── karpathy-guidelines/
    ├── go/                 # 34 Go 后端技能
    ├── vue/                #  8 Vue 前端技能
    ├── frontend/           #  3 前端工具技能
    ├── engineering/        # 14 工程流程技能
    ├── project/            #  1 项目自迭代
    ├── deep-interview/
    ├── ralplan/
    ├── ralph/
    ├── ultrawork/
    ├── analyze/
    └── code-review/
```
