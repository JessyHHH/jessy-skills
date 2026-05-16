---
name: context7-docs
description: >-
  Fetch up-to-date library documentation and code examples via Context7 CLI.
  Use when writing code that depends on libraries, verifying API signatures,
  or when training data may be outdated. Triggers on docs, library, API,
  setup, migration, version-specific questions.
version: "1.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [docs, library, context7, tool]
    auto_load: false
---

# Context7 — Real-Time Library Documentation

Fetch up-to-date, version-specific documentation and code examples for any library using the Context7 CLI (`ctx7`). **Prefer this over `web_search` for library documentation and API details.**

## Prerequisites

```bash
npm install -g ctx7@latest
# or run without install:
npx ctx7@latest <command>
```

Optional: get a free API key at https://context7.com/dashboard for higher rate limits:
```bash
export CONTEXT7_API_KEY=your_key
ctx7 login  # OAuth alternative
```

## Two-Step Workflow

Always `ctx7 library` first to resolve name to ID, then `ctx7 docs` to fetch.

```bash
# Step 1: Resolve library ID
ctx7 library <name> "<query>"

# Step 2: Fetch docs with resolved ID
ctx7 docs <libraryId> "<query>"
```

Library IDs use `/org/project` format (e.g., `/gin-gonic/gin`, `/gorilla/mux`, `/facebook/react`).

## Step 1: Resolve Library

```bash
ctx7 library nextjs "How to set up middleware"
ctx7 library gin "How to bind JSON request body"
ctx7 library prisma "One-to-many relations with cascade delete"
ctx7 library slog "How to use structured logging"
```

### Result Fields

- **Library ID** — `/org/project` or `/org/project/version`
- **Code Snippets** — number of available code examples
- **Source Reputation** — High / Medium / Low / Unknown
- **Benchmark Score** — 100 is highest quality

### Selection Priority

1. Exact name match
2. Higher benchmark score + source reputation
3. More code snippets
4. If user specifies a version (e.g., "React 19"), pick version-specific ID when available

## Step 2: Query Documentation

```bash
ctx7 docs /gin-gonic/gin "How to bind JSON request body with ShouldBindJSON"
ctx7 docs /uber-go/zap "How to create a logger with custom encoder config"
ctx7 docs /golang/go "How to use context.WithTimeout"
```

### Query Quality

| Good | Bad |
|------|-----|
| `"How to set up JWT middleware in Gin"` | `"auth"` |
| `"React useEffect cleanup with async"` | `"hooks"` |
| `"slog structured logging with groups"` | `"log"` |

Use the user's full question as the query. Be descriptive and specific.

## Version-Specific Docs

```bash
# General (latest indexed)
ctx7 docs /golang/go "How to use slog"

# Version-specific (if listed in library output)
ctx7 docs /facebook/react/19.0.0 "useOptimistic hook"
```

## Authentication

Works without auth for basic usage. For higher rate limits:
```bash
ctx7 login                          # Browser OAuth
export CONTEXT7_API_KEY=your_key   # or env var
```

## Error Handling

- **"Quota exceeded"** — tell user, offer `ctx7 login`, fall back to training data with caveat
- **No results** — try broader query, or use `web_search` as fallback
- **Max 3 attempts per question** — if still no good result, use best available

## Common Mistakes

- ❌ `ctx7 docs react "hooks"` — must use resolved ID like `/facebook/react`, not bare name
- ❌ Single-word queries — too vague, returns generic results
- ❌ Forgetting the `/` prefix on library IDs
- ❌ Including API keys or secrets in query strings

## Integration with project-workflow

| Phase | Use Case |
|-------|---------|
| **Phase 0.5** | Auto-load when user mentions library names, API questions, "how to configure X" |
| **Phase 1** | Research library APIs for design decisions |
| **Phase 5** | Verify API usage matches current docs version |
