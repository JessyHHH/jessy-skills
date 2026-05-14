---
name: mixclaw-cron-review
description: "快速查看 mixclaw 项目的后台 Code Review cron job 最新报告。触发词：查审查、mixclaw review、代码审查报告。"
version: "1.0"
author: "jessyhuang"
---

# Mixclaw Cron Review Checker

快速读取并总结 mixclaw 项目后台 code review cron 的最新报告。

## 触发

用户说：查审查 / mixclaw review / 代码审查报告 / cron 审查 / 最新 review

## 步骤

1. 找到最新报告文件：

```bash
ls -t ~/.hermes/cron/output/97740591f60d/ | head -1
```

2. 读取文件末尾的总结部分（最后 50 行包含统计表格和整体评价）：

```bash
tail -50 ~/.hermes/cron/output/97740591f60d/<latest-file>
```

3. 提取关键信息并展示：

```
## Mixclaw Code Review — <时间>

| 级别 | 数量 |
|------|------|
| CRITICAL | N |
| HIGH | N |
| MEDIUM | N |
| LOW | N |

### 需要优先处理
1. [HIGH] <问题概述>
2. [MEDIUM] <问题概述>
...

### 整体评价
<整体评价段落>
```

## 报告存储位置

```
~/.hermes/cron/output/97740591f60d/
```

历史报告按时间戳命名：`YYYY-MM-DD_HH-MM-SS.md`

## Cron Job 信息

- **Job ID**: 97740591f60d
- **项目**: mixclaw (Go 1.25.3)
- **频率**: 每 60 分钟
- **内容**: git pull → git diff HEAD~1 → delegate_task code-review
