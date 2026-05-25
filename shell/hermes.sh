# Auto-load core skills into every Hermes session
# Core: project-workflow (9-phase pipeline) + karpathy-guidelines (coding discipline)
hermes() {
    local AUTO_SKILLS="project-workflow,karpathy-guidelines"
    local args=("$@")
    local has_skills=0
    local i
    for ((i=1; i<=$#; i++)); do
        if [[ "${args[$i]}" == "-s" || "${args[$i]}" == "--skills" ]]; then
            has_skills=1
            local next=$((i+1))
            # Guard: if -s is last arg or next arg is a flag, insert AUTO_SKILLS
            if [[ $next -le $# && "${args[$next]}" != -* ]]; then
                # Avoid duplicating skills already present
                if [[ "${args[$next]}" != *"project-workflow"* ]]; then
                    args[$next]="${args[$next]},${AUTO_SKILLS}"
                fi
            else
                # -s without a value: insert AUTO_SKILLS after -s
                local new_args=("${args[@]:0:$next}" "${AUTO_SKILLS}" "${args[@]:$next}")
                args=("${new_args[@]}")
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
