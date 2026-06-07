# Skill Routing：Codex 和 Claude Code 如何共用 Skills

## 目标

Codex 生成 contract 时，不只要告诉 Claude Code 做什么，还要告诉它：

```text
这次任务建议使用哪些 skills
为什么需要这些 skills
哪些 skills 是必须的
Claude Review Gate 是否需要调整 skill routing
```

## 共享 skills 根目录

项目里的共同来源应该是：

```text
skills/
```

Codex 使用：

```text
.agents/skills -> ../skills
```

Claude Code 使用：

```text
~/.claude/skills/<skill> -> <repo>/skills/<skill>
```

这样两边看到的是同一套 skill 内容。

## Codex Planner Skills

Codex 在 Phase 0-3 主要用 planner skills：

```text
project-workflow-codex
  主流程：发现、澄清、contract、preflight、replan、audit

karpathy-guidelines
  简洁、手术式、目标驱动、新鲜证据

prior-research
  涉及库、SDK、CLI、API、云服务时，先查当前文档

skill-creator
  创建或更新 Codex skill 时使用
```

根据任务类型再加载：

```text
golang-testing / golang-security / golang-database
vue-best-practices / vue-testing-best-practices
frontend-design / webapp-testing
code-review / diagnose / tdd
```

## Recommended Claude Code Skills

contract 里应该写清楚 Claude Code 执行阶段建议加载：

```text
project-workflow-claude
  required: true
  reason: 接管 Review Gate 和 Phase 4-6

karpathy-guidelines
  required: true
  reason: 执行和 review 纪律

domain skills
  required: depends
  reason: 和任务涉及文件相关
```

例如：

```text
Vue 任务:
  vue-best-practices
  vue-testing-best-practices

Go 数据库任务:
  golang-database
  golang-testing
  golang-error-handling

文档/skill 任务:
  skill-creator
  karpathy-guidelines
```

## Contract 里的 Skill Routing 区块

建议格式：

```markdown
## Skill Routing

### Codex Planner Skills Used
- `project-workflow-codex`
  - required: true
  - reason: Generate and validate Cross-Agent Plan Contract.

### Recommended Claude Code Skills
- `project-workflow-claude`
  - required: true
  - reason: Run Claude Review Gate and Phase 4-6.
- `karpathy-guidelines`
  - required: true
  - reason: Keep execution surgical and evidence-based.

### Claude Review Gate Skill Check
Claude Code must verify:
1. recommended skills match the actual task
2. missing required skills are reported
3. unnecessary skills are not loaded blindly
4. skill routing changes are returned as Review Gate findings
```

## Task-Level Skills

每个 task 也可以加：

```json
{
  "id": "T1",
  "prompt": "Update Vue component tests.",
  "files": ["src/components/Foo.vue", "src/components/Foo.spec.ts"],
  "recommendedSkills": ["vue-best-practices", "vue-testing-best-practices"],
  "verification": ["npm test"]
}
```

task-level skills 的作用是让 Claude Code 的 subagent 更容易拿到正确上下文。

## Claude Review Gate 如何检查 skill routing

Claude Review Gate 必须回答：

```text
推荐 skills 是否足够？
有没有缺少的 domain skill？
有没有不必要的 skill？
task-level recommendedSkills 是否合理？
如果修改 skill routing，会不会改变 contract 范围？
```

如果 Claude 建议修改 skill routing，Codex 在 Phase 3.5 判断是否采纳。
