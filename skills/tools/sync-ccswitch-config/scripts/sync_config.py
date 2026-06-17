#!/usr/bin/env python3
"""
Sync shared config from ~/.claude/settings.json to cc-switch's common_config_claude.

Merges (add-only, never removes):
  - enabledPlugins
  - extraKnownMarketplaces
  - mcpServers
  - model
  - Shared env vars (excludes provider-specific ones like ANTHROPIC_BASE_URL,
    ANTHROPIC_API_KEY, ANTHROPIC_MODEL, ANTHROPIC_DEFAULT_*_MODEL)

Usage:
  python3 sync_config.py          # sync and report
  python3 sync_config.py --dry-run  # show what would change, don't write
"""

import copy
import json
import os
import sqlite3
import sys
from pathlib import Path

# Provider-specific env vars — these belong to provider.settings_config, NOT common_config
PROVIDER_ENV_KEYS = {
    "ANTHROPIC_BASE_URL",
    "ANTHROPIC_API_KEY",
    "ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL",
    "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME",
    "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME",
}

# Keys in settings.json that should be synced to common_config
SYNC_KEYS = [
    "enabledPlugins",
    "extraKnownMarketplaces",
    "mcpServers",
    "model",
]


def resolve_path(p: str) -> Path:
    """Resolve ~ in paths."""
    return Path(p).expanduser()


def read_settings_json(path: Path) -> dict:
    """Read and parse settings.json."""
    if not path.exists():
        print(f"[ERROR] settings.json not found at {path}")
        sys.exit(1)
    with open(path, "r") as f:
        return json.load(f)


def read_common_config(db_path: Path) -> dict:
    """Read common_config_claude from cc-switch database."""
    if not db_path.exists():
        print(f"[ERROR] cc-switch database not found at {db_path}")
        sys.exit(1)

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    cursor = conn.execute(
        "SELECT value FROM settings WHERE key = 'common_config_claude'"
    )
    row = cursor.fetchone()
    conn.close()

    if row is None:
        print("[INFO] No existing common_config_claude found, starting fresh.")
        return {}

    return json.loads(row["value"])


def write_common_config(db_path: Path, config: dict) -> None:
    """Write common_config_claude back to cc-switch database."""
    conn = sqlite3.connect(str(db_path))
    config_json = json.dumps(config, indent=2, ensure_ascii=False)

    existing = conn.execute(
        "SELECT key FROM settings WHERE key = 'common_config_claude'"
    ).fetchone()

    if existing:
        conn.execute(
            "UPDATE settings SET value = ? WHERE key = 'common_config_claude'",
            (config_json,),
        )
    else:
        conn.execute(
            "INSERT INTO settings (key, value) VALUES ('common_config_claude', ?)",
            (config_json,),
        )

    conn.commit()
    conn.close()


def filter_shared_env(env: dict) -> dict:
    """Return only shared env vars, excluding provider-specific ones."""
    return {k: v for k, v in env.items() if k not in PROVIDER_ENV_KEYS}


def deep_merge(base: dict, incoming: dict) -> dict:
    """
    Merge incoming into base. Only adds new keys, never removes or overwrites.
    For nested dicts, merge recursively.
    For scalar values, keep base value if it exists.
    """
    for key, incoming_val in incoming.items():
        if key not in base:
            # New key — add it
            base[key] = incoming_val
        elif isinstance(base[key], dict) and isinstance(incoming_val, dict):
            # Both are dicts — merge recursively
            deep_merge(base[key], incoming_val)
        # else: key exists in base, keep base value (don't overwrite)
    return base


def compute_diff(old_config: dict, new_config: dict) -> dict:
    """Compute what was added (for reporting). Returns dict of additions."""
    diff = {
        "enabledPlugins": {},
        "extraKnownMarketplaces": {},
        "mcpServers": {},
        "env": {},
        "model": None,
    }

    # Check each sync key
    for key in ["enabledPlugins", "extraKnownMarketplaces", "mcpServers"]:
        old_val = old_config.get(key, {})
        new_val = new_config.get(key, {})
        if isinstance(old_val, dict) and isinstance(new_val, dict):
            added = {k: v for k, v in new_val.items() if k not in old_val}
            if added:
                diff[key] = added

    # Check env (shared env only)
    old_env = old_config.get("env", {})
    new_env = new_config.get("env", {})
    shared_new = filter_shared_env(new_env)
    shared_old = filter_shared_env(old_env)
    added_env = {k: v for k, v in shared_new.items() if k not in shared_old}
    if added_env:
        diff["env"] = added_env

    # Check model
    if "model" in new_config and "model" not in old_config:
        diff["model"] = new_config["model"]

    return diff


def report_diff(diff: dict) -> None:
    """Print a human-readable report of changes."""
    has_changes = False

    for section, label in [
        ("enabledPlugins", "🔌 Plugins"),
        ("extraKnownMarketplaces", "🏪 Marketplaces"),
        ("mcpServers", "🔧 MCP Servers"),
        ("env", "⚙️  Shared Env Vars"),
    ]:
        items = diff.get(section, {})
        if items:
            has_changes = True
            print(f"\n{label}:")
            for k, v in items.items():
                if isinstance(v, (dict, list)):
                    print(f"  + {k}")
                else:
                    print(f"  + {k} = {v}")

    if diff.get("model"):
        has_changes = True
        print(f"\n🤖 Model:")
        print(f"  + model = {diff['model']}")

    if not has_changes:
        print("\n✅ No new changes to sync — common_config_claude is already up to date.")


def main():
    dry_run = "--dry-run" in sys.argv

    settings_path = resolve_path("~/.claude/settings.json")
    db_path = resolve_path("~/.cc-switch/cc-switch.db")

    # Read sources
    print(f"📖 Reading settings.json from {settings_path}")
    settings = read_settings_json(settings_path)

    print(f"📖 Reading common_config_claude from {db_path}")
    common_config = read_common_config(db_path)

    # Build the synced config: start with old, merge in new additions
    synced = copy.deepcopy(common_config)  # deep copy to avoid mutating original
    synced.setdefault("enabledPlugins", {})
    synced.setdefault("extraKnownMarketplaces", {})
    synced.setdefault("mcpServers", {})
    synced.setdefault("env", {})

    for key in SYNC_KEYS:
        if key in settings:
            if isinstance(settings[key], dict):
                synced[key] = deep_merge(synced.get(key, {}), settings[key])
            else:
                # Scalar value (like "model") — only set if not already present
                if key not in synced:
                    synced[key] = settings[key]

    # Handle env separately — only shared env vars
    if "env" in settings:
        shared_env = filter_shared_env(settings["env"])
        synced["env"] = deep_merge(synced.get("env", {}), shared_env)

    # Compute and report diff
    diff = compute_diff(common_config, synced)
    report_diff(diff)

    if dry_run:
        print("\n🔍 --dry-run: No changes written to database.")
        return

    # Check if there are actual changes
    has_changes = any(
        bool(v) if v != 0 else False  # exclude model=None
        for v in [
            diff["enabledPlugins"],
            diff["extraKnownMarketplaces"],
            diff["mcpServers"],
            diff["env"],
            diff["model"],
        ]
    )

    if not has_changes:
        return

    # Write back
    print(f"\n💾 Writing updated common_config_claude to database...")
    write_common_config(db_path, synced)
    print("✅ Sync complete! cc-switch common_config_claude is now up to date.")


if __name__ == "__main__":
    main()
