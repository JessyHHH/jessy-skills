# CONTEXT.md 双层结构 + Phase 0.3 重设计 — Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** 将 project-workflow Phase 0.3 从仅支持 Go 的"实体黄页"升级为支持全部项目类型的"双层 AI 操作手册 + 知识地图"。

**Architecture:** 修改 project-workflow SKILL.md 的 Phase 0.3（重写），统一三个 references 的版本号到 v7.0，新增 CONTEXT.md 格式规范文件。不涉及其他 Phase 逻辑变更。

**Tech Stack:** Markdown（SKILL.md 文件），无代码依赖。

---

## Task 1: 新增 CONTEXT.md 格式规范 reference

**Objective:** 创建 `references/context-md-spec.md`，定义双层标记、字段、置信度等级。

**Files:**
- Create: `skills/project-workflow/references/context-md-spec.md`

**Actions:**

Step 1: 创建文件

写入以下内容到 `skills/project-workflow/references/context-md-spec.md`：

```markdown
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
```

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
```

Step 2: 验证

```bash
test -f skills/project-workflow/references/context-md-spec.md && echo "PASS"
```

---

## Task 2: 重写 Phase 0.3 和调整 Phase 0 auto-transition

**Objective:** 替换 project-workflow SKILL.md 的 Phase 0.3 为新设计，调整 Phase 0 末尾的 auto-transition。

**Files:**
- Modify: `skills/project-workflow/SKILL.md`

**Actions:**

### Step 1: 替换 Phase 0 的 auto-transition 描述

找到 `**Auto-transition: Launch Phase 0.3 and Phase 0.5 in parallel.**` 这段，替换为：

```markdown
   **Auto-transition: Launch Phase 0.3 and Phase 0.5.**
   - Phase 0.3: analysis + CONTEXT.md generation — runs first (HARD-GATE)
   - Phase 0.5: task signal matching + skill loading — runs after 0.3 completes
   - Phase 0.5 augments from Phase 0.3 findings → Phase 1

   **Exit:** `Phase 0 complete. [type] detected. → Phase 0.3.`
```

### Step 2: 完全替换 Phase 0.3 内容

找到 `## Phase 0.3: Pre-Task Codebase Analysis` 整段（从该标题到下一个 `## Phase 0.5` 之前），替换为：

```markdown
## Phase 0.3: Codebase Analysis + CONTEXT.md Generation

<HARD-GATE>
CONTEXT.md missing OR commit SHA ≠ HEAD → MUST run Phase 0.3.
Skip ONLY when CONTEXT.md exists AND commit matches AND announced with reason.
适用于全部项目类型（Go / Vue / Node / Skills Repository），无例外。
</HARD-GATE>

**Goal:** Analyze codebase → generate/refresh CONTEXT.md (Knowledge Layer + Instruction Layer skeleton). Ground all subsequent phases in real code, not assumptions.

**Procedure:**

1. **Check CONTEXT.md freshness:**
   - If `CONTEXT.md` exists: read commit SHA from header → compare with `git rev-parse HEAD`
   - Match → announce "CONTEXT.md fresh (commit <sha>), skipping analysis." → skip to Phase 0.5
   - No match or no CONTEXT.md → proceed to step 2

2. **Announce:** "**Phase 0.3: Codebase Analysis** — understanding the project before proceeding."

3. **Branch by project type** (detected in Phase 0):

   ```
   Phase 0.3: Codebase Analysis
     │
     ├── Go 项目（有 go.mod + .go 文件）
     │   └── delegate_task(go-analysis) → Knowledge + Instruction 骨架
     │
     ├── Vue/Node 项目（有 package.json）
     │   └── delegate_task(fe-analysis) → 组件树 + 路由 + 状态管理
     │
     └── Skills Repository（有 skills/*/SKILL.md）
         └── delegate_task(skills-analysis) → SKILL.md 结构 + 引用完整性
   ```

4. **For Go projects:** Run `delegate_task`:
   ```
   delegate_task(
     goal="Deep read-only analysis.

   Part A — Architecture: error handling patterns, DI approach, concurrency model,
     testing conventions, file organization. Confidence level per finding.

   Part B — Entity Map: all main structs with relationships.
     Format: Name ★★★/★★/★ (CONFIDENCE). Source: path/to/file.go:line.
     Rules: mark all inferred meanings, skip helper types, max 15 entities.

   Part C — Key Interfaces: abstracts that define system boundaries.
     Include source path, implementations, invariants.

   Part D — Package Map: directory → responsibility (1 line each).

   Part E — Instruction Layer skeleton: build/test/lint commands from Phase 0 detection,
     coding conventions inferred from code patterns.

   Output: full CONTEXT.md with BOTH Knowledge Layer and Instruction Layer
   (using <!-- KNOWLEDGE_START --> / <!-- KNOWLEDGE_END --> wrappers).
   Header MUST include: Commit: <sha> | Date: <iso> | Go <version>.
   Follow format spec in references/context-md-spec.md.",
     context="Project: <path>. Go version: <version>. Task: <summary>.",
     toolsets=["terminal", "file"]
   )
   ```

5. **For Skills Repository:** Run `delegate_task`:
   ```
   delegate_task(
     goal="Analyze this Skills Repository.

   Part A — SKILL.md inventory: count total skills, categorize by directory,
     list auto_load skills, detect version mismatches (frontmatter vs directory name).

   Part B — Reference integrity: for each skill, verify referenced files in
     references/ exist. Flag broken references with [BROKEN] marker.

   Part C — Structure map: directory tree showing skill categories and nesting.

   Part D — Instruction Layer skeleton: extract common patterns from skill
     references (build commands, testing conventions, naming rules).
     Suggest invariants from repeated patterns across skills.

   Output: full CONTEXT.md with Knowledge Layer (inventory + structure) and
   Instruction Layer (common patterns as conventions).
   Follow format spec in references/context-md-spec.md.
   Header MUST include: Commit: <sha> | Date: <iso> | Skills Repository.",
     context="Project: <path>. Skill count: <N>. Task: <summary>.",
     toolsets=["terminal", "file"]
   )
   ```

6. **Write/overwrite CONTEXT.md** from delegate_task output:
   - `write_file(path='CONTEXT.md', content=<output>)`
   - Full overwrite — no merge. The analysis is the source of truth.
   - If subdirectory CONTEXT.md files exist, leave them untouched (hand-merge if conflicts found in cross-validation).

7. **Generate Instruction Layer skeleton** (if delegate_task didn't already):
   - Insert build/test/lint commands detected in Phase 0
   - Mark all entries with `[auto]` tag
   - Template sections: `## Build & Test Commands`, `## Code Conventions`, `## Invariants`

8. **Cross-validation** (lightweight, inline):
   - Sample 5 entity Source paths → `search_files` verify existence
   - Architecture claims vs go.mod: if "uses samber/oops" → grep go.mod for samber/oops
   - If subdirectory CONTEXT.md exists → diff for conflicting declarations
   - Log failures but don't block

9. **Announce results to user** (MUST be visible):
   ```
   "Phase 0.3: Codebase Analysis — [project-type], commit <sha>

   Knowledge Layer: generated
     - Architecture: <N> patterns (error handling, DI, ...)
     - Entity Map: <N> entities, <N> relationships, <N> interfaces
     - Confidence: HIGH <N> / MEDIUM <N> / LOW <N>
     - Package structure: <N> directories mapped

   Instruction Layer: skeleton ready
     - Commands: build, test, lint, security
     - Conventions: <N> patterns detected [auto]
     - Invariants: template (fill during Phase 1 Grill)

   Cross-validation: 5/5 paths exist ✓ | go.mod consistency ✓ | subdirectory conflicts 0

   → CONTEXT.md written."
   ```

10. **Use analysis results to:**
    - Inform Phase 0.5 skill selection (auto-load skills detected from codebase patterns)
    - Ground Phase 1 design questions in real code
    - If user only asked a question (not a change request): answer from analysis directly. STOP.

11. **Auto-transition to Phase 0.5.**

    **Exit:** `Phase 0.3 complete. [project-type] analyzed. CONTEXT.md written (commit <sha>). → Phase 0.5.`
```

### Step 3: 验证替换完整性

```bash
# 验证新 Phase 0.3 包含 HARD-GATE
grep -c "HARD-GATE" skills/project-workflow/SKILL.md
# Expected: increased by 1 (new HARD-GATE)

# 验证新 Phase 0.3 包含 Skills Repository 分支
grep -c "Skills Repository" skills/project-workflow/SKILL.md
# Expected: increased

# 验证 Phase 0 auto-transition 不再说 "parallel"
grep -c "parallel" skills/project-workflow/SKILL.md
# Expected: decreased
```

---

## Task 2.5: Phase 0.5 step 7 联动更新 + Phase 0 announce 补充

**Objective:** Phase 0 auto-transition 从 parallel 改为 sequential 后，Phase 0.5 step 7 的措辞需要同步。同时补充 Phase 0 对 Skills Repository 类型的 announce 格式。

**Files:**
- Modify: `skills/project-workflow/SKILL.md`

**Actions:**

### Step 1: 修复 Phase 0.5 step 7 的 "parallel" 措辞

找到 Phase 0.5 的 step 7：

```
7. **Augment from Phase 0.3 findings** (runs after Phase 0.3 completes):
   - Phase 0.3 runs in parallel with the selection above. When it finishes, scan...
```

替换为：

```markdown
7. **Augment from Phase 0.3 findings** (runs after Phase 0.3 completes):
   - Phase 0.3 already completed. Scan its analysis output for codebase patterns not yet covered (samber, gRPC, database, concurrency patterns).
```

### Step 2: 修复 Phase 0 announce 输出 — 补充 Skills Repository

找到 Phase 0 的 announce 输出 format：

```
5. **Announce findings:**
   "Phase 0: Environment
   - Type: Go (go 1.25.3) / Vue (3.x + TypeScript) / Node
   - Skill pool: skills/go/ / skills/vue/
   - Tooling: go available / node available"
```

替换为：

```markdown
5. **Announce findings:**
   ```
   "Phase 0: Environment
   - Type: Go (go 1.25.3) / Vue (3.x + TypeScript) / Node / Skills Repository
   - Skill pool: skills/go/ / skills/vue/ / (Skills: in-repo skills/)
   - Tooling: go available / node available / git available"
   ```
```

### Step 3: 验证

```bash
# Phase 0.5 step 7 不再出现 "parallel"
grep -A3 "Augment from Phase 0.3" skills/project-workflow/SKILL.md | grep -c "parallel"
# Expected: 0

# Phase 0 announce 包含 Skills Repository
grep -c "Skills Repository" skills/project-workflow/SKILL.md
# Expected: increased
```

---

## Task 3: 版本号统一

**Objective:** 三处版本号统一为 v7.0。

**Files:**
- Modify: `skills/project-workflow/SKILL.md`
- Modify: `skills/project-workflow/references/full-skill-routing.md`
- Modify: `skills/project-workflow/references/golang-skill-routing.md`

**Actions:**

### Step 1: 修改 SKILL.md frontmatter

找到 `version: "v6.3"` → 替换为 `version: "v7.0"`

### Step 2: 修改 SKILL.md heading

找到 `# Project Workflow v6.1` → 替换为 `# Project Workflow v7.0`

### Step 3: 修改 full-skill-routing.md

找到 `# Full Skill Routing Table — project-workflow v6.0` → 替换为 `# Full Skill Routing Table — project-workflow v7.0`

### Step 4: 修改 golang-skill-routing.md

找到 `Auto-selection rules for Phase 0.5 of project-workflow v5.0.` → 替换为 `Auto-selection rules for Phase 0.5 of project-workflow v7.0.`

### Step 5: 验证

```bash
# 所有文件版本统一
grep -rn "v7.0" skills/project-workflow/
grep -rn "v6\.[0-9]" skills/project-workflow/   # 应该为 0 结果
grep -rn "v5\.0" skills/project-workflow/       # 应该为 0 结果（除非有意保留）
```

---

## 验证总结

完成所有 Task 后：

```bash
# 1. Phase 0.3 包含 HARD-GATE
grep -A5 "<HARD-GATE>" skills/project-workflow/SKILL.md | head -10

# 2. 包含三种项目类型分支
grep -c "Skills Repository\|Vue/Node\|Go 项目" skills/project-workflow/SKILL.md

# 3. 版本号统一
grep "v7.0" skills/project-workflow/SKILL.md
grep "v7.0" skills/project-workflow/references/full-skill-routing.md
grep "v7.0" skills/project-workflow/references/golang-skill-routing.md

# 4. 新 reference 存在
test -f skills/project-workflow/references/context-md-spec.md && echo "PASS"

# 5. Phase 0 不再说 "parallel"（改为顺序）
grep "parallel" skills/project-workflow/SKILL.md | grep -i "phase 0"
```
