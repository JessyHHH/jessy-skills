# Codex Plan Contract Template

```markdown
# Codex Plan Contract: <title>

## Metadata
- workflow: project-workflow-codex
- version: v0.1
- base_commit:
- created_at:
- status: DRAFT | PREFLIGHT_PASS | APPROVED_FOR_EXECUTION | EXECUTED | VERIFIED

## Discovery Evidence
- branch:
- dirty_files:
- files_read:
- commands_run:

## Skill Routing
- codex_skills:
- optional_domain_skills:

## Scope
- goal:
- in_scope:
- out_of_scope:
- expected_changed_files:
- forbidden_changes:

## Tasks
```json
[
  {
    "id": "T1",
    "ownerRole": "executor",
    "files": [],
    "instructions": "",
    "expectedEvidence": [],
    "forbiddenChanges": []
  }
]
```

## Agent Execution Map
- parallel_groups:
- serial_dependencies:
- integration_owner: main Codex agent

## Verification Contract
- commands:
- semantic_checks:
- acceptable_skips:

## Final Audit Checklist
- git status reviewed
- diff stat reviewed
- changed files match scope
- verification evidence fresh
- user request satisfied
```
