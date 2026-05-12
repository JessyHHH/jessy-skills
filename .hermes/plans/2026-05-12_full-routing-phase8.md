# Plan: 全量 Skill 路由 + 自迭代 Phase 8

## Goal

project-workflow Phase 0.5 路由表覆盖全部 59 个 skill，新增 Phase 8 自迭代。

## 1. 路由表扩展

当前 Phase 0.5 只覆盖 Go 技能（~25 条信号）。新增：

### Engineering 信号（任务驱动，始终生效）
| 关键词 | Skill |
|--------|-------|
| diagnose, debug, bug, broken, failing, regression | `diagnose` |
| tdd, red-green-refactor, test-first | `tdd` |
| prototype, mockup, try designs, play with it | `prototype` |
| architecture, refactor, improve codebase | `improve-codebase-architecture` |
| issues, break down, tickets, tasks | `to-issues` |
| PRD, spec, requirements document | `to-prd` |
| triage, review bug, incoming issue | `triage` |
| zoom out, big picture, unfamiliar code | `zoom-out` |
| grill me, stress test, challenge plan | `grill-me` |
| handoff, compact, another agent | `handoff` |
| simplify, caveman | `caveman` |

### Frontend 信号
| 关键词 | Skill |
|--------|-------|
| design, UI, landing, dashboard, component, styling | `frontend-design` |
| artifact, shadcn, claude.ai artifact | `web-artifacts-builder` |
| playwright, browser test, e2e, screenshot | `webapp-testing` |

### Vue 扩展信号
| 关键词 | Skill |
|--------|-------|
| vue, composition API, script setup | `vue-best-practices` |
| router, navigation guard | `vue-router-best-practices` |
| pinia, store, state management | `vue-pinia-best-practices` |
| vitest, vue test | `vue-testing-best-practices` |
| debug vue, hydration, reactivity bug | `vue-debug-guides` |
| jsx, render function | `vue-jsx-best-practices` |
| options API, data(), methods | `vue-options-api-best-practices` |
| composable, MaybeRef | `create-adaptable-composable` |

## 2. Phase 8: Self-Iteration Loop

### 触发条件
- 当前在 `test` 分支
- Phase 7 验证通过
- 有代码变更

### 流程
```
Phase 7 (pass) → Phase 8
  ↓
Self-Review（加载 code-review skill，全量审查）
  ↓
发现问题？──→ Auto-fix → Phase 7 (re-test)
  ↓ 无问题
Merge to main → Done
```

### 迭代上限
- 最多 3 轮
- 每轮必须产生实际改进（避免死循环）
- 3 轮后仍有问题 → 停止，报告给用户

## 文件变更

| 文件 | 改动 |
|------|------|
| `skills/project-workflow/SKILL.md` | Phase 0.5 路由表扩展 + 新增 Phase 8 |
| `skills/project-workflow/references/full-skill-routing.md` | 新建：完整 59-skill 路由表 |

## 验证

- grep 确认每个 skill 名在路由表中出现
- test 分支上跑一轮看 Phase 8 触发
