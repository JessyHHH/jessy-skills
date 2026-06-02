export const meta = {
  name: 'phase6-verify',
  description: 'Verification Iron Law — analyze failures, fix one pass, return dry-round state for Master loop',
  phases: [
    {title: 'Analyze', detail: 'Filter failed checks by exit code'},
    {title: 'Fix', detail: 'Fix each failure with minimal changes'},
    {title: 'Report', detail: 'Return state for Master dry-round loop'}
  ]
}

// Parse args: {projectType, checkResults, dryRounds}
var input = typeof args === 'string' ? JSON.parse(args) : args
var projectType = input.projectType || 'unknown'
var checkResults = input.checkResults || []
var dryRounds = input.dryRounds || 0

// Filter failed checks — exitCode !== 0 only (stderr is not a failure signal)
var failures = checkResults.filter(function(c) {
  return c.exitCode !== 0
})

// ===== DRY-ROUND CHECK =====
// If no failures and dryRounds >= 1: second consecutive clean round → DONE
if (failures.length === 0) {
  dryRounds = dryRounds + 1
  return {
    allPassed: true,
    dryRounds: dryRounds,
    shouldContinue: dryRounds < 2,
    phase: 'verify-passed'
  }
}

// ===== FIX PASS =====
// Failures found — reset dry counter, run single fix pass
dryRounds = 0
log(failures.length + ' checks failed — fix pass (dry streak broken)')

phase('Fix')
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

phase('Report')
// Master Agent re-runs Bash checks and re-invokes this script
// with updated checkResults and current dryRounds value
return {
  allPassed: false,
  dryRounds: dryRounds,
  shouldContinue: true,
  remainingFailures: failures.map(function(f) { return f.name }),
  phase: 'fix-complete'
}
