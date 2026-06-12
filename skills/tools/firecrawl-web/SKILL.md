---
name: firecrawl-web
description: "DEPRECATED: use prior-research instead. Search, scrape, and crawl the web via Firecrawl CLI."
---

# Firecrawl — Web Search & Scraping via CLI

Search, scrape, crawl, and interact with the web. Returns clean Markdown optimized for LLM context windows.

## Prerequisites

```bash
npm install -g firecrawl-cli
# or run without install:
npx firecrawl-cli <command>
```

Authentication (prompted on first use):
```bash
firecrawl login                              # Browser OAuth
firecrawl login --api-key fc-your-api-key   # Direct API key
export FIRECRAWL_API_KEY=fc-your-key        # Environment variable
```

Check status: `firecrawl --status`

## Command Escalation Pattern

Follow this order — from lightest to heaviest:

| Need | Command | When |
|------|---------|------|
| Find pages on a topic | `search` | No specific URL yet |
| Get a page's content | `scrape` | Have a URL |
| Find URLs within a site | `map` | Need to locate a subpage |
| Bulk extract a site section | `crawl` | Need many pages (e.g., all /docs/) |
| Click, scroll, fill forms | `scrape` + `interact` | Page requires browser actions |

## Commands

### `search` — Search the web

```bash
# Basic search
firecrawl search "<query>"

# Limit results + filter
firecrawl search "AI news" --limit 10 --sources news
firecrawl search "Go concurrency patterns" --categories github --limit 20

# Time filters
firecrawl search "tech announcements" --tbs qdr:d   # past day
firecrawl search "Go 1.26 features" --tbs qdr:w     # past week
firecrawl search "React 19" --tbs qdr:m             # past month

# Search AND scrape results (get full content)
firecrawl search "Go slog best practices" --scrape --scrape-formats markdown --limit 5

# Output to file
firecrawl search "<query>" -o .firecrawl/search-results.json --json
```

**Key options:** `--limit` (max 100), `--sources` (web/news/images), `--categories` (github/research/pdf), `--tbs` (time filter), `--scrape` (fetch full content), `--location` (geo-target)

### `scrape` — Extract page content

```bash
# Basic (Markdown output)
firecrawl scrape https://example.com
firecrawl https://example.com                    # shortcut

# Multiple URLs (concurrent)
firecrawl scrape https://site.com/page1 https://site.com/page2

# HTML output
firecrawl https://example.com --html

# Main content only (strips nav, footer, ads)
firecrawl https://blog.example.com --only-main-content

# Wait for JS rendering
firecrawl https://spa-app.com --wait-for 3000

# Screenshot
firecrawl https://example.com --screenshot

# Save to file
firecrawl https://example.com -o .firecrawl/page.md
firecrawl https://example.com --format json -o .firecrawl/data.json --pretty
```

**Key options:** `--only-main-content`, `--wait-for <ms>`, `--screenshot`, `--format` (markdown/html/links/images/screenshot/summary/json), `-o <path>`, `--exclude-tags`, `--include-tags`

### `map` — Discover all URLs on a site

```bash
# List all URLs
firecrawl map https://docs.example.com

# Filter by keyword
firecrawl map https://example.com --search "blog"

# Limit + save
firecrawl map https://example.com --limit 500 -o .firecrawl/urls.txt

# Subdomains
firecrawl map https://example.com --include-subdomains
```

### `crawl` — Bulk extract a site section

```bash
# Start crawl
firecrawl crawl https://docs.example.com

# Wait for completion with progress
firecrawl crawl https://docs.example.com --wait --progress --limit 100 --max-depth 3
```

## Output & Organization

Write results to `.firecrawl/` directory. Add `.firecrawl/` to `.gitignore`.

```bash
firecrawl search "query" -o .firecrawl/search-<topic>.json --json
firecrawl scrape "<url>" -o .firecrawl/<site>-<page>.md
```

**Naming conventions:**
- `.firecrawl/search-{query}.json`
- `.firecrawl/search-{query}-scraped.json`
- `.firecrawl/{site}-{path}.md`

**Working with results** (don't read entire files at once):
```bash
wc -l .firecrawl/file.md && head -50 .firecrawl/file.md
grep -n "keyword" .firecrawl/file.md
jq -r '.data.web[].url' .firecrawl/search.json      # extract URLs
```

## Parallelization

Run independent operations in parallel:
```bash
firecrawl scrape "<url-1>" -o .firecrawl/1.md &
firecrawl scrape "<url-2>" -o .firecrawl/2.md &
firecrawl scrape "<url-3>" -o .firecrawl/3.md &
wait
```

## Pitfalls

- ❌ Re-scraping URLs already fetched by `search --scrape`
- ❌ Not quoting URLs (shell interprets `?` and `&`)
- ❌ Using `scrape` for search-engine-style queries — use `search` instead
- ❌ Reading entire large output files into context — use `head`/`grep` first

## Integration with project-workflow

| Phase | Use Case |
|-------|---------|
| **Phase 0.5** | Auto-load when user asks to search, scrape, research, look up |
| **Phase 1 (Design First)** | Research competitor implementations, reference docs |
| **Phase 0.3 (Analysis)** | Scrape external docs referenced in codebase |
