# Design Spec: project-workflow-claude Error Hardening

---

## 1. Metadata

- **Title:** Error Hardening for project-workflow-claude — Workflow Parse Errors + Edit Precision
- **Version:** v1.0
- **Author:** Jessy Huang
- **Date:** 2026-06-11
- **Status:** Draft
- **Related Files:**
  - `.claude/workflows/phase4-implement.js` — Phase 4 enrichment gap
  - `.claude/workflows/phase5-review.js` — Reference implementation (has enrichment)
  - `.claude/state/project-workflow-state.json` — Stale state
  - `skills/project-workflow-claude/SKILL.md` — Phase list reference
  - `.claude/skills/reviewing-implementation/SKILL.md` — Review skill prompt (if exists)
  - `.claude/skills/implementing-changes/SKILL.md` — Implement skill prompt (if exists)
  - `60b27dfc-...jsonl` (mixclaw session) — Error evidence

---

## 2. Problem Statement

用户在运行 project-workflow-claude 时遇到两类硬错误：

1. **Workflow Parse Error:** 执行 Workflow 脚本时，Claude CLI 抛出 `"Invalid workflow script: Script parse error: Unexpected token (78:2). Workflow scripts must be plain JavaScript — TypeScript syntax (type annotations like ': string[]', interfaces, generics) fails to parse."` 导致 Workflow 直接失败，无法启动子 agent。

2. **Edit Exact-String 失败:** 子 agent 使用 Edit 工具修改文件时，频繁抛出 `"Error editing file: String to replace not found"`。agent 花费多轮尝试确认文件内容、修复 old_string 格式，每次浪费 5-15 分钟和数千 token。

还有两类未直接报错但贡献失败率的软问题：

3. **Stale 冗余编辑:** old_string 与 new_string 完全相同（因为代码已被前一步修改），抛出 `"No changes to make: old_string and new_string are exactly the same"`。

4. **Phase 4 缺乏 context 注入:** implement 子 agent 收不到 fileContents/diffText/grillDecisions/planSections，导致基于过时上下文发起 Edit。

---

## 3. Evidence-Backed Root Causes

### 3.1 Workflow Parse Error — TypeScript 语法入侵

**Evidence (JSONL `60b27dfc-...jsonl:1118-1119`):**

Line 1118 包含 agent 生成的 Workflow 脚本，包含以下结构（为脚本内部的任务定义使用了内联类型注解风格的对象属性）：

```javascript
// 脚本中 specCheck 字段的值是字符串，本身不是问题
// 但 schema 的 properties 中包含了 TypeScript 风格的注解
const tasks = [
  {
    id: 'gf-01-tenant-config-table',
    description: 'EnsureTenantConfigTable in tenant_config.go',
    files: ['internal/repository/tenant_config.go'],
    specCheck: 'Does it create mixiot_tenant_config table with correct columns?',
    // 这些字段本身是普通 JS，不是问题
  }
]

// 关键：当 agent 用 TS 的 type 标注语法写 schema 时，解析失败
// "Unexpected token (78:2)" — 第 78 行第 2 列是 ")" 或类似的纯 JS 不支持的结构
```

Line 1119 的错误响应：
```
"Invalid workflow script: Script parse error: Unexpected token (78:2). Workflow scripts must be plain JavaScript — TypeScript syntax (type annotations like `: string[]`, interfaces, generics) fails to parse."
```

**根本原因 (Inference):**

- **Agent prompt 中缺乏"只允许 plain JS"的硬性规约。** SKILL.md 的 authoring prompt 没有明确禁止 TypeScript 语法。
- Workflow parser 使用 `node --check` 或 `acorn` 等 pure-JS parser，不接受 `type`、`interface`、泛型 `<T>`、`as` 类型断言、以及嵌入 schema 中的 TS 类型注解。
- Agent 在编写复杂 schema（包含 `type: 'object'` + `properties` 深层嵌套）时，容易顺带写出 TypeScript 风格。

**验证方法 (Unknown):** Workflow parser 的内部实现未公开。但从错误信息 `"plain JavaScript"` 可以确认 parser 拒绝 TS。

### 3.2 Edit Exact-String 失败 — old_string 与文件内容不匹配

**Evidence (JSONL `60b27dfc-...jsonl:773-774, 784`):**

Line 773 — agent 发起 Edit 调用，old_string 使用了错误格式：
```
"old_string": "\tRetriever interface {\n\t\tSearch(ctx context.Context, query string, topK int) ([]SearchResult, error)\n\t}"
```
这个 old_string 以 tab + `Retriever interface {` 开头。

Line 784 — 实际的 Python bytes 检查显示文件内容是：
```
89: 'type Retriever interface {\n'
```
以 `type Retriever interface {` 开头（包含 `type` 关键字）。

**根本原因 (Evidence):** old_string 遗漏了 `type` 关键字。agent 从内存中的类型定义反向推断 old_string，而不是先 Read 文件确认精确内容。

**其他实例 (JSONL 693, 704, 724, 745, 751, 757, 798):** 同一 session 中共 7 次 `"String to replace not found"` 错误，分布在不同的文件（main.go, qdrant.go, types.go, index.go）。每次 agent 都花费 1-3 轮额外的 Read + Edit 重试来恢复。

### 3.3 Stale 重复编辑 — old_string 与 new_string 相同

**Evidence (JSONL `60b27dfc-...jsonl:1168-1169`):**

Line 1168 — agent 发起 Edit，old_string 和 new_string 完全一样：
```
"old_string": "// TenantSearcher is an optional interface...\n\tTenantSearcher interface {\n\t\tSearchWithTenant...\n\t}"
"new_string": "// TenantSearcher is an optional interface...\n\tTenantSearcher interface {\n\t\tSearchWithTenant...\n\t}"
```

Line 1169 — 错误响应：
```
"No changes to make: old_string and new_string are exactly the same."
```

**根本原因 (Inference):** 模型记忆了之前添加 TenantSearcher 的编辑操作，但未能确认该代码已存在于文件中。agent 应该先 Read 确认当前文件状态，但 prompt 没有要求"修改前先 Read 确认文件最新内容"。

### 3.4 Phase 4 缺乏 context 注入

**Evidence (`/home/huangzexi/personal/jessy-skills/.claude/workflows/phase4-implement.js`):**

`buildImplementerPrompt()` 函数（line 60-104）从 task 对象读取以下字段：
- `task.prompt` ✓
- `task.contextRefs` ✓
- `task.intakeRefs` ✓
- `task.grillRefs` ✓
- `task.expectedEvidence` ✓
- `task.forbiddenEvidence` ✓
- `task.patchBackStrategy` ✓

**缺失字段 (grep 显示完全不读取):**
- `task.fileContents` — **缺失**
- `task.diffText` — **缺失**
- `task.grillDecisions` — **缺失**
- `task.planSections` — **缺失**

**对比 (Evidence):** `phase5-review.js` 的 `enrichTaskForReview()`（line 189-254）已经完整读取 `task.fileContents`、`task.grillDecisions`、`planText`、`grillEvidence`。Phase 4 缺少了这些字段。

**影响 (Inference):** implement 子 agent 只能靠回忆或重新 Read 来获取文件内容和设计决策。没有 fileContents 注入时，agent 容易使用过时的内存状态构造 Edit 的 old_string。

### 3.5 状态文件过期

**Evidence (`/home/huangzexi/personal/jessy-skills/.claude/state/project-workflow-state.json`):**

```json
{
  "currentSkill": "finishing-development",
  "lastCompletedSkill": "verifying-completion",
  "contextSummaryPath": ".claude/state/context-summary.json",
  ...
}
```

- `currentSkill=finishing-development` — 显示上一个运行周期未正常结束
- `contextSummaryPath` 指向的文件 `.claude/state/context-summary.json` **不存在**（`ls` 验证：state/ 目录下只有 grill-evidence.json, project-workflow-state.json, task-intake.json, verification-results.json）
- 无 `status: "idle"` 标记，新任务开始前未重置

**根本原因 (Inference):** workflow 的 state 初始化逻辑仅在首次运行创建 state，未处理"已存在过期 state"的情况。SKILL.md 的启动流程没有 `resetIfStale()` 步骤。

### 3.6 Workflow 脚本分布不一致

**Evidence:**
- **Project `.claude/workflows/`:** phase3-consensus.js, phase4-implement.js, phase5-review.js, phase6-verify.js（4 个脚本，缺 phase1/phase2）
- **Global `/home/huangzexi/.claude/workflows/`:** phase1-detect-knowledge.js, phase2-plan-generate.js, phase3-consensus.js, phase4-implement.js, phase5-review.js, phase6-verify.js（6 个脚本齐全）
- **SKILL.md line 59-64:** 列出 phase1 → phase6，与 project 目录不匹配

**影响 (Inference):** 如果主 agent 尝试从 project 目录加载 phase1/phase2 脚本将失败，而 global 有但可能版本不同。虽然当前 SKILL.md 描述的执行顺序是先由主 agent 执行 phase1/phase2 再调用 phase3-6 脚本，但 project 目录缺少前端脚本是个隐患。

---

## 4. Scope

### In Scope (本次设计范围)
1. **Workflow 纯 JS 规约** — 在 authoring prompt（SKILL.md）和 review skill prompt 中注入"Workflow 脚本必须只使用 Plain JavaScript，禁止任何 TypeScript 语法"规则
2. **Phase 4 注入对齐** — phase4-implement.js 增加 `fileContents`、`diffText`、`grillDecisions`、`planSections` 字段读取和注入逻辑
3. **Edit 安全规则** — 在 implementer prompt 中注入：修改前先 Read 确认文件内容、提取唯一 old_string（包含足够上下文行）、修改失败后尝试缩小匹配范围（`replace_all` 策略）、禁止 old_string===new_string
4. **状态初始化和重置** — 新增 state 验证逻辑（`resetIfStale` 模式）、处理 contextSummaryPath 不存在的情况
5. **回归探测** — 新增验证探针
   - Workflow 脚本 dry-run parse check: `node --check .claude/workflows/*.js`
   - 受控 Edit 探测：以 `type Retriever interface {` 为例验证 Edit 不会报 string-not-found

### Out of Scope (本设计不包括)
1. **Project/Global workflow 脚本一致性对齐**（phase1/phase2 在 project 和 global 的一致性—范围太大，需单独处理）
2. **修改 Go 业务代码**（qdrant.go, index.go 等内容修复不在本设计范围）
3. **gopls LSP 配置**（改用 gopls-lsp plugin 编辑文件的方案需要独立评估）
4. **Phases 1-2 脚本创建**（project 目录缺少 phase1/phase2 脚本的修复）

---

## 5. Design Goals

| # | Goal | Measurable Criteria |
|---|------|-------------------|
| G1 | 防止 Workflow parse error | 所有 `.claude/workflows/*.js` 通过 `node --check` + 1 次 dry-run |
| G2 | 减少 Edit 失败率 | 受控 probe 实测: 连续 3 次 Edit 不出现 string-not-found |
| G3 | 子 agent 获得最新文件内容 | Phase 4 注入 fileContents，agent 不依赖过时内存 |
| G4 | 验证门显式且强制 | 回归探针作为 verifying-completion 的 evidence check |
| G5 | 新任务开始时状态干净 | `resetIfStale()` 检查并处理过期 state |

---

## 6. Proposed Approach (Recommended: Minimal Patch)

选择 **最小补丁方案** — 只修改 prompt 和脚本注入，不重写 workflow 脚本。理由如下：

### Alternative A: Full Rewrite — 风险过高
- 所有 4 个 workflow 脚本已调优多轮
- 重写引入新 bug 的风险高于收益
- 核心问题不在脚本逻辑，在 prompt 和注入

### Alternative B: Do Nothing — 不解决问题
- 用户继续遇到 parse error 和 Edit 失败
- 每次失败浪费 5-15 分钟
- 信任度损耗

### Recommended: Minimal Patch (选此方案)
- 修改 4 个文件（SKILL.md + 1 个脚本 + 2 个 prompt/rule 文件）
- 不改变现有逻辑流
- 通过回归探针验证效果

---

## 7. Detailed Design

### 7.1 Workflow 纯 JS 规约

**修改位置:**
- `skills/project-workflow-claude/SKILL.md` — 在 Workflow Scripting 章节添加规则
- `.claude/skills/reviewing-implementation/SKILL.md` — review skill 的 prompt 中注入（阻止 review agent 生成 TS 脚本）
- `.claude/skills/implementing-changes/SKILL.md` — implement skill 的 prompt 中注入

**注入内容:**
```
## Workflow Script Rules (HARD)
1. Workflow scripts MUST be plain JavaScript ONLY.
2. FORBIDDEN: TypeScript type annotations (`: string`, `: number[]`, `: MyInterface`), interfaces, generics (`<T>`), type assertions (`as string`), enums.
3. FORBIDDEN: Arrow functions with type annotations. Use `function() {}` instead.
4. All schema definitions must use plain JS objects with string values for property types: `{type: 'object', properties: {name: {type: 'string'}}}`.
5. All variable declarations: `var` or `const` with no type annotation.
6. After writing the script, ALWAYS parse-verify with `node --check <scriptPath>` before passing to Workflow().
7. If the Workflow() call returns a parse error, inspect the error line number, remove ALL TypeScript syntax from that line and surrounding lines, and retry.
```

### 7.2 Phase 4 注入对齐

**修改位置:**
- `.claude/workflows/phase4-implement.js`

**修改内容 (3 处):**

**A) Task schema default 扩展（line 19-28）** — 添加默认值：
```javascript
t.fileContents = t.fileContents || {}
t.diffText = t.diffText || ''
t.grillDecisions = t.grillDecisions || []
t.planSections = t.planSections || ''
```

**B) `buildImplementerPrompt()` 函数扩容（在 line 103 前）** — 追加注入块：
```javascript
// File contents injection
var fileContentKeys = Object.keys(task.fileContents || {})
if (fileContentKeys.length > 0) {
  parts.push('\n## Current File Contents\n')
  for (var k = 0; k < fileContentKeys.length; k++) {
    parts.push('### ' + fileContentKeys[k] + '\n```\n' + (task.fileContents[fileContentKeys[k]] || '') + '\n```\n')
  }
}

// Diff text
if (task.diffText) {
  parts.push('\n## Git Diff (changed lines)\n```diff\n' + task.diffText + '\n```')
}

// Grill decisions
if (task.grillDecisions && task.grillDecisions.length > 0) {
  parts.push('\n## Design Decisions\n' + task.grillDecisions.join('\n'))
}

// Plan sections
if (task.planSections) {
  parts.push('\n## Task Section from Plan\n' + task.planSections)
}
```

**C) `agent()` schema 输出扩容（line 114-131）** — 无需修改，现有 `changedFiles` + `summary` 已足够。

### 7.3 Edit 安全规则

**修改位置:**
- `.claude/skills/implementing-changes/SKILL.md` — implement skill 的 prompt

**注入内容 (Edit Safety 部分):**
```
## Edit Tool Safety Rules (HARD)
1. ALWAYS Read the target file first to get EXACT content before calling Edit.
2. The `old_string` must be an EXACT byte-for-byte match of the file content. Check indentation (tabs vs spaces), punctuation, and surrounding whitespace.
3. Include enough context lines (at least 2-3 lines of surrounding code) to make the match unique.
4. If Edit returns "String to replace not found": (a) Read the actual file content at the target location, (b) Copy the exact text from the Read result into `old_string`, (c) NEVER guess the indentation.
5. NEVER set `old_string` and `new_string` to the same value — this is a no-op and will be rejected.
6. After a successful edit, use Read to confirm the change was applied correctly before proceeding.
7. If multiple attempts fail, switch to Bash (Python or sed) for the edit instead of Edit tool.
8. Prefer `replace_all: true` when renaming a symbol that appears multiple times.
```

### 7.4 状态初始化/重置

**修改位置:**
- `skills/project-workflow-claude/SKILL.md` — 在启动流程中添加 state validation

**新增函数 (作为启动流程的步骤 0):**
```
## State Initialization Protocol
1. Before starting any task, read `.claude/state/project-workflow-state.json`.
2. If state exists and `status` is not "idle":
   a. Check if `contextSummaryPath` file exists.
   b. If file does NOT exist, log warning and set `contextSummaryPath: null`.
   c. If `currentSkill` points to an invalid skill, reset to null.
   d. Create a backup of old state as `project-workflow-state.json.bak`.
   e. Set `status: "idle"` and reset `currentSkill`, `lastCompletedSkill`, `nextSkill` to null.
3. If no state file exists, create fresh state with `status: "idle"`.
4. Write updated state back.
```

### 7.5 回归探测

**验证探针定义 (implement skill prompt 或 verifying-completion skill prompt):**

```
## Regression Probes (must pass before completion claim)

1. **Workflow Parse Check:** Run `node --check .claude/workflows/*.js` and confirm all scripts parse as valid JavaScript.

2. **Controlled Edit Probe:**
   a. Create a temporary Go file: `/tmp/edit-probe/types.go` with content:
      ```go
      type Retriever interface {
          Search(ctx context.Context, query string, topK int) ([]SearchResult, error)
      }
      ```
   b. Use Edit to replace `Search` with `SearchWithContext` using `old_string` "type Retriever interface {\n\tSearch(ctx context.Context, query string, topK int) ([]SearchResult, error)\n}".
   c. Verify the Edit succeeds on first attempt (no "String to replace not found").
   d. Clean up /tmp/edit-probe/types.go.

3. **Phase 4 Enrichment Check:**
   a. Verify phase4-implement.js contains `task.fileContents`, `task.diffText`, `task.grillDecisions`, `task.planSections` references.
   b. Grep count of each field: `grep -c 'task\.fileContents' .claude/workflows/phase4-implement.js`.

4. **State Cleanliness Check:**
   a. If `.claude/state/project-workflow-state.json` exists, verify `status` is "idle" or `contextSummaryPath` is null/missing is handled gracefully.
```

---

## 8. Success Criteria

| # | Criterion | How to Verify | Evidence Required |
|---|-----------|---------------|-------------------|
| SC1 | 所有 workflow 脚本通过 `node --check` | 运行 `node --check .claude/workflows/*.js` | stdout 无错误 |
| SC2 | 修改后的脚本 dry-run 成功 | 在测试 task 中运行 Workflow() | Workflow 启动成功 |
| SC3 | implementer prompt 包含 Edit safety 规则 | 检查 `.claude/skills/implementing-changes/SKILL.md` | Edit Tool Safety Rules 段落存在 |
| SC4 | review skill prompt 包含 Plain JS 规则 | 检查 `.claude/skills/reviewing-implementation/SKILL.md` | Workflow Script Rules 段落存在 |
| SC5 | Phase 4 注入字段存在 | grep phase4-implement.js | fileContents, diffText, grillDecisions, planSections 各至少 2 处引用 |
| SC6 | 受控 Edit 探测通过 | 执行上述 probe | 首次 Edit 成功，无 string-not-found |
| SC7 | 新任务启动时 state 干净 | 创建测试 task 验证 | 旧 state 备份，新 state 为 idle |

---

## 9. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Prompt-only 规则被模型忽略 | Medium | High | 回归探测门 (SC6) — 失败则阻塞完成 |
| Phase 4 注入增加 token 消耗 | High | Low-Medium | 只注入 task 实际涉及的文件内容 (`fileContentKeys.length > 0` 时注入)；大文件只注入相关片段 |
| State 重置删除有用历史 | Low | Medium | 备份旧 state (`*.bak`) 后再重置 |
| Workflow 脚本修改引入新 bug | Low | Medium | 只加法修改 (append 字段)，不修改现有逻辑流程 |
| Edit 安全规则过于严格导致 agent 过度谨慎 | Low | Low | 规则第 7 条提供兜底方案 (Python/sed) |
| SKILL.md 中嵌入大量规则后 skill 响应变慢 | Medium | Low | 规则是可执行指令，不是对话内容；agent 只会按需使用 |
| Modify 4 个文件后，不同 agent 版本出现不一致 | Low | Medium | 所有修改在同一提交中，原子性回滚 |

---

## 10. Assumption Ledger

| Assumption | Confidence | Rationale |
|------------|-----------|-----------|
| Workflow parser 拒绝任何 TS 语法 | High | 确认信息："plain JavaScript — TypeScript syntax fails to parse" (line 1119) |
| 子 agent Edit 失败的主因是 prompt 质量而非工具 bug | Medium | 7 次连续失败后 agent 能通过 Python 成功编辑，说明工具正常 |
| 注入 fileContents 可以减少 Edit 失败 | Medium | 需通过 probe 验证；当前无直接统计 |
| state 过期一定会导致下次启动异常 | Low | 当前 SKILL.md 的启动顺序中 agent 的状态更新逻辑可以覆盖过期文件 |
| `.claude/plans/` 中过期的模板不会被 live workflow 复用 | Medium | 未知 — 未验证 live workflow 是否重新生成计划还是重读旧文件 |
| 用户期望"新任务 = 干净状态" | High | workflow state 的 `runMode` 和 `currentSkill` 指向旧 session 显然不正常 |

---

## 11. Unknowns

| Unknown | Why It Matters | How to Resolve |
|---------|---------------|----------------|
| Workflow parser 的内部实现细节 (acorn/swc/node --check) | 帮助精确制定语法禁止清单 | 尝试在本地复现 78:2 错误，观察 parser 行为 |
| `.claude/plans/` 中过期的模板文件是否会被 live workflow 复用 | 如果是，需要添加 plan freshness 检查 | 检查 phase2-plan-generate.js 的输出；添加 plan 文件的 `generatedAt` 时间戳比较 |
| 当前 project workflow 脚本在不含 phase1/phase2 时主 agent 如何回退 | 回退机制的健壮性影响启动成功率 | 检查 SKILL.md 的 phase1/phase2 执行逻辑：主 agent 是否直接执行而不是调用脚本 |
| Edit 工具在 containter/远程环境下的行为差异 | 隔离的工作目录 (worktree) 下 file path 解析不同 | 在 phase4-implement 的 worktree isolation 分支中验证 Edit 路径传递 |
