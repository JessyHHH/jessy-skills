# Skill Routing

Contract skill routing must include:

```text
Codex Planner Skills Used
Recommended Claude Code Skills
Claude Review Gate Skill Check
Task-Level Recommended Skills
```

Required defaults:

```text
Codex: project-workflow-codex, karpathy-guidelines
Claude Code: project-workflow-claude, karpathy-guidelines
```

Add domain skills from task evidence only. Claude Review Gate can propose additions or removals, but Codex decides whether to accept them during replan.
