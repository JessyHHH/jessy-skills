## Goal

Build a Go 1.26 dashboard web service — single-file HTTP server with embedded HTML dashboard, following Go 1.26 modern patterns.

## Context

- **Go version:** 1.26.0 (from go.mod)
- **Project type:** Greenfield — only `go.mod` exists
- **Design:** Approved ("确认") — dark-themed dashboard with system status, quick stats, recent activities
- **Patterns:** net/http (1.22+ enhanced), slog logging, `t.Context()`, `b.Loop()`
- **Testing:** `httptest`, `-race`, benchmarks
- **Docker:** `golang:1.26-alpine`

## Approach

Single-file implementation: `main.go` containing the server, dashboard HTML (embedded via `embed`), and all handlers. No external dependencies beyond stdlib.

## Files

| File | Action | Description |
|------|--------|-------------|
| `main.go` | CREATE | Main server + handlers + embedded HTML dashboard |
| `main_test.go` | CREATE | Tests: health endpoint, dashboard serving, stats tracking |
| `main_bench_test.go` | CREATE | Benchmarks using `b.Loop()` |
| `Dockerfile` | CREATE | Multi-stage golang:1.26-alpine |
| `go.mod` | MODIFY | Add `go 1.26.0` (exists, verify) |

## Step-by-step Plan

### Step 1: Create `main.go`
- Package `main`, embed `//go:embed dashboard.html` for the HTML template
- Server struct with `sync.Mutex`-protected stats (request count, start time, recent logs)
- Routes using Go 1.22+ `http.NewServeMux` with method-based patterns:
  - `GET /` — serve dashboard HTML
  - `GET /health` — JSON health check
  - `GET /api/stats` — JSON stats (request count, uptime, memory)
  - `GET /api/activities` — recent activity log
- slog structured logging on each request
- Middleware for request counting and activity tracking
- Dark-themed CSS inline in HTML

### Step 2: Create `main_test.go`
- `TestHealthEndpoint` — verify `/health` returns 200 + JSON
- `TestDashboardServes` — verify `/` returns HTML
- `TestStatsEndpoint` — verify `/api/stats` returns correct fields
- `TestActivitiesTracking` — verify multiple requests populate activity log
- `TestConcurrentAccess` — race-condition test with `-race`
- All tests use `httptest.NewServer` and `t.Context()`

### Step 3: Create `main_bench_test.go`
- `BenchmarkHealth` using `b.Loop()`
- `BenchmarkDashboard` using `b.Loop()`
- `BenchmarkStats` using `b.Loop()`

### Step 4: Create `Dockerfile`
- Multi-stage: `golang:1.26-alpine` build → scratch/alpine runtime
- Expose port 8080
- Non-root user

## Verification

1. `go mod tidy` — clean go.sum
2. `go build ./...` — must exit 0
3. `go vet ./...` — no warnings
4. `go test -race -count=1 ./...` — ALL PASS
5. `go test -bench=. -benchmem ./...` — benchmarks run
6. `curl localhost:8080/health` — verify JSON response
7. `curl localhost:8080/` — dark-themed HTML

## Risks

- **Go 1.26 availability:** `go.mod` says 1.26.0 — the local `go` binary must support it. If only 1.24 is available, may need to adjust.
- **Template size:** Tiny dashboard, <200 lines HTML — no risk.
- **Race conditions:** `sync.Mutex` protects all shared state, but verify with `-race`.
