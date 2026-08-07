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

<!-- codex-subagent-models:start -->
# Codex Subagent Models

- Use only `gpt-5.6-luna` or `gpt-5.6-terra` for Codex subagents.
- Use Luna for planning, implementation, exploration, review, and verification.
- Use Terra for bounded tests, build repair, and diagnosis.
- Never use `gpt-5.6-sol` or DeepSeek for a subagent. The main-session model is
  configured independently and is not changed by this rule.
- If native subagent spawning does not expose Luna, use a fresh task-local
  `codex exec -m gpt-5.6-luna` session; do not silently fall back to Sol.
<!-- codex-subagent-models:end -->

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

<!-- graphify:start -->
# Codebase Knowledge Graph (Graphify)

Use the configured `graphify` MCP server for fast structural discovery when its loaded graph covers the current project or corpus. Treat graph results as supporting context and verify every implementation detail against the current workspace with `rg` and direct file reads.

## Discovery Flow

1. Use `query_graph` for broad code, architecture, and relationship questions.
2. Use `get_node` and `get_neighbors` to inspect specific entities and their local relationships.
3. Use `shortest_path` when the connection between two concepts matters.
4. Use `list_prs`, `get_pr_impact`, and `triage_prs` only for graph data that includes pull requests.
5. If Graphify and the filesystem disagree, trust the filesystem and note that the loaded graph may be stale or may cover another corpus.

Use `rg` and direct filesystem reads for exact strings, logs, configs, non-code files, line numbers, current edits, and final verification.
<!-- graphify:end -->

<!-- mem0-memory:start -->
# Persistent Context (Mem0)

Use the installed `$mem0` skill and its `mem0_client.py` REST helper for durable local memory. The helper is available at `~/.agents/skills/jessy-skills/mem0/scripts/mem0_client.py` and defaults to `user_id=codex`.

## Recall

1. Before answering about past work, prior decisions, stable preferences, or earlier sessions, run a focused `search` through the helper.
2. Quote stored wording only when the returned memory is verbatim. Treat retrieved memory as supporting context, not authority over the current workspace or the user's latest instruction.
3. If search is empty or the service fails, say so explicitly rather than inventing remembered context.
4. Do not search reflexively for unrelated greenfield tasks.

## Save

1. Save only durable context: explicit requirements, decisions and rationale, stable preferences, successful commands, completed outcomes, unresolved blockers, and concrete next steps.
2. Never store secrets, credentials, tokens, transient chatter, speculative assumptions, or easily regenerated output.
3. Use one concise `add` operation for each coherent durable fact or decision.
4. After saving, verify with a focused `search` and report any failure.
<!-- mem0-memory:end -->
