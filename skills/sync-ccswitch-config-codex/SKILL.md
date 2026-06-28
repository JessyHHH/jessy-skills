---
name: sync-ccswitch-config-codex
description: Sync shared Codex config from ~/.codex/config.toml into cc-switch common_config_codex. Use when Codex MCP servers, trusted projects, agents, skills config, developer instructions, or shared settings should survive provider switches.
---

# Sync cc-switch Codex Config

Sync shared Codex configuration into cc-switch so provider switches do not drop common settings.

## Source And Target

- Source: `~/.codex/config.toml`
- Target DB: `~/.cc-switch/cc-switch.db`
- Target key: `settings.common_config_codex`
- Target format: TOML text

## Default Behavior

Run:

```bash
python3.11 scripts/sync_config.py --dry-run
python3.11 scripts/sync_config.py
```

Use a Python 3.11+ interpreter because the script imports `tomllib`. On this
machine, `/Users/jessyhuang/.local/bin/python3.11` is known to work; system
`python3` may be Python 3.9 and fail with `ModuleNotFoundError: tomllib`.

The sync is add-only:

- Add missing shared top-level keys.
- Add missing shared tables.
- Keep existing cc-switch values when a key already exists.
- Exclude provider/auth settings.
- Exclude hooks unless `--include-hooks` is passed.

## Synced By Default

- shared model/runtime preferences such as `model`, `model_reasoning_effort`, `model_context_window`, `service_tier`, `approvals_reviewer`, `developer_instructions`
- `[features]`
- `[projects]`
- `[mcp_servers]`
- `[agents]`
- `[notice]`
- `[tui]`
- `[[skills.config]]` when present

## Excluded By Default

- `model_provider`
- `[model_providers]`
- auth, token, key, secret, and password fields
- provider base URLs and provider-specific auth fields
- `[hooks]` unless explicitly requested

To include hooks:

```bash
python3.11 scripts/sync_config.py --include-hooks --dry-run
```

## Post-Sync Verification

Always verify the target after syncing:

```bash
python3.11 -c "import sqlite3,tomllib; text=sqlite3.connect('/Users/jessyhuang/.cc-switch/cc-switch.db').execute('select value from settings where key=\"common_config_codex\"').fetchone()[0]; data=tomllib.loads(text); print(data.get('mcp_servers', {}).keys())"
python3.11 scripts/sync_config.py --dry-run
```

If `tomllib.loads` reports duplicate keys or the requested MCP server is still
missing, repair `settings.common_config_codex` before finishing. The current
sync script is add-only and may not add a new child table such as
`[mcp_servers.mempalace]` when `[mcp_servers]` already exists in the target.
