# Testing Workflow Skill Changes

## How to test a modified project-workflow SKILL.md

### Method 1: `-z` one-shot (recommended)

Use hermes `-z` with explicit phase instructions to skip earlier phases:

```bash
cd /tmp/test-go-project
hermes -z "Phase 0 and Phase 1 are already complete. Phase 1 findings: [list signals].
Execute Phase 1.5: re-scan and load missing skills." \
  -s project-workflow,karpathy-guidelines -m deepseek-v4-pro --provider deepseek
```

This works because the model reads the skill's phase instructions and executes the specified phase directly.

### Method 2: PTY interactive (NOT recommended)

Starting `hermes chat` with PTY + `process submit` fails because:
- Phase 1 `clarify()` times out after 120s with no real user
- Agent loops on the same question
- Use only for full end-to-end validation with a real human

### Test project setup

Create a minimal project in `/tmp/test-go-project/`:
```bash
mkdir -p /tmp/test-go-project/.hermes/plans
cat > /tmp/test-go-project/go.mod << 'EOF'
module test-project
go 1.25.3
require (
    github.com/stretchr/testify v1.9.0
    google.golang.org/grpc v1.68.0
)
EOF
```

For Phase 2 post-plan check tests, write a mock plan with technical signals:
```bash
cat > /tmp/test-go-project/.hermes/plans/plan.md << 'EOF'
# Plan: Fix Cache
Use sync.RWMutex for protection. Add prometheus metrics.
Wrap errors with fmt.Errorf. Use testify mock.
TLS for gRPC streams.
EOF
```

### Verification

Check that the correct skills are loaded:
- Phase 1.5: should load skills from deep interview findings
- Phase 2 post-plan check: should load skills from plan technical signals
- Both: should skip already-loaded skills (no duplicate `skill_view` calls)
