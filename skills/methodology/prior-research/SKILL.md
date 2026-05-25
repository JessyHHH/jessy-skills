---
name: prior-research
description: "研究方法论。教 Agent 什么时候该搜（WHEN）、按什么顺序搜（HOW）、搜完怎么用（USE）。搜索优先级链：curl(2s) → context7(2s) → firecrawl(5s) → delegate_task(最后)。触发词：'docs', 'library', 'API', 'search', 'scrape', '怎么配置', '不确定怎么用', '最新版API', 'context7', 'firecrawl'。吸收 context7-docs 和 firecrawl-web。"
version: "1.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [research, search, context7, firecrawl, methodology]
    auto_load: false
    absorbs: [context7-docs, firecrawl-web]
---

# Prior Research — 先搜再写，不猜

**核心理念：** 在写任何代码之前，先确认你用的 API、库、模式是正确的。不要依赖训练数据（它可能过时）。不要猜（猜错的代价远大于搜一下的 2 秒）。

---

## WHEN：什么时候必须搜

| 场景 | 例子 |
|------|------|
| 用新库或不熟悉的库 | "viper 怎么读 YAML 配置？" |
| API 签名不确定 | "gin.ShouldBindJSON 参数是什么？" |
| 版本差异 | "Go 1.22 的 for range 变了什么？" |
| 废弃 API | "ioutil.ReadAll 还在吗？" |
| 未知模式 | "Go 里单例怎么实现？" |

**不搜的场景：** 项目内已有代码能回答的（看项目文件即可）、纯逻辑问题、命名讨论。

---

## HOW：搜索优先级链

**核心原则：先快后慢，先精确后模糊。**

```
优先级 1: curl + API 端点（~2s）
  ├── GitHub API: curl -s "https://api.github.com/search/repositories?q=..."
  └── 适用：结构化 API 查询、包注册表搜索

优先级 2: context7（~2s）
  ├── ctx7 library <name> "<query>"     ← 解析库名到 ID
  ├── ctx7 docs <libraryId> "<query>"   ← 取文档片段
  └── 适用：库文档、API 签名、代码示例

优先级 3: firecrawl（~5s）
  ├── firecrawl search "<query>"        ← 网页搜索
  ├── firecrawl scrape <url>            ← 抓取页面内容
  └── 适用：开源项目分析、案例研究、网页内容

优先级 4: delegate_task(web)（最后手段）
  └── 仅用于需要浏览器交互的多页复杂搜索
```

**铁律：** 优先级 1-3 都试过仍无答案，才用 4。绝不要从 4 开始。

---

## context7 用法

### 两步流程

```bash
# Step 1: 解析库名 → 库 ID
ctx7 library gin "How to bind JSON request body"

# Step 2: 用库 ID 查文档
ctx7 docs /gin-gonic/gin "How to bind JSON with ShouldBindJSON"
```

### 库 ID 格式

`/org/project` 或 `/org/project/version`。如 `/gin-gonic/gin`、`/uber-go/zap`、`/golang/go`。

### 查询质量

| ✅ 好 | ❌ 差 |
|------|------|
| "How to set up JWT middleware in Gin" | "auth" |
| "slog structured logging with groups" | "log" |
| "React useEffect cleanup with async" | "hooks" |

用完整的自然语言描述你的需求，不要用单关键词。

### 版本特定查询

```bash
ctx7 docs /facebook/react/19.0.0 "useOptimistic hook"
```

### 错误处理

- Quota exceeded → 告诉用户，尝试 `ctx7 login`，或 fallback 到训练数据并明确声明不确定性
- 无结果 → 换更宽的查询，或用 firecrawl
- 最多 3 次尝试 → 仍未果则取最佳结果

---

## firecrawl 用法

### 命令升级链（从轻到重）

| 需求 | 命令 | 场景 |
|------|------|------|
| 搜索网页 | `search` | 没有具体 URL |
| 抓取页面 | `scrape` | 知道 URL |
| 发现站点内 URL | `map` | 需要定位子页面 |
| 批量抓取 | `crawl` | 需要多个页面 |

### Search

```bash
firecrawl search "Go concurrency patterns" --limit 10
firecrawl search "viper read config" --categories github --limit 5

# 搜索 + 同时抓取（~15s）
firecrawl search "Go slog best practices" --scrape --scrape-formats markdown --limit 5
```

### Scrape

```bash
firecrawl scrape https://github.com/gin-gonic/gin --only-main-content
firecrawl https://pkg.go.dev/github.com/spf13/viper   # shortcut
```

### 输出管理

写到 `.firecrawl/` 目录（加入 `.gitignore`）：

```bash
firecrawl search "query" -o .firecrawl/search-<topic>.json --json
firecrawl scrape "<url>" -o .firecrawl/<site>-<page>.md
```

**不要整个文件读进上下文**——先用 `head -50` 或 `grep -n "keyword"` 定位。

---

## USE：搜完怎么用

1. **API 文档 > 训练数据。** 如果 context7 返回的签名和你的记忆不同，以前者为准。
2. **不确定时说不确定。** 如果搜索结果模糊或矛盾，明确告诉用户"context7 返回 X，firecrawl 返回 Y，我也不确定哪个是对的"。
3. **引用来源。** 当你使用搜索到的信息时，标注是哪个工具从哪里查的。
4. **不要偷偷搜然后假装自己知道。** 用户看得出来。

---

## Pitfalls

- ❌ **从 delegate_task(web) 开始搜索** → 先试试 curl/context7/firecrawl
- ❌ **单关键词搜索** → context7 和 firecrawl 都需要完整自然语言查询
- ❌ **跳过验证** → 搜完就写，不验证 API 签名 → Phase 6 失败
- ❌ **整个大文件读进上下文** → 用 head/grep 定位后用 read_file(offset=)
- ❌ **重新搜已经搜过的** → 检查 `.firecrawl/` 目录是否已有结果
- ❌ **URL 不引号** → URL 里 `?` 和 `&` 会被 shell 解释
- ❌ **猜而不搜** → 不确定时猜测 → 2 秒搜索能省下 20 分钟调试
