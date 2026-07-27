#!/usr/bin/env python3
"""Snapshot reusable local Codex configuration into this repository."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import os
import re
import stat
import sys
import tempfile
import tomllib
from pathlib import Path
from urllib.parse import urlsplit


EXCLUDED_TOP_LEVEL = {"model_provider", "model_providers"}
SENSITIVE_COMPACT_KEYS = {
    "apikey",
    "auth",
    "authorization",
    "authtoken",
    "credential",
    "credentials",
    "password",
    "passwd",
    "privatekey",
    "secret",
    "token",
}
SENSITIVE_KEY_PARTS = {
    "accesstoken",
    "apikey",
    "authtoken",
    "clientsecret",
    "credential",
    "password",
    "privatekey",
    "refreshtoken",
}
SENSITIVE_KEY_TERMS = {
    "auth",
    "authorization",
    "credential",
    "credentials",
    "passwd",
    "password",
    "secret",
    "token",
}
SAFE_NON_SECRET_KEYS = {
    "bearer_token_env_var",
    "model_auto_compact_token_limit",
}
CREDENTIAL_PATTERNS = (
    re.compile(r"(?i)\b(?:sk|ghp|github_pat|xox[baprs])[-_][A-Za-z0-9_-]{12,}\b"),
    re.compile(r"\bAKIA[A-Z0-9]{12,}\b"),
    re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._-]{12,}\b"),
    re.compile(
        r"(?i)\b(?:password|secret|api[_-]?key|access[_-]?token)\s*[:=]\s*[^\s,;]{6,}"
    ),
)
BARE_KEY_RE = re.compile(r"^[A-Za-z0-9_-]+$")


class SyncError(RuntimeError):
    """Raised when a source value cannot be snapshotted safely."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("~/.codex"),
        help="local Codex directory (default: ~/.codex)",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="repository root inferred from this script by default",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="report snapshot drift without writing files",
    )
    return parser.parse_args()


def compact_key(key: str) -> str:
    return re.sub(r"[^a-z0-9]", "", key.lower())


def split_key(key: str) -> str:
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", key)


def is_sensitive_key(key: str) -> bool:
    lowered = key.lower()
    if lowered in SAFE_NON_SECRET_KEYS:
        return False
    compact = compact_key(key)
    normalized = split_key(key).lower()
    terms = {term for term in re.split(r"[^a-z0-9]+", normalized) if term}
    return (
        compact in SENSITIVE_COMPACT_KEYS
        or bool(terms & SENSITIVE_KEY_TERMS)
        or any(part in compact for part in SENSITIVE_KEY_PARTS)
    )


def placeholder_for(key: str) -> str:
    name = re.sub(r"[^A-Za-z0-9]+", "_", split_key(key)).strip("_").upper()
    return f"${{{name or 'SECRET'}}}"


def looks_like_credential(value: str) -> bool:
    if any(pattern.search(value) for pattern in CREDENTIAL_PATTERNS):
        return True
    if "://" not in value:
        return False
    try:
        parsed = urlsplit(value)
    except ValueError:
        return False
    return parsed.password is not None


def sanitize(value: object, path: tuple[str, ...] = ()) -> object:
    if isinstance(value, dict):
        clean: dict[str, object] = {}
        for key, child in value.items():
            key = str(key)
            if not path and key in EXCLUDED_TOP_LEVEL:
                continue
            if is_sensitive_key(key):
                clean[key] = placeholder_for(key)
            else:
                clean[key] = sanitize(child, path + (key,))
        return clean
    if isinstance(value, list):
        return [sanitize(child, path + (str(index),)) for index, child in enumerate(value)]
    if isinstance(value, str) and looks_like_credential(value):
        dotted = ".".join(path) or "<root>"
        raise SyncError(f"credential-like value found under non-sensitive key: {dotted}")
    if isinstance(value, float) and not math.isfinite(value):
        dotted = ".".join(path) or "<root>"
        raise SyncError(f"non-finite float is not supported in snapshots: {dotted}")
    return value


def credential_paths(value: object, path: tuple[str, ...] = ()) -> list[str]:
    issues: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            key = str(key)
            child_path = path + (key,)
            if is_sensitive_key(key):
                issues.append(".".join(child_path))
            else:
                issues.extend(credential_paths(child, child_path))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            issues.extend(credential_paths(child, path + (str(index),)))
    elif isinstance(value, str) and looks_like_credential(value):
        issues.append(".".join(path) or "<root>")
    return issues


def read_safe_agent(path: Path) -> bytes:
    content = read_required(path)
    try:
        parsed = tomllib.loads(content.decode("utf-8"))
    except (UnicodeDecodeError, tomllib.TOMLDecodeError) as exc:
        raise SyncError(f"cannot parse agent TOML {path}: {exc}") from exc
    issues = credential_paths(parsed)
    if issues:
        raise SyncError(
            f"agent TOML contains credential-bearing paths: {path}: {', '.join(issues)}"
        )
    return content


def format_key(key: str) -> str:
    return key if BARE_KEY_RE.fullmatch(key) else json.dumps(key, ensure_ascii=False)


def format_string(value: str) -> str:
    if "\n" not in value:
        return json.dumps(value, ensure_ascii=False)
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\t", "\\t")
        .replace("\b", "\\b")
        .replace("\f", "\\f")
    )
    return f'"""\n{escaped}"""'


def format_value(value: object) -> str:
    if isinstance(value, str):
        return format_string(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, (dt.datetime, dt.date, dt.time)):
        return value.isoformat()
    if isinstance(value, list) and not any(isinstance(item, dict) for item in value):
        return "[" + ", ".join(format_value(item) for item in value) + "]"
    raise SyncError(f"unsupported TOML value type: {type(value).__name__}")


def is_array_of_tables(value: object) -> bool:
    return isinstance(value, list) and bool(value) and all(
        isinstance(item, dict) for item in value
    )


def render_table(
    path: tuple[str, ...], data: dict[str, object], *, array: bool = False
) -> list[str]:
    lines: list[str] = []
    if path:
        name = ".".join(format_key(part) for part in path)
        lines.append(f"[[{name}]]" if array else f"[{name}]")

    scalar_items: list[tuple[str, object]] = []
    table_items: list[tuple[str, dict[str, object]]] = []
    array_table_items: list[tuple[str, list[dict[str, object]]]] = []
    for key, value in data.items():
        if isinstance(value, dict):
            table_items.append((key, value))
        elif is_array_of_tables(value):
            array_table_items.append((key, value))
        else:
            scalar_items.append((key, value))

    lines.extend(f"{format_key(key)} = {format_value(value)}" for key, value in scalar_items)

    for key, child in table_items:
        if lines:
            lines.append("")
        lines.extend(render_table(path + (key,), child))

    for key, children in array_table_items:
        for child in children:
            if lines:
                lines.append("")
            lines.extend(render_table(path + (key,), child, array=True))

    return lines


def render_config(source: Path) -> bytes:
    try:
        parsed = tomllib.loads(source.read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise SyncError(f"cannot read source config {source}: {exc}") from exc
    sanitized = sanitize(parsed)
    if not isinstance(sanitized, dict):
        raise SyncError("source config root is not a TOML table")

    body = "\n".join(render_table((), sanitized)).rstrip() + "\n"
    header = (
        "# Generated from ~/.codex/config.toml by codex/scripts/sync_from_local.py.\n"
        "# Provider configuration is excluded; sensitive values use ${ENV_NAME} placeholders.\n\n"
    )
    output = (header + body).encode("utf-8")
    try:
        round_trip = tomllib.loads(output.decode("utf-8"))
    except tomllib.TOMLDecodeError as exc:
        raise SyncError(f"generated config is invalid TOML: {exc}") from exc
    if round_trip != sanitized:
        raise SyncError("generated config failed TOML round-trip validation")
    return output


def read_required(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError as exc:
        raise SyncError(f"cannot read required source file {path}: {exc}") from exc


def atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as handle:
        temp_path = Path(handle.name)
        handle.write(content)
    try:
        temp_path.chmod(0o644)
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def sync_file(path: Path, expected: bytes, check: bool) -> bool:
    exists = path.exists() or path.is_symlink()
    if exists and not stat.S_ISREG(path.lstat().st_mode):
        print(f"UNSAFE {path} is not a regular file", file=sys.stderr)
        return False
    current = path.read_bytes() if exists else None
    mode = path.lstat().st_mode & 0o777 if exists else None
    if current == expected and mode == 0o644:
        print(f"OK    {path}")
        return True
    if check:
        print(f"DRIFT {path}")
        return False
    atomic_write(path, expected)
    print(f"WRITE {path}")
    return True


def main() -> int:
    args = parse_args()
    source_dir = args.source_dir.expanduser().resolve()
    repo_root = args.repo_root.expanduser().resolve()
    global_dir = repo_root / "codex" / "global"

    source_agents = source_dir / "agents"
    try:
        expected_config = render_config(source_dir / "config.toml")
        expected_agents = read_required(source_dir / "AGENTS.md")
        agent_snapshots = [
            (source.name, read_safe_agent(source))
            for source in sorted(source_agents.glob("*.toml"))
        ] if source_agents.is_dir() else []
    except SyncError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 2

    clean = True
    clean &= sync_file(global_dir / "config.toml", expected_config, args.check)
    clean &= sync_file(global_dir / "AGENTS.md", expected_agents, args.check)

    for name, content in agent_snapshots:
        clean &= sync_file(
            repo_root / "codex" / "agents" / name,
            content,
            args.check,
        )

    if not clean:
        message = (
            "Codex repository snapshot is out of date."
            if args.check
            else "Codex repository snapshot could not be updated safely."
        )
        print(message, file=sys.stderr)
        return 1
    print("Codex repository snapshot is up to date.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
