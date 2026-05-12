#!/bin/bash
set -e
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
echo "Installing Hermes dotfiles from: $DOTFILES"

# Backup existing skills (non-fatal if fails)
if [ -d "$HOME/.hermes/skills" ] && [ "$(ls -A "$HOME/.hermes/skills" 2>/dev/null)" ]; then
    BACKUP="$HOME/.hermes/skills.bak.$(date +%Y%m%d_%H%M%S)"
    echo "→ Backing up existing skills to $BACKUP"
    cp -r "$HOME/.hermes/skills" "$BACKUP" 2>/dev/null || echo "  ⚠ Backup failed, continuing anyway"
fi

# Copy skills
echo "→ Copying skills..."
mkdir -p ~/.hermes/skills
cp -r "$DOTFILES/skills/"* ~/.hermes/skills/
echo "  ✓ Skills installed ($(ls "$DOTFILES/skills" | wc -l | tr -d ' ') skills)"

# Clean stale skills (exists locally but not in dotfiles)
echo "→ Checking for stale skills..."
for skill_dir in ~/.hermes/skills/*/; do
    skill_name=$(basename "$skill_dir")
    # Skip builtin skills (they have category subdirectories)
    if [[ "$skill_name" == "apple"* || "$skill_name" == "autonomous"* || 
          "$skill_name" == "creative" || "$skill_name" == "data-science" ||
          "$skill_name" == "devops" || "$skill_name" == "email" ||
          "$skill_name" == "gaming" || "$skill_name" == "github" ||
          "$skill_name" == "mcp" || "$skill_name" == "media" ||
          "$skill_name" == "mlops" || "$skill_name" == "note-taking" ||
          "$skill_name" == "productivity" || "$skill_name" == "red-teaming" ||
          "$skill_name" == "research" || "$skill_name" == "smart-home" ||
          "$skill_name" == "social-media" || "$skill_name" == "software-development" ]]; then
        continue
    fi
    if [ ! -d "$DOTFILES/skills/$skill_name" ]; then
        echo "  - Removing stale skill: $skill_name"
        rm -rf "$skill_dir"
    fi
done

# Auto-detect shell config file
SHELL_RC=""
if [ -f ~/.zshrc ]; then SHELL_RC=~/.zshrc; fi
if [ -f ~/.bashrc ]; then SHELL_RC=~/.bashrc; fi
if [ -z "$SHELL_RC" ]; then
    echo "  ⚠ No ~/.zshrc or ~/.bashrc found — creating ~/.bashrc"
    touch ~/.bashrc
    SHELL_RC=~/.bashrc
fi

# Update hermes shell function (replace old version if exists)
SHELL_FUNC_START=$(grep -n '# Auto-load core skills\|# Bypass:' "$SHELL_RC" 2>/dev/null | head -1 | cut -d: -f1)
if [ -n "$SHELL_FUNC_START" ]; then
    # Remove old function (from comment to closing })
    END_LINE=$(tail -n "+$SHELL_FUNC_START" "$SHELL_RC" | grep -n '^}' | head -1 | cut -d: -f1)
    if [ -n "$END_LINE" ]; then
        DELETE_END=$((SHELL_FUNC_START + END_LINE - 1))
        sed -i '' "${SHELL_FUNC_START},${DELETE_END}d" "$SHELL_RC" 2>/dev/null || \
        sed -i "${SHELL_FUNC_START},${DELETE_END}d" "$SHELL_RC"
        echo "  ↻ Old shell function removed from $SHELL_RC"
    fi
fi
# Add new function
echo "" >> "$SHELL_RC"
cat "$DOTFILES/shell/hermes.sh" >> "$SHELL_RC"
echo "  ✓ Shell function installed to $SHELL_RC"

# Reload
echo "→ Reloading Hermes skills..."
hermes skills list > /dev/null 2>&1 || true

echo ""
echo "Done. Run 'source $SHELL_RC' or open a new terminal."
