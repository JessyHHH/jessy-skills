#!/bin/bash
set -e
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
echo "Installing Hermes dotfiles from: $DOTFILES"

# Backup existing skills
if [ -d ~/.hermes/skills ] && [ "$(ls -A ~/.hermes/skills 2>/dev/null)" ]; then
    BACKUP="~/.hermes/skills.bak.$(date +%Y%m%d_%H%M%S)"
    echo "→ Backing up existing skills to $BACKUP"
    cp -r ~/.hermes/skills "$BACKUP"
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

# Add hermes shell function
if ! grep -q 'hermes()' ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    cat "$DOTFILES/shell/hermes.sh" >> ~/.zshrc
    echo "  ✓ Shell function added to ~/.zshrc"
else
    echo "  - Shell function already exists, skipped (update manually if needed)"
fi

# Reload
echo "→ Reloading Hermes skills..."
hermes skills list > /dev/null 2>&1 || true

echo ""
echo "Done. Run 'source ~/.zshrc' or open a new terminal."
