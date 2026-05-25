---
name: data-model-first
description: "数据模型优先方法论。先设计实体关系和数据结构再写 storage 层。5 步：ER 关系 → struct/表定义 → 索引策略 → storage 接口 → 实现。触发词：'数据模型', '数据库设计', '新增表', '新增存储', '表结构', '建表', 'entity', 'model'。"
version: "1.0"
author: "jessyhuang"
metadata:
  hermes:
    tags: [data, model, database, methodology, design-first]
    auto_load: false
---

# Data Model First — 先设计数据结构，再写存储

**核心理念：** 数据结构是所有代码的基础。如果模型错了，handler、storage、测试全要重写。先花 10 分钟设计模型，省下 2 小时重构。

---

## 5 步流程

```
Step 1: 实体关系（ER）
  ├── 有哪些实体？（User、Order、Product...）
  ├── 实体之间什么关系？（1:1、1:N、N:M）
  └── 输出: 描述或 Mermaid ER 图

Step 2: 定义 struct / 表结构
  ├── Go struct 字段 + tag
  ├── SQL DDL（如果有数据库）
  └── 输出: 可编译的 struct 或可执行的 DDL

Step 3: 确定索引策略
  ├── 按什么字段查询？（决定主键和索引）
  ├── 有没有唯一约束？
  └── 输出: 索引列表

Step 4: 定义 storage 接口
  ├── 接口方法签名（不实现）
  └── 输出: Go interface

Step 5: 实现存储
  ├── 按接口写具体实现
  └── 输出: MySQL/PostgreSQL/SQLite 实现代码
```

---

## 原则

1. **一个实体一个 struct。** 不要一个 struct 既当 User 又当 UserProfile。
2. **主键用 UUID 或雪花 ID。** 不要依赖自增 ID 做外部引用（分布式场景下会爆炸）。
3. **时间字段统一。** `created_at`、`updated_at`，类型统一 `time.Time`，命名统一 snake_case 转 DB 列。
4. **软删除还是硬删除。** 先定策略。软删除要 `deleted_at` 字段 + 全局过滤。
5. **字段不存派生值。** `age` 应该从 `birth_date` 计算，不存数据库。

---

## Go 项目具体做法

```go
// Step 2: 先定义 struct
type User struct {
    ID        string    `gorm:"primaryKey;type:varchar(36)" json:"id"`
    Name      string    `gorm:"not null" json:"name"`
    Email     string    `gorm:"uniqueIndex;not null" json:"email"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

// Step 3: 索引策略
// - email: 唯一索引（登录查找）
// - name: 普通索引（搜索）
// - created_at: 降序索引（时间线查询）

// Step 4: 先定义接口
type UserStorage interface {
    Create(ctx context.Context, user *User) error
    GetByID(ctx context.Context, id string) (*User, error)
    GetByEmail(ctx context.Context, email string) (*User, error)
    List(ctx context.Context, offset, limit int) ([]*User, error)
}
```

```sql
-- Step 2: 对应的 DDL
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE INDEX idx_email (email),
    INDEX idx_name (name),
    INDEX idx_created_at (created_at DESC)
);
```

---

## 触发条件

当用户说以下任一关键词时加载此 skill：
- "数据模型"、"数据库设计"、"新增表"、"新增存储"
- "表结构"、"建表"、"DDL"
- "entity"、"model"、"struct 设计"
- "ORM"、"GORM"、"migration"

---

## 关联 Skill

- `api-design-first` — API 需要用这些数据模型
- `error-taxonomy` — 存储层错误怎么分类
- `prior-research` — 不确定 GORM 的 tag 语法时先搜
