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
- Copies all 42 skills to `~/.hermes/skills/`
- Cleans stale skills removed from the repo
- Updates the `hermes()` shell function (auto-detects bash/zsh)
- Reloads Hermes skills

### Step 3: Activate

```bash
source ~/.zshrc   # macOS / Linux with zsh
# or: source ~/.bashrc  # Linux with bash
```

### Step 4: Verify

```bash
ls ~/.hermes/skills/golang-workflow/SKILL.md  # must exist
grep -c "hermes()" ~/.zshrc                    # should be 2 (function + no dups)
```

## Update (repo already cloned)

```bash
cd /path/to/jessy-skills
git pull
bash install.sh
source ~/.zshrc
```

## Report to User

After install, tell the user:
- 42 skills installed to `~/.hermes/skills/`
- Shell function `hermes()` added to `~/.zshrc` (auto-detected)
- `golang-workflow` + `karpathy-guidelines` will auto-load on every `hermes` invocation
- Run `source ~/.zshrc` or open a new terminal to activate
