# SETUP — AI Agent Install Guide

This file contains machine-readable instructions for installing jessy-skills.
An AI agent (Hermes, Claude Code, Codex, etc.) can read this file and execute
each step autonomously. No human intervention required.

## Prerequisites

- Hermes Agent installed (`which hermes`), Claude Code installed (`which claude`), and/or Codex installed (`which codex`)
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
- Copies all skills to `~/.hermes/skills/`
- Overwrites platform snapshots at `~/.jessy-skills-claude` and/or `~/.jessy-skills-codex`
- Links Claude Code skills from `~/.jessy-skills-claude/skills` into `~/.claude/skills/`
- Links Codex skills through `~/.agents/skills/jessy-skills -> ~/.jessy-skills-codex/skills` when `codex` is available
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
| Claude Code | `project-workflow-claude` (v2.8) | `CLAUDE.md` auto-load | `~/.claude/skills/` → `~/.jessy-skills-claude/skills` |
| Codex | `project-workflow-codex` (v0.1) | `AGENTS.md` auto-load | `~/.agents/skills/jessy-skills` → `~/.jessy-skills-codex/skills` |

| Shell | Config File | Status |
|-------|-------------|--------|
| zsh | `~/.zshrc` | ✅ |
| bash | `~/.bashrc` | ✅ |
| PowerShell / pwsh | `$PROFILE` | ✅ |
| fish | manual | ⚠️ |

### Claude Code Specific

After install, restart Claude Code or run `/reload-skills` to activate skills. The project's `CLAUDE.md` boot layer auto-loads each session. The `project-workflow-claude` v2.8 skill is a modular orchestrator: 1 thin control plane + 7 independent execution skills. 4 active Workflow scripts (phase3-6) provide deterministic pipeline automation; Phase 0-2 use Skill+Agent direct execution (no Harness overhead). Model: Sonnet/Haiku only, no Opus.

install.sh is safe for environments with other Claude Code plugins installed. It overwrites only the managed snapshot `~/.jessy-skills-claude`, then refreshes symlinks for jessy-skills entries in `~/.claude/skills/`. Non-jessy-skills entries such as superpowers, omc, and skill-creator are preserved.

### Codex Specific

After install, restart Codex so it reloads `AGENTS.md` and skill discovery paths. The Codex branch entry point is `project-workflow-codex`: it keeps planning, orchestration, integration, and final audit in the main Codex session, then delegates bounded implementation/review/verification work to Codex agents instead of Claude Code `Workflow(...)` scripts.

Codex configuration should use the current hooks feature flag:

```toml
[features]
hooks = true
```

Do not use the deprecated `codex_hooks = true` key.

Codex skill discovery links:

```bash
test -d ~/.jessy-skills-codex/skills/project-workflow-codex
test -L ~/.agents/skills/jessy-skills && readlink ~/.agents/skills/jessy-skills
```

The current repo can switch branches freely after install. Codex global discovery points at the copied snapshot, not the mutable checkout.

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

project-workflow-claude v2.8 is a modular orchestrator — thin control plane + 7 independent execution skills.

```bash
claude                          # Start Claude Code normally
/project-workflow-claude        # Run the workflow
```

The workflow auto-detects MCP availability (Context7, Firecrawl) and falls back to native WebFetch/WebSearch when MCP servers are not available. 4 active Workflow scripts (phase3-6) provide deterministic pipeline automation. Phase 0-2 use Skill+Agent direct execution (no Harness overhead).

## Report to User

After install, tell the user:
- Skills installed to `~/.hermes/skills/`, `~/.claude/skills/`, and/or `~/.agents/skills/jessy-skills`
- Claude/Codex snapshots are overwritten at `~/.jessy-skills-claude` and `~/.jessy-skills-codex` during global sync
- Hermes: Shell integration at `~/.jessy-skills/hermes.sh` (sourced from config)
- Claude Code: CLAUDE.md auto-loads; run `/reload-skills` to activate
- Codex: AGENTS.md auto-loads; run `/skills` or invoke `$project-workflow-codex`
- Codex config: use `[features].hooks = true` if hooks are enabled
- Auto-loaded on every session: `project-workflow` (Hermes) / `project-workflow-claude` (Claude Code) / `project-workflow-codex` (Codex) + `karpathy-guidelines`
- Context7 + Firecrawl CLIs installed and authenticated
- Run `source ~/.zshrc` (or `~/.bashrc`, or `. $PROFILE`) or open a new terminal to activate
