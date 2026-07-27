#!/usr/bin/env python3
"""Small command-line client for a self-hosted Mem0 REST service."""

import argparse
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


DEFAULT_BASE_URL = "http://127.0.0.1:8002"


def parse_metadata(value):
    try:
        metadata = json.loads(value)
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid metadata JSON: {error.msg}") from error
    if not isinstance(metadata, dict):
        raise ValueError("metadata must be a JSON object")
    return metadata


def request_json(base_url, api_key, method, path, query=None, body=None):
    url = f"{base_url.rstrip('/')}{path}"
    if query:
        url = f"{url}?{urlencode(query)}"

    headers = {
        "Accept": "application/json",
        "X-API-Key": api_key,
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = Request(url, data=data, headers=headers, method=method)
    with urlopen(request) as response:
        return json.loads(response.read().decode("utf-8"))


def build_parser():
    parser = argparse.ArgumentParser(description="Use a self-hosted Mem0 REST service")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("status")

    add = subparsers.add_parser("add")
    add.add_argument("text")
    add.add_argument("--user-id")
    add.add_argument("--agent-id")
    add.add_argument("--run-id")
    add.add_argument("--metadata")

    search = subparsers.add_parser("search")
    search.add_argument("query")
    search.add_argument("--user-id", default="codex")
    search.add_argument("--top-k", type=int)
    search.add_argument("--threshold", type=float)

    list_command = subparsers.add_parser("list")
    list_command.add_argument("--user-id", default="codex")
    list_command.add_argument("--top-k", type=int)

    get = subparsers.add_parser("get")
    get.add_argument("memory_id")

    update = subparsers.add_parser("update")
    update.add_argument("memory_id")
    update.add_argument("text")
    update.add_argument("--metadata")

    delete = subparsers.add_parser("delete")
    delete.add_argument("memory_id")
    return parser


def dispatch(args, base_url, api_key):
    if args.command == "status":
        return request_json(
            base_url,
            api_key,
            "GET",
            "/memories",
            {"user_id": "codex", "top_k": 0},
        )

    if args.command == "add":
        body = {"messages": [{"role": "user", "content": args.text}]}
        if args.user_id:
            body["user_id"] = args.user_id
        if args.agent_id:
            body["agent_id"] = args.agent_id
        if args.run_id:
            body["run_id"] = args.run_id
        if not any((args.user_id, args.agent_id, args.run_id)):
            body["user_id"] = "codex"
        if args.metadata is not None:
            body["metadata"] = parse_metadata(args.metadata)
        return request_json(base_url, api_key, "POST", "/memories", body=body)

    if args.command == "search":
        body = {
            "query": args.query,
            "filters": {"user_id": args.user_id},
        }
        if args.top_k is not None:
            body["top_k"] = args.top_k
        if args.threshold is not None:
            body["threshold"] = args.threshold
        return request_json(base_url, api_key, "POST", "/search", body=body)

    if args.command == "list":
        query = {"user_id": args.user_id}
        if args.top_k is not None:
            query["top_k"] = args.top_k
        return request_json(base_url, api_key, "GET", "/memories", query=query)

    memory_path = f"/memories/{quote(args.memory_id, safe='')}"
    if args.command == "get":
        return request_json(base_url, api_key, "GET", memory_path)
    if args.command == "update":
        body = {"text": args.text}
        if args.metadata is not None:
            body["metadata"] = parse_metadata(args.metadata)
        return request_json(base_url, api_key, "PUT", memory_path, body=body)
    return request_json(base_url, api_key, "DELETE", memory_path)


def http_error_message(error):
    detail = ""
    try:
        payload = json.loads(error.read().decode("utf-8"))
        if isinstance(payload, dict):
            detail = payload.get("detail") or payload.get("message") or ""
    except (json.JSONDecodeError, UnicodeDecodeError):
        pass
    suffix = f": {detail}" if detail else ""
    return f"HTTP {error.code}{suffix}"


def main():
    try:
        args = build_parser().parse_args()
        api_key = os.environ.get("MEM0_API_KEY")
        if not api_key:
            raise ValueError("MEM0_API_KEY is required")
        base_url = os.environ.get("MEM0_BASE_URL", DEFAULT_BASE_URL)
        result = dispatch(args, base_url, api_key)
        json.dump(result, sys.stdout, separators=(",", ":"))
        sys.stdout.write("\n")
        return 0
    except HTTPError as error:
        message = http_error_message(error)
    except URLError as error:
        message = f"request failed: {error.reason}"
    except json.JSONDecodeError:
        message = "response was not valid JSON"
    except ValueError as error:
        message = str(error)
    print(f"mem0: {message}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
