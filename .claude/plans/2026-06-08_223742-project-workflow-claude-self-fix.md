# Implementation Plan: project-workflow-claude v2.3 自修复

> 状态：Phase 3 Complete → Phase 4 | 日期：2026-06-08 | 基于：`.claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md`

## Goal

修复 `project-workflow-claude` 技能、工作流脚本和 CONTEXT.md 中的 13 个已识别问题。

## Context

- **项目类型**：Skills Repository（16 个技能，text-only）
- **版本**：v2.3
- **提交**：`08a4c0f`
- **平台**：Claude Code v2.3+，DeepSeek v4 Pro API
- **关键约束**：Agent 子代理因 DeepSeek API 冲突而不可用

## Phase 3 Results

Verdict: **ITERATE** (API failure — plan quality not rejected)
- All 4 Workflow subagents (3 judges + synthesis) failed with: `API Error: 400 thinking options type cannot be disabled when reasoning_effort is set`
- **New finding**: This bug breaks ALL subagent spawns — Agent tool AND Workflow tool AND Skill delegation
- **Task contract warnings**: False positives — plan's json:tasks has expectedEvidence; simplified Workflow args lacked it
- **Manual review**: Plan is sound — 13 issues clearly mapped to 8 files with verification commands

## Execution Strategy (Phase 4-6 adaptation)

Since Workflow scripts cannot spawn subagents on DeepSeek API:
- **Phase 4**: Execute T1-T8 directly (master agent performs all edits). Each task is a self-contained surgical edit.
- **Phase 5**: Direct two-stage review (spec compliance check → code quality review on git diff)
- **Phase 6**: Direct Iron Law verification (run all 9 verification commands, loop until dry)

## Approach

Direct execution, one file at a time. 每个修复都是最小化的、有针对性的字符串替换。

## Files

| 文件 | 操作 | 更改数量 |
|------|--------|-------------|
| `skills/project-workflow-claude/SKILL.md` | 修改 | 6 处 |
| `skills/project-workflow-claude/references/setup.md` | 修改 | 1 处（新章节） |
| `CONTEXT.md` | 修改 | 3 处 |
| `.claude/workflows/phase3-consensus.js` | 审查 ± 修改 | 0–2 处 |
| `.claude/workflows/phase4-implement.js` | 审查 ± 修改 | 0–2 处 |
| `.claude/workflows/phase5-review.js` | 审查 ± 修改 | 0–2 处 |
| `.claude/workflows/phase6-verify.js` | 审查 ± 修改 | 0–2 处 |
| `install.sh` | 审查 ± 修改 | 0–1 处 |

## Verification

| # | 命令 | 预期结果 |
|---|---------|--------|
| V1 | `grep "project-workflow-claude/phase" skills/project-workflow-claude/SKILL.md` | 退出 1（0 个匹配项） |
| V2 | `grep "triggers:" skills/project-workflow-claude/SKILL.md` | 退出 0（≥1 个匹配项） |
| V3 | `grep "v2\.1" skills/project-workflow-claude/SKILL.md` | 退出 1（0 个匹配项） |
| V4 | `grep "grep.*-P" skills/project-workflow-claude/SKILL.md` | 退出 1（0 个匹配项） |
| V5 | `grep "\[auto\]" CONTEXT.md \| grep "76"` | 退出 1（0 个匹配项） |
| V6 | `grep -i "omc\|\.omc/state" CONTEXT.md` | 退出 1（0 个匹配项） |
| V7 | `bash install.sh` | 退出 0 |
| V8 | `git diff --check` | 退出 0 |
| V9 | `node --check .claude/workflows/phase*.js` | 全部退出 0 |

## Risks

| 风险 | 概率 | 影响 |
|------|----------|--------|
| 工作流脚本审查发现需要更深入修复的 bug | 低 | 中 |
| `grep -oE` 在文件名包含特殊字符时行为不同 | 极低 | 低 |

---

```json:tasks
[
  {
    "id": "T1",
    "prompt": "Fix 6 issues in skills/project-workflow-claude/SKILL.md:\n\n1. **Line 12 — wrong workflow path**: Change `~/.claude/workflows/project-workflow-claude/phase4-implement.js` to `~/.claude/workflows/phase4-implement.js`.\n   - Verify: `grep 'project-workflow-claude/phase' skills/project-workflow-claude/SKILL.md` returns 0 matches.\n\n2. **Line 16 — version**: Change `Claude Code v2.1+` to `Claude Code v2.3+`.\n   - Verify: `grep 'v2\\.1' skills/project-workflow-claude/SKILL.md` returns 0 matches.\n\n3. **Add triggers field in frontmatter**: After `metadata:\\n  standalone: true`, add:\n```yaml\ntriggers:\n  - \"start task\"\n  - \"implement\"\n  - \"build\"\n  - \"develop\"\n  - \"add feature\"\n  - \"fix bug\"\n  - \"refactor\"\n  - \"code change\"\n  - \"write code\"\n```\n   - Verify: `grep 'triggers:' skills/project-workflow-claude/SKILL.md` returns ≥1 match.\n\n4. **Line 692 — macOS grep compatibility**: Change `grep -oP` to `grep -oE`.\n   - Verify: `grep 'grep.*-P' skills/project-workflow-claude/SKILL.md` returns 0 matches.\n\n5. **Phase 0 Glob fallback**: Add at the start of Phase 0 step 1 (before the first Glob call): 'If the `Glob` tool is not available in your environment, fall back to `Bash(find ...)` commands.'. For each Glob call, add a fallback note.\n   - Verify: grep for 'find.*-name' in Phase 0 section confirms fallback exists.\n\n6. **Skill count references**: Search for any remaining '76' references in SKILL.md. The actual skill count is 16. Fix any found.\n   - Verify: `grep '\\b76\\b' skills/project-workflow-claude/SKILL.md` returns 0 matches.\n\nALL changes in ONE file: `skills/project-workflow-claude/SKILL.md`. Make minimal, surgical edits. Do NOT refactor or redesign any section.",
    "files": ["skills/project-workflow-claude/SKILL.md"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md", ".claude/state/grill-evidence.json"],
    "intakeRefs": {"approvedInScope": ["SKILL.md fixes"], "approvedOutOfScope": ["Other 15 skills", "settings.json"]},
    "grillRefs": ["A1: triggers keywords", "A2: Glob fallback location", "A4: fix scope"],
    "expectedEvidence": ["grep 'triggers:' skills/project-workflow-claude/SKILL.md returns match", "grep 'project-workflow-claude/phase' skills/project-workflow-claude/SKILL.md returns 0 matches", "grep 'v2\\.1' skills/project-workflow-claude/SKILL.md returns 0 matches", "grep 'grep.*-P' skills/project-workflow-claude/SKILL.md returns 0 matches", "Phase 0 contains 'find' or 'fallback' or 'Fall back' language"],
    "forbiddenEvidence": ["no new TODO comments", "no 'TBD' placeholders", "no refactoring of Phase structure"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T2",
    "prompt": "Add DeepSeek API documentation to skills/project-workflow-claude/references/setup.md.\n\nAdd a new section at the END of the file:\n\n## DeepSeek API Notes\n\nDeepSeek's API (`api.deepseek.com/anthropic`) is Anthropic-compatible but has important differences from native Anthropic:\n\n### Thinking ≠ Extended Thinking\n- DeepSeek's `reasoning_effort` feature is NOT the same as Anthropic's Extended Thinking\n- The `[1m]` suffix in model names (e.g., `deepseek-v4-pro[1m]`) controls context window size — NOT thinking budget\n- DeepSeek auto-decides thinking depth; the `/effort` command may have limited effect compared to native Anthropic\n\n### Known Issue: Agent Subagent API Conflict\n\nWhen `ANTHROPIC_DEFAULT_SONNET_MODEL` or `ANTHROPIC_DEFAULT_HAIKU_MODEL` are set to a model with `reasoning_effort` enabled (e.g., `deepseek-v4-pro[1m]`), spawning Agent subagents fails with:\n\n```\nAPI Error: 400 thinking options type cannot be disabled when reasoning_effort is set\n```\n\n**Root cause**: Claude Code's Agent tool disables thinking for non-opus subagents, but DeepSeek's API requires `thinking.type` to be `enabled` when `reasoning_effort` is set in the request.\n\n**Recommended fix**: In settings.json, set lighter models to versions without reasoning:\n```json\n{\n  \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"deepseek-v4-flash\"\n}\n```\n\nThis allows haiku-tier subagents to spawn without the thinking/reasoning conflict.\n\nMake no other changes to the file.",
    "files": ["skills/project-workflow-claude/references/setup.md"],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md"],
    "intakeRefs": {"approvedInScope": ["DeepSeek docs in setup.md"], "approvedOutOfScope": ["settings.json changes"]},
    "grillRefs": ["A3: DeepSeek docs location"],
    "expectedEvidence": ["grep 'DeepSeek API Notes' skills/project-workflow-claude/references/setup.md returns match", "grep 'thinking options type cannot be disabled' skills/project-workflow-claude/references/setup.md returns match"],
    "forbiddenEvidence": ["no deletion of existing MCP setup content"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T3",
    "prompt": "Fix 3 stale [auto] entries in CONTEXT.md at /Users/jessyhuang/Documents/jessy-skills/CONTEXT.md.\n\nRead the file first. Then make these three EXACT changes:\n\n1. Change `Skill count (~76): Medium` to `Skill count (16): High (confirmed by directory listing)`\n\n2. Change `Workflow scripts consume phase-specific JSON state files from .omc/state/ and produce structured output for pipeline handoff.` to `Workflow scripts consume JSON args from the Workflow tool and return structured results.`\n\n3. Change `triggers, dependencies fields` to `version, metadata fields`\n   (Context: The actual SKILL.md frontmatter uses `version`, `author`, `metadata` — not `triggers` or `dependencies`)\n\nDo NOT touch any [confirmed] entries. Do NOT change the header. Do NOT restructure any section.",
    "files": ["CONTEXT.md"],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md"],
    "intakeRefs": {"approvedInScope": ["CONTEXT.md [auto] refresh"], "approvedOutOfScope": ["CONTEXT.md restructure"]},
    "grillRefs": ["A4: CONTEXT.md fix scope — 3 targeted fixes"],
    "expectedEvidence": ["grep '\\[auto\\]' CONTEXT.md | grep '76' returns 0 matches", "grep -i 'omc' CONTEXT.md returns 0 matches", "grep 'version, metadata' CONTEXT.md returns match", "grep '\\[confirmed\\]' CONTEXT.md still has entries (confirmed entries preserved)"],
    "forbiddenEvidence": ["no removal of [confirmed] entries", "no restructuring of CONTEXT.md sections"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T4",
    "prompt": "Review .claude/workflows/phase3-consensus.js for issues. This is a judge panel workflow script (3 parallel judges → synthesize verdict).\n\nCheck for:\n1. Wrong file paths referencing other skills\n2. OMC state references (should be standalone in v2.3)\n3. Hardcoded paths that should be relative\n4. Syntax validity\n\nFile to review: /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase3-consensus.js\n\nRead the file first. If you find issues, fix them with minimal edits. If no issues, report 'reviewed — no changes needed'.\n\nThen run: `node --check /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase3-consensus.js`",
    "files": [".claude/workflows/phase3-consensus.js"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md"],
    "intakeRefs": {"approvedInScope": ["Workflow script review"], "approvedOutOfScope": ["script redesign"]},
    "grillRefs": ["S1: workflow scripts have no critical bugs", "S3: scripts are syntactically valid"],
    "expectedEvidence": ["node --check .claude/workflows/phase3-consensus.js exits 0", "no OMC references in phase3-consensus.js"],
    "forbiddenEvidence": ["no refactoring of judge panel logic", "no removal of existing phases/features"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T5",
    "prompt": "Review .claude/workflows/phase4-implement.js for issues. This is a parallel implementation pipeline script.\n\nCheck for:\n1. Wrong file paths referencing other skills\n2. OMC state references (should be standalone in v2.3)\n3. Hardcoded paths that should be relative\n4. Syntax validity\n5. Model selection issues — ensure haiku/sonnet/opus mapping works with DeepSeek\n\nFile to review: /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase4-implement.js\n\nRead the file first. If you find issues, fix them with minimal edits. If no issues, report 'reviewed — no changes needed'.\n\nThen run: `node --check /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase4-implement.js`",
    "files": [".claude/workflows/phase4-implement.js"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md"],
    "intakeRefs": {"approvedInScope": ["Workflow script review"], "approvedOutOfScope": ["script redesign"]},
    "grillRefs": ["S1: workflow scripts have no critical bugs", "S3: scripts are syntactically valid"],
    "expectedEvidence": ["node --check .claude/workflows/phase4-implement.js exits 0", "no OMC references in phase4-implement.js"],
    "forbiddenEvidence": ["no refactoring of pipeline logic", "no removal of existing stages"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T6",
    "prompt": "Review .claude/workflows/phase5-review.js for issues. This is the two-stage review pipeline (spec compliance → code quality → adversarial verify → final review).\n\nCheck for:\n1. Wrong file paths referencing other skills\n2. OMC state references (should be standalone in v2.3)\n3. Hardcoded paths that should be relative\n4. Syntax validity\n5. Complexity-gating correctness (P1 layered review logic)\n\nFile to review: /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase5-review.js\n\nRead the file first. If you find issues, fix them with minimal edits. If no issues, report 'reviewed — no changes needed'.\n\nThen run: `node --check /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase5-review.js`",
    "files": [".claude/workflows/phase5-review.js"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md"],
    "intakeRefs": {"approvedInScope": ["Workflow script review"], "approvedOutOfScope": ["script redesign"]},
    "grillRefs": ["S1: workflow scripts have no critical bugs", "S3: scripts are syntactically valid"],
    "expectedEvidence": ["node --check .claude/workflows/phase5-review.js exits 0", "no OMC references in phase5-review.js"],
    "forbiddenEvidence": ["no refactoring of review layers", "no removal of adversarial verify logic"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T7",
    "prompt": "Review .claude/workflows/phase6-verify.js for issues. This is the Iron Law verification script (analyze failures → fix → loop-until-dry).\n\nCheck for:\n1. Wrong file paths referencing other skills\n2. OMC state references (should be standalone in v2.3)\n3. Hardcoded paths that should be relative\n4. Syntax validity\n5. Evidence check handling correctness\n\nFile to review: /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase6-verify.js\n\nRead the file first. If you find issues, fix them with minimal edits. If no issues, report 'reviewed — no changes needed'.\n\nThen run: `node --check /Users/jessyhuang/Documents/jessy-skills/.claude/workflows/phase6-verify.js`",
    "files": [".claude/workflows/phase6-verify.js"],
    "complexity": "medium",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md"],
    "intakeRefs": {"approvedInScope": ["Workflow script review"], "approvedOutOfScope": ["script redesign"]},
    "grillRefs": ["S1: workflow scripts have no critical bugs", "S3: scripts are syntactically valid"],
    "expectedEvidence": ["node --check .claude/workflows/phase6-verify.js exits 0", "no OMC references in phase6-verify.js"],
    "forbiddenEvidence": ["no refactoring of verification logic", "no removal of dry-round loop"],
    "patchBackStrategy": "no-isolation"
  },
  {
    "id": "T8",
    "prompt": "Review install.sh at /Users/jessyhuang/Documents/jessy-skills/install.sh for outdated version references.\n\nCheck for:\n1. Any remaining 'v2.1' or 'v2.2' references (should all say v2.3)\n2. Wrong workflow script paths (e.g., 'project-workflow-claude/phase4')\n3. Missing or broken sections\n\nRead the file first. If you find issues, fix them with minimal edits. If no issues, report 'reviewed — no changes needed'.\n\nThen run: `bash -n /Users/jessyhuang/Documents/jessy-skills/install.sh` to check syntax.",
    "files": ["install.sh"],
    "complexity": "simple",
    "mutatesFiles": true,
    "contextRefs": [".claude/specs/2026-06-08-project-workflow-claude-self-fix-design.md"],
    "intakeRefs": {"approvedInScope": ["install.sh version check"], "approvedOutOfScope": ["settings.json"]},
    "grillRefs": [],
    "expectedEvidence": ["bash -n install.sh exits 0", "no v2.1 or v2.2 references in install.sh", "no 'project-workflow-claude/phase' paths in install.sh"],
    "forbiddenEvidence": ["no structural changes to install.sh logic"],
    "patchBackStrategy": "no-isolation"
  }
]
```
