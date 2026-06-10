# Verification Commands per Project Type

## Go

```bash
# 1. Clean go.sum
go mod tidy

# 2. Build all packages — must exit 0
go build ./...

# 3. Run go vet — no warnings
go vet ./...

# 4. Run all tests with race detector — ALL PASS
go test -race -count=1 ./...

# 5. Vulnerability scan
go run golang.org/x/vuln/cmd/govulncheck@latest ./...

# 6. Lint check — 0 warnings
golangci-lint run ./...
```

Collect results as:

```json
{"name": "go build", "command": "go build ./...", "exitCode": 0, "stdout": "...", "stderr": ""}
```

## Vue / Node

```bash
# 1. Clean install
npm ci
# Or: pnpm install

# 2. Type check (if TypeScript)
npx tsc --noEmit

# 3. Run tests — ALL PASS
npm test

# 4. Lint check — 0 warnings
npm run lint
```

Collect results in the same `{name, command, exitCode, stdout, stderr}` format.

## Skills Repository

### Modular Structure Checks

```bash
for skill in project-workflow-claude detecting-environment designing-solutions planning-implementation implementing-changes reviewing-implementation verifying-completion finishing-development; do
  test -f "skills/$skill/SKILL.md"
  grep -q "^name: $skill" "skills/$skill/SKILL.md"
  grep -q "^description:" "skills/$skill/SKILL.md"
done
```

### Orchestrator Markers

```bash
grep -q "Modular Skill Orchestrator" skills/project-workflow-claude/SKILL.md
grep -q "Skill(skill='detecting-environment')" skills/project-workflow-claude/SKILL.md
```

### Frontmatter Spot-Check

```bash
head -15 skills/*/SKILL.md | head -30
```

### Unresolved Issues Check

```bash
grep -rn "TODO\|FIXME" skills/
```

### Whitespace Check

```bash
git diff --check
```

### Reference Integrity

```bash
for ref in $(grep -oE 'references/[a-z0-9-]+\.md' skills/project-workflow-claude/SKILL.md); do
  test -f "skills/project-workflow-claude/$ref" && echo "checkmark $ref" || echo "cross ref not found: $ref"
done
```

## Project Type Tokens

Normalized tokens passed to `Workflow(name='phase6-verify')`:

- `go` — Go projects
- `vue` — Vue.js projects
- `node` — Node.js / JavaScript projects
- `skills-repo` — Skills Repository projects
