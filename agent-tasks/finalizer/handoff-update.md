# Finalizer Task: Handoff Update

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

Update only the handoff doc's **current, live** section:
- What was done (feature IDs, names, key implementation notes)
- Current state (what works end-to-end right now)
- What's next (next phase or open items)
- Important context (environment notes, known limitations, unresolved decisions)

If the doc carries a `> Tranche: vN` header, write into that Tranche's live content only (adding, or
updating this run's existing entry), tagging the entry `(run <run id>, <scope>)` — never trim,
summarize, or archive older Tranche history.
