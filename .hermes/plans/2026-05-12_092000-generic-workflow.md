# Plan: 工作流通用化 + 前端技能集成

## Goal

golang-workflow → project-workflow（通用），按项目类型自动路由 skill，集成 vuejs-ai/skills 前端技能。

## 目录重构

```
skills/
├── go/                    ← 原 golang-* 移入
│   ├── golang-concurrency/
│   ├── golang-testing/
│   └── ... (30+)
├── vue/                   ← 新增，clone from vuejs-ai/skills
│   └── (vue/nuxt/pinia/vitest/...)
├── project-workflow/      ← golang-workflow 改名，通用化
├── karpathy-guidelines/
├── deep-interview/
├── ralplan/
├── ralph/
├── ultrawork/
├── analyze/
└── code-review/
```

## 改动清单

### 1. Clone vuejs-ai/skills → skills/vue/
```bash
git clone --depth 1 https://github.com/vuejs-ai/skills.git /tmp/vue-skills
cp -r /tmp/vue-skills/* skills/vue/
```

### 2. 迁移 Go 技能 → skills/go/
```bash
mv skills/golang-* skills/go/
```

### 3. golang-workflow → project-workflow
- 改名：`name: project-workflow`
- 描述：`"Generic self-driving workflow: project type detection → skill routing → ..."`
- Phase 0 增强：检测 Go/Node/Vue 项目类型
- Phase 0.5 路由表新增：项目类型 → 技能目录
  - Go 项目 → 加载 skills/go/ 下的匹配 skill
  - Vue 项目 → 加载 skills/vue/ 下的匹配 skill
- Phase 7 条件验证：
  - Go → `go build ./... && go vet && go test -race`
  - Node → `npm test`
  - Vue → `npx vitest run`

### 4. 更新 shell wrapper
- `AUTO_SKILLS` 从 `golang-workflow,karpathy-guidelines` → `project-workflow,karpathy-guidelines`
- `shell/hermes.sh` 同步

### 5. 更新 install.sh
- 目录结构适配

### 6. 更新 README.md

## 风险

- skill 内部引用 `golang-workflow` 名称的需批量替换
- vue 技能可能有命名冲突
- shell wrapper 更新后需 source ~/.bashrc
- 用户现有 memory 引用的 golang-workflow 名称需更新

## 验证

- `ls skills/go/` 确认 Go 技能齐全
- `ls skills/vue/` 确认 Vue 技能已克隆
- `grep "golang-workflow" skills/` 确认无残留引用
- project-workflow SKILL.md 结构完整
