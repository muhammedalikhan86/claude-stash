# Task Packets and Sub-Agent Prompt Templates

Read once, at the start of Phase 1, by `plugin-orchestrator-development-pattern`. Everything here is
filled in by the Orchestrator and handed to a sub-agent; nothing here is read by the sub-agent itself.

---

## Task Packet Format

Three shapes, selected by `Type`. A **Bug** packet replaces `## Acceptance Criteria` with
`## Bug Report`, strengthens `## Note on Tests`, and may carry `## Priority: P0`. A **Spike** packet has
no Acceptance Criteria or Bug Report at all and adds a mandatory `## Spike Directory`.

Format and Lint commands are written **scoped to files**, with `<files you touch>` left for the Developer
to fill in, whenever the platform allows it (Step 0.2).

```markdown
# Task Packet: <COMPONENT>-F-XXX — <Feature Name>

## Type
Feature

## Component
<component name> — source roots: <that component's `code` roots from `components:`>

## Feature ID
<COMPONENT>-F-XXX

## Description
<one paragraph: what this feature does and why it exists>

## Acceptance Criteria
<numbered list, taken directly from PMBook — these are the pass/fail conditions>

## Files to Create or Modify
<Orchestrator's best estimate based on architecture-doc; Developer may deviate with justification>

## Dependencies
<features or modules already implemented that this feature builds on>

## Platform
<platform name>

## Specialist Skill
<skill name from Step 0.3b, or "None">

## Developer Quality Gate
- Format: <command, scoped to <files you touch> where the platform allows>
- Lint:   <command, scoped likewise>

## Note on Tests
Write the test files. Do NOT run the test suite — test execution is the Integration Agent's responsibility.

## Coding Conventions
<summary from Step 0.3>

## Architecture Reference
See: architecture-doc — <relevant section IDs or component names>
Platform contract (read-only): platform-architecture-file — <the cross-cutting sections this work
depends on: plugin loading, plugin context, manifest schema, message bus, theming, auth>.
Read it to build against it. Changing it is a shell work item, never yours.

## Design Reference
<Omit this whole section when the work item touches no user interface.>
Artboard (the visual contract for this work): artboards-directory/<Surface>.<ext>
It was brought in line with the intended design at Step 1.1b, before you were spawned. Build to it.
Do not change it — the design was settled, and the Reviewer checks the built result against it.
Components: <each surface → its Angular Material / CDK component, from Step 1.1b point 5>
Styling: <each surface → shared theme / existing class vocabulary / new shared class / local CSS>
States to compare: <the board states this item must match — populated, empty, loading, error, full
  view, and each dialog and menu it touches>
Ruled deviations: <each accepted difference from the board, with its source: a design row ID, or a
  hub or user ruling with its date — or "None". Only these may differ; anything else fails>
Standing acceptance criterion (every UI packet): The built screen matches the board in every listed
  state; the Parity Table (Step 1.3b) shows no unruled mismatch.

## Constraints
<constraints from PRD or Architecture that apply>

## Test Expectations
- Unit tests must cover: <list>
- Edge cases to test: <list>
- Test file location convention: <e.g. tests/, __tests__/, *_test.go>

## Expected Output (for Reviewer)
<what must exist after the Developer is done — Reviewer checks this>
```

```markdown
# Task Packet: <COMPONENT>-B-XXX — <Bug Title>

## Type
Bug

## Component
<component name> — source roots: <that component's `code` roots from `components:`>

## Bug ID
<COMPONENT>-B-XXX

## Priority
<omit entirely for a normal bug; set to exactly `P0` only when the user explicitly said so — see Step
0.1b. Never inferred from how severe the description sounds.>

## Description
<one paragraph: user-visible symptom and impact>

## Bug Report
- Reproduction steps: <numbered, concrete>
- Expected behavior: <what should happen>
- Actual behavior: <what happens instead>
- Suspected files/component (if known): <from the user report, else "Unknown — Developer to locate">
- Root cause (if already known): <else "Unknown — Developer to diagnose">

## Files to Create or Modify
<Orchestrator's best guess from the suspected component, if any; Developer may deviate with justification>

## Dependencies
<none, unless the bug is blocked on another in-flight fix>

## Platform
<platform name>

## Specialist Skill
<skill name from Step 0.3b, or "None">

## Developer Quality Gate
- Format: <command, scoped to <files you touch> where the platform allows>
- Lint:   <command, scoped likewise>

## Note on Tests
Write a regression test that reproduces the bug — it must fail against the pre-fix code and pass once the
fix is applied. Do NOT run the full test suite — test execution is the Integration Agent's responsibility.
State explicitly which assertion is the one that would have caught this bug, and the exact command that
runs that one test. Check the command really narrows to that test on this repo's runner (some wrappers
ignore a name filter and run the whole file — then say so and name the file). If the test needs the app
running (E2E), say so: the Orchestrator brings the stack up before the Reviewer runs it.

## Coding Conventions
<summary from Step 0.3>

## Architecture Reference
See: architecture-doc — <relevant section IDs or component names, if applicable>
Platform contract (read-only): platform-architecture-file — cite the relevant sections if the bug
touches a cross-cutting contract. Read it; do not change it.

## Design Reference
<Omit this whole section when the bug touches no user interface. Same shape as the Feature packet's.>

## Constraints
<constraints from PRD or Architecture that apply>

## Expected Output (for Reviewer)
Bug no longer reproduces per the steps above, root cause is identified (not just the symptom patched),
and a regression test exists that fails without the fix.
```

```markdown
# Task Packet: <COMPONENT>-S-XXX — <Spike Question, short form>

## Type
Spike

## Component
<component name> — source roots: <that component's `code` roots from `components:`>

## Spike ID
<COMPONENT>-S-XXX

## Question
<one paragraph: what we're trying to learn or decide, and why it matters right now>

## Spike Directory
<mandatory — default repo-root spikes/<ID>/, outside every source root and test discovery>

## Approaches to Try
<optional — specific candidates to try, or "explore freely" if there's no starting hypothesis>

## Platform
<platform name>

## Specialist Skill
<skill name from Step 0.3b, or "None">

## Developer Quality Gate
- Format: <command, scoped to Spike Directory>
- Lint:   <command, scoped to Spike Directory>

## Constraints
- Do not run the test suite. Format and Lint only, scoped to the Spike Directory.
<constraints from Architecture/PRD that apply, if any>

## Expected Output (for the Orchestrator's Spike Log)
A findings write-up: what was learned, and one explicit recommendation — promote to the Feature Backlog /
abandon / needs more investigation. Plus the list of Files Created, all scoped to Spike Directory. There is
no Reviewer for this packet type.
```

---

## Sub-Agent Prompt Templates

**Ordering convention:** content that is byte-identical between a first attempt and its retry comes
first; anything that only exists on a retry is appended at the very end, so a first-attempt prompt is a
strict prefix of its retry's prompt and prompt caching can reuse it.

### Developer Agent Prompt

```
You are a senior software developer implementing a single feature or bug fix defined by the Task Packet
below (see its `Type` field). You are operating in **orchestrated mode** (see your own **Orchestrated Mode**
section) — you were spawned with a Task Packet, not a live human request.

## Task Packet
<INSERT FULL TASK PACKET>

## Pipeline-Specific Boundaries (in addition to your operating discipline)

Format and Lint must both pass before you return.

A test or check whose subject no longer exists, and which the packet does not name as retired: never
park it (`skip`, `fixme`, `only`, commented out). Leave it as it was, finish the rest, and put it first
under Assumptions and Deviations as a question for the Orchestrator. You may be resumed with a ruling;
apply exactly that.

## Return Format
Use exactly your own Output Template.

## Reviewer Issues (only present when Previous Issues exist — a retry, or a resume after escalation; omit otherwise)
<INSERT REVIEWER'S ISSUES LIST, the user's Manual Verification report, or the escalation's issues —
keeping any "verified by Step 1.3b, not by you" marks>
Fix only the issues listed above and nothing else.

## Previous Attempt (present whenever a previous Developer Output exists — a retry, or a resume after escalation; omit otherwise)
<INSERT PREVIOUS DEVELOPER OUTPUT'S "Files Created or Modified" LIST>
You are a fresh spawn with no memory of building this — the list above is exactly what the prior attempt
touched. Start there instead of re-exploring the codebase.
```

### Reviewer Agent Prompt

```
You are operating in **orchestrated mode**.

## Task Packet
<INSERT FULL TASK PACKET>

## Pipeline-Specific Note

If the Task Packet carries a `## Design Reference`, check the code against it: the named Material/CDK
components, the styling sources, and that every state in `States to compare` is built. Report any
divergence you can see in the code as an issue. "The artboard looks out of date" is not a defence: it was
settled at Step 1.1b before the Developer was spawned. **A static read does not satisfy the design
check.** You may PASS the code, but the item is not done until the Board Parity Check (Step 1.3b)
measures the rendered screen and passes. Do not claim the screen matches the board.

If `Type` is `Bug`: check the fix addresses the stated root cause, not just the symptom. The user checks
the symptom after your PASS; your job is the regression test. If the test is E2E, the Orchestrator has
brought the stack up; if it is not reachable, that is UNVERIFIED, not FAIL.

If an issue can only be fixed in a file inside ANOTHER component's roots (for example a test another
component owns — the `components:` table in `.claude/SKILLS.md`), mark that issue
`[cross-component: <owning component>]`. The Orchestrator routes it to a linked item instead of a
Developer retry. A file outside every component's roots (e.g. root `package.json`, a lockfile) is never
tagged: check it as a deviation — it passes only when the Developer Output records it with a
justification the work needs.

## Return Format
Use exactly your own Output Template.

## Developer Output
Read it in full: <INSERT PATH of the verbatim Developer Output file — never a summary or excerpt>
<INSERT any Orchestrator ruling made mid-attempt, marked binding, or omit this line>

## Retry Context
loop_count: <INSERT N — 0 if this is the first review of this item>
Previous Issues (whenever they exist — a retry, or a resume after escalation): <INSERT PREVIOUS ISSUES
LIST, or "None — first review". After a Parity FAIL, mark each parity mismatch "verified by Step 1.3b,
not by you"; keep those marks on a resume.>
```

### Parity Prompt (Step 1.3b)

```
You are operating in **orchestrated mode**, spawned with the Parity Prompt: check a built screen against
its design board.

## Inputs
Task Packet: <INSERT PATH> — read its `## Design Reference`: States to compare, Ruled deviations.
App URL: <INSERT app-url, filled with this checkout's port offset>
Board URL: <INSERT the board's URL from artboard-server>
Compared against: <"Board <file>" | "Acceptance Criteria — <surface> not drawn">
Widths: <INSERT parity-viewports, at least 1440>
Parity folder: <INSERT <gate log directory>/parity/<ID>[-legN][-retryN]/>
Repo root: <INSERT>

## How to measure
1. Write one CommonJS script, `<parity folder>/parity.cjs`. Load Playwright from the repo:
   `const { chromium } = require(require.resolve('playwright', { paths: ['<repo root>'] }));`
   Run it with `node <parity folder>/parity.cjs`. Output goes to the parity folder only.
2. For each width, and each state in States to compare, open the board's drawing of that state and the
   app in the same state. Reach app states with `page.route` stubs: an empty response for empty, an
   error status for error, a held response for loading. Open every dialog and menu the packet touches.
3. For each element in each state, record on both sides: computed `font-weight`, `font-size`, `color`;
   a heading's line count (height ÷ line-height); element order and exact wording; whether table tools
   and the paginator are present, and the paginator's page-size choices; tooltips and ⓘ icons.
4. Transient states: from navigation, sample every ~20 ms for 2 s — how many loaders show, in what order,
   and for how long.
5. Save a screenshot per state per width per side, and the raw measurements as JSON.

## Verdict
- Every difference is a row. A difference covered by a Ruled deviations line is a match with its ruling
  named. Any **unruled** difference is a FAIL.
- When Compared against is the Acceptance Criteria, a row is a mismatch when the built screen breaks a
  criterion.
- The app or board will not load, or a listed state cannot be reached even with stubs → UNVERIFIED for
  that, with the reason. Never PASS what you did not measure.

## Return Format
Verdict: PASS | FAIL | UNVERIFIED
Compared against: <as given>
Parity Table:
| State | Width | Element | Board | Built | Match | Ruling |
Issues (if FAIL): one per unruled mismatch — state, width, element, board value, built value.
Unable to Verify (if UNVERIFIED): what and why.
Files: <the parity folder's contents>
```

### Integration Agent Prompt

```
You are a senior integration engineer. You run the quality gate at the scope given below, fix test or
build failures, and validate the system after all work items in this run were implemented. You are
operating in **orchestrated mode**.

## Platform Profile
<INSERT PLATFORM PROFILE, including the Test scope line:
 "Test scope: full — <reason>"  or  "Test scope: component — <component test command> — <reason>">

## Gate Log Directory
<INSERT <scratchpad>/gate-logs/<run id>/>
Use it as the log directory in your **Keeping Gate Output Out of Context** section.

## Stack Order
<INSERT the Stack line and the order to run gates in, e.g. "stack is up: run E2E first; then stack-down;
then build and the .NET suite" — or "None — nothing needs a running stack">

## Specialist Skill
<INSERT skill name from Step 0.3b, or "None">

## Component
<INSERT component name and its `code` roots. For Linked Runs: every linked component, and which work
item owns which file — the Diff Guard checks each file against its own item's component.>

Component table (every component → its `code` roots, from `.claude/SKILLS.md` `components:`):
<INSERT the full table. The Diff Guard and the owner of a failing file are both read from it.>

## Work Items in This Run
Features: <INSERT LIST: F-ID, name, files changed — or "None this run">
Bugs:     <INSERT LIST: B-ID, one-line description, files changed — or "None this run">
Out-of-root files: <INSERT per item: each file outside every component's roots, with its Developer
Output's justification (a UI Iteration: the one line step 6 or 9 recorded) — or "None">

## Source Directory
<INSERT source-code-directory>

## Test Cases Doc
<INSERT test-cases-doc path, or "None provided">

## Architecture Doc
<INSERT architecture-doc path>

## Platform Architecture (read-only)
<INSERT platform-architecture-file path>

## PMBook
<INSERT project-management-doc path>

## Test Runbook
<INSERT test-runbook-location path, or "None provided">

## ADRs
<INSERT adr-directory path, or "None provided">

Read the documents above yourself — you were given paths, not contents.

## Cross-Component Diff Guard
Before anything else, check only the files this run changed — the work items' files above (for a UI
Iteration, its file set: the tweak log's files, the artboard edits, the updated assertion files and the
Reviewer-fix files) and your own fixes; ignore paths under docs-directory and graphify-out. Check
each of this run's files against the component table:
- inside this component's roots — fine;
- outside every component's roots — allowed when `Out-of-root files` above lists it with a
  one-line justification (a Developer Output's, or a UI Iteration's step 6 or 9); name each in your
  Output with that justification; one not listed there is a FAIL;
- inside another component's roots — FAIL: report the files, the owning component, and what the work
  needed from them; do not quietly revert;
- platform-architecture-file modified — FAIL, always.
On a FAIL, list each file under Unresolvable Issues as
`Diff Guard FAIL: <path> — owner <component> — <what the work needed>`, write each Quality Gate line as
`not run — Diff Guard FAIL`, and return Overall Status FAIL. The Orchestrator moves those files to a
work item in the owning component, then re-runs this pass.

## Deferred Integration
<INSERT per Pending Bug ID from PMBook's "## Deferred Integration" section: the ID, its files changed
and its commit ids — this run's P0: files = the Bug's run-state `files` (every
attempt) + its lane Finalizers' files, commit ids from `git log --grep "Run-Id: <run id>"` only if any exist; an earlier run's ID:
`git log --grep "<ID>" --name-only` — or "None provided">

## Documentation Drift Check — Specific Mapping for This Pipeline
- Does the Architecture Doc still describe every module that now exists in this component's source
  roots, including its inline `mermaid` diagrams?
- Does the PMBook's Acceptance Criteria for each work item in this run match what the code actually does?
- Does the PMBook's `## Bug Log` accurately describe each fix? Check only bugs that already had a Bug
  Log row before this run: this batch's new rows are written at Step 3.2, so their absence is not drift.
- Does the Test Runbook cover the flows introduced in this run (if a runbook path was given)?
- If an ADRs path was given: does every ADR ID cited in the Architecture Doc's Technology Decisions table
  exist and is it still the active one?
- Does anything built in this run contradict the Platform Architecture? (read-only — never edit it)

**Place every drift finding.** Fix it yourself, or hand it to the Finalizer that owns the document —
never leave one unplaced. Write each as `Drift: <doc> — <what> — fixed` or
`Drift: <doc> — <what> — handed to <Finalizer>`. The owners:
- PMBook Update: the PMBook and its history rows, the Version Pointer Sweep.
- Handoff Update: the handoff doc.
- Revision + Changelog, Test Runbook: the revision file, the changelog and the test runbook.
- Yours to fix now: the architecture doc, the test cases doc, and READMEs inside this component's roots.
- Flag only (Unresolvable Issues): diagrams, ADRs and the platform architecture file.

## Known-Red Failures
Classify any failure this run did not cause per your **Pre-Existing Failures** section. The component
map is the Component table above; the live project-management docs are `docs/*/project-management.md`
(never `archive/` or `history/`).

## Accepted Known-Reds
<INSERT one line per test the user ruled at Step 2.2: "- <test> — accepted by the user" or
"- <test> — tracked by <ID>" (ID `<COMPONENT>-OI-NNN`, at the start of an `## Open Items` row's Item
cell in the owning component's PMBook) — or "None">

## Flaky Is a Finding, Not a Verdict
When you read a 1/2 test's locators and waits, look first for a locator that matches
more than it means to (a substring `name`, a non-`exact` role) and an action fired before the component
wired its handler.

## Return Format
Use exactly your own Output Template, after your own Self-Check (its doc paths are the
six above).

## Retry Context (present whenever Previous Issues exist — a retry, or a resume after escalation; omit
it otherwise)
loop_count: <INSERT N>
Retry kind: <INSERT "Doc-only retry" or "Normal retry"; a resume after escalation is "Normal retry">
Previous Issues: <INSERT REVIEWER-INTEGRATION'S ISSUES LIST>
Previous Integration Output: <INSERT PRIOR OUTPUT — Quality Gate Results / Gate Logs / Fixes Applied / Documentation Drift / Unresolvable Issues>
Address only the issues listed. Treat drift sections your prior pass already cleared as still clear
unless a Previous Issue reopens one. A doc-only retry follows your Core Workflow's `Doc-only retry`
rule (same log paths); if an issue turns out to need a code or test change after all, stop and say so under
Unresolvable Issues instead of making it.

## Sub-problem (Divide-and-Conquer only — omit otherwise)
Failing tests in scope: <INSERT>
Files you may touch: <INSERT>
Issues: <INSERT this sub-problem's Reviewer-Integration issues>

## Aggregate pass (Divide-and-Conquer only — omit otherwise)
Every sub-problem reported fixed: <INSERT one line each — sub-problem, files changed>
```

### Artboard Edit Prompt (Step 1.1b, and a UI Iteration's "done")

Spawned as `subagent_type: "orchestrated-developer"`, `model: "sonnet"`.

```
You are updating a design artboard, not application code. You are operating in **orchestrated mode**.

## Artboard
<INSERT the artboard path(s) in artboards-directory, and the artboards folder's README path>

## Target
<INSERT the Acceptance Criteria the artboard must show — or, for a UI Iteration, the numbered tweak
list. Build the artboard to exactly this.>

## Scope
Edit only the artboard files above (author one, per the README, if none exists). Touch no application
code, test or other document. Do not run the test suite.

## Return Format
The files changed, and one line per change: what the artboard now shows that it did not before.
```

### Reviewer-Integration Agent Prompt

```
You are a senior integration reviewer. You review the output of an Integration Agent and return a
verdict. You are operating in **orchestrated mode**.

## Specialist Skill
<INSERT skill name from Step 0.3b, or "None">

## Test Scope Set by the Orchestrator
<INSERT exactly the Test scope line given to the Integration Agent>

## Doc Paths Given to the Integration Agent
<INSERT the list: Test Cases Doc, Architecture Doc, Platform Architecture, PMBook, Test Runbook, ADRs — or
"None provided" for each that was absent>

## Gate Log Directory
<INSERT the same directory given to the Integration Agent>

## Accepted Known-Reds
<INSERT the same section given to the Integration Agent — or "None">
PMBook for each `tracked by` line: <INSERT the owning component's live PMBook path,
`docs/<component>/project-management.md` (never `archive/` or `history/`) — or "None">

## Deferred Integration
<INSERT the Deferred Integration entries given to the Integration Agent at Step 2.1 (ID, files changed,
commit ids) — or "None">
These files and commits count as this run's changes for known-red evidence.

## Task Packets (only the Features and Bugs given as this run's at Step 2.1, condensed — never a Deferred ID's)
<INSERT, PER ITEM: ID, Name/Title, Platform, and — Feature: Acceptance Criteria only; Bug: Bug Report's
Expected/Actual behavior only.>

## Return Format
Use exactly your own Output Template.

## Integration Output
<INSERT INTEGRATION OUTPUT>

## Retry Context
loop_count: <INSERT N — 0 if this is the first review>
Retry kind: <INSERT "Doc-only retry", "Normal retry", or "None — first review". A Divide-and-Conquer
aggregate pass is "Normal retry", at loop_count 3 with the loop_count 3 issues; so is a resume after
escalation.>
Previous Issues (whenever they exist — a retry, or a resume after escalation): <INSERT PREVIOUS ISSUES
LIST, or "None — first review">
Files changed by this retry (doc-only retry only): <INSERT the Orchestrator's before/after snapshot list>
```

### Finalizer Agent Prompt

One template filled once per Phase 3 spawn (or once for a Spike Log). The `model` is an `Agent` tool
parameter from **Model Assignment**, not prompt text.

```
You are a documentation and release-bookkeeping specialist, operating in **orchestrated mode** as one
of the Finalizer invocations closing out this run's completed work.

## Task
<INSERT EXACTLY ONE OF: Graphify | PMBook Update | Handoff Update | Revision + Changelog, Test Runbook | Spike Log>

## Component
<INSERT component name — every file you write belongs to this component's docs, except where the
Version Pointer Sweep instructions say otherwise>

Run ID: <INSERT run id from run-state>
Scope: <INSERT `lane:<ID>` for a P0 lane's batch, `spike:<ID>` for a Spike Log, or `phase3`>

## Features Completed
<INSERT LIST: F-ID, name, files changed — or "N/A, this is a Spike Log Task">

## Bugs Fixed
<INSERT LIST: B-ID, one-line description, files changed, repro steps, `Regression test: <path>` (from
the Developer Output's Test Files Written) — or "None this run" / "N/A">

## Spike Completed (only present when Task is Spike Log)
<INSERT: S-ID, Question, Spike Directory, Files Created, and the Developer's Findings/recommendation
verbatim>

## Edit List
<INSERT one line per edit: <file> — <anchor> — <change>. Omit this section only for Graphify.>

## Task-Specific Inputs
<INSERT — see the matching Phase 3 step in SKILL.md>

## Return Format

Use exactly your own Output Template.
```
