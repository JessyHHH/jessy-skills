# Plan: Phase 9 — Self-Reflection Retrospective

## Goal

Workflow 结束后，自动做反省总结：分析本次会话得失 → 保存长期记忆 → 必要时创建/更新 skill。

## Phase 9: Retrospective & Learn

### 触发
Phase 7 (或 Phase 8) 完成后，始终执行。

### 步骤

1. **会话回顾：** 扫描本次 workflow 的关键事件：
   - Phase 7 失败了几次？什么原因？
   - Phase 6 发现了什么问题？
   - 用户纠正了几次？什么模式？
   - 哪些 skill 被加载了？哪些被遗漏了？

2. **教训提取：**
   - 如果同一错误出现 ≥2 次 → 保存到 memory
   - 如果发现新的工作模式 → 建议创建 skill
   - 如果路由表遗漏 skill → 更新 routing table
   - 如果性能差 → 记录瓶颈

3. **记忆保存：**
   - 用户偏好 → `memory(action='add', target='user', ...)`
   - 项目约定 → `memory(action='add', target='memory', ...)`
   - 工具陷阱 → `memory(action='add', target='memory', ...)`

4. **Skill 建议：**
   - 如果本次完成了一个复杂任务（5+ tool calls）
   - 如果克服了一个棘手错误
   - 如果用户纠正了一个方法然后成功了
   → 建议用户保存为 skill

5. **输出反思报告：**
   ```
   "Phase 9: Retrospective
   - Session: N phases, M tool calls
   - Mistakes fixed: X (pattern saved to memory)
   - Skills loaded: Y (Z new this session)
   - Learnings saved: A memories, B skill suggestions
   - Next time: [concrete improvement]"
   ```

### 文件改动

`skills/project-workflow/SKILL.md` — 新增 Phase 9 section + transition 表更新
