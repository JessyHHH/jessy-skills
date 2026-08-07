# Jessy Graph Host-Native Retrospective

- Live verification found that `FastMCP.server.run()` bypassed the composed Starlette app, including Bearer authentication and `/healthz`. Production entrypoints must be tested through the exact callable that systemd executes.
- Codex CLI global controls (`-a`, `-c`, `-s`, and `-C`) must precede `exec`; new and resumed sessions now share the same controls.
- The relay-compatible output contract works with `--output-last-message` plus local `CodexResultV1` validation; `--output-schema` remains prohibited.
- A dirty main-session pivot makes base-commit scope guards report pre-existing files. Record the baseline exception explicitly and compare task-local deltas; never hide or modify unrelated user state such as `.idea/`.
- Destructive Docker cleanup must remain after the full host live gate. The exact container and two volumes were deleted only after real MCP, Codex, restart, source-integrity, and credential-redaction evidence passed.
- Read-only plan-review subagents repeatedly routed to the unrelated workflow-control diff. Their reports were rejected and recorded as `BLOCKED_AGENT`; local evidence remained authoritative.

