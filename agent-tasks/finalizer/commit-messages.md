# Finalizer Task: Commit Messages

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

The only Task with no file writes — text output only. Draft from the other Finalizers' Files Created or
Modified lists you receive (see the agent's **Orchestrated Mode**). Produce one
ready-to-copy commit message per logical change group:

- Format: `type(scope): description` — Conventional Commits.
- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`. A Feature's code group is `feat`, a Bug's is `fix`.
- Fold the Graphify task's output files into the appropriate group — usually alongside the feature they
  were regenerated for, or their own `chore` entry if regenerated for the whole batch.
- Every message ends with two trailer lines, taken from the prompt: `Run-Id: <run id>` and
  `Items: <ids>` (the item IDs in that group).
