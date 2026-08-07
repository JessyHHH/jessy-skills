# LangGraph 结合 Codex CLI 的受控多 Agent 编排方案

> 目标：让主会话负责监督、规划和审批，让 Codex CLI 作为执行 Agent 修改代码，同时通过 LangGraph、Git Worktree、结构化输出和确定性校验，降低 subagent 执行跑偏的风险。

---

## 1. 背景

在多 Agent 开发模式中，常见分工是：

- 主会话负责理解需求、拆分任务、监视执行和验收；
- subagent 负责检索代码、修改文件和运行测试。

实际使用中，subagent 容易出现以下问题：

1. 没有获得完整上下文；
2. 自行补充了错误假设；
3. 修改了不应该修改的文件；
4. 为了“完成任务”扩大重构范围；
5. 只验证局部测试，没有验证业务目标；
6. 主会话只能在执行完成后发现偏差。

因此，不能只依赖自然语言提示词约束 subagent，而应把约束做成程序能够验证的规则。

本方案采用以下原则：

> **LLM 负责语义理解，程序负责权限和边界控制。**

---

## 2. 总体架构

```text
┌──────────────────────────────────────────────┐
│ Codex CLI / Codex 客户端主会话               │
│                                              │
│ 用户提出任务                                 │
│ 主会话查看状态、Diff、测试结果并审批          │
└──────────────────────┬───────────────────────┘
                       │
                       │ 第一阶段：直接调用脚本
                       │ 后续阶段：MCP
                       ▼
┌──────────────────────────────────────────────┐
│ LangGraph Supervisor                         │
│                                              │
│ 1. 创建任务契约                              │
│ 2. 创建 Git Worktree                        │
│ 3. 调用 Codex CLI                            │
│ 4. 校验真实 Git Diff                        │
│ 5. 执行固定测试                              │
│ 6. 审核或暂停                                │
└──────────────────────┬───────────────────────┘
                       │
                       │ codex exec
                       ▼
┌──────────────────────────────────────────────┐
│ Codex CLI Worker                             │
│                                              │
│ - 在独立 Worktree 中运行                     │
│ - 使用 workspace-write sandbox              │
│ - 输出 JSONL 事件                            │
│ - 最终结果符合 JSON Schema                   │
└──────────────────────────────────────────────┘
```

推荐角色划分：

| 组件 | 责任 |
|---|---|
| Codex 主会话 | 接收用户任务、查看执行结果、作出最终决策 |
| LangGraph | 保存任务状态、控制节点流转、重试、审批、恢复 |
| Codex CLI Worker | 阅读代码、修改代码、运行任务内允许的命令 |
| Git Worktree | 隔离每个执行任务，避免污染主开发目录 |
| Validator | 校验修改文件、命令、Diff、测试结果 |
| Checkpointer | 保存 LangGraph 状态，支持暂停和恢复 |

---

## 3. 最重要的控制思想

### 3.1 不直接让 Codex 修改主工作区

错误方式：

```text
/root/application/project
    ↑
多个 subagent 直接修改
```

推荐方式：

```text
/root/application/project
/tmp/codex-worktrees/task-001
/tmp/codex-worktrees/task-002
/tmp/codex-worktrees/task-003
```

每个任务使用独立 Git Worktree。

### 3.2 不相信 Agent 自己报告的修改范围

Codex 最终可能返回：

```json
{
  "changed_files": [
    "internal/service.go"
  ]
}
```

但真实修改范围必须通过 Git 获取：

```bash
git diff --name-only HEAD
```

Agent 的输出只能作为说明，Git Diff 才是事实来源。

### 3.3 测试命令由任务契约指定

不要完全让 Codex 自己决定执行什么测试。

任务契约中应包含：

```json
{
  "test_commands": [
    "go test ./internal/modules/documents/...",
    "go test -race ./internal/modules/documents/task/..."
  ]
}
```

LangGraph 在 Codex 完成后，再独立执行这些命令。

### 3.4 高风险操作必须经过审批

以下动作不应由执行 Agent 自动完成：

- `git push`；
- 合并主分支；
- 修改数据库表结构；
- 执行生产 migration；
- 发布部署；
- 删除大量文件；
- 修改生产配置；
- 使用 `danger-full-access`；
- 修改允许范围外的文件。

---

## 4. 分阶段落地方案

不要一开始就搭建完整 MCP 平台。推荐按四个阶段实施。

### 阶段一：手动跑通 Codex CLI 执行

目标：

- Codex 能在指定目录执行；
- 能修改代码；
- 能生成结构化结果；
- 能读取真实 Diff。

### 阶段二：Python 封装 Codex CLI

目标：

- 使用 `asyncio.create_subprocess_exec` 调用 `codex exec`；
- 解析 JSONL 事件；
- 保存 Codex thread ID；
- 保存最终 JSON 结果。

### 阶段三：加入 LangGraph

目标：

- 将创建 Worktree、执行、校验、测试、审批编排为固定节点；
- 保存任务状态；
- 支持重试和人工审批。

### 阶段四：通过 MCP 接入 Codex 主会话

目标：

- 主会话可以调用 `submit_task`；
- 查询任务状态、Diff 和测试结果；
- 执行 `approve_task` 或 `reject_task`；
- 主会话不再直接修改代码。

---

# 第一部分：最小闭环

## 5. 环境检查

### 5.1 检查 Codex CLI

```bash
codex --version
codex login status
codex doctor --summary
```

如果没有安装：

```bash
npm install -g @openai/codex@latest
```

### 5.2 检查 Git 仓库

```bash
cd /root/application/your-project
git status
git rev-parse --show-toplevel
```

建议主仓库当前没有未提交修改。

### 5.3 测试非交互执行

```bash
codex exec \
  --cd /root/application/your-project \
  --sandbox read-only \
  "分析当前项目结构，不要修改文件"
```

### 5.4 测试 JSONL 输出

```bash
codex exec \
  --cd /root/application/your-project \
  --sandbox read-only \
  --json \
  "分析项目结构并列出主要模块"
```

启用 `--json` 后，输出为逐行 JSON 事件，常见事件包括：

- `thread.started`；
- `turn.started`；
- `item.started`；
- `item.completed`；
- `turn.completed`；
- `turn.failed`；
- `error`。

---

## 6. 创建独立 Worktree

假设主仓库是：

```text
/root/application/your-project
```

创建任务目录：

```bash
mkdir -p /tmp/codex-worktrees

git -C /root/application/your-project worktree add \
  /tmp/codex-worktrees/task-001 \
  -b codex/task-001
```

检查：

```bash
git -C /tmp/codex-worktrees/task-001 status
```

Codex 后续只在该目录执行：

```bash
codex --ask-for-approval never exec \
  --cd /tmp/codex-worktrees/task-001 \
  --sandbox workspace-write \
  "完成指定任务"
```

> `workspace-write` 只能提供工作区级别的文件系统约束，不能表达“只允许修改三个指定文件”。指定文件范围仍需通过 Git Diff 二次校验。

---

## 7. 任务契约

每次执行前，主会话需要生成一个结构化任务契约。

示例：

```json
{
  "task_id": "task-001",
  "repository": "/root/application/your-project",
  "base_ref": "HEAD",
  "objective": "修复文档删除后后台索引仍写入 Qdrant 的问题",
  "allowed_files": [
    "internal/modules/documents/app/service.go",
    "internal/modules/documents/task/index.go",
    "internal/modules/documents/task/index_test.go"
  ],
  "forbidden_actions": [
    "修改数据库表结构",
    "修改 API 请求或响应结构",
    "将异步索引改成同步",
    "执行 git push",
    "执行部署",
    "修改未授权文件"
  ],
  "acceptance_criteria": [
    "索引写入前重新读取文档状态",
    "deleted 状态不得写入 Qdrant",
    "approve 后立即 delete 不产生残留向量",
    "原有文档模块测试通过"
  ],
  "test_commands": [
    "go test ./internal/modules/documents/...",
    "go test -race ./internal/modules/documents/task/..."
  ],
  "max_retries": 2
}
```

任务契约应该由主会话负责决定，不应交给执行 subagent 自行扩大。

---

## 8. Codex 执行提示词模板

```text
你是受限代码执行 Agent。

任务目标：
{{ objective }}

允许修改的文件：
{{ allowed_files }}

禁止事项：
{{ forbidden_actions }}

验收条件：
{{ acceptance_criteria }}

执行规则：

1. 先分析调用链，再实施最小修改。
2. 只允许修改明确列出的文件。
3. 不要修改数据库结构、API 格式和部署配置。
4. 不要执行 git push、git merge、git reset --hard。
5. 不要重构无关代码。
6. 修改完成后运行与当前修改直接相关的测试。
7. 无法在授权范围内完成时，返回 blocked。
8. 不要为了完成任务而自行改变架构。
9. 最终输出必须符合指定 JSON Schema。
```

建议把提示词保存在文件中，而不是在 Python 中散落拼接：

```text
prompts/
└── executor.md
```

---

## 9. Codex 最终输出 Schema

创建：

```text
schemas/codex-result.schema.json
```

内容：

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "status": {
      "type": "string",
      "enum": [
        "success",
        "blocked",
        "failed"
      ]
    },
    "summary": {
      "type": "string"
    },
    "changed_files": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "commands": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "tests": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "command": {
            "type": "string"
          },
          "exit_code": {
            "type": "integer"
          },
          "summary": {
            "type": "string"
          }
        },
        "required": [
          "command",
          "exit_code",
          "summary"
        ],
        "additionalProperties": false
      }
    },
    "risks": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "needs_supervisor": {
      "type": "boolean"
    }
  },
  "required": [
    "status",
    "summary",
    "changed_files",
    "commands",
    "tests",
    "risks",
    "needs_supervisor"
  ],
  "additionalProperties": false
}
```

调用命令：

```bash
codex --ask-for-approval never exec \
  --cd /tmp/codex-worktrees/task-001 \
  --sandbox workspace-write \
  --json \
  --output-schema ./schemas/codex-result.schema.json \
  --output-last-message /tmp/task-001-result.json \
  "按照任务契约执行代码修改"
```

说明：

- `--json`：输出 JSONL 执行事件；
- `--output-schema`：约束最终回复结构；
- `--output-last-message`：把最终结果写入文件；
- `--sandbox workspace-write`：允许修改工作区；
- `--ask-for-approval never`：非交互运行，遇到无法执行的操作直接失败或返回。

---

# 第二部分：Python 封装

## 10. 推荐项目目录

```text
codex-orchestrator/
├── pyproject.toml
├── README.md
├── prompts/
│   └── executor.md
├── schemas/
│   └── codex-result.schema.json
├── orchestrator/
│   ├── __init__.py
│   ├── state.py
│   ├── command.py
│   ├── worktree.py
│   ├── codex_runner.py
│   ├── validators.py
│   ├── tests_runner.py
│   ├── graph.py
│   └── main.py
└── data/
    ├── tasks/
    ├── events/
    └── results/
```

## 11. 安装依赖

```bash
python3 -m venv .venv
source .venv/bin/activate

pip install langgraph
```

开发阶段可以使用内存 checkpointer。

生产阶段建议额外使用数据库持久化实现。

---

## 12. 状态定义

`orchestrator/state.py`：

```python
from typing import Any, TypedDict


class AgentState(TypedDict, total=False):
    task_id: str
    repository: str
    base_ref: str
    workspace: str
    branch_name: str

    objective: str
    allowed_files: list[str]
    forbidden_actions: list[str]
    acceptance_criteria: list[str]
    test_commands: list[str]
    max_retries: int
    retry_count: int

    codex_thread_id: str
    codex_events: list[dict[str, Any]]
    codex_result: dict[str, Any]

    actual_changed_files: list[str]
    diff_text: str
    violations: list[str]
    test_results: list[dict[str, Any]]

    status: str
    review_feedback: str
```

---

## 13. 通用命令执行器

`orchestrator/command.py`：

```python
import asyncio
from dataclasses import dataclass
from typing import Sequence


@dataclass
class CommandResult:
    command: list[str]
    return_code: int
    stdout: str
    stderr: str


async def run_command(
    command: Sequence[str],
    *,
    cwd: str | None = None,
    timeout: int = 600,
) -> CommandResult:
    process = await asyncio.create_subprocess_exec(
        *command,
        cwd=cwd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    try:
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            process.communicate(),
            timeout=timeout,
        )
    except TimeoutError:
        process.kill()
        await process.wait()
        raise RuntimeError(
            f"命令执行超时：{' '.join(command)}"
        )

    return CommandResult(
        command=list(command),
        return_code=process.returncode,
        stdout=stdout_bytes.decode(
            "utf-8",
            errors="replace",
        ),
        stderr=stderr_bytes.decode(
            "utf-8",
            errors="replace",
        ),
    )
```

---

## 14. Worktree 管理

`orchestrator/worktree.py`：

```python
from pathlib import Path

from .command import run_command
from .state import AgentState


WORKTREE_ROOT = Path("/tmp/codex-worktrees")


async def create_worktree(
    state: AgentState,
) -> dict:
    task_id = state["task_id"]
    repository = Path(state["repository"]).resolve()
    workspace = WORKTREE_ROOT / task_id
    branch_name = f"codex/{task_id}"

    WORKTREE_ROOT.mkdir(
        parents=True,
        exist_ok=True,
    )

    if workspace.exists():
        raise RuntimeError(
            f"任务 Worktree 已存在：{workspace}"
        )

    result = await run_command(
        [
            "git",
            "-C",
            str(repository),
            "worktree",
            "add",
            str(workspace),
            "-b",
            branch_name,
            state.get("base_ref", "HEAD"),
        ],
    )

    if result.return_code != 0:
        raise RuntimeError(
            f"创建 Worktree 失败：{result.stderr}"
        )

    return {
        "workspace": str(workspace),
        "branch_name": branch_name,
        "status": "worktree_created",
    }


async def cleanup_worktree(
    state: AgentState,
) -> dict:
    workspace = state.get("workspace")

    if not workspace:
        return {}

    result = await run_command(
        [
            "git",
            "-C",
            state["repository"],
            "worktree",
            "remove",
            "--force",
            workspace,
        ],
    )

    if result.return_code != 0:
        return {
            "violations": state.get(
                "violations",
                [],
            ) + [
                f"清理 Worktree 失败：{result.stderr}"
            ]
        }

    return {
        "status": "cleaned",
    }
```

> 不建议让 Codex 自己创建或删除 Worktree。Worktree 生命周期由 LangGraph 管理。

---

## 15. 构建 Codex Prompt

`orchestrator/codex_runner.py`：

```python
import asyncio
import json
import os
from pathlib import Path
from typing import Any

from .state import AgentState


def format_items(items: list[str]) -> str:
    if not items:
        return "- 无"

    return "\n".join(
        f"- {item}" for item in items
    )


def build_codex_prompt(
    state: AgentState,
) -> str:
    return f"""
你是受限代码执行 Agent。

任务目标：
{state["objective"]}

允许修改的文件：
{format_items(state["allowed_files"])}

禁止事项：
{format_items(state["forbidden_actions"])}

验收条件：
{format_items(state["acceptance_criteria"])}

执行规则：

1. 先分析相关调用链。
2. 只做满足目标所需的最小修改。
3. 只允许修改任务契约列出的文件。
4. 不得修改数据库结构、API 格式或部署配置。
5. 不得执行 git push、git merge、git reset --hard。
6. 不得扩大任务范围或重构无关代码。
7. 修改后运行直接相关的测试。
8. 无法在约束内完成时返回 blocked。
9. 最终输出必须符合 JSON Schema。
""".strip()
```

---

## 16. 调用 Codex CLI

继续编辑 `orchestrator/codex_runner.py`：

```python
async def execute_codex(
    state: AgentState,
) -> dict[str, Any]:
    task_id = state["task_id"]
    workspace = Path(
        state["workspace"]
    ).resolve()

    project_root = Path(__file__).resolve().parent.parent
    schema_path = (
        project_root
        / "schemas"
        / "codex-result.schema.json"
    )

    result_dir = project_root / "data" / "results"
    event_dir = project_root / "data" / "events"

    result_dir.mkdir(
        parents=True,
        exist_ok=True,
    )
    event_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    result_file = result_dir / f"{task_id}.json"
    event_file = event_dir / f"{task_id}.jsonl"

    codex_bin = os.environ.get(
        "CODEX_BIN",
        "codex",
    )

    command = [
        codex_bin,
        "--ask-for-approval",
        "never",
        "exec",
        "--cd",
        str(workspace),
        "--sandbox",
        "workspace-write",
        "--json",
        "--output-schema",
        str(schema_path),
        "--output-last-message",
        str(result_file),
        build_codex_prompt(state),
    ]

    environment = os.environ.copy()

    process = await asyncio.create_subprocess_exec(
        *command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=environment,
    )

    if process.stdout is None:
        raise RuntimeError(
            "无法读取 Codex stdout"
        )

    if process.stderr is None:
        raise RuntimeError(
            "无法读取 Codex stderr"
        )

    events: list[dict[str, Any]] = []
    stderr_lines: list[str] = []
    thread_id = ""

    async def read_stdout() -> None:
        nonlocal thread_id

        with event_file.open(
            "w",
            encoding="utf-8",
        ) as output:
            async for raw_line in process.stdout:
                line = raw_line.decode(
                    "utf-8",
                    errors="replace",
                ).strip()

                if not line:
                    continue

                output.write(line + "\n")
                output.flush()

                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    events.append({
                        "type": "invalid_jsonl",
                        "raw": line,
                    })
                    continue

                events.append(event)

                if (
                    event.get("type")
                    == "thread.started"
                ):
                    thread_id = str(
                        event.get(
                            "thread_id",
                            "",
                        )
                    )

    async def read_stderr() -> None:
        async for raw_line in process.stderr:
            stderr_lines.append(
                raw_line.decode(
                    "utf-8",
                    errors="replace",
                ).strip()
            )

    await asyncio.gather(
        read_stdout(),
        read_stderr(),
    )

    return_code = await process.wait()

    if return_code != 0:
        return {
            "status": "codex_failed",
            "codex_thread_id": thread_id,
            "codex_events": events,
            "violations": [
                "Codex CLI 执行失败",
                "\n".join(
                    stderr_lines[-20:]
                ),
            ],
        }

    if not result_file.exists():
        return {
            "status": "codex_failed",
            "codex_thread_id": thread_id,
            "codex_events": events,
            "violations": [
                "Codex 未生成最终结果文件"
            ],
        }

    try:
        codex_result = json.loads(
            result_file.read_text(
                encoding="utf-8",
            )
        )
    except json.JSONDecodeError as exc:
        return {
            "status": "codex_failed",
            "codex_thread_id": thread_id,
            "codex_events": events,
            "violations": [
                f"Codex 最终结果不是合法 JSON：{exc}"
            ],
        }

    return {
        "status": "codex_completed",
        "codex_thread_id": thread_id,
        "codex_events": events,
        "codex_result": codex_result,
    }
```

---

## 17. 校验真实修改文件

`orchestrator/validators.py`：

```python
from pathlib import PurePosixPath

from .command import run_command
from .state import AgentState


def normalize_git_path(path: str) -> str:
    return PurePosixPath(
        path.strip()
    ).as_posix()


def file_is_allowed(
    changed_file: str,
    allowed_files: list[str],
) -> bool:
    changed = normalize_git_path(
        changed_file
    )

    for allowed in allowed_files:
        normalized = normalize_git_path(
            allowed
        )

        if normalized.endswith("/"):
            if changed.startswith(normalized):
                return True
        elif changed == normalized:
            return True

    return False


async def validate_diff(
    state: AgentState,
) -> dict:
    workspace = state["workspace"]

    names_result = await run_command(
        [
            "git",
            "diff",
            "--name-only",
            "HEAD",
        ],
        cwd=workspace,
    )

    if names_result.return_code != 0:
        return {
            "status": "validation_failed",
            "violations": [
                f"读取修改文件失败："
                f"{names_result.stderr}"
            ],
        }

    actual_changed_files = [
        normalize_git_path(line)
        for line in names_result.stdout.splitlines()
        if line.strip()
    ]

    violations = [
        f"修改了未授权文件：{path}"
        for path in actual_changed_files
        if not file_is_allowed(
            path,
            state["allowed_files"],
        )
    ]

    diff_result = await run_command(
        [
            "git",
            "diff",
            "--binary",
            "HEAD",
        ],
        cwd=workspace,
    )

    if diff_result.return_code != 0:
        violations.append(
            f"读取 Diff 失败："
            f"{diff_result.stderr}"
        )

    if not actual_changed_files:
        violations.append(
            "Codex 没有产生任何代码修改"
        )

    return {
        "actual_changed_files": actual_changed_files,
        "diff_text": diff_result.stdout,
        "violations": violations,
        "status": (
            "boundary_violation"
            if violations
            else "diff_validated"
        ),
    }
```

建议进一步增加以下校验：

- 禁止新增 migration 文件；
- 禁止修改 CI/CD 文件；
- 禁止修改密钥和环境变量文件；
- 限制最大 Diff 行数；
- 限制新增或删除文件数量；
- 检查二进制文件；
- 检查 Git submodule 变化；
- 检查符号链接；
- 检查是否有未跟踪文件。

获取未跟踪文件：

```bash
git status --porcelain
```

---

## 18. 由 LangGraph 独立执行测试

`orchestrator/tests_runner.py`：

```python
import shlex
from typing import Any

from .command import run_command
from .state import AgentState


async def run_fixed_tests(
    state: AgentState,
) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    violations = list(
        state.get("violations", [])
    )

    for test_command in state.get(
        "test_commands",
        [],
    ):
        args = shlex.split(test_command)

        result = await run_command(
            args,
            cwd=state["workspace"],
            timeout=1200,
        )

        record = {
            "command": test_command,
            "exit_code": result.return_code,
            "stdout": result.stdout[-10000:],
            "stderr": result.stderr[-10000:],
        }

        results.append(record)

        if result.return_code != 0:
            violations.append(
                f"测试失败：{test_command}"
            )

    return {
        "test_results": results,
        "violations": violations,
        "status": (
            "tests_failed"
            if violations
            else "tests_passed"
        ),
    }
```

注意：

> 直接使用 `shlex.split` 不支持管道、重定向和复杂 Shell 表达式。生产环境应把测试命令设计为“可执行文件 + 参数数组”，而不是任意 Shell 字符串。

更安全的任务契约形式：

```json
{
  "test_commands": [
    [
      "go",
      "test",
      "./internal/modules/documents/..."
    ],
    [
      "go",
      "test",
      "-race",
      "./internal/modules/documents/task/..."
    ]
  ]
}
```

---

# 第三部分：LangGraph 编排

## 19. 推荐节点

```text
START
  ↓
create_worktree
  ↓
execute_codex
  ↓
validate_diff
  ├── 越权 → reject
  ↓
run_fixed_tests
  ├── 失败 → review
  ↓
approval_gate
  ├── 批准 → accepted
  ├── 返工 → resume_codex
  └── 拒绝 → rejected
```

完整生产图可增加：

```text
create_contract
validate_contract
create_worktree
plan_only
validate_plan
execute_codex
validate_diff
security_scan
run_fixed_tests
supervisor_review
approval_gate
create_patch
apply_patch
cleanup_worktree
```

---

## 20. 基础 LangGraph

`orchestrator/graph.py`：

```python
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import interrupt

from .codex_runner import execute_codex
from .state import AgentState
from .tests_runner import run_fixed_tests
from .validators import validate_diff
from .worktree import create_worktree


def reject_task(
    state: AgentState,
) -> dict:
    return {
        "status": "rejected",
    }


def approval_gate(
    state: AgentState,
) -> dict:
    decision = interrupt({
        "type": "code_change_approval",
        "task_id": state["task_id"],
        "changed_files": state.get(
            "actual_changed_files",
            [],
        ),
        "violations": state.get(
            "violations",
            [],
        ),
        "test_results": state.get(
            "test_results",
            [],
        ),
        "diff": state.get(
            "diff_text",
            "",
        ),
        "options": [
            "approve",
            "reject",
            "retry",
        ],
    })

    if not isinstance(decision, dict):
        return {
            "status": "rejected",
            "review_feedback": (
                "审批数据格式错误"
            ),
        }

    action = decision.get("action")
    feedback = str(
        decision.get("feedback", "")
    )

    return {
        "status": action or "rejected",
        "review_feedback": feedback,
    }


def route_after_diff(
    state: AgentState,
) -> str:
    if state.get("violations"):
        return "reject"

    return "run_tests"


def route_after_tests(
    state: AgentState,
) -> str:
    return "approval"


builder = StateGraph(AgentState)

builder.add_node(
    "create_worktree",
    create_worktree,
)
builder.add_node(
    "execute_codex",
    execute_codex,
)
builder.add_node(
    "validate_diff",
    validate_diff,
)
builder.add_node(
    "run_tests",
    run_fixed_tests,
)
builder.add_node(
    "approval",
    approval_gate,
)
builder.add_node(
    "reject",
    reject_task,
)

builder.add_edge(
    START,
    "create_worktree",
)
builder.add_edge(
    "create_worktree",
    "execute_codex",
)
builder.add_edge(
    "execute_codex",
    "validate_diff",
)

builder.add_conditional_edges(
    "validate_diff",
    route_after_diff,
    {
        "reject": "reject",
        "run_tests": "run_tests",
    },
)

builder.add_conditional_edges(
    "run_tests",
    route_after_tests,
    {
        "approval": "approval",
    },
)

builder.add_edge(
    "approval",
    END,
)
builder.add_edge(
    "reject",
    END,
)

checkpointer = InMemorySaver()

graph = builder.compile(
    checkpointer=checkpointer,
)
```

说明：

- `InMemorySaver` 只适用于本地开发；
- 进程重启后状态会丢失；
- 生产环境应换成 SQLite 或 PostgreSQL checkpointer；
- 每个任务必须使用稳定且唯一的 `thread_id`。

---

## 21. 启动任务

`orchestrator/main.py`：

```python
import asyncio
import json
import uuid

from .graph import graph


async def main() -> None:
    task_id = (
        "task-"
        + uuid.uuid4().hex[:8]
    )

    task = {
        "task_id": task_id,
        "repository": (
            "/root/application/your-project"
        ),
        "base_ref": "HEAD",
        "objective": (
            "修复文档删除后后台索引"
            "仍写入 Qdrant 的问题"
        ),
        "allowed_files": [
            (
                "internal/modules/documents/"
                "app/service.go"
            ),
            (
                "internal/modules/documents/"
                "task/index.go"
            ),
            (
                "internal/modules/documents/"
                "task/index_test.go"
            ),
        ],
        "forbidden_actions": [
            "修改数据库表结构",
            "修改 API 格式",
            "将异步索引改为同步",
            "执行 git push",
            "修改其他文件",
        ],
        "acceptance_criteria": [
            "写入前重新读取文档状态",
            "deleted 状态不写入 Qdrant",
            "并发删除不产生残留",
        ],
        "test_commands": [
            (
                "go test "
                "./internal/modules/documents/..."
            ),
        ],
        "max_retries": 2,
        "retry_count": 0,
        "violations": [],
        "status": "created",
    }

    config = {
        "configurable": {
            "thread_id": task_id,
        }
    }

    result = await graph.ainvoke(
        task,
        config=config,
    )

    print(
        json.dumps(
            result,
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    asyncio.run(main())
```

运行：

```bash
python -m orchestrator.main
```

执行到 `interrupt()` 后，LangGraph 会保存状态并暂停。

---

## 22. 恢复审批

恢复图执行时，使用相同的 `thread_id`。

示例：

```python
import asyncio

from langgraph.types import Command

from orchestrator.graph import graph


async def approve() -> None:
    task_id = "task-12345678"

    config = {
        "configurable": {
            "thread_id": task_id,
        }
    }

    result = await graph.ainvoke(
        Command(
            resume={
                "action": "approve",
                "feedback": "Diff 和测试均通过",
            }
        ),
        config=config,
    )

    print(result)


asyncio.run(approve())
```

拒绝：

```python
Command(
    resume={
        "action": "reject",
        "feedback": "修改范围过大",
    }
)
```

返工：

```python
Command(
    resume={
        "action": "retry",
        "feedback": (
            "状态检查位置过早，"
            "需要在最终 upsert 前再次检查"
        ),
    }
)
```

要真正实现返工，需要在图中增加 `resume_codex` 节点。

---

## 23. 继续同一个 Codex Thread

第一次执行时，应从 JSONL 中保存：

```json
{
  "type": "thread.started",
  "thread_id": "0199a213-..."
}
```

返工时使用：

```bash
codex exec resume 0199a213-... \
  "根据审核意见继续修改：在最终 upsert 前重新检查文档状态"
```

在并发任务中，不建议使用：

```bash
codex exec resume --last
```

因为可能恢复到错误任务。

LangGraph 应始终保存具体 `codex_thread_id`。

Python 返工节点示意：

```python
async def resume_codex(
    state: AgentState,
) -> dict:
    thread_id = state.get(
        "codex_thread_id"
    )

    if not thread_id:
        return {
            "status": "retry_failed",
            "violations": [
                "缺少 Codex thread ID"
            ],
        }

    command = [
        "codex",
        "--ask-for-approval",
        "never",
        "exec",
        "resume",
        thread_id,
        (
            "按照审核意见继续修改：\n"
            + state.get(
                "review_feedback",
                "",
            )
        ),
    ]

    # 后续处理方式与 execute_codex 相同：
    # 读取 JSONL、保存结果、重新校验 Diff。
```

---

# 第四部分：接入 Codex 客户端

## 24. 两种连接方式

### 方式 A：主会话直接执行本地编排脚本

最简单：

```text
用户
  ↓
Codex 主会话
  ↓ 执行命令
python -m orchestrator.main
```

优点：

- 快速；
- 不需要 MCP；
- 便于调试。

缺点：

- 主会话不容易直接查询结构化任务状态；
- 审批和恢复要通过命令完成。

### 方式 B：LangGraph 暴露 MCP Server

最终推荐：

```text
Codex 主会话
  ↓ MCP
LangGraph MCP Server
  ↓
Codex CLI Worker
```

建议提供以下 MCP 工具：

| 工具 | 作用 |
|---|---|
| `submit_task` | 创建任务并启动 LangGraph |
| `get_task_status` | 获取任务当前节点和状态 |
| `get_task_events` | 查看 Codex JSONL 事件 |
| `get_task_diff` | 获取真实 Git Diff |
| `get_test_results` | 获取固定测试结果 |
| `approve_task` | 批准代码修改 |
| `reject_task` | 拒绝并清理 Worktree |
| `retry_task` | 带审核意见继续原 Codex Thread |
| `create_patch` | 生成补丁文件 |
| `apply_patch` | 经批准后应用补丁 |

---

## 25. 在 Codex CLI 中添加 MCP 服务

本地 stdio MCP：

```bash
codex mcp add langgraph-supervisor \
  -- python -m orchestrator.mcp_server
```

如果需要传环境变量：

```bash
codex mcp add langgraph-supervisor \
  --env CODEX_BIN=/usr/local/bin/codex \
  --env WORKTREE_ROOT=/tmp/codex-worktrees \
  -- python -m orchestrator.mcp_server
```

远程 Streamable HTTP MCP：

```bash
codex mcp add langgraph-supervisor \
  --url https://your-domain.example/mcp
```

检查：

```bash
codex mcp list
codex mcp get langgraph-supervisor
```

删除：

```bash
codex mcp remove langgraph-supervisor
```

---

## 26. Codex 主会话中的使用方式

连接 MCP 后，可以对 Codex 主会话这样说：

```text
使用 langgraph-supervisor 提交一个受限代码任务。

目标：
修复文档删除后后台索引仍写入 Qdrant 的问题。

允许修改：
- internal/modules/documents/app/service.go
- internal/modules/documents/task/index.go
- internal/modules/documents/task/index_test.go

禁止：
- 修改数据库结构
- 修改 API 请求和响应格式
- 将异步索引改成同步
- git push
- 修改其他文件

验收：
- deleted 状态不得写入 Qdrant
- approve 后立即 delete 不产生残留
- 文档模块测试通过

执行结束后不要自动应用修改。
先返回真实 Diff、测试结果和风险，等待我批准。
```

预期流程：

```text
主会话调用 submit_task
        ↓
LangGraph 创建 Worktree
        ↓
LangGraph 调用 codex exec
        ↓
Codex 执行修改
        ↓
LangGraph 校验 Diff
        ↓
LangGraph 执行固定测试
        ↓
主会话调用 get_task_diff
        ↓
用户批准
        ↓
主会话调用 approve_task
```

---

# 第五部分：补丁与合并策略

## 27. 不建议自动 Cherry-pick

第一版应只生成补丁：

```bash
git -C /tmp/codex-worktrees/task-001 \
  diff --binary HEAD \
  > /tmp/task-001.patch
```

用户审核后，在主仓库应用：

```bash
git -C /root/application/your-project \
  apply --check /tmp/task-001.patch

git -C /root/application/your-project \
  apply /tmp/task-001.patch
```

再次查看：

```bash
git -C /root/application/your-project status
git -C /root/application/your-project diff
```

### 生产流程建议

```text
Codex 修改 Worktree
    ↓
生成 Patch
    ↓
安全扫描
    ↓
人工审批
    ↓
独立进程应用 Patch
    ↓
重新执行完整测试
    ↓
人工提交或创建 PR
```

不要让持有模型凭据的执行进程同时持有仓库推送权限。

---

## 28. 审核通过后提交

也可以在 Worktree 中提交：

```bash
git -C /tmp/codex-worktrees/task-001 add \
  internal/modules/documents/app/service.go \
  internal/modules/documents/task/index.go \
  internal/modules/documents/task/index_test.go

git -C /tmp/codex-worktrees/task-001 commit \
  -m "fix: prevent deleted documents from being indexed"
```

然后由人工在主仓库执行：

```bash
git cherry-pick <commit-id>
```

推荐把“生成提交”和“推送远程仓库”拆成两个权限不同的阶段。

---

# 第六部分：安全设计

## 29. Codex Sandbox 不是完整授权系统

`workspace-write` 能限制写入工作区，但还需要额外措施：

1. 独立 Worktree；
2. 允许文件白名单；
3. Git Diff 校验；
4. 固定测试命令；
5. 命令白名单；
6. 禁止网络或限制网络；
7. 不提供部署凭据；
8. 不提供 Git 推送凭据；
9. 高风险动作走 `interrupt()`；
10. 超出边界直接丢弃 Worktree。

---

## 30. 不要把认证文件放进仓库

需要保护：

```text
~/.codex/auth.json
~/.codex/config.toml
```

其中认证文件应按密码处理：

- 不提交 Git；
- 不复制到任务目录；
- 不输出到日志；
- 不发到聊天；
- 不挂载到不可信容器；
- 不让仓库中的脚本读取。

如果 LangGraph 通过 systemd 或 Docker 启动，需要确保运行用户能够访问正确的 Codex 配置，同时避免把配置暴露给代码仓库。

---

## 31. CODEX_HOME 与运行用户

你在终端中可以运行 Codex，不代表 systemd、Docker 或另一个 Linux 用户也能运行。

建议显式设置：

```bash
export CODEX_BIN=/home/your-user/.nvm/versions/node/v24/bin/codex
export CODEX_HOME=/home/your-user/.codex
```

Python：

```python
environment = os.environ.copy()
environment["CODEX_HOME"] = (
    "/home/your-user/.codex"
)
```

检查：

```bash
sudo -u your-user \
  CODEX_HOME=/home/your-user/.codex \
  /home/your-user/.nvm/versions/node/v24/bin/codex \
  login status
```

---

## 32. 命令权限建议

执行 Agent 可以允许：

```text
git diff
git status
go test
npm test
pnpm test
pytest
cargo test
项目内代码生成命令
```

执行 Agent 默认禁止：

```text
git push
git clean -fdx
git reset --hard
rm -rf
docker system prune
kubectl apply
kubectl delete
helm upgrade
terraform apply
数据库 migration
生产环境脚本
```

程序不能只检查 Codex 最终报告的 `commands` 字段。

更可靠的方式是：

- 使用 Codex JSONL 的 `command_execution` 事件记录命令；
- 使用 Codex execpolicy；
- 在容器或受限系统用户中运行；
- 不把敏感凭据放入执行环境。

---

# 第七部分：监控与可观测性

## 33. 建议记录的数据

每个任务保存：

```json
{
  "task_id": "task-001",
  "langgraph_thread_id": "task-001",
  "codex_thread_id": "0199a213-...",
  "repository": "/root/application/project",
  "workspace": "/tmp/codex-worktrees/task-001",
  "status": "waiting_for_review",
  "current_node": "approval_gate",
  "allowed_files": [],
  "actual_changed_files": [],
  "violations": [],
  "test_results": [],
  "created_at": "",
  "updated_at": ""
}
```

建议日志维度：

- `task_id`；
- `codex_thread_id`；
- LangGraph 节点；
- 命令开始和完成；
- 命令退出码；
- 文件修改列表；
- Diff 行数；
- 测试耗时；
- 重试次数；
- 审批人；
- 审批结果；
- 错误信息。

---

## 34. 状态机建议

```text
created
worktree_created
codex_running
codex_completed
diff_validated
boundary_violation
tests_running
tests_passed
tests_failed
waiting_for_review
retrying
approved
rejected
patch_created
applied
cleaned
failed
```

状态不要只存在自然语言消息里，应保存成结构化字段。

---

# 第八部分：失败与重试

## 35. 可以自动重试的情况

- Codex 临时执行失败；
- 模型返回格式不合法；
- 测试失败但修改范围未越权；
- 审核明确给出局部修复意见；
- 命令因临时依赖问题失败。

## 36. 不应自动重试的情况

- 修改了未授权文件；
- 修改数据库结构；
- 删除大量文件；
- 需要改变 API 协议；
- 需要增加新的基础设施；
- 任务目标本身存在冲突；
- 需要生产环境凭据；
- 超过最大重试次数。

越权时建议：

```text
标记 boundary_violation
    ↓
停止当前图
    ↓
保存 Diff 和日志
    ↓
不允许继续原地修改
    ↓
用户决定丢弃或重新创建任务
```

---

# 第九部分：建议的最小可用版本

## 37. 第一版只实现以下能力

第一版不要实现：

- 多仓库；
- 多用户；
- Web 管理后台；
- 自动合并；
- 自动部署；
- 复杂 Agent 团队；
- 动态生成任意命令；
- 自动修改数据库。

第一版只实现：

1. 输入一个任务契约；
2. 创建一个 Worktree；
3. 调用一次 `codex exec`；
4. 解析 JSONL；
5. 获取真实 Diff；
6. 校验允许文件；
7. 运行固定测试；
8. 输出结果；
9. 人工决定是否应用 Patch。

最小闭环：

```text
task.json
   ↓
python -m orchestrator.main
   ↓
/tmp/codex-worktrees/task-xxx
   ↓
codex exec
   ↓
diff + test result
   ↓
人工审核
```

---

## 38. 第一版验收清单

### Codex CLI

- [ ] `codex --version` 正常；
- [ ] `codex login status` 正常；
- [ ] `codex exec --sandbox read-only` 正常；
- [ ] `codex exec --json` 能输出 JSONL；
- [ ] `--output-schema` 能生成结构化结果；
- [ ] 能读取 `thread.started` 的 thread ID。

### Worktree

- [ ] 每个任务创建独立 Worktree；
- [ ] Codex 不操作主仓库；
- [ ] Worktree 路径唯一；
- [ ] 越权任务可以直接丢弃 Worktree；
- [ ] 任务结束可以清理 Worktree。

### 边界校验

- [ ] 真实修改文件来自 `git diff --name-only HEAD`；
- [ ] 未跟踪文件也会被检查；
- [ ] 修改范围超出白名单时拒绝；
- [ ] 禁止 migration、部署文件和密钥文件；
- [ ] Diff 过大时转人工审核。

### 测试

- [ ] 测试命令来自任务契约；
- [ ] 测试由 LangGraph 独立执行；
- [ ] 保存退出码；
- [ ] 保存关键 stdout 和 stderr；
- [ ] 测试失败不会自动应用修改。

### 审批

- [ ] 审批前展示真实 Diff；
- [ ] 审批前展示测试结果；
- [ ] 审批支持 approve、reject、retry；
- [ ] retry 使用具体 Codex thread ID；
- [ ] 不使用 `resume --last` 处理并发任务。

---

# 第十部分：推荐最终架构

```text
┌──────────────────────────────────────────────────┐
│ Codex 主会话                                     │
│                                                  │
│ - 理解用户需求                                   │
│ - 生成任务契约                                   │
│ - 通过 MCP 提交任务                              │
│ - 查看真实 Diff                                  │
│ - 查看测试结果                                   │
│ - 审批或返工                                     │
└────────────────────────┬─────────────────────────┘
                         │ MCP
                         ▼
┌──────────────────────────────────────────────────┐
│ LangGraph Supervisor                             │
│                                                  │
│ create_contract                                  │
│ validate_contract                                │
│ create_worktree                                  │
│ execute_codex                                    │
│ validate_diff                                    │
│ run_fixed_tests                                  │
│ supervisor_review                                │
│ interrupt / resume                               │
│ create_patch                                     │
└────────────────────────┬─────────────────────────┘
                         │ codex exec
                         ▼
┌──────────────────────────────────────────────────┐
│ Codex CLI Worker                                 │
│                                                  │
│ workspace-write sandbox                          │
│ 独立 Git Worktree                                │
│ JSONL 事件                                       │
│ JSON Schema 最终结果                             │
└────────────────────────┬─────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────┐
│ 确定性校验层                                     │
│                                                  │
│ Git Diff                                         │
│ 文件白名单                                       │
│ 命令策略                                         │
│ 固定测试                                         │
│ 安全扫描                                         │
│ Patch 生成                                       │
└──────────────────────────────────────────────────┘
```

---

# 结论

结合 Codex CLI 使用 LangGraph 时，推荐关系是：

```text
Codex 客户端负责交互和审批
LangGraph 负责流程和状态
Codex CLI 负责代码执行
Git Worktree 负责环境隔离
确定性程序负责边界校验
```

不要把整个任务直接交给一个 subagent，让它同时负责分析、设计、修改、测试和自我验收。

更稳定的方式是：

```text
主会话定义任务契约
    ↓
LangGraph 创建隔离环境
    ↓
Codex CLI 执行原子任务
    ↓
程序检查真实修改
    ↓
程序执行固定测试
    ↓
主会话审核和批准
```

第一步只需要完成：

> **LangGraph 调用一次 `codex exec`，在独立 Worktree 修改代码，然后由程序校验真实 Git Diff。**

这个最小闭环稳定后，再接 MCP、多任务、持久化、可视化和自动化审批。
