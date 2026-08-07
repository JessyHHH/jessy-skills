#!/usr/bin/env python3
"""Validate Phase 4 task contracts, schedule safe waves, and enforce file scope."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


TASK_BLOCK_RE = re.compile(r"```json:tasks\s*(\[.*?\])\s*```", re.DOTALL)
TASK_ID_RE = re.compile(r"^T[0-9]+-[a-z0-9][a-z0-9-]*$")
PATCH_STRATEGIES = {"no-isolation", "harness-managed", "external-report"}
COMPLEXITIES = {"simple", "medium", "complex"}
LIST_FIELDS = (
    "files",
    "readFiles",
    "resources",
    "dependsOn",
    "contextRefs",
    "intakeRefs",
    "grillRefs",
    "acceptanceCommands",
    "expectedEvidence",
    "forbiddenEvidence",
)


class ContractError(ValueError):
    pass


def load_tasks(plan_path: Path) -> list[dict[str, Any]]:
    try:
        text = plan_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise ContractError(f"cannot read plan: {exc}") from exc

    match = TASK_BLOCK_RE.search(text)
    if not match:
        raise ContractError("plan must contain one ```json:tasks array block")
    try:
        tasks = json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        raise ContractError(f"invalid json:tasks block: {exc}") from exc
    if not isinstance(tasks, list) or not tasks:
        raise ContractError("json:tasks must be a non-empty array")
    if not all(isinstance(task, dict) for task in tasks):
        raise ContractError("every task must be an object")
    return tasks


def _validate_exact_path(value: str, field: str, task_id: str) -> None:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or any(char in value for char in "*?[]"):
        raise ContractError(f"{task_id}.{field} must contain exact repo-relative paths: {value}")


def validate_tasks(tasks: list[dict[str, Any]]) -> None:
    errors: list[str] = []
    ids: list[str] = []

    for index, task in enumerate(tasks):
        task_id = task.get("id", f"task[{index}]")
        try:
            if not isinstance(task.get("id"), str) or not TASK_ID_RE.fullmatch(task["id"]):
                raise ContractError(f"{task_id}.id must match T<number>-<short-name>")
            ids.append(task["id"])
            if not isinstance(task.get("prompt"), str) or not task["prompt"].strip():
                raise ContractError(f"{task_id}.prompt must be a non-empty string")
            if task.get("complexity") not in COMPLEXITIES:
                raise ContractError(f"{task_id}.complexity must be simple, medium, or complex")
            if not isinstance(task.get("mutatesFiles"), bool):
                raise ContractError(f"{task_id}.mutatesFiles must be boolean")

            for field in LIST_FIELDS:
                value = task.get(field)
                if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
                    raise ContractError(f"{task_id}.{field} must be an array of non-empty strings")
                if len(value) != len(set(value)):
                    raise ContractError(f"{task_id}.{field} must not contain duplicates")

            for field in ("files", "readFiles"):
                for value in task[field]:
                    _validate_exact_path(value, field, task_id)

            if task["mutatesFiles"] and not task["files"]:
                raise ContractError(f"{task_id}.files must list every allowed writable file")
            if not task["mutatesFiles"] and task["files"]:
                raise ContractError(f"{task_id}.files must be empty for a read-only task")
            if not task["acceptanceCommands"]:
                raise ContractError(f"{task_id}.acceptanceCommands must contain an executable command")
            if not task["expectedEvidence"]:
                raise ContractError(f"{task_id}.expectedEvidence must not be empty")
            if not task["forbiddenEvidence"]:
                raise ContractError(f"{task_id}.forbiddenEvidence must not be empty")

            strategy = task.get("patchBackStrategy")
            if task["mutatesFiles"] and strategy not in PATCH_STRATEGIES:
                raise ContractError(f"{task_id}.patchBackStrategy is missing or invalid")
            if not task["mutatesFiles"] and strategy not in (None, "external-report"):
                raise ContractError(f"{task_id}.patchBackStrategy is invalid for a read-only task")
        except ContractError as exc:
            errors.append(str(exc))

    if len(ids) != len(set(ids)):
        errors.append("task ids must be unique")

    id_set = set(ids)
    for task in tasks:
        task_id = task.get("id")
        for dependency in task.get("dependsOn", []):
            if dependency == task_id:
                errors.append(f"{task_id}.dependsOn cannot reference itself")
            elif dependency not in id_set:
                errors.append(f"{task_id}.dependsOn references unknown task {dependency}")

    if not errors:
        try:
            _topological_order(tasks)
        except ContractError as exc:
            errors.append(str(exc))
    if errors:
        raise ContractError("; ".join(errors))


def _topological_order(tasks: list[dict[str, Any]]) -> list[str]:
    by_id = {task["id"]: task for task in tasks}
    remaining = set(by_id)
    completed: set[str] = set()
    order: list[str] = []
    while remaining:
        ready = [task["id"] for task in tasks if task["id"] in remaining and set(task["dependsOn"]) <= completed]
        if not ready:
            raise ContractError("dependsOn contains a cycle")
        order.extend(ready)
        completed.update(ready)
        remaining.difference_update(ready)
    return order


def tasks_conflict(left: dict[str, Any], right: dict[str, Any]) -> bool:
    left_writes, right_writes = set(left["files"]), set(right["files"])
    left_reads, right_reads = set(left["readFiles"]), set(right["readFiles"])
    if left_writes & (right_writes | right_reads):
        return True
    if right_writes & (left_writes | left_reads):
        return True

    left_resources, right_resources = set(left["resources"]), set(right["resources"])
    if "unknown" in left_resources or "unknown" in right_resources:
        return True
    if left_resources & right_resources:
        return True

    left_unisolated = left["mutatesFiles"] and left.get("patchBackStrategy") != "harness-managed"
    right_unisolated = right["mutatesFiles"] and right.get("patchBackStrategy") != "harness-managed"
    if left_unisolated or right_unisolated:
        return True
    return False


def build_waves(tasks: list[dict[str, Any]]) -> list[list[str]]:
    remaining = {task["id"] for task in tasks}
    completed: set[str] = set()
    waves: list[list[str]] = []

    while remaining:
        ready = [task for task in tasks if task["id"] in remaining and set(task["dependsOn"]) <= completed]
        if not ready:
            raise ContractError("dependsOn contains a cycle")

        wave: list[dict[str, Any]] = []
        reader_count = 0
        for task in ready:
            if not task["mutatesFiles"] and reader_count >= 4:
                continue
            if any(tasks_conflict(task, selected) for selected in wave):
                continue
            wave.append(task)
            reader_count += int(not task["mutatesFiles"])

        if not wave:
            wave = [ready[0]]
        wave_ids = [task["id"] for task in wave]
        waves.append(wave_ids)
        completed.update(wave_ids)
        remaining.difference_update(wave_ids)

    return waves


def run_git(worktree: Path, *args: str) -> bytes:
    try:
        return subprocess.check_output(["git", "-C", str(worktree), *args], stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as exc:
        message = exc.output.decode("utf-8", errors="replace").strip()
        raise ContractError(f"git {' '.join(args)} failed: {message}") from exc


def changed_files(worktree: Path, base: str) -> list[str]:
    run_git(worktree, "rev-parse", "--verify", f"{base}^{{commit}}")
    tracked = run_git(worktree, "diff", "--name-only", "--no-renames", "-z", base, "--")
    untracked = run_git(worktree, "ls-files", "--others", "--exclude-standard", "-z")
    names = tracked.split(b"\0") + untracked.split(b"\0")
    return sorted({name.decode("utf-8", errors="surrogateescape") for name in names if name})


def command_validate(plan: Path) -> dict[str, Any]:
    tasks = load_tasks(plan)
    validate_tasks(tasks)
    return {"valid": True, "taskCount": len(tasks), "taskIds": [task["id"] for task in tasks]}


def command_schedule(plan: Path) -> dict[str, Any]:
    tasks = load_tasks(plan)
    validate_tasks(tasks)
    waves = build_waves(tasks)
    by_id = {task["id"]: task for task in tasks}
    writer_limit = max(sum(int(by_id[task_id]["mutatesFiles"]) for task_id in wave) for wave in waves)
    return {"valid": True, "writerLimit": writer_limit, "integration": "serial", "waves": waves}


def command_check_scope(plan: Path, task_id: str, worktree: Path, base: str) -> tuple[dict[str, Any], int]:
    tasks = load_tasks(plan)
    validate_tasks(tasks)
    task = next((candidate for candidate in tasks if candidate["id"] == task_id), None)
    if task is None:
        raise ContractError(f"unknown task id: {task_id}")

    root = Path(run_git(worktree, "rev-parse", "--show-toplevel").decode().strip()).resolve()
    if root != worktree.resolve():
        raise ContractError(f"worktree path must be its Git root: {worktree}")

    changed = changed_files(worktree, base)
    allowed = sorted(task["files"])
    unexpected = sorted(set(changed) - set(allowed))
    result = {
        "status": "PASS" if not unexpected else "BOUNDARY_VIOLATION",
        "taskId": task_id,
        "base": base,
        "allowedFiles": allowed,
        "changedFiles": changed,
        "unexpectedFiles": unexpected,
    }
    return result, 0 if not unexpected else 3


def command_check_plan_scope(plan: Path, worktree: Path, base: str) -> tuple[dict[str, Any], int]:
    tasks = load_tasks(plan)
    validate_tasks(tasks)
    root = Path(run_git(worktree, "rev-parse", "--show-toplevel").decode().strip()).resolve()
    if root != worktree.resolve():
        raise ContractError(f"worktree path must be its Git root: {worktree}")

    changed = changed_files(worktree, base)
    allowed = sorted({path for task in tasks for path in task["files"]})
    unexpected = sorted(set(changed) - set(allowed))
    result = {
        "status": "PASS" if not unexpected else "BOUNDARY_VIOLATION",
        "base": base,
        "allowedFiles": allowed,
        "changedFiles": changed,
        "unexpectedFiles": unexpected,
    }
    return result, 0 if not unexpected else 3


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate-plan", help="validate a plan json:tasks contract")
    validate.add_argument("plan", type=Path)

    schedule = subparsers.add_parser("schedule", help="print safe dependency and conflict waves")
    schedule.add_argument("plan", type=Path)

    scope = subparsers.add_parser("check-scope", help="compare actual changes with one task allowlist")
    scope.add_argument("plan", type=Path)
    scope.add_argument("task_id")
    scope.add_argument("--worktree", required=True, type=Path)
    scope.add_argument("--base", required=True)

    plan_scope = subparsers.add_parser("check-plan-scope", help="compare actual changes with all plan allowlists")
    plan_scope.add_argument("plan", type=Path)
    plan_scope.add_argument("--worktree", required=True, type=Path)
    plan_scope.add_argument("--base", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.command == "validate-plan":
            result, exit_code = command_validate(args.plan), 0
        elif args.command == "schedule":
            result, exit_code = command_schedule(args.plan), 0
        elif args.command == "check-scope":
            result, exit_code = command_check_scope(args.plan, args.task_id, args.worktree, args.base)
        else:
            result, exit_code = command_check_plan_scope(args.plan, args.worktree, args.base)
    except ContractError as exc:
        result, exit_code = {"status": "INVALID", "error": str(exc)}, 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
