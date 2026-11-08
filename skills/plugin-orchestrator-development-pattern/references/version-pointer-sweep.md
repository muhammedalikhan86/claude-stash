# Version Pointer Sweep

Carried out by the **PMBook Update** Finalizer, and only when the Orchestrator's Task-Specific Inputs say
this run bumped a `> Version:` header. The PMBook Update Task owns it because it already owns the PMBook,
and no other parallel Finalizer touches these header lines — so running it there keeps every parallel
Finalizer on disjoint files.

Every governed document carries staleness pointers in its blockquote header —
`> PRD: … (built against vN)`, `> Architecture: … (built against vN)` and, in a plugin,
`> Platform Architecture: … (built against vN)`. A version bump is not finished until those pointers have
moved with it. A pointer left citing the old version silently claims a document was reviewed against
something that has since changed.

## Within the resolved component

- If this run bumped the component's `prd-file`, update the `> PRD: … (built against vN)` line in its
  `architecture-doc` and `project-management-doc`.
- If it bumped `architecture-doc`, update the `> Architecture: … (built against vN)` line in its
  `project-management-doc`.

## Sideways, when the resolved component is the shell

A bump of the shell's `architecture-doc` reaches every plugin. For every *other* component in the
`components:` table:

1. Update its `> Platform Architecture: … (built against vN)` header to the shell's new version — whether
   or not it turns out to be affected. That is what makes "reviewed and unaffected" distinguishable from
   "never looked at".
2. Judge whether the shell change is **contract-affecting** for that component: plugin loading, the
   Plugin Context shape, the manifest schema, the message bus, shared theming, auth. An internal
   refactor, a diagram move or a wording change moves no plugin.
3. Where it is contract-affecting, raise a work item in **that component's** PMBook naming the shell
   version and what changed, and bump that component's own `architecture-doc` version with a history row
   (in its `history-directory`) recording why. Make no other edit to that component's documents.
4. Report the sweep under Notes: which components were behind, which were affected, which work items
   were raised.

**Which pointers move.** Only the blockquote header lines of each component's `architecture-doc` and
`project-management-doc` (`> PRD:`, `> Architecture:`, `> Platform Architecture:`). A `built against`
line anywhere else — a handoff, changelog, revision file, test cases doc or runbook — is **reported, not
moved**: list each under Notes with its file and version. Moving it would claim a review nobody did; the
owning component's own run moves it.

Repointing a header line, and adding the PMBook item in step 3, are the **only** edits to another
component's documents this pattern permits. `platform-architecture-file` itself stays read-only.

Version history rows always go to `history-directory`, never into a live document; a live governed doc
carries a two-line pointer stub only.
