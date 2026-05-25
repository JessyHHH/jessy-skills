---
name: write-pr-description
description: "Write clear, structured pull request descriptions from git history. Use when user says 'write PR description', 'draft PR', 'create pull request', 'PR template', 'summarize changes', or before opening a PR."
---

# Write PR Description

Generate a clear, scannable pull request description from the current git state -- diffs, branch history, and commit messages.

## When to Use

This skill activates when:
- User says "write PR description", "draft PR", "create pull request"
- User says "summarize changes", "PR template", "what goes in the PR"
- Before opening a pull request
- After completing a feature branch

## Before You Start

1. **Check what exists already** -- does the branch have a PR template (`.github/PULL_REQUEST_TEMPLATE.md`)? Does the repo use a specific PR format? Respect existing conventions.
2. **Gather the raw material** -- the steps below use git commands to understand what changed.
3. **If you lack context** (unfamiliar codebase, unclear motivation), ask the user one clarifying question before drafting. Don't guess the "why".

## Process

### Step 1: Collect the Facts

Run these commands in parallel to gather the full picture:

```bash
# What changed (file-level)
git diff --stat origin/main...HEAD

# What branch / commit range
git log --oneline origin/main...HEAD

# If only one commit, get the full message
git log --format="%B" -1 origin/main...HEAD

# Check if there's a PR template
ls .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || echo "no template"
```

If `origin/main` doesn't exist (e.g. this is a new repo), use `HEAD~N` or `main` instead.

### Step 2: Categorize the Changes

Read the diffs and commits. Classify each change:

| Category | Signal |
|----------|--------|
| **Feature** | New files, new functions, new endpoints, new behavior |
| **Fix** | Bug fixes, corrected logic, error handling improvements |
| **Refactor** | Renames, moved code, extracted helpers, style changes, no behavior change |
| **Chore** | Dependencies, config, CI, formatting, comments, non-functional |
| **Breaking** | Changed public API, removed fields, changed signatures, migration needed |
| **Docs** | README, docstrings, comments, external documentation changes |

### Step 3: Extract the "Why"

From commit messages and conversation context (not just diffs):
- What problem does this solve?
- What triggered this change?
- What alternatives were considered and rejected?

If commit messages are low-quality (e.g. "fix stuff"), derive the "why" from the diff and your conversation context instead. The "why" is the most important part of a PR description -- it's what reviewers need to evaluate whether the approach is right.

### Step 4: Write the Description

Use the template below. **Fill every section** -- empty sections suggest incomplete thinking.

```
## Summary

<1-3 sentences. What does this PR do? Why? Keep it under 200 chars total.>

## Changes

- <concrete change, no fluff. Use subject->predicate format>
- <group by feature/fix/refactor where relevant>

## Motivation

<Background. What problem? Why now? Link to issues/tickets if applicable.>

## Test Plan

- [ ] <manual test step or automated test coverage>
- [ ] <edge case covered>
- [ ] <integration / e2e step if applicable>

## Screenshots / Demos (if applicable)

<Before/after screenshots, terminal outputs, or anything visual. Delete section if not applicable.>

## Breaking Changes (if applicable)

<What breaks? Migration steps? Delete section if not applicable.>
```

### Step 5: Polish

Before presenting the description, check:

- **No implementation walkthrough** -- focus on what/why, not how. Reviewers read the diff for "how".
- **No filler** -- cut "this PR implements a solution for the problem of..." to "Fixes <problem> by <mechanism>."
- **Active voice** -- "Add rate limiting" not "Rate limiting was added."
- **Scannable** -- sections, bullet points, bold for key decisions. A reviewer should grasp the PR in 30 seconds.
- **Linked issues** -- if the repo uses GitHub/GitLab issue tracking, link related issues with `Fixes #123` or `Closes #123`.

## Output Format

Present the final description as a markdown block the user can copy into the PR body. Follow it with a one-line summary of what you found (e.g., "3 feature commits, 1 refactor, 12 files changed").

## Scenario: Commit Messages Are Already Good

If every commit message is well-written and self-contained, the PR description can be lighter -- a summary sentence and a "Changes" list derived from commit subjects, with links to related issues. Don't repeat what each commit message says verbatim; synthesize.

## Scenario: Single-Purpose PR (One Commit)

If the PR is one commit with a good message, the PR description is nearly identical to that commit message body. Add a Test Plan section and links.

## Scenario: Large / Multi-Feature PR

If the PR touches many files across unrelated concerns, suggest splitting it before writing the description. A large PR with a sprawling description is a smell. Say: "This PR covers [N] distinct concerns. Consider splitting into [suggested breakdown] before opening." Then still produce the best single-PR description you can.

## Connection to Other Skills

- **Before**: Use `code-review` to review the changes before describing them -- fixes issues before they reach the reviewer.
- **After**: Use this skill's output as the body when opening the PR via `gh pr create`.
- **Related**: `to-issues` breaks plans into tickets; this skill summarizes completed tickets into a PR.

## Anti-Patterns

**Don't do these:**

- **Copy-paste commit messages verbatim** -- synthesize, don't regurgitate.
- **Describe the diff line-by-line** -- "Changed line 42 of auth.go from x to y". That's what the diff tab is for.
- **Write a novel** -- 200-500 words is the sweet spot. If you need more than 800 words, the PR is probably too large.
- **Skip the test plan** -- even if it's just a manual smoke test, tell the reviewer how you verified this works.
- **Use present continuous** -- "Adding feature X" is ambiguous (in progress? done?). Use imperative mood: "Add feature X".
