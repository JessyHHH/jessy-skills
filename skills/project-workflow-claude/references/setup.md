# project-workflow-claude Setup Guide

## Recommended MCP Servers

These MCP servers enhance the workflow but are NOT required. Phase 0 auto-detects availability and falls back to native tools.

### Context7 — Library & Framework Documentation

Context7 provides up-to-date documentation for libraries, frameworks, and APIs. Preferred over WebFetch for documentation queries.

**Install:**
```bash
claude mcp add context7 -- npx @upstash/context7-mcp@latest
```

**Verify:**
```
Ask Claude: "Look up the docs for golang slices"
Expected: Context7 returns official Go documentation
```

### Firecrawl — Web Search & Scraping

Firecrawl provides advanced web search and page scraping. Preferred over WebSearch for research tasks.

**Install:**
```bash
claude mcp add firecrawl -- npx @anthropic/firecrawl-mcp@latest
```

Set `FIRECRAWL_API_KEY` environment variable (get from https://firecrawl.dev).

**Verify:**
```
Ask Claude: "Search for Go 1.25 release notes"
Expected: Firecrawl returns search results
```

## Fallback Behavior

If neither MCP is available, the workflow falls back to Claude Code native tools:
- Documentation queries → `WebFetch`
- Web searches → `WebSearch`

No functionality is lost — MCP servers only improve quality and speed.

## Quick Check

Run in Claude Code:
```
Phase 0 will auto-detect MCP availability.
If MCP tools appear in available tools list → available.
If not → suggest checking this setup guide.
```

## DeepSeek API Notes

DeepSeek's API (`api.deepseek.com/anthropic`) is Anthropic-compatible but has important differences from native Anthropic:

### Thinking ≠ Extended Thinking
- DeepSeek's `reasoning_effort` feature is NOT the same as Anthropic's Extended Thinking
- The `[1m]` suffix in model names (e.g., `deepseek-v4-pro[1m]`) controls **context window size** — NOT thinking budget
- DeepSeek auto-decides thinking depth; the `/effort` command may have limited effect compared to native Anthropic
- Thinking blocks (`{"type": "thinking", "thinking": "..."}`) appear in responses but depth is model-controlled, not user-controlled

### Known Issue: Agent Subagent API Conflict

When `ANTHROPIC_DEFAULT_SONNET_MODEL` or `ANTHROPIC_DEFAULT_HAIKU_MODEL` are set to a model with `reasoning_effort` enabled (e.g., `deepseek-v4-pro[1m]`), spawning Agent subagents fails with:

```
API Error: 400 thinking options type cannot be disabled when reasoning_effort is set
```

**Root cause**: Claude Code's Agent tool disables thinking for non-opus subagents (haiku/sonnet tiers), but DeepSeek's API requires `thinking.type` to be `enabled` when `reasoning_effort` is set in the request. The conflicting settings cause the API to reject subagent spawns.

**Impact**: All subagent delegation is broken — this includes the `Agent` tool, `Workflow` scripts (which spawn agents internally), and any skill that delegates to subagents.

**Recommended fix**: In `settings.json`, set lighter models to versions without reasoning:

```json
{
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash"
}
```

This allows haiku-tier subagents to spawn without the thinking/reasoning conflict. For sonnet-tier agents, consider using `deepseek-v4-pro` (without `[1m]`) if your use case doesn't require the 1M context window.
