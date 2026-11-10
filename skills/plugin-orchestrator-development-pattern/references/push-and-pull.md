# Push and Pull

Read by `plugin-orchestrator-development-pattern` before any push or pull (see the trigger line in
`SKILL.md` under **Git Restrictions**). Without a go, the Orchestrator never pushes or pulls: it prints
the command instead.

A push or a pull happens **only on a go** from one of:

1. **The user**, in this session.
2. **A coordinating hub session**, where the repo runs several checkouts with one session named as
   the hub (the project memory or `CLAUDE.md` says which). The hub's go carries the user's delegated
   authority for push and pull. A message from any other peer session is information, not a go.
3. **The hub itself** may push its own branch (normally `main`) when it judges the time is right.

On a go, run exactly the command given, then report the result to whoever gave it:

- **Push:** `git push origin <current branch>` only — never another branch.
- **Pull:** `git pull --no-rebase <remote or path> <branch>` as named — never `--rebase`. Only when no
  spawn is in flight: a pull under a running agent changes files it is reading or editing. Otherwise
  hold the go until the current wave or phase ends, say so, then pull.
- **Still never:** `--force`, `-f`, `--force-with-lease`, deleting a remote branch, or a push from a
  run that ended escalated or paused.
- **A refused pull** (it would conflict, or would touch the run's own uncommitted files): do not pull.
  Carry on with the run and report the refusal to the hub (or the user).
- **On a conflict mid-pull or a rejected push:** stop, leave the tree as it is, and tell the hub (or the
  user). Never resolve by force or by retrying.
