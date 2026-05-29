# Spec: CONTEXT.md 双层结构 + Phase 0.3 重设计

**Date:** 2026-05-29
**Status:** PLAN PENDING
**Project:** jessy-skills (Skills Repository)
**Grill 决策记录:** 已完成 5 步追问（边界/数据/错误/测试/风险），全部达成共识

---

## 1. 问题陈述

### 现状

- Phase 0.3 触发条件 `has go.mod + Go files` → Skills Repository 和 Vue/Node 项目**永远不会触发**
- CONTEXT.md 只存实体列表（Part B），丢了最有价值的架构分析（Part A）
- merge 追加模式 → 幽灵实体永远不消失
- 无时效标记 → Agent 不知道分析是否过期
- 无操作层 → 缺少 CLAUDE.md 那种"怎么做"的指令信息
- 用户反馈：从未见过 Phase 0.3 的执行踪迹，都是从 Phase 0.5 开始

### 目标

CONTEXT.md 从"代码黄页"升级为"AI 操作手册 + 知识地图"，覆盖全部四种项目类型。

---

## 2. CONTEXT.md 双层结构

### 文件位置

```
project/
├── CONTEXT.md              ← 全局：项目级架构 + 通用约定
├── internal/
│   └── service/
│       └── CONTEXT.md      ← 可选：包/模块级细粒度上下文
```

层级规则：子目录 CONTEXT.md 覆盖根目录（就近原则）。Agent 修改某包时自动注入该包的 CONTEXT.md。

### 双层 Section 标记

```markdown
<!-- KNOWLEDGE_START -->
...机器生成，全量覆盖...
<!-- KNOWLEDGE_END -->

<!-- INSTRUCTION_START -->
...人工维护，只增不改...
<!-- INSTRUCTION_END -->
```

| 属性 | Knowledge Layer | Instruction Layer |
|---|---|---|
| 谁写 | Phase 0.3 delegate_task(analyze) 全量覆盖 | 自动生成骨架 + Grill 过程中追加 + 人工编辑 |
| 更新策略 | **全量覆盖**（对比 commit SHA，代码没变就跳过） | 只增不改（机器不覆盖 Instruction 区） |
| 内容 | 架构模式、实体地图、依赖关系、包归属、置信度 | 构建命令、测试命令、lint 命令、代码约定、不变量/红线 |
| 置信度 | 四级：HIGH/MEDIUM/LOW/?(未确认) | `[confirmed]` / `[auto]` 标记 |
| 大小限制 | < 200 行（精简优先） | 不限（有价值的指令不删） |

### Knowledge Layer 结构

```markdown
<!-- KNOWLEDGE_START -->
⚠️ Auto-generated | Commit: abc1234 | Date: 2026-05-29 | Go 1.25.3

## Architecture
- Error handling: samber/oops, 三层分类
- DI: samber/do, container 注入
- Concurrency: errgroup + context 传播
- Testing: testify suite + mockery
- DB: Repository 接口抽象

## Entity Map
```
User (core ★★★) ──1:N──▶ Order (core ★★★)
  │                          │
  └──1:1──▶ Profile          └──N:1──▶ Product (core ★★)
```

## Entities
### User ★★★ (HIGH)
- 定义: 用户账户。Source: internal/model/user.go:12
- 方法: Authenticate, Authorize

### Order ★★★ (MEDIUM)
- 定义: 订单。Source: internal/model/order.go:8
- 方法: Submit, Cancel

## Key Interfaces
### Repository (INTERFACE)
- Source: internal/storage/repository.go:15
- 实现: PostgresRepository, CacheRepository
- 不变量: 所有 DB 操作必须经过此接口

## Package Map
```
internal/
├── model/      ← 实体定义
├── service/    ← 业务逻辑
├── storage/    ← 数据访问（Repository 模式）
└── handler/    ← HTTP/gRPC 入口
```

## Confidence
| Level | Items |
|-------|-------|
| HIGH | User, Order, Repository (文档/注释佐证) |
| MEDIUM | Product, Profile (代码推断) |
| LOW | Entity relationships (纯结构推断) |
<!-- KNOWLEDGE_END -->
```

### Instruction Layer 结构

```markdown
<!-- INSTRUCTION_START -->
## Build & Test Commands
- Build: `go build ./...`
- Test: `go test -race -count=1 ./...`
- Lint: `golangci-lint run ./...`
- Security: `govulncheck ./...`

## Code Conventions
- 错误处理: samber/oops 包装，禁止裸 return err [confirmed]
- 依赖注入: samber/do，禁止全局变量 [confirmed]
- 测试: testify suite，mockery 生成 mock [confirmed]
- 新 service: 放 internal/service/，命名 xxx_service.go [auto]
- 文件组织: 按领域分包，禁止 utils/ 杂物袋 [confirmed]

## Invariants (NEVER VIOLATE)
- 所有 DB 访问必须通过 Repository 接口 [confirmed]
- 禁止在 handler 层写业务逻辑 [confirmed]

## Domain Glossary
- Account = 租户级别实体，非用户账户 [confirmed]
<!-- INSTRUCTION_END -->
```

---

## 3. Phase 0.3 新流程

### HARD-GATE（最高优先级）

```xml
<HARD-GATE>
CONTEXT.md missing OR commit SHA ≠ HEAD → MUST run Phase 0.3.
Skip ONLY when CONTEXT.md exists AND commit matches AND announced with reason.
适用于全部项目类型（Go / Vue / Node / Skills Repository），无例外。
</HARD-GATE>
```

### 按项目类型分支

```
Phase 0.3: Codebase Analysis
  │
  ├── Go 项目（有 go.mod + .go 文件）
  │   └── delegate_task(analyze-Go) → Knowledge Layer + Instruction 骨架
  │
  ├── Vue/Node 项目（有 package.json）
  │   └── delegate_task(analyze-FE) → 组件树 + 路由 + 状态管理
  │
  └── Skills Repository（有 skills/*/SKILL.md）
      └── delegate_task(analyze-Skills) → SKILL.md 结构 + 引用完整性
```

### Go 项目的 analyze prompt

```
delegate_task(
  goal="Deep read-only analysis.

Part A — Architecture: error handling, DI, concurrency, testing, 
  file organization patterns. Confidence levels.

Part B — Entity Map: all main structs with relationships, 
  importance stars (★★★ core / ★★ important / ★ support).
  Rules: mark inferred meanings with confidence level (HIGH/MEDIUM/LOW),
  no helper types, max 15 entities.

Part C — Key Interfaces: abstracts that define system boundaries.
  Include invariants.

Part D — Package Map: directory → responsibility mapping.

Output as structured 4-section Knowledge Layer format 
(with <!-- KNOWLEDGE_START --> / <!-- KNOWLEDGE_END --> wrappers).
Include commit SHA from git rev-parse HEAD.",
  context="...",
  toolsets=["terminal", "file"]
)
```

### Skills Repository 的 analyze prompt

```
delegate_task(
  goal="Analyze this Skills Repository.

Part A — SKILL.md structure: count total skills, categorize by directory,
  identify auto_load skills, detect version mismatches.

Part B — Reference integrity: for each skill, check referenced files exist.
  Flag broken references.

Part C — Version consistency: scan all SKILL.md version fields,
  flag any that don't match their directory name or have obvious drift.

Part D — Instruction Layer skeleton: extract common commands found in 
  references, suggest invariants from repeated patterns.

Commit SHA: from git rev-parse HEAD.",
  context="...",
  toolsets=["terminal", "file"]
)
```

### Step 3 之后：交叉验证

```
Phase 0.3 Step 3.5 — 轻量交叉验证（全量覆盖后立即执行）：
1. 抽样验证：Knowledge Layer 前 5 个实体的 Source 路径 → search_files 确认存在
2. 声明验证：grep go.mod 确认架构声明与依赖一致
3. 矛盾检测：如有子目录 CONTEXT.md，diff 冲突条目
4. 如有失败：标记置信度降级，不阻塞流程
```

### 输出规范（必须对用户可见）

```
"Phase 0.3: Codebase Analysis — [project-type] 项目，基于 commit abc1234

Knowledge Layer: 全量覆盖写入
  - 架构发现: 3 patterns (error handling, DI, concurrency)
  - 实体地图: 5 entities, 4 relationships, 2 interfaces
  - 置信度: HIGH 3 / MEDIUM 1 / LOW 2
  - 包结构: 4 directories mapped

Instruction Layer: 骨架已生成（命令 + 约定模板），待 Phase 1 Grill 补充 [confirmed] 项

交叉验证: 5/5 实体路径存在 ✓ | go.mod 一致性 ✓ | 子目录冲突 0

→ CONTEXT.md 已更新。"
```

---

## 4. 改动范围

### 修改

| 文件 | 改动 | 行数估计 |
|---|---|---|
| `skills/project-workflow/SKILL.md` | Phase 0.3 完全重写 | ~80 行新增 |
| `skills/project-workflow/SKILL.md` | 版本号 v6.3 → v7.0 | 1 行 |
| `skills/project-workflow/SKILL.md` | Phase 0 auto-transition 调整 | ~5 行 |

### 新增

| 文件 | 内容 |
|---|---|
| `skills/project-workflow/references/context-md-spec.md` | CONTEXT.md 格式规范（双层标记、字段定义、置信度等级） |

### 版本统一

| 位置 | 当前 | 目标 |
|---|---|---|
| SKILL.md frontmatter | v6.3 | v7.0 |
| references/full-skill-routing.md | v6.0 | v7.0 |
| references/golang-skill-routing.md | v5.0 | v7.0 |

### 不涉及

- Vue/Go 具体分析 prompt（先搭框架，prompt 细节后续迭代）
- 48 个 references 的 mixgo 整理（独立任务）
- 其他 Phase 逻辑改动

---

## 5. 验收标准

1. Phase 0.3 对 Skills Repository 触发且执行
2. CONTEXT.md 生成后包含 Knowledge Layer + Instruction Layer 双层标记
3. commit SHA 写入 Knowledge Layer header
4. Phase 0.3 输出对用户可见（摘要而非静默）
5. HARD-GATE 在 SKILL.md 中以 XML 标签明确标注
6. 版本号统一为 v7.0（三处）
