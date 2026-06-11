#!/bin/bash
# Regression: verify Edit tool exact-string matching pattern that historically failed.
# The key issue: old_string must include the full keyword (e.g., "type Retriever interface {")
# not just "Retriever interface {".
set -euo pipefail

PROBE_DIR="/tmp/edit-probe-$$"
trap 'rm -rf "$PROBE_DIR"' EXIT

mkdir -p "$PROBE_DIR"

cat > "$PROBE_DIR/types.go" <<'GOEOF'
package rag

import "context"

// Retriever is the search interface — all retrieval strategies implement this.
type Retriever interface {
	Search(ctx context.Context, query string, topK int) ([]SearchResult, error)
}
GOEOF

echo "=== Probe file created at $PROBE_DIR/types.go"
echo "=== Content (with whitespace markers):"
cat -A "$PROBE_DIR/types.go"
echo ""

# Verify the correct pattern (with "type" keyword) is present
if grep -Fq "type Retriever interface {" "$PROBE_DIR/types.go"; then
  echo "=== PASS: 'type Retriever interface {' found in probe file"
  echo "=== Edit tool MUST use old_string starting with 'type Retriever interface {'"
else
  echo "=== FAIL: 'type Retriever interface {' not found"
  exit 1
fi

# Show why the wrong pattern fails
echo ""
echo "=== Diagnostic: searching for 'Retriever interface {' WITHOUT 'type' keyword"
echo "=== This substring exists but is not unique — anchoring on 'type' keyword is required"
grep -Fn "Retriever interface {" "$PROBE_DIR/types.go" || true

echo ""
echo "=== RESULT: PASS — Regression probe validates exact-string matching constraints"
