# 验证方法：Codex 如何确认流程真的走完

## 目标

用户不想监督整个流程，所以验证必须由 Codex 主动完成。

Codex 验证的不是一句“Claude Code 完成了”，而是验证整条链路：

```text
Phase 0 是否有事实证据
Phase 1 是否逐题澄清并由用户确认
Phase 2 是否生成合格 contract
Codex Phase 3 是否完成 contract preflight
Claude Review Gate 是否经过 Claude Code 审核
Phase 3.5 是否由 Codex replan
Phase 4-6 是否由 Claude Code 执行并验证
Phase 5 是否由 Codex final audit
```

## 验证对象

Codex 要验证三类东西：

```text
1. Process
   状态机有没有跳步

2. Artifact
   contract、review、replan、result、audit 是否存在且完整

3. Outcome
   git diff 和验证命令是否满足用户原始需求
```

## 必须存在的证据

一次完整运行至少应该留下这些证据：

```text
.codex/runs/<run-id>/discovery.md
.codex/runs/<run-id>/clarity.md
.claude/plans/<timestamp>-codex-contract-v1-<slug>.md
.codex/runs/<run-id>/preflight-v1.md
.codex/runs/<run-id>/claude-review-gate-v1.md
.codex/runs/<run-id>/replan-v1-to-v2.md
.claude/plans/<timestamp>-codex-contract-v2-<slug>.md
.codex/runs/<run-id>/claude-result.md
.codex/runs/<run-id>/final-audit.md
```

不是每次都一定有 v2。如果 Claude Review Gate 一次 APPROVE，可以没有 replan-v1-to-v2，但必须有：

```text
Codex 对 Claude Review Gate 的 triage 记录
```

## 状态机验证

Codex 应该按顺序检查状态：

```text
REQUEST_RECEIVED
DISCOVERY_DONE
WAITING_FOR_USER_CLARIFICATION
CLARITY_CONFIRMED_BY_USER
CONTRACT_DRAFTED
CODEX_CONTRACT_PREFLIGHT_PASSED
CLAUDE_REVIEW_GATE_APPROVED
CODEX_REPLAN_DONE
CONTRACT_APPROVED_FOR_EXECUTION
USER_APPROVED_EXECUTION
CLAUDE_PHASE4_DONE
CLAUDE_PHASE5_PASSED
CLAUDE_PHASE6_PASSED
CODEX_AUDIT_PASSED
DONE
```

如果某个状态缺证据，Codex 必须停在最近的可信状态。

例如：

```text
有 contract，但没有 Phase 1 用户确认
  -> 停在 WAITING_FOR_USER_CLARIFICATION

有 contract，但没有 Claude Review Gate
  -> 停在 CODEX_CONTRACT_PREFLIGHT_PASSED

有 Claude result，但没有 user approval
  -> FAIL，因为执行 gate 被跳过

有 Phase6 pass，但 diff 超出 expected files
  -> FAIL 或 PASS_WITH_RISK
```

## Contract 验证

Codex 检查 contract：

```text
- 有 base_commit
- 有 user_request
- 有 in_scope / out_of_scope
- 有 expected_changed_files
- 有 forbidden_changes
- 有 json tasks
- 每个 task 有 files
- 每个 task 有 verification
- 有 Claude Review Gate instructions
- 有 result shape 要求
```

如果缺任意关键项，不能交给 Claude Code。

## Claude Review Gate 验证

Codex 检查 Claude 的 review：

```text
- verdict 是否是 APPROVE / ITERATE / REJECT
- findings 是否结构化
- high/critical findings 是否有 suggested change
- missing_questions 是否已处理
- execution_risks 是否已转入 contract risks
```

如果 Claude 只给自然语言夸奖，没有结构化 review，Codex 要求重审。

## Replan 验证

Codex 检查自己是否做了 review triage：

```text
- 每个 finding 是否 ACCEPT / DEFER / REJECT
- ACCEPT 的 finding 是否写进新 contract
- REJECT 是否有理由
- 新 contract 是否重新 preflight
- 如果 verdict 是 ITERATE，是否重新交给 Claude Review Gate
```

## 执行结果验证

Codex 检查 Claude result：

```text
- claude_review_gate_verdict = APPROVE
- user_approved_execution = true
- 每个 task status = done 或有明确 blocked reason
- phase5_verdict 没有 critical/high unresolved
- phase6_verdict = pass
- verification_commands 有实际输出
- changed_files 没有越界
```

## Git / 文件验证

Codex 最后自己跑：

```bash
git status --short
git diff --stat
git diff
git diff --check
```

根据任务类型再跑 contract 里的验证命令。

对于文档任务，可以加：

```bash
find codex -maxdepth 2 -type f -name README.md
find codex -name 'SKILL.md' -print
```

## Final Audit Verdict

Codex 最终只能输出：

```text
PASS
  流程和结果都满足证据要求

PASS_WITH_RISK
  结果基本满足，但有明确未验证项或外部限制

FAIL
  流程跳步、证据缺失、结果越界、验证失败
```

## 用户不监督时的默认行为

如果用户说“不想监督，你来验证”，Codex 默认执行：

```text
1. 不要求用户检查每个中间文件
2. Codex 自己做 contract preflight
3. Codex 自己 triage Claude Review Gate findings
4. Codex 自己决定是否需要 contract v2
5. Codex 自己做 final audit
6. 只在需要用户授权改文件时请求批准
7. 最后只汇报 verdict、证据和风险
```

这样用户不用盯过程，但仍然保留关键控制权。
