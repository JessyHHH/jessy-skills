#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SOURCE="$TMP/home/.codex"
REPO="$TMP/repo"
mkdir -p "$SOURCE/agents" "$REPO/codex/agents"

cat > "$SOURCE/AGENTS.md" <<'EOF'
# Global Codex instructions

Use current documentation.
EOF

cat > "$SOURCE/agents/worker.toml" <<'EOF'
name = "worker"
model = "gpt-test"
EOF

cat > "$SOURCE/config.toml" <<'EOF'
model_provider = "custom"
model = "gpt-test"
model_auto_compact_token_limit = 12345
developer_instructions = """
Keep this multiline value.
Do not lose quoted text: "current".
"""

[model_providers.custom]
name = "Private provider"
base_url = "https://private.example.test"
api_key = "provider-secret-value"

[features]
multi_agent = true

[mcp_servers.postman]
command = "postman-server"
args = ["--stdio"]

[mcp_servers.postman.env]
POSTMAN_API_KEY = "postman-secret-value"
SAFE_MODE = "1"

[mcp_servers.mysql.env]
MYSQL_USER = "root"
MYSQL_PASSWORD = "mysql-secret-value"

[security_shapes]
AWS_SECRET_ACCESS_KEY = "aws-secret-value"
SERVICE_TOKEN = "service-token-value"
DB_PASSWD = "database-passwd-value"
HTTP_AUTH = "http-auth-value"
SECRET_KEY = "secret-key-value"
serviceToken = "camel-service-token-value"
awsSecretAccessKey = "camel-aws-secret-value"
httpAuth = "camel-http-auth-value"

[agents]
max_threads = 4

[plugins."build-web-apps@openai-api-curated"]
enabled = true

[hooks]

[[hooks.SessionStart]]
matcher = ""

[[hooks.SessionStart.hooks]]
type = "command"
command = "echo ready"
EOF

SYNC=(python3 "$ROOT/codex/scripts/sync_from_local.py" --source-dir "$SOURCE" --repo-root "$REPO")
"${SYNC[@]}" >/dev/null

cmp "$SOURCE/AGENTS.md" "$REPO/codex/global/AGENTS.md"
cmp "$SOURCE/agents/worker.toml" "$REPO/codex/agents/worker.toml"
[ "$(stat -c '%a' "$REPO/codex/global/AGENTS.md")" = "644" ]
[ "$(stat -c '%a' "$REPO/codex/global/config.toml")" = "644" ]

python3 - "$REPO/codex/global/config.toml" <<'PY'
import pathlib
import sys
import tomllib

data = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert "model_provider" not in data
assert "model_providers" not in data
assert data["model"] == "gpt-test"
assert data["model_auto_compact_token_limit"] == 12345
assert data["mcp_servers"]["postman"]["env"]["POSTMAN_API_KEY"] == "${POSTMAN_API_KEY}"
assert data["mcp_servers"]["mysql"]["env"]["MYSQL_PASSWORD"] == "${MYSQL_PASSWORD}"
assert data["mcp_servers"]["postman"]["env"]["SAFE_MODE"] == "1"
assert data["security_shapes"]["AWS_SECRET_ACCESS_KEY"] == "${AWS_SECRET_ACCESS_KEY}"
assert data["security_shapes"]["SERVICE_TOKEN"] == "${SERVICE_TOKEN}"
assert data["security_shapes"]["DB_PASSWD"] == "${DB_PASSWD}"
assert data["security_shapes"]["HTTP_AUTH"] == "${HTTP_AUTH}"
assert data["security_shapes"]["SECRET_KEY"] == "${SECRET_KEY}"
assert data["security_shapes"]["serviceToken"] == "${SERVICE_TOKEN}"
assert data["security_shapes"]["awsSecretAccessKey"] == "${AWS_SECRET_ACCESS_KEY}"
assert data["security_shapes"]["httpAuth"] == "${HTTP_AUTH}"
assert data["plugins"]["build-web-apps@openai-api-curated"]["enabled"] is True
assert data["hooks"]["SessionStart"][0]["hooks"][0]["command"] == "echo ready"
PY

if rg -q 'provider-secret-value|postman-secret-value|mysql-secret-value|aws-secret-value|service-token-value|database-passwd-value|http-auth-value|secret-key-value|camel-service-token-value|camel-aws-secret-value|camel-http-auth-value' "$REPO/codex/global/config.toml"; then
    echo "FAIL: generated config contains a source credential" >&2
    exit 1
fi

"${SYNC[@]}" --check >/dev/null
printf '\n# drift\n' >> "$REPO/codex/global/config.toml"
if "${SYNC[@]}" --check >/dev/null 2>&1; then
    echo "FAIL: --check did not detect config drift" >&2
    exit 1
fi

"${SYNC[@]}" >/dev/null
"${SYNC[@]}" --check >/dev/null

cp "$SOURCE/config.toml" "$TMP/config-safe.toml"
cat >> "$SOURCE/config.toml" <<'EOF'

unsafe_endpoint = "https://user:password@example.test"
EOF
if "${SYNC[@]}" >/dev/null 2>&1; then
    echo "FAIL: sync accepted a credential-like value under a non-sensitive key" >&2
    exit 1
fi
mv "$TMP/config-safe.toml" "$SOURCE/config.toml"

cat > "$SOURCE/agents/unsafe.toml" <<'EOF'
name = "unsafe"
serviceToken = "agent-secret-value"
EOF
if "${SYNC[@]}" >/dev/null 2>&1; then
    echo "FAIL: sync accepted a credential-bearing agent TOML" >&2
    exit 1
fi
rm "$SOURCE/agents/unsafe.toml"

OUTSIDE="$TMP/outside-agents.md"
cp "$SOURCE/AGENTS.md" "$OUTSIDE"
chmod 600 "$OUTSIDE"
rm "$REPO/codex/global/AGENTS.md"
ln -s "$OUTSIDE" "$REPO/codex/global/AGENTS.md"
if "${SYNC[@]}" >/dev/null 2>&1; then
    echo "FAIL: sync accepted a symlinked repository target" >&2
    exit 1
fi
[ "$(stat -c '%a' "$OUTSIDE")" = "600" ]
rm "$REPO/codex/global/AGENTS.md"
"${SYNC[@]}" >/dev/null

cat >> "$SOURCE/config.toml" <<'EOF'

not_a_number = nan
EOF
if "${SYNC[@]}" >/dev/null 2>&1; then
    echo "FAIL: sync accepted a non-finite float" >&2
    exit 1
fi

echo "PASS: local Codex snapshot sync"
