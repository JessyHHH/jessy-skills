# SETUP — AI Agent Install Guide

This file contains machine-readable instructions for installing jessy-skills.
An AI agent (Hermes, Claude Code, Codex, etc.) can read this file and execute
each step autonomously. No human intervention required.

## Prerequisites

- Hermes Agent installed (`which hermes`)
- Git (`which git`)

## Step 1: Clone (if not already in this directory)

If you are reading this file and are NOT already inside the jessy-skills repo:

```bash
git clone https://github.com/JessyHHH/jessy-skills.git
cd jessy-skills
```

Do NOT re-clone if you are already inside the repo.

## Step 2: Copy skills to Hermes

```bash
mkdir -p ~/.hermes/skills
cp -r ./skills/* ~/.hermes/skills/
```

Verify: `ls ~/.hermes/skills/golang-workflow/SKILL.md` must exist.

## Step 3: Register GitHub tap for future updates

```bash
hermes skills tap add https://github.com/JessyHHH/jessy-skills.git
```

## Step 4: Add shell auto-load function

Auto-detect the correct shell config file:

```bash
if [ -f ~/.zshrc ]; then SHELL_RC=~/.zshrc; elif [ -f ~/.bashrc ]; then SHELL_RC=~/.bashrc; else SHELL_RC=~/.bashrc; fi
```

Check if the function already exists:

```bash
grep -q 'hermes()' "$SHELL_RC" 2>/dev/null && echo "EXISTS" || echo "NOT_FOUND"
```

If NOT_FOUND, append `shell/hermes.sh`:

```bash
echo "" >> "$SHELL_RC"
cat ./shell/hermes.sh >> "$SHELL_RC"
echo "Added hermes() to $SHELL_RC"
```

## Step 5: Reload skills

```bash
hermes skills list > /dev/null 2>&1
```

## Step 6: Verify

```bash
echo "=== Verification ==="
echo "Skills installed: $(ls ~/.hermes/skills/ | wc -l)"
hermes skills list 2>/dev/null | grep -c "enabled" && echo "✓ Skills loaded"
echo "Shell function: $(grep -c 'hermes()' $SHELL_RC) occurrence(s) in $SHELL_RC"
```

Expected output: 70+ skills installed, shell function present.

## Step 7: Report

Tell the user:
- How many skills were installed
- Which shell config was updated (bashrc or zshrc)
- That they should run `source <shell_rc>` or open a new terminal
- That `golang-workflow` + `karpathy-guidelines` will auto-load on every `hermes` invocation

## Cleanup (optional)

The cloned repo directory can be kept for future `git pull` updates, or deleted:

```bash
# Keep: cd ~/path/to/jessy-skills && git pull && bash install.sh
# Delete: rm -rf ~/path/to/jessy-skills
```
