---
name: error-taxonomy
description: "错误分类方法论。所有错误分三类：ValidationError(HTTP 400)、BusinessError(HTTP 422)、SystemError(HTTP 500)。每类有明确的定义、处理方式和边界。触发词：'错误处理', 'error handling', '错误码', 'error code', 'error classification', '错误分类'。"
version: "1.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [error, taxonomy, methodology, classification]
    auto_load: false
---

# Error Taxonomy — 错误三分法

**核心理念：** 不是所有错误都一样。校验错误、业务错误、系统错误的处理方式截然不同。混在一起会让调用方（前端、其他服务）无法正确响应。

---

## 三类错误

| 类型 | HTTP 码 | gRPC 码 | 含义 | 例子 |
|------|---------|---------|------|------|
| **ValidationError** | 400 | InvalidArgument | 用户输入不合法 | name 为空、email 格式错 |
| **BusinessError** | 422 | FailedPrecondition | 业务规则冲突 | 用户已存在、余额不足 |
| **SystemError** | 500 | Internal | 系统故障 | 数据库挂了、panic、网络超时 |

---

## 每类的处理原则

### ValidationError（400）

```
位置: handler 层（离用户最近）
原则: 尽早返回，不污染业务逻辑
包含: 哪个字段错了、期望什么格式
不包含: 内部实现细节、堆栈信息
```

```go
// ✅ 好的校验错误
if req.Name == "" {
    return nil, status.Error(codes.InvalidArgument, "name is required")
}

// ❌ 差的——底层错误直接暴露
return nil, fmt.Errorf("sql: no rows in result set")
```

### BusinessError（422）

```
位置: service 层（业务逻辑）
原则: 返回明确错误码，前端据此展示提示
包含: 错误码（int 或 string）、人类可读描述
不包含: SQL 语句、内部状态
```

```go
// ✅ 好的业务错误
var ErrUserAlreadyExists = errors.New("user already exists")
var ErrInsufficientBalance = errors.New("insufficient balance")

// ❌ 差的——错误码为 0 或用 int 表示一切
return errors.New("error code 5001")
```

### SystemError（500）

```
位置: 最底层（数据库、网络、外部服务）
原则: 打日志 + 包装错误上下文 + 不暴露内部细节给用户
包含: 日志中有完整堆栈和 SQL，返回给用户只有 "internal error"
不包含: SQL 语句、文件路径、IP 地址暴露给用户
```

```go
// ✅ 好的系统错误处理
if err != nil {
    slog.Error("failed to query user", "user_id", id, "error", err)
    return nil, status.Error(codes.Internal, "internal error")
}

// ❌ 差的——暴露内部细节
return nil, fmt.Errorf("SELECT * FROM users WHERE id=%s: %w", id, err)
```

---

## 分层映射

```
┌──────────────────────────────────────┐
│ Handler 层                            │
│  ├── 参数校验 → ValidationError(400)  │
│  └── 调用 service                     │
└──────────────┬───────────────────────┘
               │
┌──────────────▼───────────────────────┐
│ Service 层                            │
│  ├── 业务逻辑 → BusinessError(422)    │
│  └── 调用 storage                     │
└──────────────┬───────────────────────┘
               │
┌──────────────▼───────────────────────┐
│ Storage 层                            │
│  └── DB 错误 → 包装为 SystemError     │
│      (打日志 + 不暴露 SQL)            │
└──────────────────────────────────────┘
```

---

## 错误包装（Go 项目）

```go
// 使用 samber/oops 或 fmt.Errorf %w
if err != nil {
    return fmt.Errorf("creating user %s: %w", name, err)
}

// 调用方判断
if errors.Is(err, ErrUserAlreadyExists) {
    return status.Error(codes.AlreadyExists, "user already exists")
}
```

---

## 反模式

- ❌ **所有错误都返回 500** → 前端无法区分"我写错了"和"服务器崩了"
- ❌ **用 HTTP 200 包错误** → `{"error": "xxx"}` 在 200 里
- ❌ **sql.ErrNoRows 直接暴露给客户端** → 应该转为业务错误或 404
- ❌ **panic 当错误处理** → `recover()` 是最后防线，不要依赖
- ❌ **错误码用裸 int** → 定义具名常量或类型

---

## 触发条件

当用户说以下任一关键词时加载此 skill：
- "错误处理"、"error handling"、"错误码"、"error code"
- "错误分类"、"error classification"
- "怎么处理这个错误"、"应该返回什么状态码"

---

## 关联 Skill

- `golang-error-handling` — Go 语言级别的错误处理惯例
- `api-design-first` — API 设计时同时定义错误码
- `data-model-first` — 数据模型设计时考虑错误场景
