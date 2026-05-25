# 工作流专业化改造计划 v2（Grill 修正版）

## Goal

将 jessy-skills 从"工具箱"升级为"方法论体系"。消除 project-workflow 的重复、过期引用和不可见性。

## Grill 关键发现

1. **Phase 出口不可见**：project-workflow 只有在 Phase 0.5 宣布"加载了什么 skill"，没有在每个 Phase 结束时宣布"用了什么 skill"。导致用户不知道 Agent 在哪个 Phase 用了哪个 skill。
2. **Skill Re-Check 重复**：Phase 1 Step 9 和 Phase 2 Step 6 做同样的事（扫路由表→diff→补漏）。
3. **Phase 8 Step 1 和 Phase 6 验证重复**。
4. **"59 skills" 过期**、**"step 5.5" 不存在**、**Karpathy #5 引用错误的工具名**。

## 改造清单

### Step 1: 修 project-workflow 的 6 个过期/重复问题

| # | 问题 | 位置 | 改法 |
|---|------|------|------|
| 1 | Skill Re-Check 重复 | 行 247-257 | 删除 Phase 2 Step 6 |
| 2 | Phase 8 验证重复 | 行 599-612 | `go test -race` → "Verify Phase 6 results still hold" |
| 3 | "59 skills" 过期 | 行 128/255/751 | 59 → 55 |
| 4 | 重复引用行 | 行 751 | 删除第二行 |
| 5 | "step 5.5" 不存在 | 行 528/561 | 5.5 → 5 |
| 6 | Karpathy #5 引用 `web_search()` | 行 26 | 改为 prior-research 优先级链 |

### Step 2: 加 Phase 出口可见性

**2a. Self-Driving Transition Rules 表加 `Skills Expected` 列：**

```
| Phase | → | Skills Expected | Condition |
| 0.5   | 1 | routing-table   | skills loaded |
| 1     | 2 | deep-interview  | Design approved + spec written |
| 2     | 3 | plan            | Plan saved |
| 3     | 4 | ralplan         | Plan approved |
| 4     | 5 | ultrawork       | All tasks done |
| 5     | 6 | code-review     | Both stages pass |
| 6     | 7 | (none)          | ALL checks PASS |
| 7     | 8 | (none)          | 7.1+7.2 dispatched |
| 8     | — | (none)          | Branch resolved |
```

**2b. 每个 Phase procedure 末尾加出口声明模板：**
```
Template: "Phase X complete. [skill] verified. → Phase Y."
```

### Step 3: 创建 `prior-research` skill

合并 `context7-docs` + `firecrawl-web` 为一个研究方法论 skill。

**文件：** `skills/methodology/prior-research/SKILL.md`

**内容结构：**
- 触发条件（WHEN）
- 搜索优先级链（HOW）：curl(2s) → context7(2s) → firecrawl(5s) → delegate_task(最后)
- 结果使用规则（USE）：API 文档 > 训练数据，不确定时说"不确定"
- context7 和 firecrawl 的 CLI 用法（从旧 skill 提取精华）
- Pitfalls

### Step 4: 创建 `api-design-first` / `data-model-first` / `error-taxonomy`

三个顶层方法论 skill，放在 `skills/methodology/`。

### Step 5: 更新路由表

- 移除 `context7-docs` 和 `firecrawl-web` 的独立路由规则
- 新增 `prior-research` 的触发词（合并了旧的触发词）
- 新增三个新 skill 的路由规则

### Step 6: 标记 deprecated

- `tools/context7-docs/SKILL.md` → description 加 `DEPRECATED → 使用 prior-research`
- `tools/firecrawl-web/SKILL.md` → description 加 `DEPRECATED → 使用 prior-research`

### Step 7: 写自动化测试脚本

**文件：** `tests/test-workflow-changes.sh`

**内容：** 层 1 结构验证（7 项检查，全自动）。

### Step 8: 验证

层 1 跑脚本 → 全部 PASS。层 2 开新会话手动跑 5 条。

---

## Files to Create

| 文件 | 大小 |
|------|------|
| `skills/methodology/prior-research/SKILL.md` | ~200 行 |
| `skills/methodology/api-design-first/SKILL.md` | ~120 行 |
| `skills/methodology/data-model-first/SKILL.md` | ~120 行 |
| `skills/methodology/error-taxonomy/SKILL.md` | ~120 行 |
| `tests/test-workflow-changes.sh` | ~80 行 |

## Files to Modify

| 文件 | 改动 |
|------|------|
| `skills/project-workflow/SKILL.md` | 删除 Phase 2 Step 6 + 修正 6 个过期问题 + 加 Phase 出口声明 |
| `skills/project-workflow/references/full-skill-routing.md` | 更新路由规则 |
| `skills/tools/context7-docs/SKILL.md` | 标记 deprecated |
| `skills/tools/firecrawl-web/SKILL.md` | 标记 deprecated |

## Risks

| 风险 | 缓解 |
|------|------|
| 路由表更新丢触发词 | 层 1 测试自动检查 |
| 旧 skill 仍被加载 | 层 1 检查路由表无冗余引用 |
| Phase 出口声明写漏 | 层 1 检查每个 Phase 有出口声明 |
