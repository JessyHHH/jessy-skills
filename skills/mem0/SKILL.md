---
name: mem0
description: Save, search, inspect, update, and delete durable local memory through a self-hosted Mem0 REST service. Use when a user asks Codex to remember stable context or recall prior work.
---

# Mem0

Use the helper installed through the jessy-skills discovery symlink; this skill has no MCP dependency. It requires `MEM0_API_KEY` and uses `MEM0_BASE_URL`, defaulting to `http://127.0.0.1:8002`.

Run it as:

```bash
python3 "$HOME/.agents/skills/jessy-skills/mem0/scripts/mem0_client.py" COMMAND [ARGS]
```

Available commands are `status`, `add`, `search`, `list`, `get`, `update`, and `delete`. Use `--help` on a command for its exact arguments.

Use `user_id=codex` as the default durable scope. The helper applies that scope to `add` when no user, agent, or run scope is supplied, and always defaults `search` and `list` to it.

## Workflow

- Search before answering questions about past work, prior decisions, or saved preferences.
- Store only durable context that will help later: stable decisions, requirements, preferences, successful commands, and lasting blockers.
- Never store credentials, API keys, access tokens, private keys, or other secrets.
- Preserve exact wording when it matters; do not present a summary as a quotation.
- After every save, verify it with a focused `search` and report the result or failure.
- Use `status` to distinguish service or authentication problems from an empty search.
