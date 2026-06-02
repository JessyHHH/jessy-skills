#!/bin/bash
set -e
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
echo "Installing jessy-skills from: $DOTFILES"
echo ""

# === Platform detection ===
HAS_HERMES=0
HAS_CLAUDE=0
command -v hermes >/dev/null 2>&1 && HAS_HERMES=1
command -v claude >/dev/null 2>&1 && HAS_CLAUDE=1
echo "→ Platform detection: Hermes=$([ $HAS_HERMES -eq 1 ] && echo 'yes' || echo 'no'), Claude Code=$([ $HAS_CLAUDE -eq 1 ] && echo 'yes' || echo 'no')"
echo ""

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

# === Install skills to Claude Code (symlink-based) ===
if [ $HAS_CLAUDE -eq 1 ]; then
    echo "→ Installing skills to Claude Code..."
    mkdir -p ~/.claude/skills
    CC_INSTALLED=0
    for skill_dir in "$DOTFILES/skills/"*/; do
        skill_name=$(basename "$skill_dir")
        target="$HOME/.claude/skills/$skill_name"

        # Skip if already a symlink to the same location
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_dir" ]; then
            continue
        fi

        # Remove existing non-symlink entry if present
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            rm -rf "$target"
        fi

        # Create symlink
        ln -sfn "$skill_dir" "$target"
        CC_INSTALLED=$((CC_INSTALLED + 1))
    done
    echo "  ✓ Claude Code skills installed ($CC_INSTALLED symlinks)"
fi

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
if [ -f ~/.bashrc ] || [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ] || command -v bash >/dev/null 2>&1; then
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

# === Claude Code setup ===
if [ $HAS_CLAUDE -eq 1 ]; then
    echo ""
    echo "→ Setting up Claude Code integration..."

    # === Branch detection: Claude Code needs 'claude' branch ===
    if [ -d "$DOTFILES/.git" ]; then
        CURRENT_BRANCH=$(git -C "$DOTFILES" branch --show-current 2>/dev/null || echo "unknown")
        if [ "$CURRENT_BRANCH" != "claude" ]; then
            echo "  ⚠ Current branch: $CURRENT_BRANCH — Claude Code needs 'claude' branch"
            # Check if claude branch exists
            if git -C "$DOTFILES" show-ref --verify --quiet refs/heads/claude 2>/dev/null || \
               git -C "$DOTFILES" show-ref --verify --quiet refs/remotes/origin/claude 2>/dev/null; then
                echo "  → Auto-switching to 'claude' branch..."
                git -C "$DOTFILES" checkout claude 2>/dev/null || \
                git -C "$DOTFILES" checkout -b claude origin/claude 2>/dev/null
                echo "  ✓ Switched to claude branch"
            else
                echo "  ⚠ 'claude' branch not found. Staying on $CURRENT_BRANCH."
                echo "  → For Claude Code support: git checkout claude (after git fetch)"
            fi
        else
            echo "  ✓ Already on claude branch"
        fi
    fi

    # Create .claude/skills symlink in the repo if running from within it
    if [ -d "$DOTFILES/skills" ] && [ ! -L "$DOTFILES/.claude/skills" ]; then
        mkdir -p "$DOTFILES/.claude"
        ln -sfn ../skills "$DOTFILES/.claude/skills" 2>/dev/null || true
        echo "  ✓ .claude/skills → ../skills symlink created"
    fi

    # Install workflow scripts to global location (so they work from any project)
    WF_INSTALL="$HOME/.claude/workflows/project-workflow-claude"
    if [ -d "$DOTFILES/.claude/workflows" ]; then
        mkdir -p "$WF_INSTALL"
        cp "$DOTFILES/.claude/workflows/"*.js "$WF_INSTALL/" 2>/dev/null || true
        echo "  ✓ Workflow scripts installed to $WF_INSTALL/ ($(ls "$WF_INSTALL" 2>/dev/null | wc -l | tr -d ' ') scripts)"
    fi

    # Create .claude/workflows symlink if running from within the repo
    if [ -d "$DOTFILES/.claude/workflows" ] && [ ! -L "$HOME/.claude/workflows" ]; then
        # Workflow scripts stay in the repo; they're accessed via CWD
        echo "  ✓ .claude/workflows/ available from project root"
    fi

    # Copy project CLAUDE.md if not already present
    if [ -f "$DOTFILES/CLAUDE.md" ] && [ ! -f "$HOME/.claude/CLAUDE.md" ]; then
        # Don't auto-overwrite user's global CLAUDE.md; just inform
        echo "  ℹ Project CLAUDE.md available at $DOTFILES/CLAUDE.md"
    fi

    echo "  ✓ Claude Code integration ready"

    # project-workflow-claude v2.1 — standalone, no external dependencies
    echo "  ℹ project-workflow-claude v2.1 is fully standalone"
    echo "  → 4 Workflow scripts included (.claude/workflows/)"
    echo "  → Auto-detects Context7/Firecrawl MCP (falls back to WebFetch/WebSearch)"
    echo "  → Iron Law: references/iron-law.md"

    echo "  ℹ Restart Claude Code or run /reload-skills to activate"
fi

# === Reload ===
if [ $HAS_HERMES -eq 1 ]; then
    echo "→ Reloading Hermes skills..."
    hermes skills list > /dev/null 2>&1 || true
fi

echo ""
echo "Done."
if [ $HAS_HERMES -eq 1 ]; then
    echo "  Hermes: skills installed to ~/.hermes/skills/"
    echo "  zsh:  source ~/.zshrc"
    echo "  bash: source ~/.bashrc"
fi
if [ $HAS_CLAUDE -eq 1 ]; then
    echo "  Claude Code: skills installed to ~/.claude/skills/"
    echo "  Run /reload-skills in Claude Code to activate"
fi
echo "  pwsh: . \$PROFILE"
