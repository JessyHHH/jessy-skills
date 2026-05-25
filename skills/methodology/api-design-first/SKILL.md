---
name: api-design-first
description: "API 设计优先方法论。先设计契约（proto/OpenAPI/JSON Schema）再写 handler。5 步走：定义契约 → 错误码枚举 → handler 骨架 → 业务逻辑 → 独立 review。触发词：'新增 API', '新增接口', '新增 RPC', 'API 设计', '接口设计', 'endpoint', 'gRPC', 'proto'。"
version: "1.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [api, design, methodology, contract-first]
    auto_load: false
---

# API Design First — 先设计契约，再写实现

**核心理念：** API 的消费者（前端、其他服务、CLI）不需要知道你的实现细节——他们只需要知道契约。先定契约，所有人都能并行工作。

---

## 5 步流程

```
Step 1: 定义数据契约
  ├── gRPC → .proto 文件
  ├── REST → OpenAPI / JSON Schema
  └── 输出: 一个可 review 的契约文件

Step 2: 定义错误码枚举
  ├── 业务错误有哪些？（见 error-taxonomy）
  └── 输出: 错误码列表（int + 描述）

Step 3: 写 handler 骨架
  ├── 函数签名 + 参数校验 + 返回结构
  ├── 不写业务逻辑（放 Step 4）
  └── 输出: 可编译的骨架代码

Step 4: 实现业务逻辑
  ├── 填入 Step 3 的骨架
  └── 输出: 完整 handler

Step 5: 独立 review
  ├── Step 1 → 前端/reviewer 可并行 review 契约
  └── 输出: 已 review 的 API
```

---

## 每一步可独立 review

这意味着：
- **Step 1 完成后**，前端可以开始写调用代码（即使后端还没实现）
- **Step 2 完成后**，QA 可以写错误场景测试
- **Step 3 完成后**，code reviewer 可以检查函数签名和校验逻辑

---

## 原则

1. **一个 RPC/endpoint 做一件事。** 不要一个接口做"查询+创建+更新"。
2. **请求和响应结构命名清晰。** `CreateUserRequest` / `CreateUserResponse`，不是 `Req` / `Res`。
3. **错误返回结构化。** 不要在 HTTP 200 里放 `{"error": "xxx"}`。
4. **先想失败场景。** "用户不存在怎么办？参数非法怎么办？超时怎么办？"
5. **版本策略先定。** v1/v2 URL 前缀？gRPC package 版本号？

---

## Go 项目具体做法（gRPC）

```protobuf
// Step 1: 先写这个
service UserService {
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
}

message CreateUserRequest {
  string name = 1;
  string email = 2;
}

message CreateUserResponse {
  string user_id = 1;
}
```

```go
// Step 3: 再写骨架
func (s *UserServer) CreateUser(ctx context.Context, req *pb.CreateUserRequest) (*pb.CreateUserResponse, error) {
    // 参数校验
    if req.Name == "" {
        return nil, status.Error(codes.InvalidArgument, "name is required")
    }
    // TODO: Step 4 填业务逻辑
    return nil, status.Error(codes.Unimplemented, "not implemented")
}
```

---

## Go 项目具体做法（REST）

```go
// Step 1: 先定义结构
type CreateUserRequest struct {
    Name  string `json:"name" binding:"required"`
    Email string `json:"email" binding:"required,email"`
}

type CreateUserResponse struct {
    UserID string `json:"user_id"`
}

// Step 3: 再写骨架
func (h *UserHandler) CreateUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    // TODO: Step 4 填业务逻辑
    c.JSON(501, gin.H{"error": "not implemented"})
}
```

---

## 触发条件

当用户说以下任一关键词时加载此 skill：
- "新增 API"、"新增接口"、"新增 RPC"、"新建 endpoint"
- "API 设计"、"接口设计"、"RPC 定义"
- "proto"、"OpenAPI"、"Swagger"
- "gRPC service"、"REST endpoint"

---

## 关联 Skill

- `error-taxonomy` — 当设计错误码时同时加载
- `data-model-first` — 当 API 涉及新数据模型时同时加载
- `prior-research` — 当不确定库的 API 签名时先搜
