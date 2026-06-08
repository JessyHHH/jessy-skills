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
var contextSummary = input.contextSummary || ''
var taskIntakeSnapshot = input.taskIntakeSnapshot || null
var grillSummary = input.grillSummary || ''

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
    verdict: {type: 'string', enum: ['APPROVE', 'ITERATE', 'REJECT']},
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

// Build self-review visibility context for review prompts
var selfReviewContext = ''
for (var i = 0; i < selfReviewStatuses.length; i++) {
  var sr = selfReviewStatuses[i]
  if (sr) {
    selfReviewContext += 'Task ' + (sr.taskId || 'unknown') + ' self-review: status=' + (sr.status || 'NONE')
    if (sr.concerns && sr.concerns.length > 0) {
      selfReviewContext += ', concerns=' + sr.concerns.join('; ')
    }
    if (sr.contextNeeded) {
      selfReviewContext += ', contextNeeded=' + sr.contextNeeded
    }
    selfReviewContext += '\n'
  }
}

// Build context fields for prompts
var contextHeader = ''
if (contextSummary) {
  contextHeader += '\nCONTEXT SUMMARY (confirmed facts from environment analysis):\n' + contextSummary + '\n'
}
if (taskIntakeSnapshot) {
  contextHeader += '\nTASK INTAKE SNAPSHOT (original scope at task assignment):\n' + JSON.stringify(taskIntakeSnapshot, null, 2) + '\n'
}
if (grillSummary) {
  contextHeader += '\nGRILL SUMMARY (design/Judge Panel findings):\n' + grillSummary + '\n'
}
if (selfReviewContext) {
  contextHeader += '\nPHASE 4 SELF-REVIEW STATUS (implementer-performed review):\n' + selfReviewContext + '\n'
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
        return {verdict: 'REJECT', issues: ['Task ' + task.id + ' self-review status: ' + selfReview.status]}
      }
      if (selfReview.status === 'NEEDS_CONTEXT') {
        specFailed.push({taskId: task.id, issues: ['Needs context: ' + (selfReview.contextNeeded || 'unspecified')], selfReview: selfReview})
        return {verdict: 'REJECT', issues: ['NEEDS_CONTEXT: ' + (selfReview.contextNeeded || 'unspecified')]}
      }
      if (selfReview.status === 'DONE_WITH_CONCERNS' && selfReview.concerns && selfReview.concerns.length > 0) {
        concernNote = '\n\nSELF-REVIEW CONCERNS (implementer flagged these):\n' + selfReview.concerns.map(function(c) { return '- ' + c }).join('\n')
      }
    }

    // Build intake snapshot validation note
    var intakeNote = ''
    if (taskIntakeSnapshot && taskIntakeSnapshot[task.id]) {
      intakeNote = '\n\nTASK INTAKE SNAPSHOT (original scope for this task):\n' + JSON.stringify(taskIntakeSnapshot[task.id], null, 2) + '\nVerify implementation stays within this scope.'
    }

    return agent(
      'Spec compliance review for task ' + task.id + ' (' + (task.files || []).join(', ') + ').\n' +
      'The implementation plan is at: ' + planPath + ' — Read this file to understand the full plan.\n' +
      'Task requirement: ' + (task.prompt || '') + '\n' +
      'Check: does the implementation match the task spec exactly? Nothing extra? Nothing missing?' +
      contextHeader +
      intakeNote +
      concernNote + '\n\n' +
      'Return APPROVE, ITERATE, or REJECT with specific issues. Use APPROVE when the task is fully correct and complete. Use ITERATE for minor issues that need adjustment. Use REJECT for significant problems that block the task.',
      {label: 'spec-task-' + task.id, schema: SPEC_SCHEMA}
    )
  },
  // Stage 2: Code Quality Review (only if spec APPROVE)
  function(specResult, task) {
    if (!specResult || specResult.verdict !== 'APPROVE') {
      if (specResult && (specResult.verdict === 'REJECT' || specResult.verdict === 'ITERATE')) {
        specFailed.push({taskId: task.id, issues: specResult.issues, verdict: specResult.verdict})
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

var finalContextNote = ''
if (contextSummary) {
  finalContextNote += '\nCONFIRMED CONTEXT FACTS (cross-check against these):\n' + contextSummary + '\n'
}
if (taskIntakeSnapshot) {
  finalContextNote += '\nORIGINAL TASK INTAKE SNAPSHOT (verify nothing was missed):\n' + JSON.stringify(taskIntakeSnapshot, null, 2) + '\n'
}
if (grillSummary) {
  finalContextNote += '\nDESIGN/JUDGE GRILL SUMMARY:\n' + grillSummary + '\n'
}

var finalReview = await agent(
  'FINAL REVIEW of the ENTIRE implementation.\n' +
  'Changed files: ' + changedFiles.join(', ') + '\n' +
  'All per-task reviews are complete. Now check the BIG PICTURE:\n' +
  '1. Cross-task consistency — do the pieces fit together?\n' +
  '2. Integration gaps — anything missing between tasks?\n' +
  '3. Global anti-patterns — patterns to refactor across files?\n' +
  '4. Overall correctness — does the complete implementation solve the problem?\n' +
  '5. Scope verification — cross-check final implementation against original task intake snapshot scope.' +
  finalContextNote + '\n\n' +
  'Return APPROVE, ITERATE, or REJECT with specific issues and reasons. Use APPROVE when the full implementation is correct and complete. Use ITERATE for minor cross-task adjustments needed. Use REJECT for fundamental problems that block the entire implementation.',
  {schema: {
    type: 'object',
    required: ['verdict', 'issues', 'reasons'],
    properties: {
      verdict: {type: 'string', enum: ['APPROVE', 'ITERATE', 'REJECT']},
      issues: {type: 'array', items: {type: 'string'}},
      reasons: {type: 'array', items: {type: 'string'}},
      summary: {type: 'string'}
    }
  }}
)

var high = allFindings.filter(function(f) { return f.severity === 'HIGH' })
var medium = allFindings.filter(function(f) { return f.severity === 'MEDIUM' })
var low = allFindings.filter(function(f) { return f.severity === 'LOW' })

var finalReviewResult = {
  verdict: finalReview ? finalReview.verdict : 'UNKNOWN',
  reasons: finalReview && finalReview.reasons ? finalReview.reasons : [],
  issues: finalReview && finalReview.issues ? finalReview.issues : []
}

// Determine what blocked pass
var finalBlockedBy = null
var passed = verifiedCritical.length === 0 && specFailed.length === 0

if (!passed) {
  finalBlockedBy = []
  if (verifiedCritical.length > 0) finalBlockedBy.push('CRITICAL_FINDINGS: ' + verifiedCritical.length + ' adversarial-verified critical issues')
  if (specFailed.length > 0) finalBlockedBy.push('SPEC_FAILURE: ' + specFailed.length + ' task(s) failed spec review')
}

// Hard Gate: finalReview verdict must be APPROVE
var finalReviewApproved = finalReview && finalReview.verdict === 'APPROVE'
if (!finalReviewApproved) {
  passed = false
  if (!finalBlockedBy) finalBlockedBy = []
  var blockReason = 'FINAL_REVIEW_' + (finalReview ? finalReview.verdict : 'UNKNOWN')
  if (finalReview && finalReview.issues && finalReview.issues.length > 0) {
    blockReason += ': ' + finalReview.issues[0]
  }
  finalBlockedBy.push(blockReason)
}

var stage
if (!finalReview || finalReview.verdict === 'UNKNOWN') {
  stage = 'code'
} else if (passed) {
  stage = 'complete'
} else if (finalReview) {
  stage = finalReview.verdict === 'REJECT' ? 'final-rejected' : 'final-iterate'
} else {
  stage = 'code'
}

return {
  stage: stage,
  passed: passed,
  findings: verifiedCritical.concat(high).concat(medium).concat(low),
  criticalCount: verifiedCritical.length,
  highCount: high.length,
  mediumCount: medium.length,
  lowCount: low.length,
  specFailed: specFailed,
  finalReview: finalReviewResult,
  finalVerdict: finalReview ? finalReview.verdict : 'UNKNOWN',
  finalBlockedBy: finalBlockedBy
}
