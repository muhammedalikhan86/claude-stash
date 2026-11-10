# Finalizer Task: Test Runbook

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

Update or create the runbook for each completed feature and fixed bug (for a bug, the manual check is
walking the original repro steps): new flows, updated flows, edge cases, and
step-by-step manual verification instructions a human could actually follow.

**The test cases doc, when Integration handed it to you.** Integration fixes code only: each gap it
found in `test-cases-doc` reaches you as a `Drift: test cases doc — <what> — handed to Test Runbook`
line (an Edit List line, under the plugin orchestrator), with the `test-cases-doc` path. Write each
one into that doc — a missing E2E or smoke case for a flow this run added or changed, a case whose
steps or expected result no longer match the code — in the doc's own form. Touch nothing else in it,
and list it under your Output's files. No such line: leave the doc alone.
