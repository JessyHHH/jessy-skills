<!-- context7 -->
Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer -- your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Resolve library: `npx ctx7@latest library <name> "<user's question>"` — use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question)
3. Fetch docs: `npx ctx7@latest docs <libraryId> "<user's question>"`
4. Answer using the fetched documentation

You MUST call `library` first to get a valid ID unless the user provides one directly in `/org/project` format. Use the user's full question as the query -- specific and detailed queries return better results than vague single words. Do not run more than 3 commands per question. Do not include sensitive information (API keys, passwords, credentials) in queries.

For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v14.3.0`).

If a command fails with a quota error, inform the user and suggest `npx ctx7@latest login` or setting `CONTEXT7_API_KEY` env var for higher limits. Do not silently fall back to training data.
Run Context7 CLI requests outside Codex's default sandbox. If a Context7 CLI command fails with DNS or network errors such as ENOTFOUND, host resolution failures, or fetch failed, rerun it outside the sandbox instead of retrying inside the sandbox.
<!-- context7 -->

<!-- firecrawl -->
Use the installed `firecrawl` CLI first for general web research, current information, prior search, crawling, page extraction, site traversal, case studies, or site evidence. Do not run Context7 first for these tasks.

Use Context7 for library, framework, SDK, API, CLI tool, and cloud-service documentation. Fall back from Context7 to Firecrawl only when Context7 has no relevant result or lacks the required page content.

Before claiming Firecrawl is unavailable, run `command -v firecrawl`. If the CLI is unavailable or fails, use another available search/browser tool and state the fallback. Keep source evidence explicit, distinguish facts from inference, and do not fabricate inaccessible results.
<!-- firecrawl -->

<!-- go-resource-safety -->
# Go Build/Test Resource Safety

When compiling or testing Go projects, be conservative with package-level parallelism.

- Do not run unbounded `go test ./...` by default on medium or large repositories.
- Before running whole-repo Go build/test commands, inspect local resource pressure and project size first, for example CPU count, available memory, current load, and approximate package count.
- If the repository is large, resource pressure is high, or risk is unclear, use serial package execution:
  - `go test -p 1 ./...`
  - `go build -p 1 ./...`
- Only use parallel Go test/build execution after explicitly judging that local resources are sufficient. Prefer a small bounded value such as `-p 2`; avoid default/unbounded parallelism for large repos.
- Do not start multiple whole-repo Go test/build commands concurrently in the same workspace.
- If serial testing is too slow, explain the tradeoff and ask before increasing parallelism.
<!-- go-resource-safety -->

<!-- codebase-memory-mcp:start -->
# Codebase Knowledge Graph (codebase-memory-mcp)

This project uses codebase-memory-mcp to maintain a knowledge graph of the codebase.
Use MCP graph tools first for fast code discovery, then verify against the current workspace files with `rg`/direct file reads. Do not treat graph results as authoritative without checking source files, because the index may be stale.

## Discovery Flow
1. Use `search_graph` to quickly find candidate functions, classes, routes, variables, or files.
2. Use `trace_path` when caller/callee relationships matter.
3. Use both:
   - `get_code_snippet` for graph-context source snippets.
   - `rg`/direct file reads for the current on-disk source.
4. If graph and filesystem disagree, trust the filesystem and mention that the graph may be stale.
5. Use `query_graph` for complex code-structure questions.
6. Use `get_architecture` for high-level project summaries.

## Use `rg`/filesystem directly for
- String literals, error messages, logs, config values.
- Non-code files such as Dockerfiles, shell scripts, configs, docs.
- Confirming exact implementation details, line numbers, imports, and current edits.
- Checking whether graph results are stale or incomplete.

## Examples
- Locate a handler: `search_graph(name_pattern=".*OrderHandler.*")`, then inspect matching files with `rg`.
- Understand calls: `trace_path(function_name="OrderHandler", direction="inbound")`, then verify callers in source files.
- Read implementation: use `get_code_snippet(...)` and also read the matching file from disk.
<!-- codebase-memory-mcp:end -->

<!-- mempalace-memory:start -->
# Persistent Context (MemPalace)

Use the configured `mempalace` MCP server as the persistent memory layer across sessions.

## Recall
1. At the beginning of a new session, call `mempalace_status` once. If the current task is likely to continue earlier project work, run a focused search scoped to that project's wing before proceeding.
2. Before answering about past work, prior decisions, user preferences, people, projects, or earlier sessions, call `mempalace_search` first. Use a short keyword query and scope it with `wing`/`room` when the project or topic is known.
3. For relational or time-dependent facts, use `mempalace_kg_query` or `mempalace_kg_timeline` as appropriate.
4. Quote relevant stored content verbatim. If nothing is found or the MCP server fails, say so explicitly; do not invent remembered context or silently fall back to a guess.
5. Do not search reflexively for greenfield tasks that have no likely connection to prior context.

## Save
1. When the user asks to remember/save something, before context compaction, or after a substantive task that creates useful continuity, prefer one `mempalace_checkpoint` call over many individual writes.
2. Persist only durable, useful context: explicit requirements, decisions and rationale, stable preferences/facts, important exact snippets, successful commands, completed outcomes, unresolved blockers, and concrete next steps.
3. Keep checkpoint content verbatim when wording matters. Never claim a paraphrase is a quote, and do not store secrets, credentials, transient chatter, speculative assumptions, or easily regenerated output unless the user explicitly requests it.
4. Use concise taxonomy: `wing` is the project/person/domain and `room` is the topic such as `decisions`, `preferences`, `setup`, `debugging`, or `handoff`.
5. Do not double-file when a background hook already saved the same context. After writing, verify with `mempalace_memories_filed_away`, `mempalace_status`, or a focused `mempalace_search`.
6. If a previously stored fact changes, preserve history with `mempalace_kg_supersede` or invalidate the old fact and add the new one; do not silently overwrite temporal context.

MemPalace is local-first and stores original content in drawers backed by the persistent `/data` volume. Treat retrieved memory as supporting context, not as authority over the current workspace or the user's latest instruction.
<!-- mempalace-memory:end -->
