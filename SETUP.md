# SETUP — AI Agent Install Guide

This file contains machine-readable instructions for installing jessy-skills.
An AI agent (Hermes, Claude Code, Codex, etc.) can read this file and execute
each step autonomously. No human intervention required.

## Prerequisites

- Hermes Agent installed (`which hermes`)
- Git (`which git`)
- Node.js + npm (`which node && which npm`)

### Fix npm global prefix (if permission denied on `npm install -g`)

If `npm install -g` fails with `EACCES`, set a user-local prefix:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.zshrc  # or ~/.bashrc
export PATH=~/.npm-global/bin:$PATH
```

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
- Copies all 76+ skills to `~/.hermes/skills/`
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

### Step 5: Install Tool CLIs

Install Context7 (real-time library docs) and Firecrawl (web search/scraping):

```bash
npm install -g ctx7@latest firecrawl-cli@latest
```

### Step 6: Authenticate Tools

Both tools require browser OAuth. Run each — a browser window will open for authorization:

```bash
ctx7 login        # opens context7.com — click Authorize
firecrawl login   # interactive: choose "1" for browser login
```

Verify:

```bash
ctx7 whoami       # shows login name + email
firecrawl --status  # shows credits + auth status
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
- 76+ skills installed to `~/.hermes/skills/`
- Shell integration installed to `~/.jessy-skills/hermes.sh` (sourced from config)
- Auto-loaded on every `hermes` invocation: `project-workflow`, `karpathy-guidelines`
- Context7 + Firecrawl CLIs installed and authenticated
- Run `source ~/.zshrc` (or `~/.bashrc`, or `. $PROFILE`) or open a new terminal to activate
