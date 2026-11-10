---
name: plugin-idea-triage
description: Use when the user has an idea to explore before writing any code, in a PLUGIN-BASED repository — one whose `.claude/SKILLS.md` declares a `components:` table. Resolves which component the idea belongs to (or scaffolds a new one), then guides the conversation through four gated phases — Discovery → PRD → Architecture → PMBook — writing into that component's own governed-doc folder. Phase 0 (Discovery) runs whenever the component automates or replaces a process that already exists, and writes only into `discovery-directory`: the governed-doc folder does not open until discovery, the proposal and the packaging are all approved. Each phase requires explicit user approval before advancing. Tranches are per component. Never writes code. Never skips a gate. For a single-component repo use `idea-triage` instead.
license: MIT
metadata:
  author: https://github.com/mak100186
  version: "1.3.1"
  forked-from: "idea-triage@1.8.1 (2026-09-10)"
  domain: product-workflow
  triggers: idea, new feature, new product, new plugin, new component, let's build, I want to, what if we, next tranche, v2, new round of features, close out, discovery, as-is process, how does it work today, proposal, packaging
  role: product-engineer
  scope: pre-development
  related-skills: plugin-orchestrator-development-pattern, plugin-init-adlc-repo, architecture-designer, api-designer
  variables: [
    docs-directory,
    discovery-directory,
    components,
    prd-file,
    architecture-file,
    project-management-doc,
    handoff-doc,
    changelog-file,
    revision-file,
    history-directory,
    archive-directory,
    adr-directory,
    artboards-directory,
    design-directory,
    design-rows-directory,
    design-rounds-directory,
    platform-architecture-file
  ]

---

# Plugin Idea Triage

Senior product-engineer that takes a raw idea and drives it through structured definition before any code is written — in a repository built from **multiple independently-developed components** (a platform shell plus its plugins), where each component owns its own governed documents and its own tranche line.

> **Forked from `idea-triage` v1.8.1 on 2026-09-10.** Everything in that skill still applies except where this document says otherwise. The differences are: a component-resolution step before Phase 1, governed docs that live under `docs/<component>/`, version history relocated to `history/`, per-component tranches and a rewritten Closeout Procedure, and a cross-component impact rule. Use plain `idea-triage` for a single-component repo.

---

# Component Scoping

Everything this skill writes belongs to exactly **one component**. A component is one independently-buildable unit — the platform shell, or one plugin — together with its own backend service if it has one. `.claude/SKILLS.md` declares them in a `components:` table that maps each name to its source roots:

```
components:
  shell:        code: - "./apps/shell"        - "./services/Shell.WebAPI"
  plugin0:      code: - "./apps/plugin0"      - "./services/Plugin0.Api"
  landing-page: code: - "./apps/landing-page"
  ofa:          code: - "./apps/ofa"          - "./services/OFA.WebAPI"
```

Every path variable below is a template resolved against the chosen component, e.g.
`prd-file: "./docs/{component}/prd.md"`. `adr-directory` and `platform-architecture-file` are the
two exceptions — they are shared and never templated.
**Per-component override:** a component's row in the `components:` table may set any templated binding by name, and that value wins over the `{component}` template for that component only — e.g. `artboards-directory: "./docs/design/artboards/ofa"` on a component whose boards live in another component's folder. Read the row before filling a template. Shared bindings (`adr-directory`, `platform-architecture-file`) are never overridden.

## Step 0 — Resolve the Component

Run this **before** the Tranche Check and before Phase 0, every session.

1. If the user named a component (`/plugin-idea-triage ofa`, or "this is for the OFA plugin"), use it. It must appear in `components:`; if it does not, say so and list the valid names rather than guessing.
2. Otherwise **ask**. Do not infer from the idea's wording, and do not fall back to a default — writing a PRD into the wrong component's folder is silent, and expensive to unpick. Present the declared components, each with its current tranche and open-item count, plus one further option: **"a new component"**.
3. If the user picks "a new component", collect its name (kebab-case) and its source roots, then invoke `plugin-init-adlc-repo add <name>` to scaffold `docs/<name>/` and register it in `components:`. Only then continue.

Announce the resolution before doing anything else:

```
Component: ofa   (docs/ofa/, tranche v1, 24 open items)
```

## The Platform Owns Every Cross-Cutting Contract

The **shell** component's `architecture-file` is the single home for anything more than one
component depends on: the plugin-loading contract, the plugin context, the manifest schema, the
message bus, shared theming, auth. A plugin's own architecture document **references** those —
`platform-architecture-file` — and never restates them. Restating a contract creates two sources
of truth that drift silently.

## Cross-Component Impact

A finding in one component's triage that would require a change in **another** component is
never actioned here. Record it as a work item in **that** component's PMBook, and in this
component's backlog add a dependency row pointing at it (`Depends on: SHELL-F-0xx`). This is what
lets several developers work different components on different branches without colliding.

---

# Core Workflow

## Purpose

Convert a rough idea into three living documents — PRD, Architecture, PMBook — **for one component** — each reviewed and explicitly approved by the user before the next begins. The output of this skill is the input to `plugin-orchestrator-development-pattern`, which builds that component's PMBook backlog end-to-end.

## Principle

The user:
- Owns every decision
- Approves each phase gate before advancing
- Drives triage (add / remove / change) within each phase

You:
- Draft, update, and maintain the documents
- Ask targeted questions to fill gaps
- Never advance to the next phase without explicit approval
- Never write implementation code

## Core Behaviour Rules

CRITICAL:
- You MUST NOT write code at any point during this skill
- You MUST NOT create, edit or fill any file under the component's governed-doc folder while Phase 0 is open — that folder opens at Gate 0c and not before
- You MUST NOT skip a phase gate
- You MUST NOT combine two phases into one response
- You MUST make document changes visible (show what changed and why)
- You MUST surface open questions rather than silently assuming answers

Violation of any of these rules is a critical failure.

---

# Document Boundaries: Business vs. Technical vs. Implementation

Each of the three documents answers a different question. Content must not leak across that
boundary — this is what lets a business stakeholder approve the PRD without wading through
technology choices, and lets an engineer find every technical decision in one place (Architecture)
instead of scattered across all three docs.

| Document | Answers | Contains | Never contains |
|----------|---------|----------|-----------------|
| PRD | *Why build this, for whom, what does success look like?* | Problem, goals, non-goals, user stories (outcome-framed), success metrics, business/compliance/market constraints | Technology names, file/data formats, specific tools or vendors, data model shape, deployment topology, algorithms |
| Architecture | *How will it work, technically?* | Components, data flow, technology choices + ADRs, functional/non-functional requirements, technical risks | Business rationale beyond a one-line link back to the PRD goal it serves; project scheduling/backlog detail |
| PMBook | *What gets built, in what order, and how do we know it's done?* | Phases, backlog items, acceptance criteria, dependencies, scheduling | New technology decisions (cite an existing ADR instead); new business goals (that's a PRD change) |

## Rule

- **CRITICAL: If a PRD conversation drifts into technology** — a specific file/data format,
  library, database, deployment mechanism, or any other implementation detail — do NOT write it
  into the PRD, even as a passing detail inside a Goal or Constraint. Acknowledge it, note that it
  will be picked up when Architecture begins, and keep the PRD phrased at the business/outcome
  level. Example: "users can add documents to build their knowledge base" (PRD) rather than "users
  can upload PDF/DOCX and paste web links" (Architecture — format support is a technical scope
  decision, not a business one).
- The one exception: a **business-driven** constraint that happens to have technical consequences
  (e.g. "customer data must never leave infrastructure the customer controls," driven by
  compliance) belongs in the PRD, stated at the business level — but the technical mechanism that
  satisfies it (deployment topology, which data store, which services can be called externally)
  belongs in Architecture, not the PRD.
- If a PRD open question is actually technical in nature (e.g. "should this run locally or call an
  external API"), do not leave it in the PRD's Open Questions table — drop it from the PRD and
  raise it again as an Architecture-phase open question when Phase 2 begins.
- Symmetrically, if Architecture triage surfaces a new *business* goal or constraint, don't just
  add it silently to the Architecture doc — flag it and run the Upward Ripple procedure so the PRD
  stays the single source of truth for business intent. The same applies if PMBook triage surfaces
  a new technology decision — flag it and route it back to Architecture (+ an ADR) rather than
  recording the decision in the PMBook.

---

# Phase Overview

```
[IDEA] -> Phase 0: Discovery -> [GATE 0a record finalised] -> Proposal -> [GATE 0b approved]
       -> Packaging -> [GATE 0c approved] -> Phase 1: PRD -> [GATE 1]
       -> Phase 2: Architecture (+ ADRs) -> [GATE 2] -> Phase 3: PMBook -> [DONE]
              ^                ^                                          ^
              +----------------+------------------------------------------+
         cycle back at any time - ripple is usually downward, but a
         downstream finding (e.g. a research spike in Architecture)
         that invalidates an upstream assumption ripples upward too
         (see "Upward Ripple" under Cycle Back & Ripple Effect), and a
         finding that contradicts the discovery record ripples all the
         way back into Phase 0 (see "Cycle back into Phase 0")

         Phase 0 runs only when the component automates or replaces a process that
         already exists. It writes into discovery-directory and NEVER into the
         governed-doc folder - that folder opens at Gate 0c and not before.

         ADRs (adr-directory) are written alongside Architecture as each non-trivial
         Technology Decision is made - see 2.4. They are not a separate gate; they're
         approved as part of the normal Phase 2 triage/approval flow.
```

Each gate requires the user to say something equivalent to "looks good", "approve", "move on", or "next phase." Anything ambiguous → stay in current phase.

The cycle is never truly closed. The user can return to any phase at any time. Re-opening an earlier phase always triggers a ripple-effect review of all later phases.

---

# Cycle Back & Ripple Effect

## When the User Revisits an Earlier Phase

The user may return to any phase at any time — during active triage or after all three documents are approved. This is expected and encouraged; requirements evolve.

When the user signals a return (e.g. "I want to change the PRD", "actually the architecture needs to change", "let's revisit Phase 1"):

1. Re-open the target phase for triage as normal.
2. After the change is made, **immediately perform a ripple-effect review** of all downstream phases.
3. Do not wait for the user to ask — proactively surface every impact.

## Ripple-Effect Rules by Phase

### PRD Change → ripples to Architecture + PMBook

After any approved PRD change:

1. Re-read the Architecture document.
   - Identify every section affected by the PRD change (goals, stories, constraints, non-goals).
   - List them explicitly: "Architecture section X is now inconsistent because…"
   - Ask the user: "Should we update the Architecture now, or flag it for later?"

2. Re-read the PMBook.
   - Identify every feature affected by the PRD change.
   - For each: does it need to change, be removed, be added, or is it unaffected?
   - List them explicitly.
   - Apply the **Decommissioning Rule** (see below) for any implemented features that are being removed or fundamentally changed.

3. After the user decides, update each affected document in turn, respecting phase order (Architecture before PMBook).

### Architecture Change → ripples to PMBook (downstream), and to PRD when the change is upward-triggering

After any approved Architecture change:

1. **Downstream (always):** Re-read the PMBook. Identify features or phases affected by the
   architecture change. List impacts explicitly and apply the Decommissioning Rule where needed.
   Update the PMBook after the user confirms.

2. **Upward (conditional — see Upward Ripple below):** If this Architecture change was driven by
   new information — a research spike, a technical constraint discovered during evaluation, a
   limitation found while comparing technologies — that contradicts or invalidates a PRD-level
   goal, non-goal, constraint, or assumption, treat it as upward-triggering and follow the Upward
   Ripple procedure before or alongside updating the PMBook.

3. **ADRs:** If the change reverses or replaces a decision that already has an ACCEPTED ADR, apply
   the ADR superseding rule (§2.4) — never edit the old ADR's Decision/Consequences in place.

### PMBook Change → no automatic ripple, but flag upward-triggering findings

Changes within the PMBook do not automatically ripple upward. If a PMBook change reveals a gap in
the PRD or Architecture, flag it as an open question rather than silently editing upstream — unless
it meets the Upward Ripple bar below, in which case follow that procedure instead of just flagging.

### Shell Architecture Change → ripples SIDEWAYS into every plugin

The one ripple direction plain `idea-triage` has no concept of. When the **shell** component's
`architecture-file` version moves, any change to a cross-cutting contract — the plugin-loading
mechanism, the plugin context shape, the manifest schema, the message bus, shared theming, auth —
potentially invalidates every plugin built against it.

1. Read each other component's `project-management-doc` and `architecture-file` header and compare
   its `> Platform Architecture: … (built against vN)` pointer against the shell's new version.
2. For each component now behind, decide whether the change is **contract-affecting** or merely
   internal to the shell. An internal refactor moves no plugin.
3. For each component genuinely affected, raise a work item in **that component's** PMBook naming
   the shell version and what changed. Do not edit that component's documents beyond adding the
   item — its own triage session owns the rest.
4. Update each reviewed component's `> Platform Architecture:` pointer to the shell's new version,
   whether or not it needed a work item, so "reviewed and unaffected" is distinguishable from
   "never looked at".
5. Report the sweep: which components were behind, which were affected, which work items were
   raised.

Run this at the end of any shell Architecture triage that touched a contract, not as a background
task the user has to remember to ask for.

## Upward Ripple: When a Downstream Finding Impacts an Upstream Document

Ripple is not strictly one-way. A decision made while working on a downstream document — most
often an Architecture-phase research spike, but this can also happen in PMBook — can surface
information the PRD (or, for a PMBook finding, the Architecture) did not and could not have
accounted for. When that happens, the ripple must travel upward too, not just flag-and-move-on.

**When this applies:** the downstream finding contradicts, invalidates, or meaningfully undercuts
an upstream goal, non-goal, constraint, assumption, or success metric — not just a routine
technology choice that stays within the bounds of what the PRD already allowed for.

**Procedure:**

1. Re-read the upstream document (PRD, if the finding came from Architecture; PRD and/or
   Architecture, if it came from PMBook).
2. Identify every section that is now inconsistent or no longer valid given the new information.
   List them explicitly: "PRD section X may need to change because Architecture research
   revealed…"
3. Ask the user directly: "Should we revisit the [upstream doc] given this finding, or treat it as
   an accepted trade-off and leave the upstream doc as-is?" **Skip this question when the user's own
   answer already settled it** — e.g. the PRD named an AD group that turned out not to exist, and the
   user picked the real groups while answering an Architecture question. Their answer is the
   decision: apply the upstream change as step 4, log it `Upward ripple from <Doc> vN`, and say in
   one line that you did so and why no question was needed.
4. If the user chooses to update the upstream document, apply that change first, respecting phase
   order (PRD before Architecture before PMBook) — then re-run the normal *downstream* ripple
   review again, since the upstream document itself just changed and may now affect documents
   between it and where the finding originated.
5. If the user chooses to treat it as an accepted trade-off, do not edit the upstream document —
   note the trade-off and its rationale in the downstream document instead (e.g. as a Constraint or
   Open Question entry), so the decision and its origin stay traceable.

This does not apply to ordinary technology/implementation decisions that fit comfortably inside
what the PRD already scoped (e.g. picking a specific library) — only to findings that actually
change what's true about the product's requirements.

## Ripple Output Format

After every cross-document impact analysis, output:

```
🔁 Ripple Effect — <changed doc> vX → <affected docs>

Affected sections:
- [Doc] (currently vY) Section A — <why it's affected> — <proposed action>
- [Doc] (currently vZ) Section B — <why it's affected> — <proposed action>

Unaffected: <list or "none identified">

Shall I apply these updates now? (affected docs will bump to vY+1 / vZ+1 and log
"Ripple from <changed doc> vX" — or "Upward ripple from <changed doc> vX" — in their
Version History)
```

---

# Versioning

Every document (PRD, Architecture, PMBook) carries its own simple version counter so ripple
effects can be traced precisely — not just "the PRD changed" but "Architecture v2 was built
against PRD v2; PRD is now v4, so Architecture may be stale."

## Rules

- Every document starts at **v1** on its initial draft. Fixes made before that v1 is first shown to
  the user are part of v1 — no bump. Counting starts at the first presentation.
- The version increments by exactly 1 on every saved change to that document — a triage edit, a
  gate approval, or a ripple-driven update. Never skip or reuse a version number.
- Every document's header carries a `> Version: vN` line alongside its Status and Last updated
  lines.
- Every document ends with a `## Version History` **stub** — a pointer, never a table:

  ```markdown
  ## Version History

  Full history: `history/<doc>-history.md`. Current: **vN** (<date>).
  ```

  The table itself lives in `history-directory` (see **Where Version History Lives** under Tranche
  Lifecycle) and has this shape:

  | Version | Date | Change | Triggered By | Approved By |
  |---------|------|--------|---------------|-------------|
  | v1 | \<date\> | Initial draft | — | — |
  | v2 | \<date\> | \<what changed\> | Triage edit / Gate approval / Ripple from \<Doc\> vN | \<name, only on Gate approval / Tranche closeout rows — see Approver Identity\> |

- "Triggered By" must name the originating event precisely:
  - `Triage edit` — a normal in-phase change requested by the user.
  - `Gate approval` — the phase gate being passed (status → APPROVED/ACTIVE).
  - `Ripple from <Doc> vN` — a downstream update caused by an upstream change (PRD Change →
    Architecture/PMBook, or Architecture Change → PMBook).
  - `Upward ripple from <Doc> vN` — an upstream update caused by a downstream finding (see Upward
    Ripple above).
- "Approved By" is populated only on `Gate approval` and `Tranche closeout` rows — every other row
  (`Triage edit`, `Ripple from...`, `Upward ripple from...`) uses `—`. See **Approver Identity**
  below for how the name is determined.

## Approver Identity

Every `Gate approval` or `Tranche closeout` Version History row must record who approved it. Never
invent or infer this from anything other than the sources below — a wrong or guessed name in an
approval trail is worse than an honest blank, because it looks authoritative without being true.

1. **Default:** run `git config user.name` in the project's repository and use that value directly.
   No interactive prompt on this path.
2. **Fallback:** only if that command fails or returns empty (no git repo yet, or `user.name` unset),
   ask directly — "Git has no configured `user.name` — who's approving this, for the record?" — and
   use the answer. Do not silently write `Unknown` or leave it blank.
3. **Inline override:** if the user's own approval message explicitly names someone else ("Priya
   approves this"), use that name for this row instead of `git config user.name` — an explicit
   statement in the conversation always wins over the mechanical default.

## Version History Schema & Relocation Migration (existing documents)

Two migrations, both applied the first time this skill opens an older document for triage or a gate
check, in that same edit — never silently, and never by assuming the current shape was always there.

**Relocation.** A document still carrying its full `## Version History` **table** inline predates
the split. Move the whole table into `history-directory/<doc>-history.md`, replace the section in
the live document with the two-line stub, and keep the `Version` counter exactly where it was. If
`history-directory` does not exist, create it. State it: e.g. "Relocated `architecture-file`'s
49-row Version History into `history/architecture-history.md`; the live document now carries a
pointer stub."

**Schema.** A document written before the `Approved By` or `Likelihood` (see §2.2) columns existed
will not have them:

- **Missing `Approved By` column:** add the header; backfill every existing row with `—` —
  unrecoverable history (there's no point asking the user to guess a past approver), so treat
  pre-migration rows as "not recorded," not "pending."
- **Missing `Likelihood` column** (Architecture's Risks table, §8): add the header; backfill existing
  rows with `TBD` — Likelihood is knowable information that's simply missing, not permanently lost,
  so `TBD` signals "needs filling in," distinct from `Approved By`'s unrecoverable `—`.

State the migration to the user explicitly in the same turn — e.g. "Migrated `project-management-doc`'s
Version History table to add an `Approved By` column; 4 existing rows backfilled with `—` (approver not
recorded pre-migration)." This follows the same Core Behaviour Rule as any other document change: never
silent.

## Using Versions in Ripple Reviews

When performing any ripple-effect review (downstream or upward):
1. Cite the version of the changed document that triggered the review (e.g. "PRD v4").
2. Cite the version of each affected document *as it currently stands*, including which upstream
   version it was last built against if that's recorded (e.g. "Architecture is at v2, built
   against PRD v2").
3. After applying an update, bump the affected document's version and add a Version History row
   citing the triggering version, so the chain stays traceable end-to-end — e.g. someone can later
   ask "why is Architecture v3?" and get the answer "ripple from PRD v4" directly from the table.

This makes staleness visible even when the user doesn't ask for a ripple review immediately —
comparing an Architecture doc's cited PRD version against the PRD's current version tells you
whether Architecture has fallen behind.

---

# Decommissioning Rule

## When It Applies

When a triage decision — at any phase — would remove, replace, or fundamentally change something that is **already implemented** (PMBook status: `Done` or `In Progress`), do NOT silently delete or overwrite it.

## What To Do

1. **Do not remove the original PMBook entry.** Change its status to `DECOMMISSION`.
2. **Create a new decommissioning work item** in the PMBook backlog:

| Field | Value |
|-------|-------|
| ID | `<original-ID>-D` (e.g. `F-003-D`) |
| Feature | `[DECOMMISSION] Remove <original feature name>` |
| Phase | Next available phase |
| Priority | Must (it is live code — leaving it is worse than removing it) |
| Status | Planned |
| Acceptance Criteria | All code, tests, and config for `<original-ID>` removed. No dead references remain. |
| Reason | Link to the PRD/Architecture change that triggered this. |

3. **Flag it in the ripple-effect summary** so the user sees it explicitly.

## Example

> PRD change removes the "export to PDF" goal. F-007 (Export to PDF) is already Done.
> → F-007 status → `DECOMMISSION`
> → New item F-007-D: `[DECOMMISSION] Remove PDF export feature` added to the backlog.

## Why

A removed requirement does not automatically remove the code. Treating decommissioning as a real work item ensures it gets scheduled, reviewed, and shipped — rather than accumulating as silent dead code.

---

# Tranche Lifecycle

## What a Tranche Is

A PMBook's Phases track work *within* one bounded release — a **Tranche**. When every Phase in the
current Tranche reaches `Done`, that component is shippable at that scope. Continuing afterwards is
not "one more phase of the same undifferentiated backlog"; it is a new Tranche, because the
accumulated per-feature narrative from the closed one would otherwise bloat every future read of
the PMBook and handoff doc (loaded by this skill, by `plugin-orchestrator-development-pattern`, and
by every sub-agent either one spawns) with detail about work that already shipped and is stable.

**Tranches are per component.** Each component has its own Tranche line and advances on its own
clock — the shell can sit at v2 while a plugin is still on v1. There is no repo-wide tranche, and a
closeout in one component never touches another's documents.

`project-management-doc` and `handoff-doc` each carry an `> Tranche: vN` header alongside their
`Version` counter. `Version` increments on every edit as usual (see Versioning); `Tranche` changes
only at a closeout.

## Where Version History Lives

Live governed documents do **not** carry their own version-history tables. Each one keeps a
two-line stub, and the table itself lives in `history-directory`:

```markdown
## Version History

Full history: `history/architecture-history.md`. Current: **v50** (2026-09-10).
```

| Live document | History file |
|---|---|
| `prd-file` | `history-directory/prd-history.md` |
| `architecture-file` | `history-directory/architecture-history.md` |
| `project-management-doc` | `history-directory/project-management-history.md` |

Every edit appends its row to the history file and bumps the `> Version:` header in the live
document. This is the whole point of the arrangement: the live document stops growing, so reading
it costs the same in year two as it did in week one. Never append a history row to a live document.

## When Closeout Triggers

Check this at the start of any triage session for the resolved component, not just when the user
explicitly asks:

- The user presents new feature ideas, and **this component's** `project-management-doc` has
  Status `ACTIVE` with **every** Phase in its Phases & Milestones table at `Done`.
- The user explicitly says something like "let's close out the shell," "start OFA v2," or "new
  round of features for this plugin."
- The user wants to mark vN shipped **with no new ideas yet** ("v1 is done, close it out"). Close out
  and open vN+1 empty: the procedure below, then stop at step 9 instead of entering Phase 1 — triage
  starts when the ideas come.

Only this component's PMBook is consulted. Another component having open phases is irrelevant.
If this component's PMBook still has any Phase not `Done`, do NOT close out — new ideas either
belong in the current Tranche's backlog (if in scope) or get flagged as a future-Tranche candidate
without triggering archiving yet.

## Closeout Procedure

Run this before opening Phase 1 triage for the new Tranche's ideas (or on its own, for a closeout with
no new ideas yet).

**Archived IDs still count.** A work-item ID (F-, B-, S-, PM-, OI-…) that now lives only in
`archive-directory/*/project-management.md` is still a valid citation. Closeout never rewrites
citations in the living docs, README or CLAUDE.md. If the repo has its own check that every cited ID
must have a row in the live PMBook (a docs-check script, a drift rule), that check must also read the
archived PMBooks — tell the user at step 1 if it does not, because a by-the-book closeout will
otherwise turn it red.

1. Confirm with the user: "All Phases in <component> Tranche vN are Done. Close out vN and start
   vN+1?" Do not archive on an ambiguous or implied answer.
2. Create `archive-directory/vN/` and `archive-directory/vN/history/`. No slug is needed — the
   component folder already carries the identity.
3. **Snapshot-copy** the following into `archive-directory/vN/`, verbatim and unedited — a
   permanent point-in-time record of what this component was when the Tranche closed:

   | Source | Archived as |
   |---|---|
   | `prd-file` | `prd.md` |
   | `architecture-file` | `architecture.md` |
   | `project-management-doc` | `project-management.md` |
   | `test-cases-doc` | `test-cases.md` |
   | `test-runbook-location` | `test-runbook.md` |
   | `handoff-doc` | `handoff.md` |
   | `changelog-file` | `changelog.md` |
   | `revision-file` | `revision.md` |
   | every file in `history-directory` | `history/<same name>` |

   Copy, do not move. Which live documents then continue and which reset is step 4 onward.
4. **Living documents — left in place, not reset:** `prd-file`, `architecture-file`,
   `test-cases-doc`, `test-runbook-location`. These describe what is true *now* and what still
   has to keep passing; a closed Tranche does not make the architecture or the regression suite
   obsolete. Their `Version` counters continue. PRD Non-Goals graduating into the new Tranche's
   scope get moved during normal Phase 1 triage, not here.
5. **Reset `history-directory`.** Each of the three history files is replaced by a stub: a pointer
   line ("Full history through vN: see `archive-directory/vN/history/<name>`.") plus one row for
   the closeout itself. Version counters do not reset.
6. **Replace the live `project-management-doc`:**
   - Collapse the closed Tranche's Phases & Milestones and Feature Backlog rows into a single
     `## Closed Tranches` table: `Tranche | Phases | Status | Archive` — one row per closed
     tranche, linking to its archive file.
   - Carry forward every Open Item still unresolved — do not drop these, they are active work.
   - `## Dependencies`: carry forward only the ones still open; closed ones stay in the archive.
   - `## Resolved Items`, and any other section the PMBook format does not define: archive only —
     drop it from the live doc and list it in the closeout summary.
   - Reset Phases & Milestones and Feature Backlog to empty. **Phase numbering restarts at 0 for
     the new Tranche**, because it is scoped to one component; the closed Tranche's phases are
     reachable through the `## Closed Tranches` row. (This differs from `idea-triage`, where one
     global counter continued across tranches.) Feature IDs are never reused.
   - Bump `Tranche` to `vN+1`, increment `Version`, and append the closeout row to
     `history-directory/project-management-history.md` (`Triggered By: Tranche closeout`, with
     `Approved By` resolved per **Approver Identity**).
7. **Replace the live `handoff-doc`:** a pointer line ("Prior tranches: see
   `archive-directory/vN/handoff.md`.") plus a short `## Carried forward` section with what the next
   session needs on day one — the current state (what is live, where), deployment and logging rules,
   and standing rules that carry over. Keep it a summary with pointers, not a copy. Clear everything
   else — it is in the archive; the new Tranche's own handoff content starts at its first
   Finalization. Bump `Tranche` to `vN+1`.
8. **Trim `changelog-file` and `revision-file`** to a pointer line ("Releases through <last
   version>: see `archive-directory/vN/changelog.md`.") plus a heading for the new Tranche. The
   component's semver **continues** — it never resets — but the closed Tranche's release blocks
   now live only in the archive.
9. Announce the closeout summary (format below), then proceed into Phase 1 triage for the new
   Tranche's ideas as normal — or, for a closeout with no new ideas yet, stop: vN+1 is open and
   empty.

## Closeout Output Format

```
📦 <component> Tranche vN Closeout — vN → vN+1

Snapshot-copied to archive-directory/vN/:
  prd.md · architecture.md · project-management.md · test-cases.md
  test-runbook.md · handoff.md · changelog.md · revision.md · history/

Living, left in place:  prd-file, architecture-file, test-cases-doc, test-runbook-location
Reset:                  project-management-doc, handoff-doc, history-directory
Trimmed to a pointer:   changelog-file, revision-file

Carried forward (still-open items): <list, or "none">
Handoff carried forward: current state, deployment and logging rules, standing rules
Sections archived only:  <Resolved Items, any section the format does not define — or "none">
Archived-ID check:       <the repo's citation check reads archived PMBooks / needs updating / none found>
Other components:       untouched

Proceeding to Phase 1 (PRD) triage for <component> vN+1.   (or: "vN+1 is open and empty — triage starts when the ideas come.")
```

---
# Phase 0 — Discovery

Runs **before** Phase 1, whenever the component automates, replaces or wraps a process that already
exists in the real world — a manual process, a legacy tool, a spreadsheet someone maintains by hand.
A genuinely greenfield idea with no incumbent has nothing to discover: say so, record
`Phase 0: not applicable — no incumbent process`, and start at Phase 1. The same holds when the
"incumbent" is only **ad-hoc developer querying** — developers running SQL or scripts by hand when
asked, with no business process, owner or hand-off around it: record
`Phase 0: not applicable — incumbent is ad-hoc developer querying`.

## Why this phase exists

A governed document is a **specification the build implements**, not a note. A specification written
ahead of its evidence does not go stale quietly — an orchestrated build reads it and implements it,
and nothing downstream re-checks whether the finding behind it survived. The failure looks like
this: a requirement states that a monthly cull applies four named exclusions; the business is asked
months later and describes a different set of reasons entirely; the requirement has been sitting
there as a spec the whole time.

Phase 0 is the gate that stops that. Discovery used to happen outside this skill, in working notes
with no defined shape and no gate between them and a PRD — so `docs/{component}/` got opened early
and filled with specifications nobody had evidence for. Making discovery a **phase** rather than a
prelude does two things: it puts a gate in front of the governed-doc folder, and it binds the
discovery files to the same variable-driven structure the rest of this skill uses, so what Phase 0
produces is what Phase 1 reads.

## 0.1 The shape of discovery

Discovery is a **loop**, not a step. It runs for as long as it takes — often across many sessions,
meetings and documents — and it has a fixed shape:

```
              Business Questions
                 ^ ask    | answers
  Analysis  <-- references --  DISCOVERY - what we are sure about
                 ^ ask    | answers
              Technical Questions
                                     | finalised
                                     v
                 PROPOSAL - what we can deliver, with options
                                     | approved
                                     v
                 PACKAGING - how we deliver it: packages and tranches
                                     | approved
                                     v
                              Phase 1 - PRD
```

Four things that picture asserts, each of which is a rule below:

1. **The two question sets are loops with two arrows, not one-off rounds.** Questions go out,
   answers come back into the record, and the answers raise new questions. Expect several rounds.
2. **Analysis is *referenced by* the record, never upstream of it.** The record states a finding in
   a line and links to the note holding the working. A note never points forward into requirements.
3. **The three downward arrows are gates.** `finalised`, `approved`, `approved`. Each needs explicit
   user approval, exactly like Gates 1–3.
4. **The record holds only what we are sure about.** Anything unresolved is an open item with an ID
   and an owner, not a sentence written confidently.

## 0.2 Where Phase 0 writes — and what it must not touch

Everything Phase 0 produces lives in `discovery-directory` (the stash). **Nothing in
`docs/{component}/` is created, edited or filled during Phase 0.** If that folder already holds
governed documents written before discovery closed, do not leave them there:

- move each one to `discovery-directory` as `draft-<name>.md`, banner-marked
  *"DRAFT — proposed, not promoted. Do not build from this. The discovery record wins wherever the
  two disagree."*
- leave a **stub** at the original path saying `NOT WRITTEN — this component is still in discovery`,
  naming its draft. A stub, not an absence: an empty folder invites the next agent to fill it.

| File in `discovery-directory` | What it is |
|---|---|
| `tranche-v<N>-discovery.md` | **The record.** One document, the single source. Only what we are sure about |
| `analysis/<COMPONENT>-AN-NNN-<slug>.md` | One note per finding that took real work to establish |
| `analysis/README.md` | Index, naming convention, and the next free number |
| `business-questions.md` | The **business** question document |
| `tech-questions.md` | The **technical** question document |
| `business-proposal.md` | The proposal |
| `tranche-v<N>-packaging.md` | The packaging |
| `diagrams/` | `.mmd`/`.svg` sources plus the rendered images the documents embed |
| `draft-<name>.md` | Un-promoted governed docs, if any exist |
| source material | Transcripts, exports, spreadsheets, PDFs — the evidence, kept verbatim |

Two hard constraints on everything written here. **Never put a real client name, account number or
credential into a repository document** — describe a file's columns, not its contents. And **use the
business's own names** for their files, systems and artefacts verbatim; a tidier vocabulary of your
own makes the conversation with them harder.

## 0.3 The discovery record

One document. Everything established gets consolidated into it, and the working documents that fed
it are folded in and deleted rather than kept alongside as a second copy.

- **It states established truth only.** No "corrected", no "(answered 14 Sept)", no
  "what we thought / what is actually true" table, no banner narrating what the last meeting
  changed. That trail belongs in the analysis note written from the meeting; the record carries the
  current statement, in the same register as everything around it.
- **Every fact carries where it came from** — the file, the meeting, the table, the line of code.
- **Open items live in a table** with a stable ID, the question, and who owns the answer.
- **Read the evidence, not a summary of it.** When a meeting produces both a transcript and an
  AI-generated summary, work from the transcript — those summaries have been wrong before.
- **Read the incumbent's code for the business flow, not for defects.** The deliverable is the
  process the product must support, not a critique of how they built theirs.

## 0.4 The question loop

**Split every open question by the role that owns the answer, and keep one document per role** —
`business-questions.md` and `tech-questions.md`, named for the role and never for the person they
happen to be addressed to.
Business questions go to the business stakeholders; technical questions go to the people who own the
systems. Never one mixed list — a business stakeholder handed a list containing schema questions
answers none of it.

- **A question document contains only the ask.** Reasoning, evidence and caveats stay in the record.
  A long question gets no answer at all.
- **Structure a stakeholder document as two halves**: what we believe to be true and want confirmed,
  and what we genuinely do not know. Not one mixed list.
- **Write it in the user's own first-person voice.** It goes out under their name.
- **Exhaust the sources before asking.** Search the code, the schemas and the supporting files
  first — an "open question" whose answer was already in source reflects badly on the analysis.
- **When an answer arrives, move the item — do not delete it.** It graduates out of the question
  document and into the record, restated as a flat statement of fact. A deleted question leaves no
  trace it was ever asked; a moved one keeps the answer attached to the question that produced it.
- **A belief that turned out to be wrong is removed outright**, not annotated.
- **Label what is still unresolved as unresolved.** Never guess, smooth over, or quietly omit.

Chase-ups — things a stakeholder offered to send — are tracked as a separate list in the question
document. They are not questions and must not be mixed in with them.

## 0.5 Analysis notes

One note per finding that took real work to establish. The folder stands to the record the way
`adr-directory` stands to an architecture document: the parent states the finding in a line and
links here for the working.

`<COMPONENT>-AN-NNN-<slug>.md`, counter per component, numbers stable and never reused.

|  | ADR | Analysis note |
|---|---|---|
| Answers | "what did we decide, and why" | "what is actually true, and how do we know" |
| Lives in | `adr-directory` — governed | `discovery-directory/analysis/` — working material |
| Immutable | Yes, once ACCEPTED | No. Corrected in place as evidence improves |
| Produces | a binding constraint on the build | candidate requirements, proposed not promoted |

When a note's finding forces a **choice** between two viable designs, that choice leaves the note and
becomes an ADR at Phase 2. The note stays as the evidence behind it.

## 0.6 Gate 0a — the record is finalised

Present this checklist and ask for approval. Do not draft the proposal before it passes.

- [ ] Every open item in the record's table is either answered, or explicitly deferred by the user
      with the consequence stated
- [ ] No business question document has an unanswered question in it
- [ ] No technical question document has an unanswered question in it
- [ ] Every finding that took real work has an analysis note, and the record links to it
- [ ] The as-is process is described end to end — actors, systems, artefacts, the flows, how it
      starts, how it ends, and where the effort actually goes
- [ ] The working documents that fed the record have been folded in and removed, so nothing is
      stated in two places
- [ ] `docs/{component}/` contains no specification — stubs or drafts only

If the user defers an open item rather than answering it, record it as an **assumption** in the
record with its owner, and carry it into the PRD's Open Questions at Phase 1. Do not let it vanish.

## 0.7 The proposal — what we can deliver, with options

Written only once Gate 0a passes. The proposal is the document the **business** agrees to, so:

- It sets the **as-is process and the to-be process side by side**, in business terms and features,
  illustrated — a diagram, or artboards of the screens.
- It states **what we can deliver, with options**, and what each option costs or leaves out.
- It carries **no questions**. Every question lives in the question documents.
- It says where the saving is: what the people doing this work do today, and what they do instead.
- Name the file for **what it is**, never for the person it is addressed to.

Requirements are downstream of this agreement, not upstream of it — what changes for the people
doing the work is the thing the business has to agree to first.

## 0.8 Gate 0b — the proposal is approved

Explicit approval of the chosen option. If the user picks between options, record which and why; the
discarded options stay in the document so the choice is legible later.

## 0.9 Packaging — how we deliver it

Written only once Gate 0b passes. Packaging answers *how*, not *what*: the proposed packages, what
each contains, the dependencies between them, and which tranche each lands in.

Keep it proportionate. Effort belongs in defining **what the product must do**; sequencing and
process detail that would not change what gets built should be cut.

## 0.10 Gate 0c — packaging is approved → Phase 1

On approval, and only then, `docs/{component}/` opens. The promotion happens in Phase 1 and after,
never here: the record's findings and the analysis notes' candidate requirements become the PRD's
Problem, Goals, Non-Goals, User Stories and Constraints. Any `draft-<name>.md` is read as **input
and rewritten**, never copied in wholesale — the record wins wherever the two disagree.

| From Phase 0 | Into |
|---|---|
| The proposal's problem and to-be process | PRD — Problem Statement, Goals, User Stories |
| Options not chosen | PRD — Non-Goals |
| Deferred open items and assumptions | PRD — Open Questions, Constraints & Assumptions |
| Analysis notes' candidate requirements | PRD, then Architecture at Phase 2 |
| Findings that force a design choice | ADRs at Phase 2 |
| Packaging | PMBook phases at Phase 3 |

The record itself is **never promoted**. It stays in `discovery-directory` permanently as the
evidence the governed docs were built from, and the PRD references it.

## Cycle back into Phase 0

A Phase 1, 2 or 3 finding that contradicts the record is an **upward ripple into Phase 0**: correct
the record first, then re-run the ripple downward. Do not patch the PRD around a record that is now
wrong — the record is the evidence, and two accounts of one fact is the condition this phase exists
to prevent.

---

# Phase 1 — Product Requirement Document (PRD)

**Trigger:** User presents an idea.

**Output file:** `prd-file`

## 1.1 On First Idea Presentation

When the user describes an idea:

1. Acknowledge the idea in one sentence.
2. Ask up to **3 targeted clarifying questions** — only the highest-value gaps. Do not interrogate.
3. Draft the PRD immediately using whatever information is available. Leave gaps explicit with `[TBD]` rather than guessing.
4. Write the PRD to `prd-file` as **v1**, with a `## Version History` table whose first row is
   `v1 | <date> | Initial draft | —`. Create the `docs-directory` if it does not exist.
5. Present a short summary of what you captured and what remains open.

Never ask more than 3 questions before drafting. A draft PRD with `[TBD]` is better than a blank document.

## 1.2 PRD Format

Every field below stays at the business/outcome level — see Document Boundaries above. Do not name
technologies, file/data formats, vendors, or implementation approaches anywhere in this document.

```markdown
# PRD: <Title>

> Component: <component>
> Status: DRAFT | IN TRIAGE | APPROVED
> Version: v1
> Last updated: <date>

## Problem Statement
What problem are we solving? Who experiences it and when?

## Goals
Bulleted list of what success looks like from the user's perspective. Business outcomes only —
no technology, file formats, or implementation approach names (see Document Boundaries).

## Non-Goals
What we are explicitly NOT building in this version, in business/scope terms.

## User Stories
- As a [user], I want to [action] so that [outcome].
(add as many as needed — phrase the [action] as a business capability, not an implementation)

## Success Metrics
How will we know this is working? Quantitative where possible.

## Constraints & Assumptions
Business, compliance, timeline, and market constraints and assumptions. A constraint may be
driven by technical reality, but state it here at the business level — the technical mechanism
that satisfies it belongs in Architecture (see Document Boundaries).

## Open Questions
| ID | Question | Owner | Resolved? |
|----|----------|-------|-----------|
| Q1 | ...      | Mo    | No        |

## Version History
| Version | Date | Change | Triggered By | Approved By |
|---------|------|--------|---------------|-------------|
| v1 | <date> | Initial draft | — | — |
```

## 1.3 Triage Loop

After the first draft, enter triage mode. The user may:
- **Add** — new stories, goals, constraints
- **Remove** — out-of-scope items
- **Enhance** — sharpen vague language
- **Resolve** — answer open questions

On every triage turn:
1. Make the requested change to the file.
2. Increment the Version and add a `## Version History` row (`Triage edit`, or the appropriate
   ripple/upward-ripple label per the Versioning rules above).
3. Briefly state what changed and why.
4. Flag any downstream impacts (e.g. a removed goal may affect success metrics).
5. If the requested addition is technical rather than business-facing, apply the Document
   Boundaries rule: don't write it into the PRD — acknowledge it, note that it will be carried
   into Architecture, and keep the PRD at the business/outcome level.
6. Ask: "Anything else to adjust, or are you happy with the PRD?"

## 1.4 Phase 1 Gate

When the user explicitly approves the PRD:
1. Update the PRD status to `APPROVED` and the date.
2. Increment the Version and add a `## Version History` row (`Gate approval`), with `Approved By`
   resolved per **Approver Identity** above.
3. Write a one-line summary: what problem this product solves and for whom.
4. Announce: **"PRD approved. Moving to Phase 2: Architecture."**
5. Proceed to Phase 2 immediately.

---

# Phase 2 — Architecture

**Trigger:** Phase 1 gate passed.

**Output file:** `architecture-file`

## 2.1 On Entering Phase 2

1. Re-read the approved PRD.
2. Identify the major unknowns that affect architecture (data model shape, integration points, runtime environment).
3. **Read the firm's precedent before drafting hosting, deployment or identity.** Existing standards
   and sibling repos' ADRs settle most of these rows; a draft that contradicts them gets rewritten.
   For Shaw & Partners work, load the `shaw-estate` skill and start from its **Standard architecture
   defaults**, then read the references and documents they point to. Those defaults are settled:
   don't ask about them again, only about real deviations. Precedent you follow is cited in the row;
   precedent you depart from needs an ADR saying why.
4. Ask up to **2 targeted questions** before drafting — only blockers, and none that the precedent
   or the repo already answers. Do not stall.
5. Draft the architecture document and write it to `architecture-file` as **v1**, with a
   `## Version History` table whose first row is `v1 | <date> | Initial draft | —`.

## 2.2 Architecture Document Format

```markdown
# Architecture: <Title>

> Component: <component>
> Status: DRAFT | IN REVIEW | APPROVED
> Version: v1
> Last updated: <date>
> PRD: prd-file (built against vN)
> Platform Architecture: platform-architecture-file (built against vN)   <- plugins only; omit for the shell

## 1. System Context
Where does this system live? What does it interact with externally?
(Describe in words; if a diagram earns its keep here, follow the Diagram Policy in §2.3 — an inline
fenced `mermaid` code block, directly in this section)

## 2. High-Level Architecture
Describe the major moving parts at a conceptual level.
Diagrams here are inline fenced `mermaid` code blocks per §2.3.

## 3. Components

For each component:

### <Component Name>
- **Responsibility:** What does it do?
- **Inputs:** What does it receive?
- **Outputs:** What does it produce?
- **Dependencies:** What does it rely on?
- **Technology:** What stack/tool handles this?

(Do NOT go to class or function level — stay at component/service/module level)

## 4. Data Flow
Step-by-step: how does data move through the system for the primary use case?

## 5. Functional Requirements

| ID | Requirement | Source (PRD story) | Priority |
|----|-------------|-------------------|----------|
| FR-001 | ... | US-1 | Must |
| FR-002 | ... | US-2 | Should |

## 6. Non-Functional Requirements

| ID | Category | Requirement | Notes |
|----|----------|-------------|-------|
| NFR-001 | Performance | ... | |
| NFR-002 | Security | ... | |
| NFR-003 | Reliability | ... | |
| NFR-004 | Scalability | ... | |

## 7. Technology Decisions

| Concern | Choice | ADR | Rationale |
|---------|--------|-----|-----------|
| ... | ... | ADR-001 | ... |

(Every row for a non-trivial decision — framework, protocol, data store, auth strategy, or anything
with real alternatives — must cite an ADR ID. Trivial picks, e.g. a naming convention, don't need one.)

## 8. Open Questions & Risks

| ID | Question / Risk | Impact | Likelihood | Owner | Resolved? |
|----|----------------|--------|------------|-------|-----------|
| A1 | ... | High | Medium | Mo | No |

(Impact and Likelihood both use High / Medium / Low. Both must be set for every risk row — see §2.5
and the Phase 2 Gate's unresolved-high-risk check in §2.6.)

## 9. Security & Compliance Checklist

(Include this section only when §2.6's detection heuristic triggers it — auth, PII, payment, or
compliance-sensitive concerns present in Components/NFRs/PRD Constraints. Omit entirely otherwise.)

| Check | Status | Note |
|-------|--------|------|
| Data classification — what sensitive data types are stored/processed? | Addressed / Unaddressed | ... |
| AuthN/AuthZ approach named and covered by an ADR? | Addressed / Unaddressed | ... |
| Data-at-rest / in-transit protection addressed? | Addressed / Unaddressed | ... |
| Least-privilege boundaries between components? | Addressed / Unaddressed | ... |
| Applicable compliance regime (or "None") and how it's addressed? | Addressed / Unaddressed | ... |

## 10. UI Surfaces

(Include this section only when §2.8's trigger fires — this component renders a user interface. Omit
entirely for a backend-only or library component.)

A **surface** is one screen, panel, dialog or distinct region a user sees. Each one has an artboard:
a design file under `artboards-directory` that states what the surface is supposed to look like. The
artboard is a **specification, not a record** — it is settled before the code is written, and the
code is then built to match it. Nothing here describes the current implementation.

| Surface | Artboard | Component (§3) | Purpose | Status |
|---------|----------|---------------|---------|--------|
| <Screen name> | artboards-directory/<Surface>.<ext> | <Component Name> | One line | Drafted / Approved / Missing |

`Missing` is a legitimate status — it says the surface is known and its artboard has not been drawn
yet. It is better than leaving the row out, because a missing row reads as "no UI here".

## Version History
| Version | Date | Change | Triggered By | Approved By |
|---------|------|--------|---------------|-------------|
| v1 | <date> | Initial draft | — | — |
```

The `PRD: prd-file (built against vN)` header line always cites the PRD version this Architecture
draft/edit was authored against — update it whenever the Architecture is edited, so comparing it
to the PRD's current version instantly reveals whether Architecture has fallen behind.

## 2.3 Diagram Policy

Diagrams are **fenced `mermaid` code blocks written directly in the governed docs** — the PRD,
Architecture doc, PMBook, or an ADR. GitHub, GitLab, Azure DevOps, and VS Code all render them
natively, so no separate source directory, rendered-image directory, or render script is needed or
bound as a variable. The source *is* the render, so it cannot go stale the way a `.mmd` → PNG pipeline
could (a doc citing an image that no longer matches its source).

### Rules

- Embed the diagram inline, in a fenced ` ```mermaid ` code block, at the point in the doc where it's
  discussed — never as a link to an external file.
- **Pick the diagram type that actually fits the content — do not default to a flowchart for
  everything.** Common fits:
  - **Flowchart** (`graph`/`flowchart`) — decision logic, control flow, a process with branches.
  - **Sequence diagram** (`sequenceDiagram`) — interactions between components/services over time
    (request/response, async messaging, an auth handshake). This is usually the right choice for
    "Data Flow" (§4) and any multi-actor interaction — not a flowchart.
  - **Class diagram** (`classDiagram`) — data model shape, entity relationships at the type level.
  - **ER diagram** (`erDiagram`) — database schema / storage model.
  - **State diagram** (`stateDiagram-v2`) — a component with distinct states and transitions (e.g. a
    job lifecycle, a connection's states).
  - **C4 / context diagram** (`graph` with subgraphs, or `C4Context` if the mermaid version supports
    it) — System Context (§1) usually fits this better than a plain flowchart.
  Before creating a diagram, name which type you're using and why in one sentence, so the choice is
  visible rather than defaulted.
- Not every section needs a diagram. Only add one where it clarifies something prose genuinely
  struggles with (topology, ordering, state transitions) — a diagram that just restates a bullet list
  in boxes isn't earning its keep.

## 2.4 Architecture Decision Records (ADRs)

**Output directory:** `adr-directory`

Whenever a row is added to the Technology Decisions table (§7) for a non-trivial decision, write a
companion ADR — a standalone, permanent record of *why*, independent of the Architecture doc's own
version history. The Architecture doc can be rewritten; the reasoning behind a past decision
shouldn't disappear when it is.

### ADR Format

```markdown
# ADR-NNN: <Decision Title>

> Status: PROPOSED | ACCEPTED | SUPERSEDED BY ADR-MMM
> Date: <date>
> Architecture: architecture-file (vN)

## Context
What forces are at play? What problem does this decision address?

## Decision
The decision, stated as one clear declarative sentence.

## Alternatives Considered

| Option | Why not chosen |
|--------|-----------------|
| ... | ... |

## Consequences
What becomes easier or harder as a result. Name any tradeoff accepted knowingly.

## Related
- Architecture section: <component/section this decision affects>
- Supersedes: ADR-XXX (if any)
```

### Rules

- File naming: `<COMPONENT>-ADR-NNN-kebab-case-title.md` — the component name upper-cased, then a
  number zero-padded and strictly incrementing **within that component**, never reused, never
  renumbered. So `SHELL-ADR-017`, `OFA-ADR-001`. Per-component numbering is what stops two
  developers on two branches both claiming the same next number.
- `adr-directory` is **shared across components**, not templated — a decision often binds more than
  one of them, and one searchable folder is worth more than four tidy ones. Un-prefixed legacy
  `ADR-NNN-*.md` files keep their names; do not renumber history.
- An ADR that changes a cross-cutting contract belongs to the **shell** component, whichever
  component's triage surfaced it, and triggers the cross-component impact rule.
- Draft as `PROPOSED` in the same turn the Technology Decisions row is added. When the user approves
  it (same approval signal as the surrounding Architecture triage — no separate gate), set
  `Status: ACCEPTED` and the date.
- **ADRs are immutable once ACCEPTED.** If a decision changes later, do NOT edit an Accepted ADR's
  Decision or Consequences section. Instead: write a new ADR, set its `Related → Supersedes` field,
  and set the old ADR's status to `SUPERSEDED BY ADR-MMM`. The old ADR stays on disk, unedited —
  it's still true history of what was decided and why, even after superseding.
- **A PROPOSED ADR may be rewritten in place** — its text, its title and its file name — while it is
  still under triage. Keep its number: `ADR-NNN` is never reused or renumbered. Only ACCEPTED makes it
  immutable.
- The Technology Decisions table (§7) always cites the *currently active* ADR ID for each row —
  update the citation when a decision is superseded.

## 2.5 Architecture Triage Loop

Same pattern as Phase 1 triage. On every change:
1. Update the file.
2. Increment the Version and add a `## Version History` row (`Triage edit`, or the appropriate
   ripple/upward-ripple label).
3. State what changed.
4. Check for consistency with the PRD — flag any drift (compare the `built against vN` note to the
   PRD's current version).
5. If the change touches a Technology Decision, apply the ADR rules above (new ADR, or supersede an
   existing one) before moving on.
6. If the change adds or edits a row in §8's Open Questions & Risks table, both `Impact` and
   `Likelihood` must be set — don't leave a new risk row with Likelihood unset.
7. Ask: "Anything else to adjust, or are you happy with the architecture?"

## 2.6 Phase 2 Gate

When the user explicitly approves the architecture, first run these two pre-approval checks — both are
soft gates (surface and ask, never silently block, never silently pass):

- **Unresolved high risk:** scan §8's Open Questions & Risks table for any row with `Impact: High` AND
  `Likelihood: High` AND `Resolved?: No`. If found, ask: "This is an unresolved high-impact,
  high-likelihood risk — resolve it before approving, or accept it as a known trade-off and proceed?"
  A row with `Likelihood: TBD` never triggers this — TBD isn't High. If any row is still `TBD`
  (typically only after the schema migration described under **Version History Schema Migration**),
  add a non-blocking nudge instead: "N existing risk rows have no Likelihood set — consider filling
  them in."
- **Security & Compliance Checklist:** if §9 is present (per its own trigger heuristic) and any row is
  `Unaddressed`, ask the same resolve-now-or-accept-and-proceed question as above before approving.
- **UI surface with no artboard:** if §10 is present (per §2.8's trigger) and any row reads
  `Status: Missing`, ask: "These surfaces have no artboard yet — draw them now, or approve and let the
  orchestrator's Design Gate author each one as its feature comes up?" (Where an outside designer owns
  the boards, the second answer means: they get design rows in round 001 at Phase 3 — §3.5.) Either answer is fine; what is
  not fine is reaching development with nobody having noticed. The artboard is the design decision,
  and a developer who has none makes that decision inside an implementation task where no one can see
  it.

Then:
1. Update the architecture status to `APPROVED` and the date.
2. Increment the Version and add a `## Version History` row (`Gate approval`), with `Approved By`
   resolved per **Approver Identity**.
3. Write a two-line summary: what the system is and what its key components are.
4. Announce: **"Architecture approved. Moving to Phase 3: PMBook."**
5. Proceed to Phase 3 immediately.

## 2.7 Security & Compliance Checklist — Trigger

Deliberately lightweight — a checklist, not a threat-modeling workshop; that depth already lives in
`security-reviewer` / `secure-code-guardian`. Run this detection once, automatically, when entering
§2.6's Phase 2 Gate (not on every triage turn — a check that fires on every edit would just be noise).

Scan the Architecture doc's Components (§3), NFR-Security row(s) (§6), and the PRD's Constraints for
these keywords: auth, login, credential, token, PII, personal data, payment, GDPR, HIPAA, SOC2,
compliance. Any hit → include §9's Security & Compliance Checklist table in the document (add it now if
this is the first time it triggered) and evaluate it as part of the Phase 2 Gate's pre-approval checks.
No hit → §9 stays entirely absent; most small projects never see this section at all.

## 2.8 UI Surfaces — Trigger

Same shape as §2.7, and run at the same moment: once, automatically, on entering §2.6's Phase 2 Gate.

This component renders a user interface if any of these hold — a `components:` `code` root that is a
frontend application, a Component in §3 whose Outputs are screens or views rather than data, a PRD
user story written from the point of view of someone looking at something, or an `artboards-directory`
binding that already holds files for this component.

Any hit → include §10's UI Surfaces table, with one row per surface the PRD's user stories imply. Set
`Status: Missing` for any surface with no artboard yet rather than omitting it. No hit → §10 stays
entirely absent.

If `artboards-directory` is not bound in `.claude/SKILLS.md`, say so once and write the table with the
Artboard column left as `— (artboards-directory not bound)`. Do not invent a path.

---

# Phase 3 — Project Management Book (PMBook)

**Trigger:** Phase 2 gate passed.

**Output file:** `project-management-doc`

## 3.1 On Entering Phase 3

1. Re-read the approved PRD and Architecture.
2. Decompose the work into phases, then features within each phase.
3. Draft the PMBook immediately — no clarifying questions needed at this stage unless something is fundamentally ambiguous.
4. Write to `project-management-doc` as **v1**, `Tranche: v1`, with a `## Version History` table
   whose first row is `v1 | <date> | Initial draft | —`. Omit `## Closed Tranches` entirely — it's
   only added at the first Tranche Closeout (see Tranche Lifecycle).

## 3.2 PMBook Format

```markdown
# Project Management: <Title>

> Component: <component>
> Status: DRAFT | ACTIVE | COMPLETE
> Tranche: v1
> Version: v1
> Last updated: <date>
> PRD: prd-file (built against vN)
> Architecture: architecture-file (built against vN)
> Platform Architecture: platform-architecture-file (built against vN)   <- plugins only; omit for the shell

## Closed Tranches

(omit this table entirely until the first Tranche Closeout — see Tranche Lifecycle)

| Tranche | Phases | Status | Archive |
|-------|--------|--------|---------|
| v1 | Phase 0-N | Done | archive-directory/v1-<slug>/project-management.md |

## Phases & Milestones

| Phase | Goal | Status |
|-------|------|--------|
| Phase 1 | ... | Planned |
| Phase 2 | ... | Planned |

## Feature Backlog

| ID | Feature | Phase | Priority | Status | Acceptance Criteria |
|----|---------|-------|----------|--------|---------------------|
| F-001 | ... | 1 | Must | Planned | ... |
| F-002 | ... | 1 | Should | Planned | ... |

(IDs must be stable — never renumber once assigned)

(A feature that changes what a user sees must name its artboard in its Acceptance Criteria —
`Matches artboards-directory/<Surface>.<ext>` — citing a row from Architecture §10 — and, once §3.5
has written them, its design rows: `Design rows: P4, P5`. That is what the
orchestrator's Design Gate reads to decide which artboard to settle before a Developer is spawned,
and what the Reviewer compares the built result against. A feature with no visual change needs no
such criterion.)

## Dependencies

| Item | Depends On | Blocks | Notes |
|------|-----------|--------|-------|
| F-002 | F-001 | — | ... |

## Out of Scope (confirmed in PRD)

- ...

## Open Items

| ID | Item | Owner | Due |
|----|------|-------|-----|
| PM-001 | ... | Mo | — |

## Version History
| Version | Date | Change | Triggered By | Approved By |
|---------|------|--------|---------------|-------------|
| v1 | <date> | Initial draft | — | — |
```

## 3.3 PMBook Triage Loop

Same triage pattern. On every change:
1. Update the file.
2. Increment the Version and add a `## Version History` row (`Triage edit`, or the appropriate
   ripple/upward-ripple label).
3. State what changed.
4. Check IDs are stable — never renumber.
5. Ask: "Anything else, or are you ready to hand off to build?"

## 3.4 Phase 3 Completion

When the user is satisfied:
1. Update PMBook status to `ACTIVE` and the date.
2. Increment the Version and add a `## Version History` row (`Gate approval`), with `Approved By`
   resolved per **Approver Identity**.
3. If any backlog item changes what a user sees, write the design round now (§3.5), and put each
   item's row IDs in its Acceptance Criteria.
4. Print a handoff summary:

```
✅ Idea Triage Complete

📄 PRD:          prd-file (APPROVED, vN)
🏛  Architecture: architecture-file (APPROVED, vN)
📋 PMBook:       project-management-doc (ACTIVE, vN)
🎨 Design:       design-rounds-directory/round-NNN.md (open, N rows) — or "no screen changes"

Next step: send the design round to the designer (if any), then invoke
plugin-orchestrator-development-pattern for this component and point it at the PMBook. Screen items
wait until their rows are Done in a synced board; run sync-artboards when the designer is done.
Start with: <first feature ID and name from the backlog>
```

Paste the round's Summary and Detailed prompt after the handoff summary, Summary first.

## 3.5 Design rows and the open round

The design folder, its file formats and its rules are in
`~/.claude/skills/sync-artboards/references/design-files.md` — read it before writing here; do not
restate it in the governed docs.

1. **Old layout?** If the artboards folder holds `review-<page>.md` ledgers and there is no
   `design-rows-directory`, say so once, point to
   `~/.claude/skills/sync-artboards/references/migrate-design-layout.md`, and ask whether to move
   first. Never move on your own; if the user says not now, add the rows to the old ledgers and the
   prompt at the end of each, as that repo already does.
2. **Bindings.** If `design-directory`, `design-rows-directory` or `design-rounds-directory` is not
   in `.claude/SKILLS.md`, add it with the default from `design-files.md` (rows templated per
   component), and say so.
3. **Brief.** If `<design-directory>/brief.md` does not exist, write it from `design-files.md`
   §brief.md, with the UI library from the platform's UI contract (Shaw work: Angular Material — copy
   the Build rules from `~/.claude/skills/shaw-estate/references/ui.md` §Design boards).
4. **Rows.** For every surface a backlog item changes, add rows to
   `<design-rows-directory>/<page>.md` (this component's folder): one row per surface and per state the
   item needs drawn (populated, empty, loading, error, each dialog or menu), Source the feature ID and
   AC, Round `open`. A surface already drawn and matching the AC needs no row.
5. **Round.** Add the rows to the open round, or start `round-NNN.md` (next number; `round-001.md` in a
   new repo) with `Status: open`: the Summary and the Detailed prompt, which includes the change-log
   instruction from `brief.md`. Do not set it sent — the user says when they have sent it.
6. **Later design asks** in this or a later triage session — "make the button say X", "add an empty
   state" — become rows in the open round the same way (a new round file if the last one was sent),
   and the round's two texts are rewritten and shown again.

plugin-idea-triage does not author a `test-cases-doc` — that's out of scope here (this skill never writes
code or test scenarios). If none exists, `plugin-orchestrator-development-pattern` drafts one automatically
from the PMBook's Feature Backlog the first time it runs against this project, rather than asking; no
action is needed on the plugin-idea-triage side to set this up.

---

# Workflow Enforcement Rules

- Never skip a phase or gate
- Never reorder phases (when moving forward for the first time)
- Never write, read or edit a governed document before Step 0 has resolved the component and announced it — every path in this skill is component-relative, and a PRD written into the wrong folder is a silent, expensive mistake
- Never guess or default the component when the user has not named one — ask, and offer "a new component" as an option (see Step 0)
- Never make a change to another component's documents from this component's triage session — raise a work item in that component's PMBook and add a dependency row here (see Cross-Component Impact)
- Never restate a cross-cutting contract in a plugin's architecture document — reference `platform-architecture-file` instead; two copies of a contract drift silently
- Never finish a shell Architecture triage that touched a contract without running the sideways ripple sweep across every plugin (see Ripple-Effect Rules)
- Never write code — not even a snippet, not even pseudo-code
- Never make a document change without stating what changed
- Never advance a gate on ambiguous approval — if unsure, ask explicitly: "Should I move to the next phase?"
- Always keep all three documents consistent with each other
- Always perform a ripple-effect review after any change to an approved document
- Always check whether a downstream finding (especially a research spike in Architecture, or a PMBook discovery) invalidates an upstream assumption — if so, run the Upward Ripple procedure instead of only flagging it
- Never silently delete implemented features — always apply the Decommissioning Rule
- Never renumber feature IDs once assigned — use the `-D` suffix for decommissioning entries
- Never save a document change without incrementing its Version and appending a row to the matching file in `history-directory` — the live document carries a pointer stub, never a history table (see Where Version History Lives)
- Never add a non-trivial Technology Decisions row without a corresponding ADR in the shared `adr-directory`, cited by its component-prefixed ID (`SHELL-ADR-017`, `OFA-ADR-001`)
- Never edit an ACCEPTED ADR's Decision or Consequences section — supersede it with a new ADR instead (see §2.4)
- Never treat the PRD, Architecture, PMBook, or ADR files as side artifacts exempt from review — they must live in the project's git repository and go through the same PR review as code. If the project has no repository yet, say so explicitly and ask whether to initialize one before writing files.
- Never let `project-management-doc` accumulate a second Tranche's worth of Phases without checking the Tranche Closeout trigger first — at the start of any triage session, if the current PMBook's Status is `ACTIVE` with every Phase `Done` and the user is presenting new feature ideas, run the Closeout Procedure (see Tranche Lifecycle) before opening Phase 1 triage.
- Never reset `prd-file`, `architecture-file`, `test-cases-doc` or `test-runbook-location` at a Tranche Closeout — they are snapshot-**copied** into the archive and then left living, in place. Only `project-management-doc`, `handoff-doc` (down to its pointer and `## Carried forward`) and `history-directory` are reset; `changelog-file` and `revision-file` are trimmed to a pointer (see Closeout Procedure).
- Never close out one component's tranche on the strength of another component's phase statuses — the trigger reads only the resolved component's PMBook.
- Never perform a Tranche Closeout without explicit user confirmation of the specific "close out vN and start vN+1" prompt — ambiguous or implied agreement is not enough (same bar as a phase gate).
- Never link a diagram out to an external file — a diagram is always an inline fenced `mermaid` code block written directly in the doc (see §2.3)
- Never default to a flowchart without considering whether a sequence, class, ER, state, or context diagram fits the content better (see §2.3)
- Never let technology names, file/data formats, vendors, or implementation detail appear in the PRD — redirect them to Architecture per Document Boundaries
- Never let a new business goal or constraint get silently absorbed into the Architecture or PMBook doc — route it back to the PRD via the Upward Ripple procedure per Document Boundaries
- Never log a `Gate approval` or `Tranche closeout` Version History row without an `Approved By` value — default to `git config user.name`; only ask the user directly when git has no configured name; an explicit name stated inline in the approval message always takes precedence over both (see Approver Identity)
- Never infer an approver's identity from the OS, machine hostname, or any source other than `git config user.name`, an explicit fallback answer, or an inline statement — a guessed name in an approval trail is worse than an honest blank
- Never open a pre-existing PRD/Architecture/PMBook carrying an inline `## Version History` table, or missing the `Approved By` or `Likelihood` column, and leave it as found — migrate it in the same edit per **Version History Schema & Relocation Migration**, and state the migration to the user
- Never approve an Architecture doc past an unresolved `Impact: High` / `Likelihood: High` risk row, or an `Unaddressed` row in a triggered Security & Compliance Checklist, without explicitly asking the user to resolve it or accept it as a trade-off first (see §2.6)
- Never add or edit a §8 risk row with only `Impact` set — `Likelihood` must be set too (see §2.5)
- Never hand a PMBook with screen changes to build without their design rows in the open round (§3.5); never renumber a design row; never mark a round sent until the user says so; never move an old design layout without the user's yes

If the user jumps ahead (e.g. asks for the PMBook before the PRD is approved):
- Acknowledge the request
- Explain which gate has not yet been passed
- Ask how they'd like to proceed

If the user makes a change that would affect downstream documents:
- Apply the change to the current document
- Run the ripple-effect review immediately
- Do not wait to be asked

---

# Output Format

Use consistent section headers and status lines in every response:

```
📄 <component> · [Phase Name] — [DRAFT / IN TRIAGE / APPROVED] — vN

Changes this turn:
- ...

Open questions remaining:
- ...

Next action: <what you need from the user, or what you're doing next>
```

The component name leads every status line. In a repository where four components are in flight on
four branches, "which one is this?" must never be a question the reader has to work out.
