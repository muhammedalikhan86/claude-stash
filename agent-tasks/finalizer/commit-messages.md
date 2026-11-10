# Finalizer Task: Commit Messages

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

The only Task with no file writes — text output only. Draft from the other Finalizers' Files Created or
Modified lists you receive (see the agent's **Orchestrated Mode**). Produce one
ready-to-copy commit message per logical change group:

- Format: `type(scope): description` — Conventional Commits.
- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`. A Feature's code group is `feat`, a Bug's is `fix`.
- Fold the Graphify task's output files into the group of the item they were rebuilt for; rebuilt for
  the whole run, they go in the docs/chore group, whose `Items:` then lists every item in the run.
- Every message ends with two trailer lines: `Run-Id: <run id>`, from the prompt, on every commit; and
  `Items: <ids>`, listing only the item IDs whose changes are in that commit. A commit holding only
  Integration fixes says `Items: integration`. Never tag a commit with an item whose files it does not
  hold.
- **Attribution lines** (e.g. `Co-Authored-By: ...`): copy them verbatim from the prompt's attribution
  input and put them after the trailers. Never write, recall or "correct" attribution yourself — if the
  prompt gives none, add none and say so under Notes.
