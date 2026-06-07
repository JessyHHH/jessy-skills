# Phase 3.5：Claude Review Gate 后 Codex Replan

## 目标

Phase 3.5 的目标是处理 Claude Code 对 contract 的 Review Gate 审核结果。

这一步很关键：Claude Code 的 Review Gate 不是最终裁判。它是一个强审查者，但 Codex 仍然是 plan owner。

所以流程不是：

```text
Claude 说改 → 立刻改
Claude 说通过 → 立刻执行
```

而是：

```text
Claude Review Gate
  ↓
Codex 判断哪些建议值得采纳
  ↓
Codex 修改 contract
  ↓
必要时再次交给 Claude Review Gate
```

## Claude Code 应该返回什么

Claude Review Gate 不能只说：

```text
计划不错，可以做
```

它必须返回结构化 review：

```text
claude_review_gate:
  verdict: APPROVE | ITERATE | REJECT
  findings:
    - id:
      severity: critical | high | medium | low
      section:
      issue:
      why_it_matters:
      suggested_contract_change:
  missing_questions:
  execution_risks:
  approval_conditions:
```

三个 verdict 的含义：

```text
APPROVE
  contract 可以执行，但 Codex 仍然要检查是否有低风险建议值得补

ITERATE
  contract 大体方向对，但需要修改后再审

REJECT
  contract 方向、范围或证据明显不对，不能执行
```

## Codex 怎么判断建议是否采纳

Codex 要把 Claude 的 findings 分成三类：

```text
ACCEPT
  必须采纳。影响需求、范围、验收、执行安全、返工风险。

DEFER
  暂不采纳。建议有价值，但不影响当前任务，可以以后改。

REJECT
  不采纳。建议扩大范围、违背用户需求、过度设计，或和证据冲突。
```

判断标准：

```text
是否让用户需求更清楚？
是否减少 Claude Code 执行时跑偏的概率？
是否让 task 更 self-contained？
是否让验证更可执行？
是否增加了不必要范围？
是否违反用户说的 non-goals？
```

## Replan Addendum

Codex 每次 replan 都应该写一个 addendum。

建议结构：

```text
# Codex Replan Addendum

## Input
- reviewed_contract:
- claude_review_gate_verdict:
- review_time:

## Findings Accepted
- F1: accepted because ...
- F2: accepted because ...

## Findings Deferred
- F3: deferred because ...

## Findings Rejected
- F4: rejected because ...

## Contract Changes
- v1 -> v2
- changed sections:
- changed tasks:
- changed verification:

## New Status
- READY_FOR_PHASE3_REVIEW_AGAIN
- or APPROVED_FOR_EXECUTION
```

## 什么时候生成 contract 新版本

如果 Claude Review Gate 是 `ITERATE`：

```text
Codex 必须生成 v2
v2 必须说明采纳/拒绝了哪些建议
v2 必须再次 preflight
v2 必须再次交给 Claude Review Gate
```

如果 Claude Review Gate 是 `REJECT`：

```text
Codex 不能执行
Codex 应该回到 Phase 0/1/2 中对应的问题
可能需要重新澄清用户需求
```

如果 Claude Review Gate 是 `APPROVE`：

```text
Codex 仍然检查 findings
如果只有 low 风险建议，可以生成 v1.1 或记录不采纳原因
如果存在 high/critical finding，却 verdict 是 APPROVE，Codex 不能盲信，应降级为 ITERATE
```

## 进入执行的条件

只有满足下面条件，才能进入 Claude Phase 4：

```text
Claude Review Gate verdict = APPROVE
Codex 已 triage 所有 findings
没有未处理 critical/high finding
contract 状态 = APPROVED_FOR_EXECUTION
用户批准进入执行阶段
```

## 会怎么样

Phase 3.5 结束时，Codex 应该能给出明确判断：

```text
Claude 的审核建议哪些被采纳，哪些没采纳，为什么。
当前 contract 是否需要下一轮 Phase 3。
如果不需要，是否可以请求用户批准进入执行。
```

这一步让你不需要监督 Claude Review Gate 是否合理，因为 Codex 会替你做 review triage。
