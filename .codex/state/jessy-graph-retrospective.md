# Jessy Graph V1 Retrospective

- Re-run file ownership checks after every approved command that can mutate the
  attempt worktree, not only after the Codex worker exits.
- Keep MCP health routing outside the session manager; authenticated health
  probes can then validate the process without allocating transports.
- Treat live relay execution as a distinct operational gate. Deterministic
  Docker/MCP tests can pass while the external Responses upstream is returning
  502, so the final verdict must preserve that risk explicitly.
