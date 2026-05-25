# Vue Skill Routing Table

Auto-selection rules for Phase 0.5 and Phase 2 post-plan check of project-workflow v6.0.

## Codebase Signals (package.json dependencies)

| Detected in package.json | Auto-select Skill |
|--------------------------|-------------------|
| `vue` (>=3.0) | `vue-best-practices` |
| `vue` (<3.0 or Options API detected) | `vue-options-api-best-practices` |
| `vue-router` | `vue-router-best-practices` |
| `pinia` | `vue-pinia-best-practices` |
| `vitest` / `@vue/test-utils` | `vue-testing-best-practices` |
| `@vitejs/plugin-vue-jsx` | `vue-jsx-best-practices` |
| (debug-related task) | `vue-debug-guides` |
| (composable creation task) | `create-adaptable-composable` |

## Task Signals

| Task Keyword / Signal | Auto-select Skill |
|----------------------|-------------------|
| vue, 组件, component, template, script setup, composable, 组合式 | `vue-best-practices` |
| options api, data(), methods, watch, computed, 选项式 | `vue-options-api-best-practices` |
| jsx, tsx, render, h(), className, class vs | `vue-jsx-best-practices` |
| test, 测试, vitest, vue-test-utils, mount, shallowMount | `vue-testing-best-practices` |
| router, 路由, navigation, guard, beforeEach, 导航 | `vue-router-best-practices` |
| pinia, store, state, getter, action, 状态管理 | `vue-pinia-best-practices` |
| debug, 调试, error, warning, hydration, 报错 | `vue-debug-guides` |
| composable, useXxx, MaybeRef, MaybeRefOrGetter, 封装 | `create-adaptable-composable` |

## Common Combos

| Scenario | Skills |
|----------|--------|
| Vue SPA with routing + state | vue-best-practices + vue-router-best-practices + vue-pinia-best-practices |
| Writing tests | vue-best-practices + vue-testing-best-practices |
| Debugging production issue | vue-best-practices + vue-debug-guides |
| Creating reusable composable library | vue-best-practices + create-adaptable-composable |
| JSX-heavy codebase | vue-best-practices + vue-jsx-best-practices |
