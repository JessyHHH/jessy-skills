# jessy-skills — Hermes Agent Golang Workflow

一个为 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 定制的 Golang 工作流技能集合。11 阶段自驱动并行流水线，从环境检测到验证交付全自动化。

## 快速安装

**AI 自安装（推荐）：** 克隆后在 Hermes 里说 "读 SETUP.md 并安装"

**手动安装：**
```bash
git clone https://github.com/JessyHHH/jessy-skills.git
cd jessy-skills
bash install.sh          # 自动检测 bash/zsh
source ~/.bashrc         # Linux · macOS 用 ~/.zshrc
```

安装后每次启动 `hermes` 自动加载 `golang-workflow` + `karpathy-guidelines`。

## 工作流概览

```
Phase 0    → Environment Detection     Go 版本、项目类型、依赖扫描
Phase 0.3  ∥  Codebase Analysis +      并行执行：delegate_task 分析代码库
Phase 0.5  ∥  Smart Skill Selection    同时 skill_view 加载任务信号匹配的技能
              ↓ 两者完成后 augment      0.3 成果补全遗漏的代码库模式 skill
Phase 1    → Deep Interview            3 轮 clarify 澄清需求
Phase 1.5  → Skill Re-Check            重扫 interview 上下文弥补遗漏
Phase 2    → Write Plan                写计划到 .hermes/plans/
Phase 2.5  → Post-Plan Skill Check     扫 plan 技术决策加载遗漏 skill ← NEW
Phase 3    → Ralplan Consensus         多 agent 审查计划（Planner→Architect→Critic）
Phase 4    → Consolidate Skills        所有技能就位
Phase 5    → Implement                 并行实现（delegate_task tasks=[]）
Phase 6    → Code Review               安全 + 并发 + 现代化审计（始终执行）
Phase 7    → Verified Completion       build·vet·test·race·vulncheck
```

## 核心设计

- **零硬编码**：Go 版本从 `go.mod` 自动检测，Docker 镜像自动匹配
- **自驱动并行**：Phase 0.3 + 0.5 并行启动，Phase 5 delegate_task 并发实现
- **三层补漏**：Phase 0.5（prompt）+ Phase 1.5（interview）+ Phase 2.5（plan）确保不遗漏 skill
- **Modernize 保鲜**：检测到项目 Go 版本超过 skill 覆盖范围 → 自动 web search 新版特性 → 更新 golang-modernize skill
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

- **Karpathy Guidelines**：先思考再编码 · 极简主义 · 手术式修改 · 目标驱动
- **Phase 0.3 ∥ 0.5**：环境检测后 analyze 和 skill 选择并行启动，完成后 augment 补漏
- **Phase 0.3 强制**：brownfield 项目任何非问候消息都必须先跑代码分析
- **Phase 2.5 自动**：plan 写完后扫描技术决策（sync.RWMutex、goroutine、prometheus 等）加载遗漏 skill
- **Phase 6 强制**：代码审查始终执行，深度只影响审查范围（quick/standard/deep）
- **Phase 7 完整**：go mod tidy → build → vet → test -race → govulncheck → modernize lint

## 包含的技能（42 个）

### 工作流
- `golang-workflow` — 11-Phase 自驱动并行流水线（核心）
- `karpathy-guidelines` — LLM 编码纪律
- `deep-interview` — 苏格拉底式需求澄清
- `ralplan` — 多 agent 共识计划
- `ralph` — 错误自修复循环
- `ultrawork` — 并行任务执行

### Golang 专项
- `golang-modernize` — 持续现代化（Go 1.21→1.26+）
- `golang-testing` — 测试最佳实践
- `golang-concurrency` — 并发模式
- `golang-grpc` — gRPC 服务开发
- `golang-cli` — CLI 应用开发
- `golang-security` — 安全审计
- `golang-performance` — 性能优化
- `golang-benchmark` — 基准测试
- `golang-error-handling` — 错误处理
- `golang-context` — Context 模式
- `golang-database` — 数据库集成
- `golang-observability` — 可观测性（slog/Prometheus）
- `golang-design-patterns` — 设计模式
- `golang-dependency-injection` — DI 模式
- `golang-project-layout` — 项目结构
- `golang-continuous-integration` — CI/CD
- `golang-code-style` — 代码风格
- `golang-naming` — 命名规范
- `golang-documentation` — 文档
- `golang-dependency-management` — 依赖管理
- `golang-data-structures` — 数据结构
- `golang-structs-interfaces` — 类型设计
- `golang-troubleshooting` — 调试排错
- `golang-safety` — 防御性编程
- `golang-popular-libraries` — 库推荐
- `golang-stay-updated` — Go 生态资讯
- `golang-samber-lo` — samber/lo 函数式工具
- `golang-samber-mo` — samber/mo Option/Result
- `golang-samber-do` — samber/do DI
- `golang-samber-oops` — samber/oops 错误增强
- `golang-samber-ro` — samber/ro 不可变数据
- `golang-samber-slog` — samber/slog 工具
- `golang-stretchr-testify` — testify 测试框架

### 通用
- `analyze` — 代码深度分析
- `code-review` — 代码审查

## Shell 集成

`shell/hermes.sh` 提供 `hermes()` 函数，自动追加 `-s golang-workflow,karpathy-guidelines`。

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
    ├── golang-workflow/    # 核心工作流
    ├── karpathy-guidelines/
    ├── deep-interview/
    ├── ralplan/
    ├── ralph/
    ├── ultrawork/
    ├── analyze/
    ├── code-review/
    └── golang-*/           # 30+ Go 专项技能
```
