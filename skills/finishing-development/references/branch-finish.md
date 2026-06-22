# Branch Finish Menu

## Pre-Conditions (NEVER skip)

Before presenting the branch finish menu:
1. Verify Phase 6 results are still current — no new code since verification (`git status --porcelain` should show only expected artifacts in `.codex/state/` and `.codex/plans/`).
2. Never merge before verification.
3. Never push with failing tests.
4. Never discard without confirming (data loss).

## Environment Detection

```bash
# Detect git environment
git rev-parse --git-dir
git rev-parse --git-common-dir

# Determine current branch
git branch --show-current

# Determine base branch
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

## Four-Option Menu

Ask the user which finish action they want:

1. Merge locally
2. Push and create PR
3. Keep branch as-is
4. Discard this work

## Commands per Choice

### Option 1: Merge Locally

```bash
# Get current branch name
CURRENT_BRANCH=$(git branch --show-current)
# Switch to main/master and merge
git checkout main && git merge $CURRENT_BRANCH
# Or: git checkout master && git merge $CURRENT_BRANCH
```

### Option 2: Push and Create PR

```bash
# Push current branch to origin
git push -u origin $(git branch --show-current)
# Create PR via gh CLI
gh pr create --title "<description>" --body "<details>"
```

### Option 3: Keep Branch as-is

No git commands executed. The branch and all its commits remain as-is. Workflow state is saved for later resume.

### Option 4: Discard This Work

```bash
# Get current branch name
CURRENT_BRANCH=$(git branch --show-current)
# Switch to main first
git checkout main
# Delete the branch (safe: refuses if unmerged)
git branch -d $CURRENT_BRANCH
# If force needed (USE WITH CAUTION):
# git branch -D $CURRENT_BRANCH
```

**Important:** `git branch -d` (lowercase) is safe — it refuses to delete if the branch has unmerged changes. Use this first. Only escalate to `-D` (uppercase) if the user explicitly confirms.

## Red Flags (NEVER)

| Action | Rule |
|--------|------|
| Merge before Phase 6 verification | Never. Verification must be current. |
| Push with failing tests | Never. All checks must pass. |
| Discard without confirming | Never. User must explicitly choose this option. |
| Skip the menu and auto-merge | Never. Branch finish always requires user choice. |
