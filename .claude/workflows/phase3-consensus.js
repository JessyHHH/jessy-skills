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
      '=== PLAN ===\n' + planContent,
      {label: 'judge-' + a.key, schema: JUDGE_SCHEMA}
    )
  }
}))

var valid = reviews.filter(function(r) { return r != null })

phase('Synthesize')
var synthesis = await agent(
  'Synthesize ' + valid.length + ' independent plan reviews into one verdict.\n' +
  'Adopt the strongest insights from each angle. Resolve any contradictions.\n' +
  'Return: verdict (APPROVE/ITERATE/REJECT), summary (key findings), recommendation.\n\n' +
  JSON.stringify(valid, null, 2)
)

return {
  reviews: valid,
  synthesis: synthesis,
  averageScore: valid.length > 0
    ? Math.round(valid.reduce(function(s, r) { return s + r.score }, 0) / valid.length)
    : 0
}
