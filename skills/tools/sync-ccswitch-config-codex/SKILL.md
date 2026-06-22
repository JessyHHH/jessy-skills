---
name: sync-ccswitch-config-codex
description: Sync shared Codex config from ~/.codex/config.toml into cc-switch common_config_codex. Use when Codex MCP servers, trusted projects, agents, skills config, developer instructions, or shared settings should survive provider switches.
---

# Sync cc-switch Codex Config

This tool-skill mirrors the top-level `sync-ccswitch-config-codex` skill for compatibility with the repository's tools grouping.

Use the same workflow:

```bash
python3 scripts/sync_config.py --dry-run
python3 scripts/sync_config.py
```

Default behavior is add-only, excludes provider/auth secrets, and skips hooks unless `--include-hooks` is passed.
