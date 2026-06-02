export const meta = {
  name: 'phase5-review',
  description: 'Per-task review pipeline: spec compliance → parallel code quality → adversarial verify → final review',
  phases: [
    {title: 'Spec Review', detail: 'Verify each task matches plan (gated per task)'},
    {title: 'Code Review', detail: 'Parallel correctness, safety, simplicity per task'},
    {title: 'Adversarial Verify', detail: '3 skeptics try to refute CRITICAL findings'},
    {title: 'Final Review', detail: 'Overall cross-task consistency check'}
  ]
}

var input = typeof args === 'string' ? JSON.parse(args) : args
var planPath = input.planPath || ''
var changedFiles = input.changedFiles || []
var tasks = input.tasks || []
var selfReviewStatuses = input.selfReviewStatuses || []

if (changedFiles.length === 0 && tasks.length === 0) {
  return {stage: 'spec', passed: false, issues: ['No changed files or tasks'], findings: [], criticalCount: 0, highCount: 0}
}

// Build self-review lookup: taskId → status
var selfReviewMap = {}
for (var i = 0; i < selfReviewStatuses.length; i++) {
  var s = selfReviewStatuses[i]
  if (s && s.taskId) selfReviewMap[s.taskId] = s
}

var REVIEW_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'file', 'description'],
        properties: {
          severity: {type: 'string', enum: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']},
          file: {type: 'string'},
          line: {type: 'number'},
          description: {type: 'string'}
        }
      }
    }
  }
}

var SPEC_SCHEMA = {
  type: 'object',
  required: ['verdict', 'issues'],
  properties: {
    verdict: {type: 'string', enum: ['APPROVED', 'REJECTED']},
    issues: {type: 'array', items: {type: 'string'}},
    summary: {type: 'string'}
  }
}

var SKEPTIC_SCHEMA = {
  type: 'object',
  required: ['refuted'],
  properties: {
    refuted: {type: 'boolean'},
    reason: {type: 'string'}
  }
}

// ===== Per-Task Pipeline =====
var allFindings = []
var specFailed = []

phase('Spec Review')
var specResults = await pipeline(tasks,
  // Stage 1: Spec Compliance Review (GATED per task)
  function(task) {
    var selfReview = selfReviewMap[task.id]
    var concernNote = ''
    if (selfReview) {
      if (selfReview.status === 'FAILED' || selfReview.status === 'BLOCKED') {
        specFailed.push({taskId: task.id, issues: ['Self-review: ' + selfReview.status], selfReview: selfReview})
        return {verdict: 'REJECTED', issues: ['Task ' + task.id + ' self-review status: ' + selfReview.status]}
      }
      if (selfReview.status === 'NEEDS_CONTEXT') {
        specFailed.push({taskId: task.id, issues: ['Needs context: ' + (selfReview.contextNeeded || 'unspecified')], selfReview: selfReview})
        return {verdict: 'REJECTED', issues: ['NEEDS_CONTEXT: ' + (selfReview.contextNeeded || 'unspecified')]}
      }
      if (selfReview.status === 'DONE_WITH_CONCERNS' && selfReview.concerns && selfReview.concerns.length > 0) {
        concernNote = '\n\nSELF-REVIEW CONCERNS (implementer flagged these):\n' + selfReview.concerns.map(function(c) { return '- ' + c }).join('\n')
      }
    }
    return agent(
      'Spec compliance review for task ' + task.id + ' (' + (task.files || []).join(', ') + ').\n' +
      'The implementation plan is at: ' + planPath + ' — Read this file to understand the full plan.\n' +
      'Task requirement: ' + (task.prompt || '') + '\n' +
      'Check: does the implementation match the task spec exactly? Nothing extra? Nothing missing?' +
      concernNote + '\n\n' +
      'Return APPROVED or REJECTED with specific issues.',
      {label: 'spec-task-' + task.id, schema: SPEC_SCHEMA}
    )
  },
  // Stage 2: Code Quality Review (only if spec APPROVED)
  function(specResult, task) {
    if (!specResult || specResult.verdict !== 'APPROVED') {
      if (specResult && specResult.verdict === 'REJECTED') {
        specFailed.push({taskId: task.id, issues: specResult.issues})
      }
      return null
    }
    return parallel([
      function() {
        return agent('Review CORRECTNESS: ' + (task.files || []).join(', ') + '\nLogic errors, edge cases, error handling, concurrency safety. Flag CRITICAL/HIGH/MEDIUM/LOW.',
          {label: 'correctness-' + task.id, phase: 'Code Review', schema: REVIEW_SCHEMA})
      },
      function() {
        return agent('Review SAFETY: ' + (task.files || []).join(', ') + '\nNil/null panics, resource leaks, security, data races. Flag CRITICAL/HIGH/MEDIUM/LOW.',
          {label: 'safety-' + task.id, phase: 'Code Review', schema: REVIEW_SCHEMA})
      },
      function() {
        return agent('Review SIMPLICITY: ' + (task.files || []).join(', ') + '\nOver-engineering, dead code, style, Karpathy compliance. Flag CRITICAL/HIGH/MEDIUM/LOW.',
          {label: 'simplicity-' + task.id, phase: 'Code Review', schema: REVIEW_SCHEMA})
      }
    ])
  }
)

// Collect all findings from pipeline results
for (var i = 0; i < specResults.length; i++) {
  var result = specResults[i]
  if (result && Array.isArray(result)) {
    for (var j = 0; j < result.length; j++) {
      if (result[j] && result[j].findings) allFindings = allFindings.concat(result[j].findings)
    }
  } else if (result && result.findings) {
    allFindings = allFindings.concat(result.findings)
  }
}

// ===== Adversarial Verification for CRITICAL findings =====
var criticalFindings = allFindings.filter(function(f) { return f.severity === 'CRITICAL' })
var verifiedCritical = []

if (criticalFindings.length > 0) {
  log('Adversarially verifying ' + criticalFindings.length + ' CRITICAL findings (3 skeptics each)')
  phase('Adversarial Verify')

  for (var k = 0; k < criticalFindings.length; k++) {
    var f = criticalFindings[k]
    var votes = await parallel([
      function() {
        return agent('Try to REFUTE this finding. Look for reasons it might not be a real CRITICAL issue.\n\nFinding: ' + f.description + '\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : '') + '\n\nReturn refuted (boolean) and reason.',
          {label: 'skeptic-1-' + f.file, schema: SKEPTIC_SCHEMA})
      },
      function() {
        return agent('Try to REFUTE this finding. Consider: is this really CRITICAL? Could it be a false positive?\n\nFinding: ' + f.description + '\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : ''),
          {label: 'skeptic-2-' + f.file, schema: SKEPTIC_SCHEMA})
      },
      function() {
        return agent('Try to REFUTE this finding. Default to refuted=true if uncertain.\n\nFinding: ' + f.description + '\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : ''),
          {label: 'skeptic-3-' + f.file, schema: SKEPTIC_SCHEMA})
      }
    ])

    var validVotes = votes.filter(Boolean)
    if (validVotes.length < 2) {
      // Not enough valid skeptic responses — flag for human review
      verifiedCritical.push({finding: f, verified: 'UNVERIFIED', reason: 'Only ' + validVotes.length + ' of 3 skeptics responded'})
    } else {
      var survived = validVotes.filter(function(v) { return !v.refuted }).length >= 2
      if (survived) {
        verifiedCritical.push(f)
      } else {
        // Majority refuted — downgrade to HIGH (mutate in place, already in allFindings)
        f.severity = 'HIGH'
      }
    }
  }
}

// ===== Final Review =====
phase('Final Review')
var finalReview = await agent(
  'FINAL REVIEW of the ENTIRE implementation.\n' +
  'Changed files: ' + changedFiles.join(', ') + '\n' +
  'All per-task reviews are complete. Now check the BIG PICTURE:\n' +
  '1. Cross-task consistency — do the pieces fit together?\n' +
  '2. Integration gaps — anything missing between tasks?\n' +
  '3. Global anti-patterns — patterns to refactor across files?\n' +
  '4. Overall correctness — does the complete implementation solve the problem?\n\n' +
  'Return APPROVED or REJECTED with specific issues.',
  {schema: {
    type: 'object',
    required: ['verdict', 'issues'],
    properties: {
      verdict: {type: 'string', enum: ['APPROVED', 'REJECTED']},
      issues: {type: 'array', items: {type: 'string'}},
      summary: {type: 'string'}
    }
  }}
)

var high = allFindings.filter(function(f) { return f.severity === 'HIGH' })
var medium = allFindings.filter(function(f) { return f.severity === 'MEDIUM' })
var low = allFindings.filter(function(f) { return f.severity === 'LOW' })

return {
  stage: finalReview && finalReview.verdict === 'APPROVED' ? 'complete' : 'code',
  passed: verifiedCritical.length === 0 && specFailed.length === 0,
  findings: verifiedCritical.concat(high).concat(medium).concat(low),
  criticalCount: verifiedCritical.length,
  highCount: high.length,
  mediumCount: medium.length,
  lowCount: low.length,
  specFailed: specFailed,
  finalVerdict: finalReview ? finalReview.verdict : 'UNKNOWN'
}
