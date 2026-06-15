#!/bin/bash
set -e
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SYNC_HOME="$HOME/.jessy-skills-claude"
CODEX_SYNC_HOME="$HOME/.jessy-skills-codex"
CODEX_DISCOVERY_SKILLS=(
    "project-workflow-codex"
    "karpathy-guidelines"
)
echo "Installing jessy-skills from: $DOTFILES"
echo ""

sync_repo_snapshot() {
    local dest="$1"
    local label="$2"
    local tmp="${dest}.tmp.$$"

    rm -rf "$tmp"
    mkdir -p "$tmp"
    tar -C "$DOTFILES" \
        --exclude='./.git' \
        --exclude='./.claude/worktrees' \
        --exclude='./.claude/state' \
        --exclude='./.omc' \
        --exclude='./.firecrawl' \
        --exclude='./.agents/skills' \
        --exclude='./.codex' \
        -cf - . | tar -C "$tmp" -xf -
    rm -rf "$dest"
    mv "$tmp" "$dest"
    echo "  ✓ $label snapshot synced to $dest"
}

# === Platform detection ===
HAS_HERMES=0
HAS_CLAUDE=0
HAS_CODEX=0
command -v hermes >/dev/null 2>&1 && HAS_HERMES=1
command -v claude >/dev/null 2>&1 && HAS_CLAUDE=1
command -v codex >/dev/null 2>&1 && HAS_CODEX=1
echo "→ Platform detection: Hermes=$([ $HAS_HERMES -eq 1 ] && echo 'yes' || echo 'no'), Claude Code=$([ $HAS_CLAUDE -eq 1 ] && echo 'yes' || echo 'no'), Codex=$([ $HAS_CODEX -eq 1 ] && echo 'yes' || echo 'no')"
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

# === Install skills to Claude Code (symlink-only, additive, never deletes external skills) ===
if [ $HAS_CLAUDE -eq 1 ]; then
    echo "→ Installing skills to Claude Code (~/.claude/skills/)..."
    sync_repo_snapshot "$CLAUDE_SYNC_HOME" "Claude Code"
    mkdir -p ~/.claude/skills
    CC_INSTALLED=0
    CC_SKIPPED=0

    # 1. Create/refresh symlinks for jessy-skills ONLY — never touch other entries
    for skill_dir in "$CLAUDE_SYNC_HOME/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        target="$HOME/.claude/skills/$skill_name"

        # Already a symlink pointing here? Skip.
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_dir" ]; then
            CC_SKIPPED=$((CC_SKIPPED + 1))
            continue
        fi

        # Remove ONLY our own stale entry (symlink pointing elsewhere, or non-symlink we created)
        if [ -L "$target" ]; then
            # Symlink exists but points to a different jessy-skills location — refresh it
            current_target="$(readlink "$target")"
            if echo "$current_target" | grep -q "jessy-skills"; then
                rm "$target"
            else
                # Symlink points to something NOT jessy-skills — don't touch, warn
                echo "  ⚠ Skipping $skill_name (existing symlink to non-jessy-skills target: $current_target)"
                CC_SKIPPED=$((CC_SKIPPED + 1))
                continue
            fi
        elif [ -e "$target" ]; then
            # Non-symlink exists — only remove if it looks like our old copy (has our marker)
            if grep -q "jessy-skills" "$target/SKILL.md" 2>/dev/null; then
                rm -rf "$target"
            else
                echo "  ⚠ Skipping $skill_name (existing non-jessy-skills directory)"
                CC_SKIPPED=$((CC_SKIPPED + 1))
                continue
            fi
        fi

        # Create symlink
        ln -sfn "$skill_dir" "$target"
        CC_INSTALLED=$((CC_INSTALLED + 1))
    done

    echo "  ✓ Claude Code: $CC_INSTALLED symlinks created/refreshed, $CC_SKIPPED external entries preserved"

    # 2. Clean stale jessy-skills symlinks (pointing to deleted project skill dirs)
    STALE_REMOVED=0
    for target in "$HOME/.claude/skills/"*; do
        [ -L "$target" ] || continue  # only check symlinks
        link_dest="$(readlink "$target")"
        skill_name="$(basename "$target")"

        # Only clean jessy-skills symlinks
        if ! echo "$link_dest" | grep -q "jessy-skills"; then
            continue
        fi

        # Symlink target no longer exists → stale
        if [ ! -d "$link_dest" ]; then
            rm "$target"
            echo "  - Removed stale symlink: $skill_name → $link_dest (target missing)"
            STALE_REMOVED=$((STALE_REMOVED + 1))
        fi
    done
    [ $STALE_REMOVED -gt 0 ] && echo "  ✓ Cleaned $STALE_REMOVED stale jessy-skills symlinks"
fi

# === Install skills to Codex (shared root symlinks) ===
if [ $HAS_CODEX -eq 1 ]; then
    echo "→ Installing skills to Codex..."
    sync_repo_snapshot "$CODEX_SYNC_HOME" "Codex"

    # Keep Codex's startup skill index small. The full skill snapshot remains at
    # $CODEX_SYNC_HOME/skills for workflow routing and explicit path loads.
    CODEX_DISCOVERY_HOME="$CODEX_SYNC_HOME/codex/skill-discovery"
    rm -rf "$CODEX_DISCOVERY_HOME"
    mkdir -p "$CODEX_DISCOVERY_HOME"
    CODEX_DISCOVERY_INSTALLED=0
    for skill_name in "${CODEX_DISCOVERY_SKILLS[@]}"; do
        skill_dir="$CODEX_SYNC_HOME/skills/$skill_name"
        if [ -d "$skill_dir" ]; then
            ln -sfn "$skill_dir" "$CODEX_DISCOVERY_HOME/$skill_name"
            CODEX_DISCOVERY_INSTALLED=$((CODEX_DISCOVERY_INSTALLED + 1))
        else
            echo "  ⚠ Codex discovery skill missing from snapshot: $skill_name"
        fi
    done

    # User-global discovery points at the curated Codex index, not all 85 skills.
    mkdir -p "$HOME/.agents/skills"
    ln -sfn "$CODEX_DISCOVERY_HOME" "$HOME/.agents/skills/jessy-skills"
    echo "  ✓ Global Codex entry skills linked: ~/.agents/skills/jessy-skills → $CODEX_DISCOVERY_HOME ($CODEX_DISCOVERY_INSTALLED skills)"
    echo "  ℹ Full Codex skill snapshot remains available at $CODEX_SYNC_HOME/skills"

    # Install repo-managed native Codex custom agent templates. Only these templates are
    # overwritten; unrelated user agents in ~/.codex/agents are preserved.
    if [ -d "$CODEX_SYNC_HOME/codex/agents" ]; then
        mkdir -p "$HOME/.codex/agents"
        cp "$CODEX_SYNC_HOME/codex/agents/"*.toml "$HOME/.codex/agents/"
        echo "  ✓ Codex agent templates installed to ~/.codex/agents"
        echo "  → Execution/test/repair/debugging: gpt-5.3-codex; review/verification: gpt-5.4-mini"
    fi

    echo "  ℹ Codex reads AGENTS.md at session start; restart Codex if this is a fresh install"
fi

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

    # === Branch notice: installed snapshots are isolated from future repo branch switches ===
    if [ -d "$DOTFILES/.git" ]; then
        CURRENT_BRANCH=$(git -C "$DOTFILES" branch --show-current 2>/dev/null || echo "unknown")
        echo "  ℹ Source branch: $CURRENT_BRANCH; Claude Code uses snapshot $CLAUDE_SYNC_HOME"
    fi

    # Install workflow scripts to global location (~/.claude/workflows/)
    # Workflow(name='...') auto-discovers scripts here — works from any project
    # NOTE: Only phase3-6 are active. phase1-2 are kept as skeletons in project only (phased out in v2.8).
    WF_INSTALL="$HOME/.claude/workflows"
    if [ -d "$CLAUDE_SYNC_HOME/.claude/workflows" ]; then
        mkdir -p "$WF_INSTALL"
        cp "$CLAUDE_SYNC_HOME/.claude/workflows/"*.js "$WF_INSTALL/" 2>/dev/null || true
        echo "  ✓ Workflow scripts installed to $WF_INSTALL/ ($(ls "$WF_INSTALL" 2>/dev/null | wc -l | tr -d ' ') scripts)"
        echo "  → Active: Workflow(name='phase3-consensus'), Workflow(name='phase4-implement'), Workflow(name='phase5-review'), Workflow(name='phase6-verify')"
        echo "  → Phase 0-2 use Skill+Agent direct execution (no Harness overhead)"
    fi

    # Copy project CLAUDE.md if not already present
    if [ -f "$CLAUDE_SYNC_HOME/CLAUDE.md" ] && [ ! -f "$HOME/.claude/CLAUDE.md" ]; then
        # Don't auto-overwrite user's global CLAUDE.md; just inform
        echo "  ℹ Project CLAUDE.md available at $CLAUDE_SYNC_HOME/CLAUDE.md"
    fi

    echo "  ✓ Claude Code integration ready"

    # project-workflow-claude v2.8 — modular execution skills
    echo "  ℹ project-workflow-claude v2.8 — modular execution skills"
    echo "  → 1 orchestrator + 7 execution skills"
    echo "  → 6 Workflow scripts included (.claude/workflows/)"
    echo "  → Auto-detects Context7/Firecrawl MCP (falls back to WebFetch/WebSearch)"
    echo "  → Iron Law: skills/project-workflow-claude/references/iron-law.md"

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
    echo "  Claude Code snapshot: $CLAUDE_SYNC_HOME"
    echo "  Run /reload-skills in Claude Code to activate"
fi
if [ $HAS_CODEX -eq 1 ]; then
    echo "  Codex: entry skills linked to ~/.agents/skills/jessy-skills/"
    echo "  Codex custom agent templates installed to ~/.codex/agents/"
    echo "  Codex snapshot: $CODEX_SYNC_HOME"
    echo "  Run /skills or invoke \$project-workflow-codex in Codex"
fi
echo "  pwsh: . \$PROFILE"
