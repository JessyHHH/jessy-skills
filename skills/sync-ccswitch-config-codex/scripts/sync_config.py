#!/usr/bin/env python3
"""
Sync shared Codex config from ~/.codex/config.toml to cc-switch common_config_codex.

The cc-switch value is TOML text stored in SQLite settings.value where
settings.key = 'common_config_codex'. This script is add-only: existing target
values win, missing safe source keys/tables are appended.
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
import tomllib
from pathlib import Path


SECRET_PATTERNS = ("auth", "api_key", "apikey", "token", "secret", "password")
EXCLUDED_TOP_LEVEL = {"model_provider", "model_providers", "hooks"}
EXCLUDED_TABLE_PREFIXES = ("model_providers",)
DEFAULT_TOP_LEVEL_KEYS = {
    "disable_response_storage",
    "model_reasoning_effort",
    "model_context_window",
    "model_auto_compact_token_limit",
    "plan_mode_reasoning_effort",
    "model",
    "service_tier",
    "approvals_reviewer",
    "developer_instructions",
}
DEFAULT_TABLES = {"features", "projects", "mcp_servers", "agents", "notice", "tui", "skills"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="show changes without writing")
    parser.add_argument("--include-hooks", action="store_true", help="include [hooks] tables")
    parser.add_argument("--config", default="~/.codex/config.toml", help="source Codex config")
    parser.add_argument("--db", default="~/.cc-switch/cc-switch.db", help="cc-switch SQLite database")
    return parser.parse_args()


def has_secret_name(path: str) -> bool:
    lowered = path.lower()
    return any(pattern in lowered for pattern in SECRET_PATTERNS)


def read_toml(path: Path) -> tuple[str, dict]:
    if not path.exists():
        raise SystemExit(f"[ERROR] source config not found: {path}")
    text = path.read_text()
    return text, tomllib.loads(text)


def read_common_config(db_path: Path) -> str:
    if not db_path.exists():
        raise SystemExit(f"[ERROR] cc-switch database not found: {db_path}")
    conn = sqlite3.connect(str(db_path))
    try:
        row = conn.execute(
            "SELECT value FROM settings WHERE key = 'common_config_codex'"
        ).fetchone()
    finally:
        conn.close()
    return row[0] if row else ""


def write_common_config(db_path: Path, text: str) -> None:
    conn = sqlite3.connect(str(db_path))
    try:
        exists = conn.execute(
            "SELECT 1 FROM settings WHERE key = 'common_config_codex'"
        ).fetchone()
        if exists:
            conn.execute(
                "UPDATE settings SET value = ? WHERE key = 'common_config_codex'",
                (text,),
            )
        else:
            conn.execute(
                "INSERT INTO settings (key, value) VALUES ('common_config_codex', ?)",
                (text,),
            )
        conn.commit()
    finally:
        conn.close()


def table_header_regex(table_path: str) -> re.Pattern[str]:
    escaped = re.escape(table_path)
    return re.compile(rf"^\[{escaped}\]\s*$", re.MULTILINE)


def array_table_header_regex(table_path: str) -> re.Pattern[str]:
    escaped = re.escape(table_path)
    return re.compile(rf"^\[\[{escaped}\]\]\s*$", re.MULTILINE)


def top_level_key_exists(text: str, key: str) -> bool:
    return re.search(rf"^{re.escape(key)}\s*=", text, re.MULTILINE) is not None


def extract_top_level_assignment(source_text: str, key: str) -> str | None:
    pattern = re.compile(rf"^{re.escape(key)}\s*=", re.MULTILINE)
    match = pattern.search(source_text)
    if not match:
        return None
    start = match.start()
    lines = source_text[start:].splitlines()
    collected: list[str] = []
    in_multiline_string = False
    for line in lines:
        if collected and not in_multiline_string and re.match(r"^\s*\[", line):
            break
        collected.append(line)
        if line.count('"""') % 2 == 1:
            in_multiline_string = not in_multiline_string
        if not in_multiline_string and len(collected) > 1:
            break
    return "\n".join(collected).rstrip()


def extract_table_block(source_text: str, table: str, array: bool = False) -> str | None:
    regex = array_table_header_regex(table) if array else table_header_regex(table)
    match = regex.search(source_text)
    if not match:
        return None
    start = match.start()
    next_header = re.search(r"^\[", source_text[match.end() :], re.MULTILINE)
    end = match.end() + next_header.start() if next_header else len(source_text)
    return source_text[start:end].strip()


def collect_child_tables(source_data: dict, prefix: str) -> set[str]:
    result: set[str] = set()

    def walk(node: object, path: list[str]) -> None:
        if isinstance(node, dict):
            if path:
                result.add(".".join(path))
            for key, value in node.items():
                walk(value, path + [quote_table_part(key)])

    walk(source_data.get(prefix, {}), [prefix])
    return result


def quote_table_part(part: str) -> str:
    if re.match(r"^[A-Za-z0-9_-]+$", part):
        return part
    escaped = part.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def safe_top_level_keys(source_data: dict, include_hooks: bool) -> list[str]:
    keys = []
    excluded = set(EXCLUDED_TOP_LEVEL)
    if include_hooks:
        excluded.remove("hooks")
    for key in DEFAULT_TOP_LEVEL_KEYS:
        if key in source_data and key not in excluded and not has_secret_name(key):
            keys.append(key)
    return keys


def safe_tables(source_data: dict, include_hooks: bool) -> list[str]:
    tables = set(DEFAULT_TABLES)
    if include_hooks:
        tables.add("hooks")
    present = []
    for table in sorted(tables):
        if table in source_data and not has_secret_name(table):
            present.append(table)
    return present


def merge_add_only(source_text: str, target_text: str, include_hooks: bool) -> tuple[str, list[str]]:
    source_data = tomllib.loads(source_text)
    target_data = tomllib.loads(target_text or "")
    additions: list[str] = []
    chunks: list[str] = []

    for key in safe_top_level_keys(source_data, include_hooks):
        if key not in target_data and not top_level_key_exists(target_text, key):
            assignment = extract_top_level_assignment(source_text, key)
            if assignment:
                chunks.append(assignment)
                additions.append(key)

    for table in safe_tables(source_data, include_hooks):
        if table in target_data:
            continue
        if any(table.startswith(prefix) for prefix in EXCLUDED_TABLE_PREFIXES):
            continue
        block = extract_table_block(source_text, table)
        if block and not has_secret_name(block):
            chunks.append(block)
            additions.append(f"[{table}]")
            continue

        child_blocks = []
        for child in sorted(collect_child_tables(source_data, table)):
            if child == table or has_secret_name(child):
                continue
            if table_header_regex(child).search(target_text):
                continue
            child_block = extract_table_block(source_text, child)
            if child_block and not has_secret_name(child_block):
                child_blocks.append(child_block)
                additions.append(f"[{child}]")
        chunks.extend(child_blocks)

    if not chunks:
        return target_text, additions

    merged = target_text.rstrip()
    if merged:
        merged += "\n\n"
    merged += "\n\n".join(chunks).rstrip() + "\n"
    return merged, additions


def main() -> int:
    args = parse_args()
    source_path = Path(args.config).expanduser()
    db_path = Path(args.db).expanduser()

    source_text, _ = read_toml(source_path)
    target_text = read_common_config(db_path)
    merged, additions = merge_add_only(source_text, target_text, args.include_hooks)

    print(f"Source: {source_path}")
    print(f"Target: {db_path} settings.common_config_codex")
    if additions:
        print("Additions:")
        for item in additions:
            print(f"  + {item}")
    else:
        print("No additions. common_config_codex is already up to date for safe shared keys.")

    if args.dry_run:
        print("--dry-run: no database changes written.")
        return 0

    if merged != target_text:
        write_common_config(db_path, merged)
        print("Sync complete.")
    else:
        print("Nothing to write.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
