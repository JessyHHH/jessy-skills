#!/bin/bash
set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
CODEX_SYNC_HOME="$HOME/.jessy-skills-codex"

echo "Installing jessy-skills Codex branch from: $DOTFILES"
echo "This branch is Codex-only. For Claude Code or Hermes workflows, switch to the corresponding branch."
echo ""

sync_repo_snapshot() {
    local dest="$1"
    local label="$2"
    local tmp="${dest}.tmp.$$"

    rm -rf "$tmp"
    mkdir -p "$tmp"
    tar -C "$DOTFILES" \
        --exclude='./.git' \
        --exclude='./.codex/state' \
        --exclude='./.codex/plans' \
        --exclude='./.codex/specs' \
        --exclude='./.omc' \
        --exclude='./.firecrawl' \
        --exclude='./.agents/skills' \
        -cf - . | tar -C "$tmp" -xf -
    rm -rf "$dest"
    mv "$tmp" "$dest"
    echo "  ✓ $label snapshot synced to $dest"
}

HAS_CODEX=0
command -v codex >/dev/null 2>&1 && HAS_CODEX=1
echo "→ Platform detection: Codex=$([ $HAS_CODEX -eq 1 ] && echo 'yes' || echo 'no')"
echo ""

if [ $HAS_CODEX -ne 1 ]; then
    echo "  ⚠ Codex CLI not found on PATH. Install Codex first, then rerun this script."
    exit 1
fi

echo "→ Installing skills to Codex..."
sync_repo_snapshot "$CODEX_SYNC_HOME" "Codex"

mkdir -p "$HOME/.agents/skills"
ln -sfn "$CODEX_SYNC_HOME/skills" "$HOME/.agents/skills/jessy-skills"
echo "  ✓ Global Codex skills linked: ~/.agents/skills/jessy-skills → $CODEX_SYNC_HOME/skills"

if [ -d "$CODEX_SYNC_HOME/codex/agents" ]; then
    mkdir -p "$HOME/.codex/agents"
    cp "$CODEX_SYNC_HOME/codex/agents/"*.toml "$HOME/.codex/agents/"
    echo "  ✓ Codex agent templates installed to ~/.codex/agents"
    echo "  → Execution/test/repair/debugging: gpt-5.3-codex; review/verification: gpt-5.4-mini"
fi

echo ""
echo "Done."
echo "  Codex skills: ~/.agents/skills/jessy-skills/"
echo "  Codex full snapshot: $CODEX_SYNC_HOME"
echo "  Codex custom agents: ~/.codex/agents/"
echo "  This installer did not modify ~/.codex/AGENTS.md"
echo "  Restart Codex, then run /skills or invoke \$project-workflow-codex."
