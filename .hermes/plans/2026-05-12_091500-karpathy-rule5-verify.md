# Plan: 追加 Karpathy Rule #5 — Verify Before Asserting

## Goal

在 golang-workflow 和 karpathy-guidelines 的 Karpathy Enforcement 段追加第 5 条规则：不确定的事实断言必须先 web_search 验证。

## Context

LLM 在遇到不了解的库/API/版本差异时倾向于自信瞎编。需要一条硬规则强制"先搜再说"。

## Files

| 文件 | 改动 |
|------|------|
| `skills/karpathy-guidelines/SKILL.md` | Karpathy Enforcement 段追加 Rule #5 |
| `skills/golang-workflow/SKILL.md` | Karpathy Enforcement 段同步追加 Rule #5 |

## Approach

两个文件的 Karpathy Enforcement 段内容一致，在 Rule #4 之后插入：

```
5. **Verify Before Asserting** — 对任何不确定的事实断言（库 API、版本差异、弃用特性、标准库变更、依赖兼容性），先 `web_search()` 验证再输出。不瞎猜、不假设。搜索结果模糊就明说不确定。
```

## Verification

- `grep "Verify Before Asserting"` 两个文件各 1 处
- 编号 1-5 连续
- 不影响其他内容
