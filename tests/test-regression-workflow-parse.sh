#!/bin/bash
# Regression: verify all workflow scripts are plain valid JavaScript
# This catches TS syntax leaks into executable .js files.
set -euo pipefail

FAILED=0

# Check project workflows
echo "=== Checking project .claude/workflows/*.js ==="
for f in .claude/workflows/*.js; do
  echo "--- node --check $f"
  if ! node --check "$f"; then
    echo "FAIL: $f is not valid JavaScript"
    FAILED=1
  fi
done

# Check global workflows (if accessible)
if [ -d "$HOME/.claude/workflows" ]; then
  echo "=== Checking global ~/.claude/workflows/*.js ==="
  for f in "$HOME"/.claude/workflows/*.js; do
    [ -f "$f" ] || continue
    echo "--- node --check $f"
    if ! node --check "$f" 2>/dev/null; then
      echo "FAIL: $f is not valid JavaScript"
      FAILED=1
    fi
  done
fi

echo ""
echo "=== Checking for ES2022+ features (may cause Workflow parser issues) ==="
ES2022_FOUND=0
for f in .claude/workflows/*.js; do
  # Check for optional chaining, nullish coalescing in non-trivial positions, private class fields, top-level await
  if grep -nE '\?\.|#\w+\s*=' "$f" 2>/dev/null; then
    echo "NOTE: $f contains ES2020+ syntax (e.g. optional chaining ?.) — verify Workflow parser accepts it"
    ES2022_FOUND=1
  fi
done
if [ "$ES2022_FOUND" -eq 0 ]; then
  echo "No ES2022+ edge-case features detected"
fi
echo "NOTE: node --check passing does not guarantee Workflow parser compatibility."
echo "Final verification requires Workflow() dry-run with the actual script."
echo ""
if [ "$FAILED" -eq 1 ]; then
  echo "=== RESULT: FAIL — one or more workflow scripts contain invalid JS"
  exit 1
fi

echo "=== RESULT: PASS — all workflow scripts are valid JavaScript"
