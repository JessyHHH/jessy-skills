<!-- Auto-generated | Commit: 652d7204f090e14ee91fbc81ab5a03056c6dadfe | Date: 2026-07-24 | skills-repository -->

## Architecture

- This is the Codex-only branch of a reusable skills repository.
- `install.sh` copies a repository snapshot to `~/.jessy-skills-codex` and links `~/.agents/skills/jessy-skills` to its `skills` directory.
- `codex/global/` stores sanitized snapshots of the machine-level Codex configuration and instructions.
- Changed skills require skill-creator validation; deterministic helpers belong under `scripts/`.

## Current Integration State

- Graphify runs in Docker and exposes authenticated Streamable HTTP MCP at `http://127.0.0.1:8001/mcp`.
- Mem0 runs in Docker and exposes an authenticated REST API at `http://127.0.0.1:8002`; it does not expose MCP.
- The tracked snapshots use Graphify for code discovery and the Mem0 REST skill for durable memory.
- The current `/root` environment has installed the repository snapshot and global skill discovery symlink.

## Verification Commands

- `bash tests/test-*.sh`
- `git diff --check`
- `python3 /root/.codex/skills/.system/skill-creator/scripts/quick_validate.py <skill-dir>`
- `python3 skills/sync-ccswitch-config-codex/scripts/sync_config.py --dry-run`
