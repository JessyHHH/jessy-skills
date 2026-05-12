# Golang Skill Routing Table

Auto-selection rules for Phase 0.5 of project-workflow v5.0.

## Task Signal Matching

| Skill | Trigger Keywords (case-insensitive) |
|-------|-------------------------------------|
| `golang-concurrency` | goroutine, channel, select, mutex, sync, race, concurrency, worker pool, WaitGroup, atomic |
| `golang-testing` | test, 测试, 用例, tdd, unit, integration, testify, mock, benchmark |
| `golang-stretchr-testify` | testify, mock, suite, assert, require (only if testify detected in imports) |
| `golang-error-handling` | error, 错误, panic, recover, oops, fmt.Errorf, errors.Is, errors.As |
| `golang-code-style` | refactor, 重构, rewrite, restructure, clean, style, format |
| `golang-modernize` | refactor, modernize, upgrade, migration, go 1.2 |
| `golang-cli` | CLI, cobra, flag, command, 命令行, urfave, viper |
| `golang-benchmark` | benchmark, 性能, profile, pprof, fast, slow |
| `golang-performance` | benchmark, 性能, optimize, hot path, allocation |
| `golang-lint` | lint, linter, golangci, vet, staticcheck |
| `golang-context` | context, ctx, timeout, deadline, cancel, propagation |
| `golang-security` | security, 安全, vulnerability, injection, auth, crypto, token |
| `golang-naming` | naming, 命名, convention, rename, MixedCaps |
| `golang-structs-interfaces` | struct, interface, type, embed, receiver, pointer vs value |
| `golang-database` | database, sql, pg, mysql, sqlite, migration, tx, query |
| `golang-dependency-injection` | DI, dependency injection, wire, fx, container, provider |
| `golang-design-patterns` | pattern, 设计模式, functional options, builder, factory, interceptor, graceful shutdown |
| `golang-project-layout` | new project, init, layout, 项目结构, module, workspace |
| `golang-continuous-integration` | CI/CD, github actions, release, goreleaser, workflow |
| `golang-grpc` | grpc, protobuf, proto, connect, stream, interceptor |
| `golang-observability` | log, observability, metric, trace, slog, prometheus |
| `golang-dependency-management` | dependency, pkg, module, go.mod, upgrade, go.work |
| `golang-documentation` | doc, comment, godoc, readme, 文档 |
| `golang-popular-libraries` | library, 推荐, choose, pick, which package |
| `golang-data-structures` | slice, map, array, data structure, container, heap, ring |
| `golang-samber-lo` | (auto-detected from go.mod import) |
| `golang-samber-mo` | (auto-detected from go.mod import) |
| `golang-samber-do` | (auto-detected from go.mod import) |
| `golang-samber-oops` | (auto-detected from go.mod import) |
| `golang-samber-ro` | (auto-detected from go.mod import) |
| `golang-safety` | defensive, safe, nil, panic prevention, copy |
| `golang-troubleshooting` | debug, troubleshoot, bug, fix, 调试, deadlock, race |
| `golang-stay-updated` | stay updated, news, community, conference |

## Codebase Signal Matching (Phase 0 import scan)

| Detected in go.mod | Auto-load |
|--------------------|-----------|
| `google.golang.org/grpc` | `golang-grpc` |
| `github.com/stretchr/testify` | `golang-stretchr-testify` |
| `github.com/samber/lo` | `golang-samber-lo` |
| `github.com/samber/mo` | `golang-samber-mo` |
| `github.com/samber/do` | `golang-samber-do` |
| `github.com/samber/oops` | `golang-samber-oops` |
| `github.com/samber/ro` | `golang-samber-ro` |
| `database/sql` or `pgx` or `sqlx` | `golang-database` |
| `github.com/spf13/cobra` or `github.com/urfave/cli` | `golang-cli` |
| `github.com/prometheus/client_golang` | (patterns known, no separate skill) |
| `go.uber.org/goleak` | (patterns known, no separate skill) |
| `log/slog` | (patterns known, no separate skill) |

## Common Multi-Skill Combos

| Task Pattern | Skills |
|-------------|--------|
| "add a new gRPC endpoint with tests" | golang-grpc + golang-testing + golang-stretchr-testify |
| "refactor the database layer" | golang-database + golang-code-style + golang-modernize + golang-error-handling |
| "fix a concurrency bug" | golang-concurrency + golang-troubleshooting + golang-safety |
| "add Prometheus metrics" | golang-observability + golang-testing |
| "new Go CLI tool" | golang-cli + golang-project-layout + golang-testing |
| "performance optimization" | golang-benchmark + golang-performance + golang-concurrency |
