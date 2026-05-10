#!/bin/bash
set -e
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
echo "Installing Hermes dotfiles from: $DOTFILES"

# Copy skills
echo "→ Copying skills..."
mkdir -p ~/.hermes/skills
cp -r "$DOTFILES/skills/"* ~/.hermes/skills/
echo "  ✓ Skills installed ($(ls "$DOTFILES/skills" | wc -l | tr -d ' ') skills)"

# Add hermes shell function
if ! grep -q 'hermes()' ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    cat "$DOTFILES/shell/hermes.sh" >> ~/.zshrc
    echo "  ✓ Shell function added to ~/.zshrc"
else
    echo "  - Shell function already exists, skipped"
fi

# Reload
echo "→ Reloading Hermes skills..."
hermes skills list > /dev/null 2>&1 || true

echo ""
echo "Done. Run 'source ~/.zshrc' or open a new terminal."
