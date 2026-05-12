# TOCTOU Shutdown Pattern — Go Concurrency Pitfall

## The Bug

A time-of-check-to-time-of-use (TOCTOU) race between a non-blocking `select` on a `done` channel and a subsequent `sync.WaitGroup.Add()`:

```go
// BUG: TOCTOU window between T1 and T2
select {
case <-rl.done:       // T1: check if stopped
    return 503
default:
}
rl.wg.Add(1)           // T2: register in-flight
                        // ⚠️ If Stop() closes rl.done between T1 and T2,
                        //    this goroutine bypasses the shutdown check
                        //    and continues to use the stopped limiter.
defer rl.wg.Done()
// ... use shared state ...
```

**Timeline of the bug:**
```
Goroutine A (request):              Goroutine B (Stop):
  select { case <-done } → default  (done not closed yet)
                                      close(done)           ← Stop() fires
  wg.Add(1)                         ← TOCTOU! Goroutine A never saw done closed
  wg.Wait()                         ← Goroutine A increments after Wait() already returned
  ... continues using stopped state ...
```

## The Fix

**Option A: Add BEFORE check** (preferred, minimal):

```go
rl.wg.Add(1)           // T1: register FIRST
select {
case <-rl.done:        // T2: check stopped
    rl.wg.Done()       // if stopped, undo the Add
    return 503
default:
}
defer rl.wg.Done()
// ... use shared state ...
```

**Option B: Mutex guard** (for complex sequences):

```go
rl.mu.Lock()
select {
case <-rl.done:
    rl.mu.Unlock()
    return 503
default:
}
rl.wg.Add(1)
rl.mu.Unlock()
defer rl.wg.Done()
```

## Detection Checklist

When reviewing concurrent Go code, check for this pattern:

1. Any non-blocking `select` on a shutdown signal
2. Followed by any state-changing operation (`wg.Add`, map write, channel send)
3. Without a mutex or ordering guarantee between them

## Real-world Example

Found in a token bucket rate limiter HTTP middleware during code review. The `Wrap()` method checked `rl.done` via `select` before calling `rl.wg.Add(1)`. Under load, `Stop()` could close `done` between these two operations, allowing requests to proceed on a stopped limiter.

Related: `delegate_task` in Hermes Agent uses `ThreadPoolExecutor` (real threads, not serialized) — concurrent operations like this are common and TOCTOU bugs are easy to miss.
