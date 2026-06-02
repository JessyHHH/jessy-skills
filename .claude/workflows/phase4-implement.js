export const meta = {
  name: 'phase4-implement',
  description: 'Parallel implementation via pipeline — one agent per task, quick-verify per task',
  phases: [
    {title: 'Implement', detail: 'Each task implemented by dedicated agent'},
    {title: 'Quick Verify', detail: 'Build + affected tests per task'},
    {title: 'Self-Review', detail: 'Implementer reports DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED'}
  ]
}

// Parse args: {tasks: [{id, prompt, files, complexity, mutatesFiles}]}
const input = typeof args === 'string' ? JSON.parse(args) : args
const tasks = (input.tasks || []).filter(function(t) { return t && t.prompt })
if (tasks.length === 0) return {total: 0, passed: 0, failed: 0, error: 'No valid tasks'}

// Budget-aware: prioritize complex tasks, report remaining tokens
if (typeof budget !== 'undefined' && budget.total) {
  var priority = {complex: 0, medium: 1, simple: 2}
  tasks.sort(function(a, b) {
    return (priority[a.complexity] || 1) - (priority[b.complexity] || 1)
  })
  log('Budget: ' + Math.round(budget.remaining() / 1000) + 'k tokens for ' + tasks.length + ' tasks')
}

phase('Implement')
const results = await pipeline(tasks,
  // Stage 1: Implement each task
  (task, _item, index) => {
    const model = task.complexity === 'simple' ? 'haiku'
      : task.complexity === 'complex' ? 'opus'
      : 'sonnet'
    return agent(task.prompt, {
      label: 'task-' + task.id + ': ' + task.files.join(', '),
      model: model,
      isolation: task.mutatesFiles ? 'worktree' : undefined
    })
  },
  // Stage 2: Quick verify (streams per task, no barrier)
  (result, task) => {
    if (!result) return {id: task.id, status: 'SKIPPED', buildPassed: false, testsPassed: false, errors: ['Agent skipped or failed']}
    return agent(
      'Quick verify these files: ' + task.files.join(', ') + '. Run build and affected tests. Report results.',
      {
        label: 'verify-task-' + task.id,
        phase: 'Quick Verify',
        schema: {
          type: 'object',
          properties: {
            buildPassed: {type: 'boolean'},
            testsPassed: {type: 'boolean'},
            errors: {type: 'array', items: {type: 'string'}}
          },
          required: ['buildPassed', 'testsPassed']
        }
      }
    )
  },
  // Stage 3: Self-Review — implementer reports status before handoff to Phase 5
  function(result, task) {
    // Capture Stage 2 result before Stage 3 transforms output
    var stage2Passed = result && result.buildPassed && result.testsPassed
    if (!result || !result.buildPassed) {
      return {taskId: task.id, status: 'FAILED', stage: 'quick-verify', _stage2Passed: !!stage2Passed}
    }
    return agent(
      'Self-review your implementation of task ' + task.id + ': ' + (task.files || []).join(', ') + '.\n' +
      'Check: all requirements from task prompt met? Edge cases handled? Tests pass? Code matches project patterns? Any concerns?\n\n' +
      'Return status: DONE (confident) | DONE_WITH_CONCERNS (list concerns) | NEEDS_CONTEXT (specify what missing) | BLOCKED (explain why)',
      {
        label: 'self-review-' + task.id,
        phase: 'Self-Review',
        schema: {
          type: 'object',
          required: ['status'],
          properties: {
            status: {type: 'string', enum: ['DONE', 'DONE_WITH_CONCERNS', 'NEEDS_CONTEXT', 'BLOCKED']},
            concerns: {type: 'array', items: {type: 'string'}},
            contextNeeded: {type: 'string'},
            blockReason: {type: 'string'}
          }
        }
      }
    ).then(function(reviewResult) {
      // Merge task.id + Stage 2 result so Phase 5 can map status back to task
      return {
        taskId: task.id,
        status: reviewResult ? reviewResult.status : 'FAILED',
        concerns: reviewResult ? reviewResult.concerns : [],
        contextNeeded: reviewResult ? reviewResult.contextNeeded : '',
        blockReason: reviewResult ? reviewResult.blockReason : '',
        _stage2Passed: stage2Passed
      }
    })
  }
)

// Compute pass/fail from Stage 2 results (captured in _stage2Passed field)
var valid = results.filter(function(r) { return r != null })
var passed = valid.filter(function(r) { return r._stage2Passed }).length
var failed = valid.filter(function(r) { return !r._stage2Passed }).length

var selfReviewStatus = results.filter(function(r) { return r && r.status }).map(function(r) {
  return {taskId: r.taskId, status: r.status, concerns: r.concerns, contextNeeded: r.contextNeeded, blockReason: r.blockReason}
})

return {
  total: tasks.length,
  passed: passed,
  failed: failed,
  selfReviewStatus: selfReviewStatus
}
