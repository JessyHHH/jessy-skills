# Phase 3：Codex Contract Preflight 自检

## 目标

Codex Phase 3 的目标是防止 Codex 把一个坏 contract 交给 Claude Code。

Claude Code 很可能会认真执行 contract。如果 contract 本身范围模糊、任务不完整、验证不清楚，后面的实现越认真，返工越大。

所以 Codex 在交接前必须自检。

这里的 Phase 3 只属于 Codex。Claude Code 后面要做的是 `Claude Review Gate`，不要再叫成 Codex Phase 3。

## Codex 应该检查什么

### 1. Snapshot 检查

检查 contract 的 `base_commit` 是否等于当前 HEAD。

```text
如果相等：
  可以继续

如果不相等：
  说明项目已经变化
  必须重新读取相关文件
  必须更新 contract
```

### 2. Evidence 检查

每个关键判断都应该能追到证据：

```text
这个文件为什么要改？
这个目录为什么要新增？
为什么不改 skills？
为什么 Claude Code 只能先 review，不能直接执行？
```

如果回答不了，contract 不合格。

### 3. Phase 1 用户确认检查

Phase 1 必须有用户确认记录：

```text
user_confirmations:
  - question
  - options
  - selected_option
  - recorded_value
```

如果 Phase 1 是 Codex 自己填的，没有用户选择或确认，Preflight 必须失败：

```text
verdict: FAIL
reason: Phase 1 clarity was not confirmed by user
```

或者在还没准备好时标成：

```text
verdict: NOT_VALID_YET
reason: waiting for Phase 1 user confirmation
```

### 4. Scope 检查

检查 contract 是否明确写了：

```text
in_scope:
out_of_scope:
expected_changed_files:
forbidden_changes:
```

对于当前这类任务，forbidden changes 应该包括：

```text
不改 skills/
不改 install.sh
不改 SETUP.md
不安装依赖
不调用 Claude Code
不写 .claude/plans/ 里的真实执行 contract
```

除非用户后来明确批准扩大范围。

### 5. Task 检查

每个 task 必须满足：

```text
有 id
有自包含 prompt
有 files
有 mutatesFiles
有 complexity
有 verification
依赖关系清楚
```

如果一个 task 需要读完整上下文才能懂，说明 prompt 不合格。

### 6. Verification 检查

contract 里的验证不能只写：

```text
看起来没问题
```

应该写成可执行或可审查的检查：

```text
find codex -maxdepth 2 -type f -name README.md
test ! -f codex/phase-0-discovery/SKILL.md
git diff -- codex
git diff --check
```

### 7. Executor Instructions 检查

检查是否明确告诉 Claude Code：

```text
先 Claude Review Gate
APPROVE 后再问用户
用户批准后才 Phase 4
Phase 5/6 不能跳过
完成后输出证据
```

如果没有这些指令，Claude Code 可能直接实现。

## Preflight 结果

Preflight 应该输出三种结果之一：

```text
PASS
  contract 可以交给 Claude Code

PASS_WITH_RISK
  可以交，但必须说明风险，例如工作区脏、某些验证不能自动跑

FAIL
  不能交，必须先修 contract

NOT_VALID_YET
  还不能判断，通常是 Phase 1 正在等用户确认
```

## 进入 Claude Code 执行的条件

只有 `PASS` 或用户明确接受 `PASS_WITH_RISK`，才能进入下一步。

如果是 `FAIL`，必须停下：

```text
不要调用 Claude Code
不要执行 Phase 4
不要改代码
先修 contract
```

## 会怎么样

Phase 3 完成后，Codex 才能说：

```text
contract 已通过 Codex preflight。
现在可以交给 Claude Code 进行 Claude Review Gate。
注意：Claude Code 此时只能 review contract，不能实现。
```
