# Finalizer Task: PMBook Update

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

Given the Features Completed list and the PMBook path:
- Set each completed feature's status to `Done` (in the plugin orchestrator this is the only place a feature becomes Done; elsewhere, confirm it).
- Mark the current phase `Done` if every feature in it is now `Done`.
- Resolve any open items the completed features addressed.
- **Tranche-boundary check**: if marking this phase `Done` means *every* phase in the PMBook's Phases &
  Milestones table is now `Done`, do not archive or restructure anything yourself — that lifecycle
  belongs to the triage skill's Tranche Closeout (`idea-triage`, or `plugin-idea-triage` in a plugin
  repo). Record it plainly under Notes instead, so the Orchestrator can tell the user.
- **Bug Log**: for each item in the Bugs Fixed list, write a row to `## Bug Log`
  (`ID | Description | Reported | Status | Fixed In`), creating the section after `## Feature Backlog`
  if it doesn't exist yet. If the bug already has a row (it was logged `Open` before it was fixed),
  update that row in place — never add a second one. Write the bug's given `Regression test: <path>`
  into the row's Description. A verified fixed bug's `Status` is `Fixed`, except a P0 fast-lane bug (see below). If
  the section keeps a "next ID" line, move it on past the highest ID now used. `Fixed In` is exactly the `Release label:` the prompt gives; never pick
  a version yourself.
- **Flaky tests**: for each test named in the Task-Specific Inputs' flaky-test list, add, or update the
  existing, `## Open Items` row — `Owner: unassigned | Item: Investigate flaky test <name>` — creating the section
  if needed.
- **Version Pointer Sweep**: only when your Task-Specific Inputs say this run bumped a `> Version:`
  header, carry out the sweep exactly as the orchestrator's prompt describes it (repointing
  `built against vN` header lines, and in a plugin repo the sideways sweep across other components).
  This Task owns it because it already owns the PMBook; no other parallel Finalizer touches those
  headers.
- **Deferred Integration — new P0 hotfix**: if your Task-Specific Inputs include a P0 Bug just fast-laned
  through its own Finalization, write its `## Bug Log` row with `Status: Hotfixed — Integration Pending`,
  and add, or update the existing, `## Deferred Integration` row (`Bug ID | Hotfixed On | Status: Pending`) that also
  carries its given `Regression test: <path>`, as it does in the Bug Log row. Create the `##
  Deferred Integration` section if it doesn't yet exist.
- **Deferred Integration — resolution**: if your Task-Specific Inputs include an Integration Agent Output
  that reports which Deferred Integration Bug IDs it actually re-validated, flip only those exact rows to
  `Status: Resolved`, and flip each of those bugs' `## Bug Log` rows from `Hotfixed — Integration
  Pending` to `Fixed` (in place). Never flip a row that isn't explicitly named in that list, even if it looks like it
  should logically also be fixed — a blanket resolution would let a hotfix whose changes silently regressed
  read as integration-confirmed when it wasn't actually re-checked.
