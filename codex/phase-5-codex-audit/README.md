# Phase 5：Codex Final Audit 最终验收

## 目标

Claude Code 完成 Phase 4-6 后，Codex 要做独立验收。

这个阶段的目标是防止：

- Claude Code 漏做 task
- Claude Code 改了不该改的文件
- Claude Code 验证命令没有真正跑
- 文档或代码虽然生成了，但不满足用户原始意图
- agent 过度乐观地声称完成

## Codex 应该做什么

### 1. 读取 Claude Code 结果

Codex 先读取 Claude 返回的结构化结果：

```text
phase3_verdict
user_approved_execution
tasks status
phase5_verdict
phase6_verdict
verification_commands
changed_files
known_risks
```

如果 Claude Code 没有返回这些信息，Codex 不能直接 PASS。

### 2. 检查 git 状态

Codex 运行：

```bash
git status --short
git diff --stat
git diff
```

然后对照 contract：

```text
changed_files 是否是 expected_files 的子集
是否出现 forbidden_changes
是否有未说明的新文件
是否有用户已有脏改动被混在一起
```

### 3. 重新运行验证

Codex 不应该只相信 Claude Code 的验证。

对于文档任务，可以重新跑：

```bash
find codex -maxdepth 2 -type f -name README.md
git diff --check
```

对于代码任务，可以重新跑 contract 里列出的测试命令。

### 4. 对照用户原始需求

Codex 要回到最初需求，逐条检查：

```text
是否在当前项目根目录下新增 codex/
是否分成几个子文件夹
是否用中文说明每个阶段
是否覆盖阶段 0 到阶段 3
是否说明后续如何调用 Claude Code
是否不是 SKILL.md
```

这个检查比“文件存在”更重要。

### 5. 给出 verdict

Codex final audit 只能给三种结果：

```text
PASS
  完全满足 contract 和用户原始需求

PASS_WITH_RISK
  基本满足，但存在明确风险或未验证项

FAIL
  不满足，必须返工
```

## 如果 FAIL 怎么办

如果 Codex audit 失败，不应该直接让 Claude Code“继续随便修”。

应该生成一个补充 contract：

```text
rework_contract:
  failed_checks:
  required_fixes:
  allowed_files:
  forbidden_changes:
  verification:
```

然后可以再次交给 Claude Code，或者由 Codex 自己在当前会话修复，取决于任务大小。

## 会怎么样

当 Codex final audit PASS 后，Codex 才能向用户说：

```text
完成。
我检查了 Claude Code 的执行结果、git diff、验证命令和原始需求。
当前状态满足 contract。
```

如果没有 final audit，最多只能说：

```text
Claude Code 声称完成，但 Codex 尚未独立验收。
```

