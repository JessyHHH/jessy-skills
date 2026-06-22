#!/usr/bin/env python3
"""Delegate to the top-level sync-ccswitch-config-codex script."""

from pathlib import Path
import runpy


SCRIPT = (
    Path(__file__).resolve().parents[3]
    / "sync-ccswitch-config-codex"
    / "scripts"
    / "sync_config.py"
)

runpy.run_path(str(SCRIPT), run_name="__main__")
