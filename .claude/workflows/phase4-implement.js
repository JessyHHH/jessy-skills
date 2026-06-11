export const meta = {
  name: 'phase4-implement',
  description: 'Parallel implementation via pipeline — one agent per task, quick-verify per task',
  phases: [
    {title: 'Implement', detail: 'Each task implemented by dedicated agent'},
    {title: 'Quick Verify', detail: 'Build + affected tests per task'},
    {title: 'Self-Review', detail: 'Implementer reports DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED'}
  ]
}

// Parse args with expanded task fields from Phase 2/3:
// {tasks: [{id, prompt, files, complexity, mutatesFiles, contextRefs, intakeRefs,
//   grillRefs, expectedEvidence, forbiddenEvidence, patchBackStrategy}]}
const input = typeof args === 'string' ? JSON.parse(args) : args
const tasks = (input.tasks || []).filter(function(t) { return t && t.prompt })
if (tasks.length === 0) return {total: 0, passed: 0, failed: 0, error: 'No valid tasks'}

// --- 1. Extend task schema parsing: default expanded fields if missing ---
for (var i = 0; i < tasks.length; i++) {
  var t = tasks[i]
  t.contextRefs = t.contextRefs || []
  t.intakeRefs = t.intakeRefs || {}
  t.grillRefs = t.grillRefs || []
  t.expectedEvidence = t.expectedEvidence || ''
  t.forbiddenEvidence = t.forbiddenEvidence || ''
  t.patchBackStrategy = t.patchBackStrategy || ''
  t.mutatesFiles = !!t.mutatesFiles
  t.fileContents = t.fileContents || {}
  t.diffText = t.diffText || ''
  t.grillDecisions = t.grillDecisions || []
  t.planSections = t.planSections || ''
}

// --- 2. Pre-pipeline validation: mutating tasks must declare patchBackStrategy ---
for (var j = 0; j < tasks.length; j++) {
  var task = tasks[j]
  if (task.mutatesFiles && !task.patchBackStrategy) {
    return {status: 'BLOCKED', reason: 'mutating task ' + task.id + ' missing patchBackStrategy'}
  }
  if (task.patchBackStrategy && ['no-isolation', 'harness-managed', 'external-report'].indexOf(task.patchBackStrategy) === -1) {
    return {status: 'BLOCKED', reason: 'task ' + task.id + ' has invalid patchBackStrategy: ' + task.patchBackStrategy}
  }
}

// Budget-aware: prioritize complex tasks, report remaining tokens
if (typeof budget !== 'undefined' && budget.total) {
  var priority = {complex: 0, medium: 1, simple: 2}
  tasks.sort(function(a, b) {
    return (priority[a.complexity] || 1) - (priority[b.complexity] || 1)
  })
  log('Budget: ' + Math.round(budget.remaining() / 1000) + 'k tokens for ' + tasks.length + ' tasks')
}

// --- 5. Closure: thread changedFiles from Stage 1 through Stage 2/3 ---
var taskChangedFiles = {}

// --- 3 & 4. Strategy-aware isolation + Enhanced implementer prompt builder ---
function getIsolation(task) {
  if (task.patchBackStrategy === 'harness-managed') return 'worktree'
  // no-isolation and external-report do not use worktree isolation
  return undefined
}

function buildImplementerPrompt(task) {
  var parts = [task.prompt]

  // Context files
  if (task.contextRefs && task.contextRefs.length > 0) {
    parts.push('\nConsider these context files: ' + JSON.stringify(task.contextRefs))
  }

  // Scope: intake refs
  if (task.intakeRefs) {
    if (task.intakeRefs.approvedInScope) {
      parts.push('\nIn scope: ' + JSON.stringify(task.intakeRefs.approvedInScope))
    }
    if (task.intakeRefs.approvedOutOfScope) {
      parts.push('Out of scope: ' + JSON.stringify(task.intakeRefs.approvedOutOfScope))
    }
  }

  // Grill decisions
  if (task.grillRefs && task.grillRefs.length > 0) {
    parts.push('\nRelevant decisions: ' + JSON.stringify(task.grillRefs))
  }

  // Evidence contract
  if (task.expectedEvidence) {
    parts.push('\nExpected evidence: ' + task.expectedEvidence)
  }
  if (task.forbiddenEvidence) {
    parts.push('Forbidden evidence: ' + task.forbiddenEvidence)
  }

  // Isolation strategy instructions
  if (task.patchBackStrategy) {
    parts.push('\nIsolation strategy: ' + task.patchBackStrategy)
    if (task.patchBackStrategy === 'no-isolation') {
      parts.push('Work directly in the main working tree. Report changed files.')
    } else if (task.patchBackStrategy === 'harness-managed') {
      parts.push('You are in an isolated worktree. Return changedFiles: [list of file paths you modified]. The harness manages the worktree lifecycle. Do not attempt to merge or apply patches.')
    } else if (task.patchBackStrategy === 'external-report') {
      parts.push('Return a description of changes made. The harness will treat this as an external report. Include changedFiles in your response.')
    }
  }

  // --- Enrichment: file contents, diff, grill decisions, plan sections ---
  var fcKeys = Object.keys(task.fileContents || {})
  if (fcKeys.length > 0) {
    parts.push('\n## Current File Contents (captured at Workflow invocation — may be stale if a prior task modified this file)\n')
    for (var i = 0; i < fcKeys.length; i++) {
      var k = fcKeys[i]
      parts.push('### ' + k + '\n```\n' + (task.fileContents[k] || '') + '\n```\n')
    }
  }
  if (task.diffText) {
    parts.push('\n## Git Diff (changed lines)\n```diff\n' + task.diffText + '\n```\n')
  }
  if (task.grillDecisions && task.grillDecisions.length > 0) {
    parts.push('\n## Design Decisions (from Grill)\n')
    for (var j = 0; j < task.grillDecisions.length; j++) {
      parts.push('- ' + task.grillDecisions[j] + '\n')
    }
  }
  if (task.planSections) {
    parts.push('\n## Task Section from Implementation Plan\n' + task.planSections + '\n')
  }

  parts.push('\n**IMPORTANT:** These file contents were captured before task execution began. Always Read the target file fresh immediately before calling Edit to get the current exact content. Do NOT rely solely on the injected file contents for Edit old_string construction.')

  return parts.join('\n')
}

phase('Implement')
const results = await pipeline(tasks,
  // Stage 1: Implement each task with enhanced prompt and strategy-driven isolation
  function(task, _item, index) {
    var model = task.complexity === 'simple' ? 'haiku' : 'sonnet'

    var enhancedPrompt = buildImplementerPrompt(task)

    return agent(enhancedPrompt, {
      label: 'task-' + task.id + ': ' + (task.files || []).join(', '),
      model: model,
      isolation: getIsolation(task),
      schema: {
        type: 'object',
        properties: {
          changedFiles: {type: 'array', items: {type: 'string'}},
          expectedEvidenceObserved: {type: 'array', items: {type: 'string'}},
          forbiddenEvidenceObserved: {type: 'array', items: {type: 'string'}},
          summary: {type: 'string'}
        }
      }
    }).then(function(implResult) {
      // Thread changedFiles into closure for Stage 2/3 access
      taskChangedFiles[task.id] = (implResult && implResult.changedFiles) ? implResult.changedFiles : []
      return implResult
    })
  },
  // Stage 2: Quick verify (streams per task, no barrier)
  function(result, task) {
    if (!result) return {id: task.id, status: 'SKIPPED', buildPassed: false, testsPassed: false, errors: ['Agent skipped or failed']}
    return agent(
      'Quick verify these files: ' + (task.files || []).join(', ') + '. Run build and affected tests. Report results.',
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
  // Stage 3: Self-Review with full result contract
  function(result, task) {
    var stage2Passed = result && result.buildPassed && result.testsPassed

    // --- 6. External-report tasks: always DONE_WITH_CONCERNS ---
    if (task.patchBackStrategy === 'external-report') {
      return {
        taskId: task.id,
        status: 'DONE_WITH_CONCERNS',
        concerns: ['External report task — manual review required'],
        contextNeeded: '',
        blockReason: '',
        _stage2Passed: stage2Passed,
        changedFiles: taskChangedFiles[task.id] || [],
        expectedEvidenceObserved: [],
        forbiddenEvidenceObserved: [],
        patchBackStatus: 'external-report:pending-review'
      }
    }

    // Stage 2 failure: short-circuit with FAILED
    if (!result || !result.buildPassed) {
      return {
        taskId: task.id,
        status: 'FAILED',
        stage: 'quick-verify',
        _stage2Passed: !!stage2Passed,
        changedFiles: taskChangedFiles[task.id] || [],
        expectedEvidenceObserved: [],
        forbiddenEvidenceObserved: [],
        patchBackStatus: task.patchBackStrategy ? task.patchBackStrategy + ':pending-review' : ''
      }
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
            blockReason: {type: 'string'},
            expectedEvidenceObserved: {type: 'array', items: {type: 'string'}},
            forbiddenEvidenceObserved: {type: 'array', items: {type: 'string'}}
          }
        }
      }
    ).then(function(reviewResult) {
      // Build patchBackStatus from strategy + disposition
      var patchBackStatusValue = ''
      if (task.patchBackStrategy === 'harness-managed') {
        patchBackStatusValue = 'harness-managed:applied'
      } else if (task.patchBackStrategy === 'no-isolation') {
        patchBackStatusValue = 'no-isolation:applied'
      }

      // --- 7. Phase 4 result contract ---
      return {
        taskId: task.id,
        status: reviewResult ? reviewResult.status : 'FAILED',
        concerns: reviewResult ? reviewResult.concerns : [],
        contextNeeded: reviewResult ? reviewResult.contextNeeded : '',
        blockReason: reviewResult ? reviewResult.blockReason : '',
        _stage2Passed: stage2Passed,
        changedFiles: taskChangedFiles[task.id] || [],
        expectedEvidenceObserved: (reviewResult && reviewResult.expectedEvidenceObserved) ? reviewResult.expectedEvidenceObserved : [],
        forbiddenEvidenceObserved: (reviewResult && reviewResult.forbiddenEvidenceObserved) ? reviewResult.forbiddenEvidenceObserved : [],
        patchBackStatus: patchBackStatusValue
      }
    })
  }
)

// Compute pass/fail from Stage 2 results (captured in _stage2Passed field)
var valid = results.filter(function(r) { return r != null })
var passed = valid.filter(function(r) { return r._stage2Passed }).length
var failed = valid.filter(function(r) { return !r._stage2Passed }).length

// --- 7. Phase 4 result contract in selfReviewStatus ---
var selfReviewStatus = results.filter(function(r) { return r && r.status }).map(function(r) {
  return {
    taskId: r.taskId,
    status: r.status,
    concerns: r.concerns,
    contextNeeded: r.contextNeeded,
    blockReason: r.blockReason,
    changedFiles: r.changedFiles || [],
    expectedEvidenceObserved: r.expectedEvidenceObserved || [],
    forbiddenEvidenceObserved: r.forbiddenEvidenceObserved || [],
    patchBackStatus: r.patchBackStatus || ''
  }
})

return {
  total: tasks.length,
  passed: passed,
  failed: failed,
  selfReviewStatus: selfReviewStatus
}
