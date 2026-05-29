# CONTEXT.md Format Specification — project-workflow v7.0

## File Location

```
project/
├── CONTEXT.md              ← 全局：项目级架构 + 通用约定
├── internal/service/
│   └── CONTEXT.md          ← 可选：包/模块级细粒度上下文
```

层级规则：子目录 CONTEXT.md 覆盖根目录（就近原则）。

## Two-Layer Structure

文件由两个标记块包裹：

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
| 谁写 | Phase 0.3 delegate_task(analyze) 全量覆盖 | 自动骨架 + Grill 追加 + 人工 |
| 更新策略 | 全量覆盖（commit SHA 一致则跳过） | 只增不改（机器不覆盖） |
| 内容 | 架构、实体、接口、包归属 | 命令、约定、不变量 |
| 大小限制 | < 200 行 | 不限 |

## Knowledge Layer Fields

### Header (required)

```
⚠️ Auto-generated | Commit: <sha> | Date: <iso-date> | <project-type>
```

For Go projects: `Go 1.25.3`. For Skills Repository: `Skills Repository`. For Vue/Node: `Vue 3.x` / `Node 22`.

### Sections

| Section | Required | Content |
|---|---|---|
| `## Architecture` | Yes | Error handling, DI, concurrency, testing, DB patterns |
| `## Entity Map` | Yes | ASCII diagram showing entity relationships |
| `## Entities` | Yes | Per-entity: name, importance (★), confidence, source path, methods |
| `## Key Interfaces` | If any | Interface name, source, implementations, invariants |
| `## Package Map` | Yes | Directory tree → responsibility |
| `## Confidence` | Yes | Summary table: HIGH/MEDIUM/LOW per item |

### Importance Stars

| Rating | Meaning |
|---|---|
| ★★★ | Core — 修改影响全局 |
| ★★ | Important — 频繁使用 |
| ★ | Support — 辅助类型 |

### Confidence Levels

| Level | Meaning | Example |
|---|---|---|
| `HIGH` | 文档/注释佐证 | 有 godoc 注释说明职责 |
| `MEDIUM` | 代码推断，有命名提示 | 从方法名推断 |
| `LOW` | 纯结构推断 | 仅从 struct 字段推断 |
| `?` | 未确认，需人工 review | Grill 过程中确认 |

## Instruction Layer Fields

### Sections

| Section | Required | Content |
|---|---|---|
| `## Build & Test Commands` | Yes | 构建/测试/lint/安全扫描命令 |
| `## Code Conventions` | Yes | 命名、文件组织、错误处理、DI、测试约定 |
| `## Invariants` | If any | 绝对不能违反的红线 |
| `## Domain Glossary` | If any | 领域术语表（消除歧义） |

### Confirmation Tags

| Tag | Meaning |
|---|---|
| `[confirmed]` | 人工确认过 |
| `[auto]` | 自动推断，未经确认 |
