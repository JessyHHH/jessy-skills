# Claude Code Platform Routing Overlay

Claude Code-specific task signal → action mapping. Used by Phase 0.5 alongside the shared base layer (`project-workflow/references/full-skill-routing.md`).

**Conflict resolution:** Overlay takes precedence over base layer. Deduplicate by skill name (Phase 0.5 has "Skip already-loaded skills" guard).

## Task Signal → Action Routing

| Signal | Action |
|--------|--------|
| 实现, implement, 写代码, build | → Phase 4: `Skill(skill='implementing-changes')` (Master-driven Agent() serial dispatch) |
| 审阅, review, 检查代码, code review | → Phase 5: `Skill(skill='reviewing-implementation')` (Master-driven Agent() spec→code→adversarial) |
| 验证, verify, 测试, test, check | → Phase 6: `Skill(skill='verifying-completion')` (Master-driven Bash + Agent fix, loop-until-dry) |
| 文档, docs, API reference, library | → Context7 MCP (优先) / WebFetch (fallback) |
| 搜索, search, research, 调研 | → Firecrawl MCP (优先) / WebSearch (fallback) |
| Grill, 设计, design, brainstorm | → Phase 1 Grill protocol + brainstorming-ideas skill |
| 计划, plan, 规划, schedule | → Phase 2 (write plan) + Phase 3 (consensus review) |
| 提交, commit, PR, push, 合并 | → Phase 8 (finish branch) |
| 回顾, retrospective, learn, 总结 | → Phase 7 (retrospective + memory compression) |

## Codebase Signal → Skill Routing

These supplement the shared base layer. Match Go package imports from go.mod / package.json:

| Codebase Signal | Skill |
|----------------|-------|
| samber/lo | golang-samber-lo |
| samber/mo | golang-samber-mo |
| samber/do | golang-samber-do |
| samber/oops | golang-samber-oops |
| samber/ro | golang-samber-ro |
| samber/slog | golang-samber-slog |
| samber/hot | golang-samber-hot |
