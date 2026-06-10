export const meta = {
  name: 'phase5-review',
  description: 'Per-task review pipeline: each task flows independently through spec → code → adversarial. Tiered models, context injection, anti-exploration guardrails.',
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
var planText = input.planText || ''
var grillEvidence = input.grillEvidence || null
var quickGateResults = input.quickGateResults || null
var baseSha = input.baseSha || ''
var headSha = input.headSha || ''

// Layer 1 Fast Gate: pre-computed by master agent before Workflow invocation.
// Shape: {filesExist: bool, diffStat: string, diffCheck: bool, importCheck: {passed: bool, issues: [...]}}
// If null/undefined, skip Layer 1 with warning (backward compatible).
var fastGateResults = input.fastGateResults || null

// P1: Strongly Recommended Fast Gate — advisory warning, not blocking
if (!fastGateResults) {
  log('ADVISORY: fastGateResults not provided. Fast Gate checks (git diff --stat, git diff --check, import check, files-exist) are strongly recommended before Phase 5. Continuing with guardrails only.')
}
var fastGateResultsAvailable = !!fastGateResults

// Validate fast gate results if provided
var fastGateIssues = []
if (fastGateResults) {
  if (!fastGateResults.filesExist) fastGateIssues.push('Files missing from working tree')
  if (!fastGateResults.diffCheck) fastGateIssues.push('git diff --check found whitespace errors')
  if (fastGateResults.importCheck && !fastGateResults.importCheck.passed) {
    fastGateIssues = fastGateIssues.concat(fastGateResults.importCheck.issues || [])
  }
}

if (changedFiles.length === 0 && tasks.length === 0) {
  return {stage: 'spec', passed: false, issues: ['No changed files or tasks'], findings: [], criticalCount: 0, highCount: 0}
}

// Build self-review lookup: taskId → status
var selfReviewMap = {}
for (var i = 0; i < selfReviewStatuses.length; i++) {
  var s = selfReviewStatuses[i]
  if (s && s.taskId) selfReviewMap[s.taskId] = s
}

// Complexity-gating functions for layered review (P1 optimization).
// Task complexity: 'simple' | 'medium' | 'complex' (defaults to 'medium' if missing).

function getComplexity(task) {
  return task.complexity || 'medium'
}

function shouldSkipSpecReview(task) {
  return getComplexity(task) === 'simple'
}

function shouldSkipCodeReview(task) {
  return getComplexity(task) === 'simple'
}

function getCodeReviewDepth(task) {
  var c = getComplexity(task)
  if (c === 'complex') return 'full'
  if (c === 'medium') return 'correctness-only'
  return 'none'
}

function shouldSkipAdversarial(task) {
  var c = getComplexity(task)
  return c !== 'complex'
}

function shouldSkipFinalReview(tasks) {
  if (!tasks || tasks.length <= 1) return true
  var fileMap = {}
  for (var i = 0; i < tasks.length; i++) {
    var t = tasks[i]
    var tFiles = t.files || []
    for (var j = 0; j < tFiles.length; j++) {
      var f = tFiles[j]
      if (fileMap[f] && fileMap[f] !== t.id) return false
      fileMap[f] = t.id
    }
  }
  return true
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

// ===== Helper functions =====

function formatFileContents(fileContents) {
  var result = ''
  if (typeof fileContents === 'object' && !Array.isArray(fileContents)) {
    for (var filePath in fileContents) {
      result += '### ' + filePath + '\n```\n' + fileContents[filePath] + '\n```\n\n'
    }
  } else if (Array.isArray(fileContents)) {
    for (var i = 0; i < fileContents.length; i++) {
      var entry = fileContents[i]
      if (typeof entry === 'object') {
        result += '### ' + (entry.file || entry.path || 'file-' + i) + '\n```\n' + (entry.content || '') + '\n```\n\n'
      }
    }
  }
  return result
}

function enrichTaskForReview(task, planText, grillEvidence) {
  var context = ''

  // Spec section
  if (task.specSection) {
    context += task.specSection + '\n\n'
  } else if (planText) {
    var extracted = ''
    var lines = planText.split('\n')
    var inSection = false
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.indexOf(task.id) !== -1 || line.indexOf('## Task') !== -1) {
        inSection = true
      }
      if (inSection) {
        extracted += line + '\n'
        if (line.match(/^## /) && extracted.trim().length > 50) break
      }
    }
    if (extracted.trim()) {
      context += extracted + '\n\n'
    } else {
      context += (task.prompt || 'No specification provided') + '\n\n'
    }
  } else {
    context += (task.prompt || 'No specification provided') + '\n\n'
  }

  // Current Code
  if (task.fileContents) {
    context += '## Current Code\n'
    if (typeof task.fileContents === 'object' && !Array.isArray(task.fileContents)) {
      for (var filePath in task.fileContents) {
        context += '### ' + filePath + '\n```\n' + task.fileContents[filePath] + '\n```\n\n'
      }
    } else if (Array.isArray(task.fileContents)) {
      for (var i = 0; i < task.fileContents.length; i++) {
        var entry = task.fileContents[i]
        if (typeof entry === 'object') {
          context += '### ' + (entry.file || entry.path || 'file-' + i) + '\n```\n' + (entry.content || '') + '\n```\n\n'
        }
      }
    }
  } else if (task.files && task.files.length > 0) {
    context += '## Task Files\n' + task.files.join(', ') + '\n\n'
  }

  // Design Decisions
  if (task.grillDecisions) {
    context += '## Design Decisions\n'
    if (Array.isArray(task.grillDecisions)) {
      for (var i = 0; i < task.grillDecisions.length; i++) {
        context += '- ' + task.grillDecisions[i] + '\n'
      }
    } else if (typeof task.grillDecisions === 'string') {
      context += task.grillDecisions + '\n'
    }
  } else if (grillEvidence) {
    context += '## Design Decisions\n' + grillEvidence + '\n\n'
  } else {
    context += '## Design Decisions\nNone provided\n\n'
  }

  return context
}

function computeTaskRisk(task, quickGateResults) {
  if (!quickGateResults || !quickGateResults.perTask) return 'normal'
  var perTask = quickGateResults.perTask[task.id]
  if (!perTask) return 'normal'
  if (perTask.expectedPassed === false || perTask.forbiddenClean === false) {
    return 'high'
  }
  return 'normal'
}

function buildGuardedSpecPrompt(task) {
  var model = task.riskLevel === 'high' ? 'sonnet' : 'haiku'

  var selfReview = selfReviewMap[task.id]
  var selfReviewText = ''
  if (selfReview) {
    selfReviewText += 'status=' + (selfReview.status || 'NONE')
    if (selfReview.concerns && selfReview.concerns.length > 0) {
      selfReviewText += ', concerns=' + selfReview.concerns.join('; ')
    }
    if (selfReview.contextNeeded) {
      selfReviewText += ', contextNeeded=' + selfReview.contextNeeded
    }
  } else {
    selfReviewText = 'Not provided'
  }

  var intakeNote = ''
  if (taskIntakeSnapshot && taskIntakeSnapshot[task.id]) {
    intakeNote = '\n\nTASK INTAKE SNAPSHOT (original scope for this task):\n' + JSON.stringify(taskIntakeSnapshot[task.id], null, 2) + '\nVerify implementation stays within this scope.'
  }

  var prompt =
    'Spec compliance review for task ' + task.id + '.\n' +
    'DO NOT read any plan files. All context is provided below.\n\n' +
    '## Task Specification\n' +
    (task.enrichedContext || task.prompt || 'No specification provided') + '\n\n' +
    '## Self-Review Status\n' + selfReviewText + '\n\n' +
    '## Instructions\n' +
    'Check: does the implementation match the task spec exactly? Nothing extra? Nothing missing?\n' +
    'Verify against expectedEvidence: ' + (task.expectedEvidence || 'none') + '\n' +
    'Check for forbiddenEvidence: ' + (task.forbiddenEvidence || 'none') + '\n' +
    'Return APPROVE, ITERATE, or REJECT with specific issues.\n\n' +
    contextHeader +
    intakeNote +
    '\n## ⚠️ REVIEW GUARDRAILS (HARD):\n' +
    '1. Maximum 5 file reads total across this review.\n' +
    '2. DO NOT read any file more than once. Content hasn\'t changed.\n' +
    '3. FORBIDDEN commands: go build, go test, go vet, golangci-lint, grep, find. You are a reviewer, not a builder.\n' +
    '4. Maximum 3 thinking blocks. Make your assessment and commit to it.\n' +
    '5. If you need context beyond what is provided, flag it as a finding rather than exploring.'

  return {prompt: prompt, model: model}
}

function buildGuardedCodePrompt(task, reviewType, diff) {
  var model
  if (reviewType === 'correctness' || reviewType === 'safety') {
    model = 'sonnet'
  } else {
    model = 'haiku'
  }

  var prompt =
    'Review ' + reviewType.toUpperCase() + ' for task ' + task.id + '.\n\n' +
    '## Git Diff (ONLY review these changed lines)\n' + diff + '\n\n' +
    '## Full File Contents (for context, do not review unchanged lines)\n' +
    (task.fileContents ? formatFileContents(task.fileContents) : (task.files || []).join(', ')) + '\n\n' +
    '## Instructions\n' +
    '- CORRECTNESS: Logic errors, edge cases, error handling, concurrency safety.\n' +
    '- SAFETY: Nil/null panics, resource leaks, security, data races.\n' +
    '- SIMPLICITY: Over-engineering, dead code, style, Karpathy compliance.\n' +
    'Flag findings with severity CRITICAL/HIGH/MEDIUM/LOW.\n\n' +
    '## ⚠️ REVIEW GUARDRAILS (HARD):\n' +
    '1. Maximum 5 file reads total across this review.\n' +
    '2. DO NOT read any file more than once. Content hasn\'t changed.\n' +
    '3. FORBIDDEN commands: go build, go test, go vet, golangci-lint, grep, find. You are a reviewer, not a builder.\n' +
    '4. Maximum 3 thinking blocks. Make your assessment and commit to it.\n' +
    '5. Only review the CHANGED lines shown in the git diff. Full files are for context only.'

  return {prompt: prompt, model: model}
}

function constructDiff(task) {
  return task.diffText || 'DIFF NOT AVAILABLE — review full file contents instead.'
}

function buildFinalReviewSummary(tasks, allFindings, specFailed) {
  var lines = []
  lines.push('## Per-Task Review Summary')
  for (var i = 0; i < tasks.length; i++) {
    var t = tasks[i]
    lines.push('- Task ' + t.id + ': ' + (t.files || []).join(', '))
  }
  if (allFindings.length > 0) {
    lines.push('\n## Total Findings: ' + allFindings.length)
  }
  if (specFailed.length > 0) {
    lines.push('\n## Spec Failures: ' + specFailed.length)
    for (var i = 0; i < specFailed.length; i++) {
      lines.push('- ' + JSON.stringify(specFailed[i]))
    }
  }
  return lines.join('\n')
}

// ===== Core per-task review orchestrator =====

async function buildFullReviewStage(task) {
  var selfReview = selfReviewMap[task.id]
  var taskResult = {taskId: task.id, specVerdict: null, findings: [], stage: 'init'}

  // Self-review status check (backward compatible)
  if (selfReview) {
    if (selfReview.status === 'FAILED' || selfReview.status === 'BLOCKED') {
      taskResult.specFailed = {taskId: task.id, issues: ['Self-review: ' + selfReview.status], verdict: selfReview.status}
      taskResult.stage = 'self-review-failed'
      return taskResult
    }
    if (selfReview.status === 'NEEDS_CONTEXT') {
      taskResult.specFailed = {taskId: task.id, issues: ['Needs context: ' + (selfReview.contextNeeded || 'unspecified')], verdict: 'NEEDS_CONTEXT'}
      taskResult.stage = 'self-review-needs-context'
      return taskResult
    }
  }

  // Fast Gate issues check
  if (fastGateIssues.length > 0) {
    taskResult.stage = 'fast-gate-failed'
    return taskResult
  }

  // Step 1: Spec Review (gated by complexity)
  if (shouldSkipSpecReview(task)) {
    taskResult.specVerdict = 'APPROVE'
    taskResult.stage = 'spec-skipped'
  } else {
    var specPrompt = buildGuardedSpecPrompt(task)
    var specResult = await agent(specPrompt.prompt, {
      label: 'spec-' + task.id,
      schema: SPEC_SCHEMA,
      model: specPrompt.model
    })
    taskResult.specVerdict = specResult ? specResult.verdict : 'ERROR'
    if (!specResult || specResult.verdict !== 'APPROVE') {
      taskResult.specFailed = {taskId: task.id, issues: specResult ? specResult.issues : ['No result'], verdict: specResult ? specResult.verdict : 'ERROR'}
      taskResult.stage = 'spec-failed'
      return taskResult
    }
    taskResult.stage = 'spec-approved'
  }

  // Step 2: Code Review (only if spec approved, gated by complexity)
  if (shouldSkipCodeReview(task)) {
    taskResult.stage = 'code-skipped'
    return taskResult
  }

  var diff = constructDiff(task)
  var codeDepth = getCodeReviewDepth(task)

  if (codeDepth === 'correctness-only') {
    var corrPrompt = buildGuardedCodePrompt(task, 'correctness', diff)
    var corrResult = await agent(corrPrompt.prompt, {
      label: 'correctness-' + task.id,
      schema: REVIEW_SCHEMA,
      model: corrPrompt.model
    })
    if (corrResult && corrResult.findings) {
      corrResult.findings.forEach(function(f) { f.taskId = task.id; f.reviewType = 'correctness' })
      taskResult.findings = taskResult.findings.concat(corrResult.findings)
    }
    taskResult.stage = 'code-done'
  } else if (codeDepth === 'full') {
    var codeResults = await parallel([
      function() {
        var p = buildGuardedCodePrompt(task, 'correctness', diff)
        return agent(p.prompt, {label: 'corr-' + task.id, schema: REVIEW_SCHEMA, model: p.model})
      },
      function() {
        var p = buildGuardedCodePrompt(task, 'safety', diff)
        return agent(p.prompt, {label: 'safety-' + task.id, schema: REVIEW_SCHEMA, model: p.model})
      },
      function() {
        var p = buildGuardedCodePrompt(task, 'simplicity', diff)
        return agent(p.prompt, {label: 'simp-' + task.id, schema: REVIEW_SCHEMA, model: p.model})
      }
    ])
    var reviewTypes = ['correctness', 'safety', 'simplicity']
    for (var j = 0; j < codeResults.length; j++) {
      if (codeResults[j] && codeResults[j].findings) {
        codeResults[j].findings.forEach(function(f) { f.taskId = task.id; f.reviewType = reviewTypes[j] })
        taskResult.findings = taskResult.findings.concat(codeResults[j].findings)
      }
    }
    taskResult.stage = 'code-done'
  }

  // Step 3: Adversarial Verify CRITICAL findings in this task (inline per task)
  var taskCritical = taskResult.findings.filter(function(f) { return f.severity === 'CRITICAL' })
  var verifiedLocal = []

  if (taskCritical.length > 0) {
    for (var k = 0; k < taskCritical.length; k++) {
      var f = taskCritical[k]
      if (shouldSkipAdversarial(task)) {
        if (getComplexity(task) === 'medium') {
          var vote = await agent(
            'Try to REFUTE this finding. Default to refuted=false if uncertain.\n\nFinding: ' + f.description + '\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : ''),
            {label: 'skeptic-' + k + '-' + (f.file || '').slice(-30), schema: SKEPTIC_SCHEMA, model: 'haiku'}
          )
          if (vote && vote.refuted) { f.severity = 'HIGH' }
          else { verifiedLocal.push(f) }
        } else {
          verifiedLocal.push(f)
        }
        continue
      }
      var votes = await parallel([
        function() { return agent('Try to REFUTE this finding.\n\nFinding: ' + f.description + '\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : ''), {label: 'skeptic-1-' + (f.file || '').slice(-20), schema: SKEPTIC_SCHEMA, model: 'haiku'}) },
        function() { return agent('Try to REFUTE this finding.\n\nFinding: ' + f.description + '\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : ''), {label: 'skeptic-2-' + (f.file || '').slice(-20), schema: SKEPTIC_SCHEMA, model: 'haiku'}) },
        function() { return agent('Try to REFUTE this finding.\n\nFinding: ' + f.description + '\nFile: ' + f.file + (f.line ? ' (line ' + f.line + ')' : ''), {label: 'skeptic-3-' + (f.file || '').slice(-20), schema: SKEPTIC_SCHEMA, model: 'haiku'}) }
      ])
      var validVotes = votes.filter(Boolean)
      if (validVotes.length < 2) {
        verifiedLocal.push({finding: f, verified: 'UNVERIFIED', reason: 'Only ' + validVotes.length + ' of 3 skeptics responded'})
      } else {
        var survived = validVotes.filter(function(v) { return !v.refuted }).length >= 2
        if (survived) {
          verifiedLocal.push(f)
        } else {
          f.severity = 'HIGH'
        }
      }
    }
  }

  taskResult.verifiedCritical = verifiedLocal
  return taskResult
}

// ===== Per-Task Independent Pipeline (P2) =====
var allFindings = []
var specFailed = []

// Enrich tasks with context before pipeline
for (var i = 0; i < tasks.length; i++) {
  tasks[i].riskLevel = computeTaskRisk(tasks[i], quickGateResults)
  tasks[i].enrichedContext = enrichTaskForReview(tasks[i], planText, grillEvidence)
}

phase('Spec + Code Review')
var pipelineResults = await pipeline(tasks,
  function(task) { return task },
  function(task) { return buildFullReviewStage(task) }
)

// Collect findings from pipeline results
var verifiedCritical = []
for (var i = 0; i < pipelineResults.length; i++) {
  var result = pipelineResults[i]
  if (!result) continue
  if (result.specFailed) {
    specFailed.push(result.specFailed)
  }
  if (result.findings && result.findings.length > 0) {
    allFindings = allFindings.concat(result.findings)
  }
  if (result.verifiedCritical && result.verifiedCritical.length > 0) {
    verifiedCritical = verifiedCritical.concat(result.verifiedCritical)
  }
}

// ===== Final Review =====
phase('Final Review')

var skipFinal = shouldSkipFinalReview(tasks)
var finalReview

if (skipFinal) {
  finalReview = {verdict: 'APPROVE', reasons: ['Final review skipped — ' + tasks.length + ' task(s) with no shared files'], issues: [], summary: 'Skipped: insufficient cross-task surface'}
} else {
  var findingsSummary = allFindings.map(function(f) {
    return '- [' + f.severity + '] ' + (f.file || '') + ': ' + (f.description || '').substring(0, 100)
  }).join('\n')

  var specFailedSummary = specFailed.map(function(sf) {
    return '- Task ' + sf.taskId + ': ' + (sf.issues || []).join('; ')
  }).join('\n')

  finalReview = await agent(
    'CROSS-TASK CONSISTENCY CHECK (summary-based, DO NOT re-read files):\n\n' +
    '## Changed Files\n' + changedFiles.join(', ') + '\n\n' +
    '## Per-Task Review Findings Summary\n' + findingsSummary + '\n\n' +
    '## Spec Failures\n' + specFailedSummary + '\n\n' +
    'Check for:\n' +
    '1. Integration gaps — do findings from different tasks point to the same missing piece?\n' +
    '2. Cross-task conflicts — do two tasks make incompatible changes?\n' +
    '3. Duplicate patterns — any issue appearing in multiple tasks?\n' +
    '4. Overall verdict: APPROVE (all verified), ITERATE (integration gaps found), REJECT (blocker)\n\n' +
    'DO NOT read any files. This is a synthesis-only check of pre-verified findings.',
    {
      schema: {
        type: 'object',
        required: ['verdict', 'issues', 'reasons'],
        properties: {
          verdict: {type: 'string', enum: ['APPROVE', 'ITERATE', 'REJECT']},
          issues: {type: 'array', items: {type: 'string'}},
          reasons: {type: 'array', items: {type: 'string'}},
          summary: {type: 'string'}
        }
      },
      model: 'haiku'
    }
  )
}

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

// P1: Layer statistics
var specSkippedCount = tasks.filter(function(t) { return shouldSkipSpecReview(t) }).length
var codeSkippedCount = tasks.filter(function(t) { return shouldSkipCodeReview(t) }).length
var adversarialSkippedCount = tasks.filter(function(t) { return shouldSkipAdversarial(t) }).length

var layersAppliedValue = {
  fastGate: fastGateResults !== null,
  specReview: tasks.length - specSkippedCount,
  codeReview: tasks.length - codeSkippedCount,
  adversarial: tasks.length - adversarialSkippedCount,
  finalReview: !skipFinal
}
var layersSkippedValue = {
  fastGate: fastGateResults === null,
  specReview: specSkippedCount,
  codeReview: codeSkippedCount,
  adversarial: adversarialSkippedCount,
  finalReview: skipFinal
}
var estimatedTokensSaved = (specSkippedCount * 2000) + (codeSkippedCount * 5000) +
  (adversarialSkippedCount * 2 * 3000) + (skipFinal ? 8000 : 0)

return {
  // P1: Layer statistics
  layersApplied: layersAppliedValue,
  layersSkipped: layersSkippedValue,
  fastGateIssues: fastGateIssues,
  fastGateResultsAvailable: fastGateResultsAvailable,
  estimatedTokensSaved: estimatedTokensSaved,
  modelTiering: {haikuCount: 0, sonnetCount: 0},
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
