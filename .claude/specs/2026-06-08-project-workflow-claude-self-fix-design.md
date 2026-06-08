# Project Workflow Claude v2.3 自修复 — 设计规范

> 状态：Phase 1 | 日期：2026-06-08 | 会话：e91863f3

## 1. 范围

修复 `project-workflow-claude` SKILL.md、CONTEXT.md、`setup.md` 和工作流脚本中的 **13 个已识别问题**。本次不更改其他 15 个 skills。

## 2. 方法

**策略**：对已识别的问题进行外科手术式修复 — 不重新设计，不重构。每个修复都是最小化的、有针对性的，并有清晰的 before/after。

**受影响的文件**：8 个文件
- `skills/project-workflow-claude/SKILL.md` — 主要修复目标（6 项更改）
- `skills/project-workflow-claude/references/setup.md` — 添加 DeepSeek 文档
- `CONTEXT.md` — 刷新过时的 `[auto]` 条目（3 项更改）
- `.claude/workflows/phase3-consensus.js` — 审查 + 修复
- `.claude/workflows/phase4-implement.js` — 审查 + 修复
- `.claude/workflows/phase5-review.js` — 审查 + 修复
- `.claude/workflows/phase6-verify.js` — 审查 + 修复
- `install.sh` — 如有需要，审查 + 修复

## 3. 详细修复

### 3.1 SKILL.md 修复

#### 修复 1：第 12 行 — 错误的工作流脚本路径
**Before**：`~/.claude/workflows/project-workflow-claude/phase4-implement.js`
**After**：`~/.claude/workflows/phase4-implement.js`
**为什么**：install.sh 直接将脚本复制到 `~/.claude/workflows/`（扁平结构）。嵌套路径 `project-workflow-claude/` 在任何地方都不存在。
**验证**：`grep "project-workflow-claude/phase" skills/project-workflow-claude/SKILL.md` → 0 个匹配项

#### 修复 2：Frontmatter — 添加 triggers 字段
**After**（在 `standalone: true` 之后添加）：
```yaml
triggers:
  - "start task"
  - "implement"
  - "build"
  - "develop"
  - "add feature"
  - "fix bug"
  - "refactor"
  - "code change"
  - "write code"
```
**为什么**：没有显式的触发关键词，Claude Code 的技能匹配仅依赖于描述解析，这不可靠。
**验证**：`grep "triggers:" skills/project-workflow-claude/SKILL.md` → ≥ 1 个匹配项

#### 修复 3：第 692 行 — macOS grep 兼容性
**Before**：`grep -oP 'references/[a-z0-9-]+\.md'`
**After**：`grep -oE 'references/[a-z0-9-]+\.md'`
**为什么**：BSD grep（macOS）不支持 `-P`（Perl regex）。`-E`（扩展正则表达式）在所有平台上都有效。在 SKILL.md 引用文件名的上下文中，`[a-z0-9-]` 是 POSIX 标准的。
**验证**：`grep "grep.*-P" skills/project-workflow-claude/SKILL.md` → 0 个匹配项

#### 修复 4：第 16 行 — 版本引用
**Before**：`Claude Code v2.1+`
**After**：`Claude Code v2.3+`

#### 修复 5：Phase 0 — Glob 回退方案
在 Phase 0 第 1 步的开头添加：
```
If Glob tool is not available in your environment, fall back to Bash(find ...) commands.
```
对于每个 Glob 调用，添加后备模式：
- Glob 失败 → `Bash(command='find . -name "go.mod" -type f')`

#### 修复 6：技能数量引用 — 76 → 16
在 SKILL.md 中搜索并修复所有出现 `76` 技能的地方。实际的技能数量是 16。

### 3.2 setup.md 修复

#### 修复 7：添加 DeepSeek API 注意事项
在末尾添加新章节：

```markdown
## DeepSeek API Notes

DeepSeek's API (`api.deepseek.com/anthropic`) is Anthropic-compatible but has important differences:

### Thinking ≠ Extended Thinking
- DeepSeek's `reasoning_effort` is NOT the same as Anthropic's Extended Thinking
- The `[1m]` suffix in model names (e.g., `deepseek-v4-pro[1m]`) controls context window size — NOT thinking budget
- DeepSeek auto-decides thinking depth; `/effort` may have limited effect

### Known Issue: Agent Subagent Conflict
When `ANTHROPIC_DEFAULT_SONNET_MODEL` or `ANTHROPIC_DEFAULT_HAIKU_MODEL` are set to a model with `reasoning_effort` (e.g., `deepseek-v4-pro[1m]`), spawning Agent subagents fails with:

```
Error: 400 thinking options type cannot be disabled when reasoning_effort is set
```

**Root cause**: Claude Code's Agent tool disables thinking for non-opus subagents, but DeepSeek's API
requires `thinking.type` to be `enabled` when `reasoning_effort` is set in the request.

**Recommended fix**: In settings.json, set lighter models to versions without reasoning:
```json
{
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash"
}
```
```

### 3.3 CONTEXT.md 修复

#### 修复 8：过时的 `[auto]` 条目
三项更改：
1. `Skill count (~76): Medium` → `Skill count (16): High (confirmed by directory listing)`
2. `Workflow scripts consume phase-specific JSON state files from .omc/state/` → `Workflow scripts consume JSON args from the Workflow tool and return structured results`
3. `triggers, dependencies fields` → `version, metadata fields`

### 3.4 工作流脚本审查

每个脚本审查以下内容：
- 对其他技能文件的错误引用
- 硬编码路径
- OMC 状态引用（应为 standalone）
- 语法有效性

如果没有问题：记录为"已审查 — 无需更改"。

### 3.5 install.sh 审查

检查过时的版本引用。已确认 v2.3 是最新的（在之前的更新中已修复）。

## 4. 验证计划

| # | 命令 | 预期结果 |
|---|---------|--------|
| 1 | `grep "project-workflow-claude/phase" skills/project-workflow-claude/SKILL.md` | 0 个匹配项 |
| 2 | `grep "triggers:" skills/project-workflow-claude/SKILL.md` | ≥ 1 个匹配项 |
| 3 | `grep "v2\.1" skills/project-workflow-claude/SKILL.md` | 0 个匹配项 |
| 4 | `grep "grep.*-P" skills/project-workflow-claude/SKILL.md` | 0 个匹配项 |
| 5 | `grep "\[auto\]" CONTEXT.md \| grep "76"` | 0 个匹配项 |
| 6 | `grep "OMC\|omc" CONTEXT.md` | 0 个匹配项 |
| 7 | `bash install.sh` | 无错误退出 |
| 8 | `git diff --check` | 无错误退出 |
| 9 | 语义：Phase 0 包含 Glob fallback 语言 | ✓ |

## 5. 风险

| 风险 | 缓解措施 |
|------|------------|
| 工作流脚本审查可能会发现需要扩展范围的 bug | 假设 [S1] — 如果发现则通知用户 |
| `grep -oE` 行为可能因平台而异 | 低风险 — 引用文件名仅有字母数字 + 破折号 |
| DeepSeek API 子代理修复需要更改 settings.json | 范围外，仅在 setup.md 中记录 |

## 6. Grill 证据

| 歧义 | 决策 |
|------------|----------|
| A1：触发关键词 | 9 个关键词：开始任务、实现、构建、开发、添加功能、修复错误、重构、代码更改、编写代码 |
| A2：Glob 回退位置 | Phase 0 第 1 步，每个 Glob 调用带注释回退 |
| A3：DeepSeek 文档位置 | setup.md 末尾的新章节 |
| A4：CONTEXT.md 修复范围 | 只修复 3 个明显错误，保持结构 |

| 假设 | 置信度 |
|------------|------------|
| S1：工作流脚本没有关键 bug | 中 |
| S2：grep -oP 在所有 macOS 版本上都会失败 | 高 |
| S3：工作流脚本语法有效 | 中 |
