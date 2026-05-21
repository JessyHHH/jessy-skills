# Full Skill Routing Table — project-workflow v6.0

Complete task-signal → skill mapping covering all 61 skills across 6 categories.

## Go Backend Skills (skills/go/)

| Signal | Skill |
|--------|-------|
| goroutine, channel, select, mutex, sync, race, concurrency, worker pool, 并发 | `golang-concurrency` |
| test, 测试, tdd, unit, integration, testify, mock, -race, 单元测试, 集成测试 | `golang-testing` + `golang-stretchr-testify` |
| error, panic, recover, oops, fmt.Errorf, errors.Is, 错误处理 | `golang-error-handling` |
| refactor, 重构, rewrite, restructure, clean, 重写 | `golang-code-style` + `golang-modernize` |
| CLI, cobra, flag, command, 命令行 | `golang-cli` |
| benchmark, 性能, profile, pprof, fast, slow, 优化 | `golang-benchmark` + `golang-performance` |
| context, ctx, timeout, deadline, cancel | `golang-context` |
| security, 安全, vulnerability, injection, crypto, 加密 | `golang-security` |
| naming, 命名, convention, rename, 规范 | `golang-naming` |
| struct, interface, type, embed, receiver, 接口, 结构体 | `golang-structs-interfaces` |
| database, sql, pg, mysql, sqlite, migration, 数据库 | `golang-database` |
| DI, dependency injection, wire, fx, container, 依赖注入 | `golang-dependency-injection` |
| pattern, 设计模式, functional options, builder | `golang-design-patterns` |
| new project, init, layout, 项目结构, 初始化 | `golang-project-layout` |
| CI/CD, github actions, release, goreleaser, 部署 | `golang-continuous-integration` |
| grpc, protobuf, proto, stream | `golang-grpc` |
| log, observability, metric, trace, slog, prometheus, 监控, 日志 | `golang-observability` |
| dependency, pkg, module, go.mod, upgrade, 依赖 | `golang-dependency-management` |
| doc, comment, godoc, readme, 文档, 注释 | `golang-documentation` |
| library, 推荐, choose, pick, 选型 | `golang-popular-libraries` |
| slice, map, array, data structure, container, 数据结构 | `golang-data-structures` |
| debug, troubleshoot, bug, fix, 调试, 排查 | `golang-troubleshooting` |
| defensive, safe, nil, panic prevention, 防御 | `golang-safety` |
| analyze, investigate, codebase, understand, 分析, 理解 | `analyze` |
| stay updated, Go news, ecosystem, 最新, 资讯, release notes | `golang-stay-updated` |
| samber/lo | `golang-samber-lo` |
| samber/mo | `golang-samber-mo` |
| samber/do | `golang-samber-do` |
| samber/oops | `golang-samber-oops` |
| samber/ro | `golang-samber-ro` |
| samber/slog | `golang-samber-slog` |
| samber/hot | `golang-samber-hot` |

## Vue Frontend Skills (skills/vue/)

| Signal | Skill |
|--------|-------|
| vue, composition API, script setup, composable, 组件 | `vue-best-practices` |
| router, navigation guard, route, 路由, beforeEach | `vue-router-best-practices` |
| pinia, store, state management, 状态管理 | `vue-pinia-best-practices` |
| vitest, vue test, component test, 测试 | `vue-testing-best-practices` |
| debug vue, hydration, reactivity bug, 调试, SSR error | `vue-debug-guides` |
| jsx, render function, h(), 渲染函数 | `vue-jsx-best-practices` |
| options API, data(), methods, mounted, watch | `vue-options-api-best-practices` |
| MaybeRef, MaybeRefOrGetter, adaptable composable | `create-adaptable-composable` |

## Frontend Tools (skills/frontend/)

| Signal | Skill |
|--------|-------|
| design, UI, landing page, dashboard, component, styling, CSS, Tailwind, 设计, 样式 | `anthropic-frontend-design` |
| artifact, shadcn, claude.ai artifact, multi-component, 复杂组件 | `anthropic-web-artifacts-builder` |
| playwright, browser test, e2e, screenshot, UI automation, 浏览器测试 | `anthropic-webapp-testing` |

## Engineering Process (skills/engineering/)

| Signal | Skill |
|--------|-------|
| diagnose, debug loop, reproduce, minimise, hypothesis, bug hunt, 诊断, 定位 | `diagnose` |
| tdd, red-green-refactor, test-first, 测试驱动 | `tdd` |
| prototype, mockup, try designs, spike, throwaway, 原型, 快速验证 | `prototype` |
| architecture, refactor, improve codebase, consolidate, decouple, 架构优化 | `improve-codebase-architecture` |
| issues, break down, tickets, implementation tasks, 拆分任务 | `to-issues` |
| PRD, spec, requirements document, product spec, 需求文档 | `to-prd` |
| triage, review bug, incoming issue, classify, 分类, 筛选 | `triage` |
| zoom out, big picture, unfamiliar code, broader context, 全局视角 | `zoom-out` |
| grill me, stress test plan, challenge design, 拷问计划 | `grill-me` |
| grill with docs, domain model, ADR, terminology, 文档拷问 | `grill-with-docs` |
| handoff, compact, another agent, context switch, 交接 | `handoff` |
| simplify, caveman, dumb it down, 简化 | `caveman` |
| write skill, create skill, author skill, 写技能 | `write-pr-description` |

## Plan-Specific Signals (Phase 2 post-plan check)

These keyword patterns appear in written plans, not in user prompts:

| Plan Pattern | Skill |
|-------------|-------|
| sync.Mutex, sync.RWMutex, sync.WaitGroup, sync.Once, atomic | `golang-concurrency` |
| context.Context, WithTimeout, WithCancel | `golang-context` |
| fmt.Errorf, %w, errors.Is, errors.As | `golang-error-handling` |
| t.Run, mock, stub, table-driven, testdata | `golang-testing` |
| sql.DB, pgx, sqlx, BEGIN, COMMIT, migration | `golang-database` |
| http.Handler, middleware, router, REST, endpoint | `golang-structs-interfaces` |
| slog.Info, prometheus, OpenTelemetry, Span | `golang-observability` |
| Vue component, defineProps, ref, reactive, <template> | `vue-best-practices` |
| createRouter, useRouter, <router-view> | `vue-router-best-practices` |
| defineStore, useStore, storeToRefs | `vue-pinia-best-practices` |
| describe, it, expect, vi.mock, mount | `vue-testing-best-practices` |
| Playwright, page.goto, locator, expect | `anthropic-webapp-testing` |
| React, JSX, Tailwind, shadcn/ui | `anthropic-web-artifacts-builder` |
| TDD cycle, red phase, green phase, refactor phase | `tdd` |
| Issue #, GitHub issue, ticket | `to-issues` / `triage` |
| Architecture decision, ADR, module boundary | `improve-codebase-architecture` |

## Tools & Integrations (skills/tools/)

| Signal | Skill |
|--------|-------|
| docs, library, API reference, 文档, 怎么配置, setup guide, migration, version-specific, deprecation, 最新API | `context7-docs` |
| search, scrape, crawl, research, 搜索, 抓取, 调研, look up, find, 找一下, 查一下, content extraction, web page, URL | `firecrawl-web` |

## Self-Learning Triggers

The workflow monitors its own effectiveness:

| Symptom | Action |
|---------|--------|
| Phase 7 fails 3+ times on same issue | Load `diagnose` + `golang-troubleshooting` |
| Phase 6 finds >5 modernization warnings | Load `golang-modernize` |
| User repeatedly corrects same type of mistake | Save correction pattern to `.hermes/plans/learned-*.md` |
| Plan doesn't reference a relevant skill | Phase 2 post-plan skill check catches and loads it |
| Build time >30s for small change | Flag for performance optimization |
