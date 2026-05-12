#!/bin/bash
set -e
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
echo "Installing Hermes dotfiles from: $DOTFILES"

# === Backup ===
if [ -d "$HOME/.hermes/skills" ] && [ "$(ls -A "$HOME/.hermes/skills" 2>/dev/null)" ]; then
    BACKUP="$HOME/.hermes/skills.bak.$(date +%Y%m%d_%H%M%S)"
    echo "→ Backing up existing skills to $BACKUP"
    cp -r "$HOME/.hermes/skills" "$BACKUP" 2>/dev/null || echo "  ⚠ Backup failed, continuing anyway"
fi

# === Copy skills ===
echo "→ Copying skills..."
mkdir -p ~/.hermes/skills
cp -r "$DOTFILES/skills/"* ~/.hermes/skills/
echo "  ✓ Skills installed ($(ls "$DOTFILES/skills" | wc -l | tr -d ' ') skill dirs)"

# === Clean stale skills ===
echo "→ Checking for stale skills..."
BUILTIN_PREFIXES="apple autonomous creative data-science devops email gaming github mcp media mlops note-taking productivity red-teaming research smart-home social-media software-development"
for skill_dir in ~/.hermes/skills/*/; do
    skill_name=$(basename "$skill_dir")
    is_builtin=0
    for prefix in $BUILTIN_PREFIXES; do
        [[ "$skill_name" == "$prefix"* ]] && is_builtin=1 && break
    done
    [ $is_builtin -eq 1 ] && continue
    if [ ! -d "$DOTFILES/skills/$skill_name" ]; then
        echo "  - Removing stale skill: $skill_name"
        rm -rf "$skill_dir"
    fi
done

# === Install shell integration (source-based, not inline) ===
echo "→ Installing shell integration..."

# Copy hermes wrapper to dotfiles location
JESSY_HOME="$HOME/.jessy-skills"
mkdir -p "$JESSY_HOME"
cp "$DOTFILES/shell/hermes.sh" "$JESSY_HOME/hermes.sh"
echo "  ✓ hermes.sh installed to $JESSY_HOME/"

SOURCE_LINE='[ -f "$HOME/.jessy-skills/hermes.sh" ] && source "$HOME/.jessy-skills/hermes.sh"'

install_shell_config() {
    local rc_file="$1"
    local name="$2"
    if [ ! -f "$rc_file" ]; then
        touch "$rc_file"
        echo "  ✓ Created $name: $rc_file"
    fi

    # Remove old inline function if exists
    if grep -q "hermes()" "$rc_file" 2>/dev/null; then
        # Find start and end of old function
        local start=$(grep -n "hermes()" "$rc_file" | head -1 | cut -d: -f1)
        if [ -n "$start" ]; then
            # Count braces to find matching end (handles nested functions)
            local depth=0 line="$start" found=0
            while IFS= read -r l; do
                depth=$((depth + $(echo "$l" | grep -o '{' | wc -l) - $(echo "$l" | grep -o '}' | wc -l)))
                if [ $depth -le 0 ] && [ $line -gt $start ]; then
                    local end=$line
                    found=1
                    break
                fi
                line=$((line + 1))
            done < <(tail -n "+$start" "$rc_file")
            if [ $found -eq 1 ]; then
                sed -i "${start},${end}d" "$rc_file" 2>/dev/null || sed -i '' "${start},${end}d" "$rc_file"
                echo "  ↻ Removed old inline hermes() from $name"
            fi
        fi
    fi

    # Remove old source line if exists (stale path)
    sed -i '/\.jessy-skills\/hermes\.sh/d' "$rc_file" 2>/dev/null || sed -i '' '/\.jessy-skills\/hermes\.sh/d' "$rc_file"

    # Add source line if not present
    if ! grep -qF "$SOURCE_LINE" "$rc_file" 2>/dev/null; then
        echo "" >> "$rc_file"
        echo "$SOURCE_LINE" >> "$rc_file"
        echo "  ✓ Shell integration added to $name"
    else
        echo "  ✓ $name already configured"
    fi
}

# Detect and configure all available shells
SHELLS_CONFIGURED=0

# zsh
if [ -f ~/.zshrc ] || [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
    install_shell_config ~/.zshrc "zsh"
    SHELLS_CONFIGURED=$((SHELLS_CONFIGURED + 1))
fi

# bash
if [ -f ~/.bashrc ] || [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
    install_shell_config ~/.bashrc "bash"
    SHELLS_CONFIGURED=$((SHELLS_CONFIGURED + 1))
fi

# PowerShell (Windows / WSL / Linux pwsh)
if command -v pwsh >/dev/null 2>&1; then
    PWSH_PROFILE=$(pwsh -NoProfile -Command '$PROFILE.CurrentUserAllHosts' 2>/dev/null || echo "")
    if [ -n "$PWSH_PROFILE" ]; then
        mkdir -p "$(dirname "$PWSH_PROFILE")"
        if [ ! -f "$PWSH_PROFILE" ]; then
            touch "$PWSH_PROFILE"
        fi
        # Remove old inline function
        if grep -q "function hermes" "$PWSH_PROFILE" 2>/dev/null || grep -q "hermes()" "$PWSH_PROFILE" 2>/dev/null; then
            # PowerShell doesn't use source; add a wrapper that calls bash
            echo "  ⚠ PowerShell profile has old hermes function — replace manually with: bash -c 'source ~/.jessy-skills/hermes.sh; hermes'"
        fi
        POWERSHELL_SOURCE_LINE='if (Test-Path "$env:USERPROFILE\.jessy-skills\hermes.sh") { function hermes { bash -c "source $env:USERPROFILE\.jessy-skills\hermes.sh; hermes `$args" } }'
        if ! grep -q "hermes.sh" "$PWSH_PROFILE" 2>/dev/null; then
            echo "" >> "$PWSH_PROFILE"
            echo "$POWERSHELL_SOURCE_LINE" >> "$PWSH_PROFILE"
            echo "  ✓ PowerShell integration added ($(basename "$PWSH_PROFILE"))"
            SHELLS_CONFIGURED=$((SHELLS_CONFIGURED + 1))
        else
            echo "  ✓ PowerShell already configured"
            SHELLS_CONFIGURED=$((SHELLS_CONFIGURED + 1))
        fi
    fi
fi

# Fallback: no shell found
if [ $SHELLS_CONFIGURED -eq 0 ]; then
    echo "  ⚠ No zsh/bash/pwsh detected. Creating ~/.bashrc as fallback."
    install_shell_config ~/.bashrc "bash (fallback)"
fi

# === Reload ===
echo "→ Reloading Hermes skills..."
hermes skills list > /dev/null 2>&1 || true

echo ""
echo "Done."
echo "  zsh:  source ~/.zshrc"
echo "  bash: source ~/.bashrc"
echo "  pwsh: . \$PROFILE"
