---
name: sync-ccswitch-config
description: >
  Sync Claude Code settings (plugins, MCP servers, marketplaces, shared env) to
  cc-switch's common_config_claude database. Use this whenever the user installs
  a plugin (/plugin), adds an MCP server, configures a marketplace, or changes
  shared env vars in settings.json — otherwise cc-switch will overwrite those
  changes on next restart. Triggers on: "sync ccswitch", "sync config",
  "sync cc-switch", "sync common config", "save config to ccswitch",
  "update ccswitch config", "backup config to ccswitch", "同步配置",
  or when the user mentions losing settings after restart.
---

# Sync cc-switch Common Config

Syncs shared configuration from `~/.claude/settings.json` into cc-switch's
SQLite database so it survives provider switches and Claude Code restarts.

## Why this exists

cc-switch manages `settings.json` as the **source of truth**. Every restart
or provider switch **overwrites** `settings.json` from the database.
Changes made directly in Claude Code (`/plugin`, MCP setup, marketplaces)
are lost unless synced back to cc-switch's database.

This skill runs the sync script that merges new additions into
`common_config_claude` — **add-only, never removes**.

## What gets synced

| Setting | Behavior |
|---------|----------|
| `enabledPlugins` | New plugins added, existing kept |
| `extraKnownMarketplaces` | New marketplaces added, existing kept |
| `mcpServers` | New MCP servers added, existing kept |
| `model` | Set if not already configured |
| `env` (shared) | New shared env vars added, existing kept |

## What is NOT synced (provider-specific)

These env vars belong to the provider's `settings_config` and are
intentionally excluded:

- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_MODEL`
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`
- `ANTHROPIC_DEFAULT_SONNET_MODEL`
- `ANTHROPIC_DEFAULT_OPUS_MODEL`
- `ANTHROPIC_DEFAULT_*_MODEL_NAME`

## Usage

Run the bundled sync script:

```bash
python3 ~/.claude/skills/sync-ccswitch-config/scripts/sync_config.py
```

For a preview without writing:

```bash
python3 ~/.claude/skills/sync-ccswitch-config/scripts/sync_config.py --dry-run
```

## Workflow

1. Run the script
2. Review the reported additions (plugins, MCPs, marketplaces, env vars)
3. If `--dry-run` was used and looks correct, run again without it
4. Report the result to the user — what was synced

The script is idempotent — running it multiple times won't duplicate anything.
