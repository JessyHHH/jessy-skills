# Codex Plan Contract: Codex-Only Workflow Migration

## Metadata

- workflow: project-workflow-codex
- version: v0.1
- base_commit: d5f5a23
- branch: codex
- created_at: 2026-06-22
- status: DRAFT

## Discovery Evidence

- Current branch: `codex`
- Worktree before plan: clean
- Current Codex entry skill: `skills/project-workflow-codex/SKILL.md`
- Current Codex agent templates: `codex/agents/*.toml`
- Claude source branch: `claude`, read-only source for v2.9 execution skill updates
- Complete grill-me source: `~/.claude/plugins/marketplaces/claude-code-skills/engineering/grill-me/skills/grill-me`
- cc-switch Codex common config target: `~/.cc-switch/cc-switch.db`, `settings.common_config_codex`, TOML text
- Official Codex subagent docs checked via OpenAI Codex manual:
  - Codex supports subagents, custom agents, `/agent` inspection, and steering/stopping/closing running subagents.

## Skill Routing

- Required skills for this migration:
  - `project-workflow-codex`
  - `karpathy-guidelines`
  - `skill-creator`
  - `openai-docs`
- Domain skills:
  - none beyond current repository skills; this is a workflow/skill migration.

## Scope

- Goal: Convert the `codex` branch into a Codex-only branch that mirrors Claude branch workflow responsibilities while using Codex-native skills, state files, docs, install behavior, and subagents.
- In scope:
  - Codex-only docs and install script
  - Codex entry orchestrator
  - seven top-level execution skills with Codex semantics
  - complete `grill-me`
  - `sync-ccswitch-config-codex`
  - tests updated to Codex-only expectations
- Out of scope:
  - changes to the `claude` branch
  - preserving Claude/Hermes workflows in `codex`
  - changing custom agent model policy
  - global user config writes outside validation dry-runs

## Tasks

```json
[
  {
    "id": "T1-docs-install",
    "ownerRole": "executor",
    "files": ["AGENTS.md", "README.md", "SETUP.md", "install.sh", "CONTEXT.md"],
    "instructions": "Make root docs and install behavior Codex-only. Remove Claude/Hermes install claims and add branch notice.",
    "expectedEvidence": ["README says branch is Codex-only", "install.sh only installs Codex snapshot, curated discovery, and codex/agents"],
    "forbiddenChanges": ["Do not overwrite ~/.codex/AGENTS.md", "Do not add Claude/Hermes install paths"]
  },
  {
    "id": "T2-workflow-entry",
    "ownerRole": "executor",
    "files": ["skills/project-workflow-codex/SKILL.md", "skills/project-workflow-codex/references/*", "skills/project-workflow-codex/agents/openai.yaml"],
    "instructions": "Upgrade project-workflow-codex into a Codex-only orchestrator that routes to the seven execution skills and uses .codex state.",
    "expectedEvidence": ["project-workflow-codex references all seven execution skills", "references use .codex paths and Codex subagent terminology"],
    "forbiddenChanges": ["Do not reference Claude Workflow scripts as an execution path"]
  },
  {
    "id": "T3-execution-skills",
    "ownerRole": "executor",
    "files": ["skills/detecting-environment/SKILL.md", "skills/designing-solutions/SKILL.md", "skills/planning-implementation/SKILL.md", "skills/implementing-changes/SKILL.md", "skills/reviewing-implementation/SKILL.md", "skills/verifying-completion/SKILL.md", "skills/finishing-development/SKILL.md"],
    "instructions": "Translate Claude v2.9 execution skill responsibilities to Codex-only semantics while keeping the same skill names.",
    "expectedEvidence": ["frontmatter contains only name and description", "skills use AGENTS.md and .codex paths", "implementation/review/verify mention Codex subagents and /agent steering"],
    "forbiddenChanges": ["Do not use Skill(), Agent(), Workflow(), AskUserQuestion as Claude tool calls"]
  },
  {
    "id": "T4-remove-platform-entries",
    "ownerRole": "executor",
    "files": ["CLAUDE.md", ".claude", "skills/project-workflow-claude", "skills/project-workflow", "codex/README.md"],
    "instructions": "Remove Claude/Hermes platform entry files from the Codex-only branch after useful content is merged into root docs.",
    "expectedEvidence": ["paths no longer exist", "README contains branch switch note"],
    "forbiddenChanges": ["Do not remove generic domain skills"]
  },
  {
    "id": "T5-grill-me",
    "ownerRole": "executor",
    "files": ["skills/grill-me", "skills/engineering/grill-me/SKILL.md"],
    "instructions": "Copy complete grill-me skill from Claude plugin marketplace, normalize Codex skill frontmatter, keep old engineering path as wrapper/deprecated compatibility.",
    "expectedEvidence": ["grill-me scripts exist", "grill-me references exist", "quick_validate passes"],
    "forbiddenChanges": ["Do not copy Claude command/persona files"]
  },
  {
    "id": "T6-ccswitch-codex",
    "ownerRole": "executor",
    "files": ["skills/sync-ccswitch-config-codex", "skills/tools/sync-ccswitch-config-codex"],
    "instructions": "Add Codex-specific cc-switch sync skill and script for common_config_codex TOML add-only merge.",
    "expectedEvidence": ["--dry-run reports common_config_codex changes without writing", "default excludes hooks", "--include-hooks is documented"],
    "forbiddenChanges": ["Do not sync auth/provider secrets", "Do not write DB during validation except explicit non-dry run"]
  },
  {
    "id": "T7-tests-validation",
    "ownerRole": "test-engineer",
    "files": ["tests/test-*.sh"],
    "instructions": "Update tests to assert Codex-only workflow structure and remove stale Claude Workflow JS assumptions.",
    "expectedEvidence": ["bash tests/test-*.sh passes", "test-codex-workflow validates Codex-only install and execution skills"],
    "forbiddenChanges": ["Do not remove meaningful validation just to make tests pass"]
  }
]
```

## Subagent Execution Map

- Implementation will be done by the main Codex session in this run because the user asked for a spec/plan before edits and the workflow itself is being migrated.
- Future `project-workflow-codex` behavior must support Codex subagents:
  - read-heavy tasks may run in parallel
  - write tasks require disjoint file sets
  - Master inspects `/agent`, steers idle agents, stops or closes stuck/completed threads, and verifies results locally

## Verification Contract

- `git diff --check`
- `bash tests/test-*.sh`
- `quick_validate.py` for changed/added skill dirs:
  - `skills/project-workflow-codex`
  - seven execution skills
  - `skills/grill-me`
  - `skills/engineering/grill-me`
  - `skills/sync-ccswitch-config-codex`
  - `skills/tools/sync-ccswitch-config-codex`
- Representative helper checks:
  - `python3 skills/grill-me/scripts/decision_tree_extractor.py --help` or sample run
  - `python3 skills/grill-me/scripts/question_generator.py --help` or sample run
  - `python3 skills/grill-me/scripts/grill_session_tracker.py --help` or sample run
  - `python3 skills/sync-ccswitch-config-codex/scripts/sync_config.py --dry-run`

## Final Audit Checklist

- git status reviewed
- diff stat reviewed
- changed files match this plan
- Claude/Hermes entry files removed
- Codex docs and install behavior are Codex-only
- all modified skills pass `$skill-creator` validation
- helper scripts run without syntax/runtime errors
- test suite passes or failures are documented with exact blockers
