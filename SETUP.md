# SETUP — AI Agent Install Guide

This file contains machine-readable instructions for installing jessy-skills.
An AI agent (Hermes, Claude Code, Codex, etc.) can read this file and execute
each step autonomously. No human intervention required.

## Prerequisites

- Hermes Agent installed (`which hermes`) and/or Claude Code installed (`which claude`)
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
- Copies all 77 skills to `~/.hermes/skills/`
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

| Platform | Workflow Skill | Shell Integration | Skill Dir |
|----------|---------------|-------------------|-----------|
| Hermes | `project-workflow` (v7.0) | `~/.jessy-skills/hermes.sh` | `~/.hermes/skills/` |
| Claude Code | `project-workflow-claude` (v2.4) | `CLAUDE.md` auto-load | `~/.claude/skills/` |

| Shell | Config File | Status |
|-------|-------------|--------|
| zsh | `~/.zshrc` | ✅ |
| bash | `~/.bashrc` | ✅ |
| PowerShell / pwsh | `$PROFILE` | ✅ |
| fish | manual | ⚠️ |

### Claude Code Specific

After install, restart Claude Code or run `/reload-skills` to activate skills. The project's `CLAUDE.md` boot layer auto-loads each session. The `project-workflow-claude` v2.4 skill is fully standalone with its own workflow scripts (phase3-consensus, phase4-implement, phase5-review, phase6-verify) and does not require OMC. Model: Sonnet/Haiku only, no Opus.

**Workflow Scripts:** 4 deterministic JS scripts in `.claude/workflows/` are included in the repository. The SKILL.md references them via relative paths from the project root. No additional installation needed beyond cloning the repo.

### Claude Code MCP Servers (Recommended, NOT Required)

For better documentation search and web research, install these MCP servers:
```bash
# Context7 — library/framework documentation
claude mcp add context7 -- npx @upstash/context7-mcp@latest

# Firecrawl — web search and scraping
claude mcp add firecrawl -- npx @anthropic/firecrawl-mcp@latest
# Set FIRECRAWL_API_KEY env var (get from https://firecrawl.dev)
```

See `skills/project-workflow-claude/references/setup.md` for detailed setup instructions.
The workflow auto-detects MCP availability and falls back to native WebFetch/WebSearch.

## Launch Mode

project-workflow-claude v2.4 is fully standalone — no external dependencies required.

```bash
claude                          # Start Claude Code normally
/project-workflow-claude        # Run the workflow
```

The workflow auto-detects MCP availability (Context7, Firecrawl) and falls back to native WebFetch/WebSearch when MCP servers are not available.

## Report to User

After install, tell the user:
- 77 skills installed to `~/.hermes/skills/` and/or `~/.claude/skills/`
- Hermes: Shell integration at `~/.jessy-skills/hermes.sh` (sourced from config)
- Claude Code: CLAUDE.md auto-loads; run `/reload-skills` to activate
- Auto-loaded on every session: `project-workflow` (Hermes) / `project-workflow-claude` (Claude Code) + `karpathy-guidelines`
- Context7 + Firecrawl CLIs installed and authenticated
- Run `source ~/.zshrc` (or `~/.bashrc`, or `. $PROFILE`) or open a new terminal to activate
