---
name: mempalace
description: Save, checkpoint, and search local AI memory through the MemPalace MCP server. Use when the user says to write/save/record/remember something in memory, save the current conversation context, file decisions or preferences for later recall, query previous memories, or use MemPalace explicitly.
---

# MemPalace

Use the configured `mempalace` MCP server as the source of truth for local memory.

## Save Workflow

When the user asks to save or remember context:

1. Prefer one `mempalace_checkpoint` MCP call over many individual writes.
2. If checkpoint/status reports that no palace exists, initialize the Docker volume first with a tiny seed directory:

```bash
mkdir -p /tmp/mempalace-seed
printf '%s\n' 'MemPalace seed file for initial local Docker palace setup.' > /tmp/mempalace-seed/seed.txt
docker run --rm -v mempalace-data:/data -v /tmp/mempalace-seed:/seed mempalace init /seed --yes --auto-mine --no-llm
```

The first initialization may download Chroma's all-MiniLM-L6-v2 ONNX model, about 79 MB, into `mempalace-data`; this can take several minutes and is a one-time cache cost.

3. Store only useful future context: decisions, requirements, preferences, stable facts, commands that worked, blockers, and important exact snippets.
4. Preserve verbatim wording when it matters. Do not invent details or summarize user data as if it were quoted.
5. Use concise `wing` and `room` names.
   - `wing`: project/person/domain, such as `mempalace`, `codex`, or `jessy`.
   - `room`: topic, such as `decisions`, `setup`, `preferences`, `docker`, or `mcp`.
6. After saving, verify with `mempalace_status` or a focused `mempalace_search`, then report what was saved at a high level and mention any failures.

Checkpoint item shape:

```json
{
  "wing": "mempalace",
  "room": "mcp",
  "content": "Exact memory content to preserve."
}
```

Use `mempalace_add_drawer` only for a single simple memory. Use `mempalace_diary_write` only when writing an agent diary entry is specifically appropriate.

## Search Workflow

When the user asks to recall or search memory:

1. Use `mempalace_search` with a short keyword query.
2. Put background explanation in `context`, not in `query`.
3. Use `wing` or `room` filters when the user names a project/topic.
4. Return the relevant found content and cite the wing/room/source metadata when available.

## Local Setup Notes

This skill expects the Codex MCP config to contain:

```toml
[mcp_servers.mempalace]
command = "docker"
args = ["run", "-i", "--rm", "-v", "mempalace-data:/data", "mempalace"]
```

If the MCP tool is unavailable, tell the user Codex likely needs to restart so the MCP config can reload.

When manually testing stdio MCP over Docker, do not allocate a TTY. Use `docker run -i --rm ...`, not an interactive TTY session, because TTY mode echoes JSON-RPC input and can confuse diagnosis.

If a Docker command fails with a Docker socket permission error inside Codex, rerun the same command with escalated permissions instead of changing the MemPalace config.
