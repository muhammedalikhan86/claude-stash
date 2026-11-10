# Finalizer Task: Spike Log

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

Given the Spike packet's ID/Question/Spike Directory and the Developer's Findings, add, or update the
existing, row in the PMBook's `## Spike Log` section (`ID | Question | Recommendation | Spike Directory | Follow-up`), creating
the section if it doesn't yet exist; tag the row `(run <run id>, spike:<ID>)` at the end of its
`Follow-up` cell. `Recommendation` is one of: promote to Feature backlog / abandon /
needs more investigation, taken directly from the Developer's Findings — never inferred or embellished.
Always a solo invocation: never co-spawned with the batch Tasks, and never followed by a Commit
Messages invocation — Spike code is left uncommitted, so there is nothing to draft a commit message for.
No Graphify, Handoff, Revision+Changelog, or Test Runbook writes accompany it, since nothing was actually
integrated or shipped.
