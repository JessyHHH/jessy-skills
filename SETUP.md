# SETUP — AI Agent Install Guide

This file contains machine-readable instructions for installing jessy-skills.
An AI agent (Hermes, Claude Code, Codex, etc.) can read this file and execute
each step autonomously. No human intervention required.

## Prerequisites

- Hermes Agent installed (`which hermes`)
- Git (`which git`)

## Fresh Install

### Step 1: Clone

```bash
git clone https://github.com/JessyHHH/jessy-skills.git
cd jessy-skills
```

### Step 2: Run install.sh

```bash
bash install.sh
```

This single command handles everything:
- Backs up existing skills to `~/.hermes/skills.bak.*`
- Copies all 59 skills to `~/.hermes/skills/`
- Cleans stale skills removed from the repo
- Installs `hermes.sh` to `~/.jessy-skills/` (clean source-based, not inline)
- Configures shell: zsh/bash/pwsh auto-detected
- Removes old inline function if exists
- Adds `source ~/.jessy-skills/hermes.sh` to shell config
- Reloads Hermes skills

### Step 3: Activate

```bash
source ~/.zshrc   # macOS / Linux with zsh
source ~/.bashrc  # Linux with bash
. $PROFILE        # Windows PowerShell
```

### Step 4: Verify

```bash
ls ~/.hermes/skills/project-workflow/SKILL.md  # must exist
grep "jessy-skills" ~/.zshrc ~/.bashrc         # single source line
```

## Update (repo already cloned)

```bash
cd /path/to/jessy-skills
git pull
bash install.sh
source ~/.zshrc  # or ~/.bashrc
```

## Platform Support

| Shell | Config File | Status |
|-------|-------------|--------|
| zsh | `~/.zshrc` | ✅ |
| bash | `~/.bashrc` | ✅ |
| PowerShell / pwsh | `$PROFILE` | ✅ |
| fish | manual | ⚠️ |

## Report to User

After install, tell the user:
- 59 skills installed to `~/.hermes/skills/`
- Shell integration installed to `~/.jessy-skills/hermes.sh` (sourced from config)
- `project-workflow` + `karpathy-guidelines` will auto-load on every `hermes` invocation
- Run `source ~/.zshrc` (or `~/.bashrc`, or `. $PROFILE`) or open a new terminal to activate
