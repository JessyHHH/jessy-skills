# Testing the Workflow Itself

How to verify workflow skill changes (Phase additions, routing tables, rule changes) without waiting for a real interactive session.

## Pattern 1: One-shot phase testing (`hermes -z`)

Use `-z` for targeted phase verification. Tell the workflow which phases are "done" and what to execute:

```bash
cd /tmp/test-go-project
hermes -z "Phase 0, 0.5, 1, 1.5 are complete. Phase 1 found:
concurrent goroutine safety, thorough unit test coverage.
Execute Phase 1.5: re-scan and load missing skills." \
  -s project-workflow,karpathy-guidelines \
  -m deepseek-v4-pro --provider deepseek
```

This works because the workflow reads the prompt as "prior phase output" and applies the current phase logic.

## Pattern 2: Mock plan for Phase 2 post-plan testing

Create a plan file with technical signals, then tell the workflow to scan it:

```bash
mkdir -p /tmp/test-project/.hermes/plans
cat > /tmp/test-project/.hermes/plans/test-plan.md << 'EOF'
# Plan: Fix Concurrent Cache Panic
## Approach
- Use sync.RWMutex to protect the cache map
- Add prometheus metrics for cache hit/miss rate
EOF

hermes -z "Phase 0-2 complete. Plan at .hermes/plans/test-plan.md.
Execute Phase 2 post-plan check: scan plan, load missing skills." \
  -s project-workflow,karpathy-guidelines
```

## Pattern 3: Test project setup

Minimal Go project for skill testing:

```bash
mkdir -p /tmp/test-go-project
cat > /tmp/test-go-project/go.mod << 'EOF'
module test-project
go 1.25.3
require (
    github.com/stretchr/testify v1.9.0
    google.golang.org/grpc v1.68.0
)
EOF
cat > /tmp/test-go-project/main.go << 'EOF'
package main
import "fmt"
func main() { fmt.Println("test") }
EOF
```

## Pattern 4: PTY interactive testing (for clarify()-dependent phases)

When testing phases that require `clarify()` (Phase 1 deep interview), PTY mode is needed:

```bash
# Start in background with PTY
terminal(command="cd /tmp/test-project && hermes chat -s project-workflow,karpathy-guidelines",
         background=true, pty=true)

# Wait for startup (watch for "❯" prompt), then submit
process(action="submit", data="修复这个并发panic的bug", session_id="proc_xxx")

# Monitor output for phase announcements
process(action="log", session_id="proc_xxx")
```

**Pitfall:** `clarify()` times out after 120s with no user response. PTY testing is best for observing Phase 0-0.5 behavior, not interactive interview phases.

## Pattern 5: Cross-domain Rule #5 testing

Verify "Verify Before Asserting" triggers web_search for any domain:

```bash
# K8s (version-specific detail)
hermes -z "Kubernetes 1.34 SidecarContainers config?" -s project-workflow,karpathy-guidelines

# Node.js (experimental feature)
hermes -z "Node.js 24 --experimental-strip-types syntax support?" -s project-workflow,karpathy-guidelines

# Obscure Go library (version-specific)
hermes -z "miniredis v2 FUNCTION LOAD support?" -s project-workflow,karpathy-guidelines
```

Key evidence of web_search: version numbers, issue references, README quotes that training data couldn't have.

## Pattern 6: Meta-workflow editing

When modifying the workflow skill itself, use the workflow's own pipeline:

```
Phase 0: detect this is jessy-skills (not Go project) → skip Go phases
Phase 1: deep interview → clarify scope
Phase 2: write plan → .hermes/plans/
Phase 3: present for user approval → wait for "确认"/"执行"
Phase 5: implement → patch SKILL.md with exact string matching
Phase 6: review → read modified sections, verify structure
Phase 7: N/A for markdown-only changes
```

Use `skill_manage(action='patch')` with exact `old_string`/`new_string` matching. Never rewrite entire SKILL.md — surgical patches preserve git history.
