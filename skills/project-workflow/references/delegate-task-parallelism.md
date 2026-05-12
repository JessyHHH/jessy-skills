# delegate_task Parallelism — Hermes Agent Internals

## How It Works

`delegate_task` uses `concurrent.futures.ThreadPoolExecutor` for parallel execution — **NOT** a serial queue or mutex:

```python
# delegate_tool.py line 2081
with ThreadPoolExecutor(max_workers=max_children) as executor:
    for i, t, child in children:
        future = executor.submit(_run_single_child, ...)
```

## Key Facts

| Property | Value |
|----------|-------|
| Concurrency model | Real OS threads (ThreadPoolExecutor) |
| Max parallel children | `delegation.max_concurrent_children` (default: 3) |
| Single task overhead | No thread pool — runs directly on main thread |
| Child agent isolation | Each child is an independent `AIAgent` instance |
| max_spawn_depth | Default 1 (leaf agents cannot delegate further) |

## Implications for Workflow Design

1. **Parallel independent tasks ARE truly parallel.** When you pass `tasks=[task1, task2, task3]`, all 3 agents run simultaneously in separate threads. Total wall time ≈ max(slowest task), not sum(all tasks).

2. **Ralplan must be sequential by design.** Planner → Architect → Critic cannot run in parallel because Architect depends on Planner's output. This is a data dependency, not a tool limitation.

3. **Ultrawork phase CAN parallelize.** Independent implementation tasks (different files, no shared state) can all go into one `delegate_task(tasks=[...])` call.

4. **Single-task mode is faster for simple work.** No thread pool overhead — the child runs directly on the main thread.

5. **Orchestrator agents are disabled.** `max_spawn_depth=1` means even `role='orchestrator'` is forced to `leaf`. Sub-agents cannot use `delegate_task` themselves.

## Config Tuning

```yaml
# ~/.hermes/config.yaml
delegation:
  max_concurrent_children: 3   # Increase for more parallelism (costs more tokens)
  max_spawn_depth: 1           # Set to 2+ to allow sub-agent delegation
  max_iterations: 50           # Max tool calls per child agent
  child_timeout_seconds: 600   # Kill child if it runs longer
```

## Performance Observations

From real-world testing:
- Planner sub-agent: 212-309s (depends on task complexity + model)
- Architect sub-agent: 147s
- Critic sub-agent: 158s
- These run **in sequence** due to data dependencies, not tool limitations
- If they were independent, wall time would be ~309s (max), not ~614s (sum)
