export const meta = {
  name: 'phase3-consensus',
  description: 'Judge panel: 3 angles review the plan in parallel, synthesize one APPROVE/ITERATE/REJECT verdict',
  phases: [
    {title: 'Review', detail: 'Architecture, risk, feasibility reviewed in parallel'},
    {title: 'Synthesize', detail: 'Merge 3 reviews into one verdict'}
  ]
}

var input = typeof args === 'string' ? JSON.parse(args) : args
var planContent = input.planContent || ''

// --- Extended input parsing (optional fields for richer context) ---
var contextSummary = input.contextSummary || null
var taskIntakeSnapshot = input.taskIntakeSnapshot || null
var grillSummary = input.grillSummary || null
var tasks = input.tasks || null

// --- Structured warnings for missing context ---
var contextWarnings = []
if (!contextSummary) {
  contextWarnings.push("contextSummary not provided — context-blind review")
}
if (!taskIntakeSnapshot) {
  contextWarnings.push("taskIntakeSnapshot not provided — scope validation skipped")
}
if (!grillSummary) {
  contextWarnings.push("grillSummary not provided — ambiguity validation skipped")
}

var taskContractWarnings = []
if (!tasks) {
  taskContractWarnings.push("tasks not provided — task contract validation skipped")
}

// --- Per-task validation (when tasks array is provided) ---
var taskContractReject = false
if (tasks && Array.isArray(tasks)) {
  tasks.forEach(function(t) {
    // mutating task must have patchBackStrategy
    if (t.mutatesFiles === true) {
      if (!t.patchBackStrategy) {
        taskContractWarnings.push("Task " + t.id + ": mutating task missing patchBackStrategy")
        taskContractReject = true
      }
    }
    // missing expectedEvidence without verification explanation in prompt
    if (!t.expectedEvidence) {
      var promptHasVerification = t.prompt && (
        t.prompt.indexOf('verify') !== -1 ||
        t.prompt.indexOf('VERIFY') !== -1 ||
        t.prompt.indexOf('test') !== -1 ||
        t.prompt.indexOf('confirm') !== -1 ||
        t.prompt.indexOf('check') !== -1 ||
        t.prompt.indexOf('validate') !== -1
      )
      if (!promptHasVerification) {
        taskContractWarnings.push("Task " + t.id + ": missing expectedEvidence with no verification explanation")
      }
    }
  })
}

// --- Scope contradiction check (when taskIntakeSnapshot is provided) ---
var scopeReject = false
var scopeFindings = []
if (taskIntakeSnapshot && taskIntakeSnapshot.approvedOutOfScope && Array.isArray(taskIntakeSnapshot.approvedOutOfScope)) {
  taskIntakeSnapshot.approvedOutOfScope.forEach(function(item) {
    if (planContent.indexOf(item) !== -1) {
      scopeFindings.push("Plan contradicts approved out-of-scope items: " + JSON.stringify(item))
      scopeReject = true
    }
  })
}

// --- Ambiguity validation (when grillSummary is provided) ---
var ambiguityReject = false
var ambiguityFindings = []
if (grillSummary && grillSummary.ambiguities && Array.isArray(grillSummary.ambiguities)) {
  grillSummary.ambiguities.forEach(function(a) {
    var isResolved = a.status === 'assumed' && a.ledgerEntry
    var isDeferred = a.status === 'deferred-out-of-scope'
    if (a.status === 'open' && !isResolved && !isDeferred) {
      ambiguityFindings.push("Unresolved open ambiguity: " + a.id)
      ambiguityReject = true
    }
  })
}

// --- Build enriched judge prompt context ---
var contextBlock = ''
if (contextSummary) {
  contextBlock += '\n=== CONTEXT SUMMARY ===\n' + JSON.stringify(contextSummary, null, 2) + '\n'
}
if (grillSummary) {
  contextBlock += '\n=== GRILL SUMMARY ===\n' + JSON.stringify(grillSummary, null, 2) + '\n'
}
if (taskIntakeSnapshot) {
  contextBlock += '\n=== TASK INTAKE SNAPSHOT ===\n' + JSON.stringify(taskIntakeSnapshot, null, 2) + '\n'
}

var ANGLES = [
  {
    key: 'architecture',
    prompt: 'Review ARCHITECTURAL SOUNDNESS. Is the design coherent? Component boundaries clear? Provide the strongest steelman antithesis — what could go wrong? Score 1-10.'
  },
  {
    key: 'risk',
    prompt: 'Review RISK. What are the real failure modes? Are mitigations concrete or hand-waving? What hidden assumptions could cause problems? Score 1-10.'
  },
  {
    key: 'feasibility',
    prompt: 'Review IMPLEMENTATION FEASIBILITY. Are steps concrete and executable? File paths correct? Concrete verification steps? Could a junior engineer follow this? Score 1-10.'
  }
]

var JUDGE_SCHEMA = {
  type: 'object',
  required: ['score', 'findings', 'verdict'],
  properties: {
    score: {type: 'number', minimum: 1, maximum: 10},
    findings: {type: 'array', items: {type: 'string'}},
    verdict: {type: 'string', enum: ['APPROVE', 'ITERATE', 'REJECT']}
  }
}

phase('Review')
var reviews = await parallel(ANGLES.map(function(a) {
  return function() {
    return agent(
      'You are reviewing an implementation plan from the ' + a.key + ' angle.\n\n' +
      a.prompt + '\n\n' +
      'Return: score (1-10), findings (specific observations), verdict (APPROVE/ITERATE/REJECT).\n\n' +
      '=== PLAN ===\n' + planContent +
      (contextBlock ? '\n' + contextBlock : ''),
      {label: 'judge-' + a.key, schema: JUDGE_SCHEMA, model: 'sonnet'}
    )
  }
}))

var valid = reviews.filter(function(r) { return r != null })

phase('Synthesize')
var synthesis = await agent(
  'Synthesize ' + valid.length + ' independent plan reviews into one verdict.\n' +
  'Adopt the strongest insights from each angle. Resolve any contradictions.\n' +
  'Return: verdict (APPROVE/ITERATE/REJECT), summary (key findings), recommendation.\n\n' +
  JSON.stringify(valid, null, 2),
  {model: 'sonnet'}
)

// --- Determine final verdict ---
var preCheckReject = taskContractReject || scopeReject || ambiguityReject
var preCheckFindings = [].concat(scopeFindings, ambiguityFindings)

var finalVerdict
if (preCheckReject) {
  finalVerdict = 'REJECT'
} else {
  var avgScore = valid.length > 0
    ? Math.round(valid.reduce(function(s, r) { return s + r.score }, 0) / valid.length)
    : 0

  // Determine verdict from reviews
  var rejectCount = valid.filter(function(r) { return r.verdict === 'REJECT' }).length
  var iterateCount = valid.filter(function(r) { return r.verdict === 'ITERATE' }).length

  if (rejectCount > 0) {
    finalVerdict = 'REJECT'
  } else if (iterateCount > 0 || avgScore < 7) {
    finalVerdict = 'ITERATE'
  } else {
    finalVerdict = 'APPROVE'
  }
}

// --- Collect all findings ---
var allFindings = preCheckFindings.slice()
valid.forEach(function(r) {
  if (r.findings && Array.isArray(r.findings)) {
    allFindings = allFindings.concat(r.findings)
  }
})

return {
  verdict: finalVerdict,
  score: valid.length > 0
    ? Math.round(valid.reduce(function(s, r) { return s + r.score }, 0) / valid.length)
    : 0,
  findings: allFindings,
  contextWarnings: contextWarnings,
  taskContractWarnings: taskContractWarnings
}
