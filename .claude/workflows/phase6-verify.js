export const meta = {
  name: 'phase6-verify',
  description: 'Verification Iron Law — analyze failures, fix one pass, return dry-round state for Master loop',
  phases: [
    {title: 'Analyze', detail: 'Filter failed checks by exit code and evidence'},
    {title: 'Fix', detail: 'Fix each failure with minimal changes'},
    {title: 'Report', detail: 'Return state for Master dry-round loop'}
  ]
}

// Parse args: {projectType, checkResults, dryRounds, evidenceChecks}
var input = typeof args === 'string' ? JSON.parse(args) : args
var projectType = input.projectType || 'unknown'
var checkResults = input.checkResults || []
var dryRounds = input.dryRounds || 0

// Evidence checks — pre-computed by Master Agent from file I/O.
// This script CANNOT call Bash(), Read(), or do any file I/O.
// Evidence types (reference for Master Agent and fix guidance):
//   'file-exists': path must exist (pre-computed by master)
//   'text-present': path must contain pattern (pre-computed by master)
//   'text-absent': path must not contain pattern (pre-computed by master)
//   'command-output-present': stdout must contain pattern (checked against checkResults)
//   'command-output-absent': stdout must not contain pattern (checked against checkResults)
// Shape: [{id, description, type, passed, details}]
var evidenceChecks = input.evidenceChecks || []

// Backward compatibility: when evidenceChecks is missing/empty,
// log a warning and fall back to command-only verification.
if (evidenceChecks.length === 0) {
  log('No evidenceChecks provided — command-only verification')
}

// Filter failed command checks — exitCode !== 0 only (stderr is not a failure signal)
var failures = checkResults.filter(function(c) {
  return c.exitCode !== 0
})

// Evaluate evidence failures — a failure is any evidenceCheck where passed === false
var evidenceFailures = evidenceChecks.filter(function(e) {
  return !e.passed
})

// ===== DRY-ROUND CHECK =====
// If no command failures AND no evidence failures → clean round.
// Two consecutive clean rounds (dryRounds >= 2) = verification complete.
if (failures.length === 0 && evidenceFailures.length === 0) {
  dryRounds = dryRounds + 1
  return {
    allPassed: failures.length === 0 && evidenceFailures.length === 0,
    dryRounds: dryRounds,
    shouldContinue: dryRounds < 2,
    phase: 'verify-passed',
    evidenceFailures: evidenceFailures,
    evidenceFailureCount: evidenceFailures.length
  }
}

// ===== FIX PASS =====
// Failures found (command OR evidence) — reset dry counter, run single fix pass.
// Evidence failures break the dry streak just like command failures.
dryRounds = 0

var totalFailures = failures.length + evidenceFailures.length
log(totalFailures + ' checks failed (' + failures.length + ' command, ' + evidenceFailures.length + ' evidence) — fix pass (dry streak broken)')

phase('Fix')

// Fix command failures
await pipeline(failures,
  function(failure) {
    var fixPrompt = 'Check "' + failure.name + '" failed.\n' +
      'Command: ' + failure.command + '\n' +
      'Stderr: ' + (failure.stderr || '(none)') + '\n' +
      'Stdout: ' + (failure.stdout || '(none)') + '\n\n' +
      'Fix the issue with MINIMAL changes. Do NOT redesign or refactor.'

    return agent(fixPrompt, {
      label: 'fix-' + failure.name,
      isolation: 'worktree'
    })
  }
)

// Fix evidence failures
await pipeline(evidenceFailures,
  function(ef) {
    var fixPrompt = 'Evidence check \'' + ef.id + '\' (' + ef.type + ': ' + ef.description + ') failed.\n' +
      'Details: ' + (ef.details || '(none)') + '\n\n' +
      'Fix the issue with MINIMAL changes.'

    return agent(fixPrompt, {
      label: 'fix-evidence-' + ef.id,
      isolation: 'worktree'
    })
  }
)

phase('Report')
// Master Agent re-runs Bash checks, re-computes evidenceChecks,
// and re-invokes this script with updated checkResults, evidenceChecks,
// and current dryRounds value.
return {
  allPassed: failures.length === 0 && evidenceFailures.length === 0,
  dryRounds: dryRounds,
  shouldContinue: true,
  remainingFailures: failures.map(function(f) { return f.name }),
  phase: 'fix-complete',
  evidenceFailures: evidenceFailures,
  evidenceFailureCount: evidenceFailures.length
}
