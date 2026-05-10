# Auto-load core skills into every Hermes session
# Core: golang-workflow (5-phase orchestrator) + karpathy-guidelines (coding discipline)
# Bypass: HERMES_NO_AUTO_SKILL=1 hermes ...
hermes() {
    if [[ "${HERMES_NO_AUTO_SKILL}" == "1" ]]; then
        command hermes "$@"
        return
    fi
    local AUTO_SKILLS="golang-workflow,karpathy-guidelines"
    local args=("$@")
    local has_skills=0
    local i
    for ((i=1; i<=$#; i++)); do
        if [[ "${args[$i]}" == "-s" || "${args[$i]}" == "--skills" ]]; then
            has_skills=1
            local next=$((i+1))
            if [[ $next -le $# && "${args[$next]}" != -* ]]; then
                args[$next]="${args[$next]},${AUTO_SKILLS}"
            fi
            break
        fi
    done
    if [[ $has_skills -eq 0 ]]; then
        command hermes -s "${AUTO_SKILLS}" "${args[@]}"
    else
        command hermes "${args[@]}"
    fi
}
