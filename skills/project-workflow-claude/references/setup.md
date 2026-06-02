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
