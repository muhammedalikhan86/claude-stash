# Spike Flow and P0 Hotfix Fast Lane

Read by `orchestrator-development-pattern` only when a Spike intake (Step 0.1c) builds its packet, a
`Type: Spike` packet reaches Spike Flow, or a `Priority: P0` Bug is `verified` at Step 1.5. Both are named exceptions to specific steps of `SKILL.md`, not parallel
pipelines. Step numbers, **Model Assignment**, **Enforcement Rules** and **Git Restrictions** below refer
to `SKILL.md`.

---

## Spike Task Packet

Built at Step 0.1c. The Feature packet's shape is in SKILL.md's **Task Packet Format**; a Spike's is:

```markdown
# Task Packet: S-XXX — <Spike Question, short form>

## Type
Spike

## Spike ID
S-XXX

## Question
<one paragraph: what we're trying to learn or decide, and why it matters right now — and any
tolerance or threshold that decides the answer (e.g. "within 0.5%"). With none named, the Developer
states its own under Assumptions.>

## Spike Directory
<mandatory — default repo-root spikes/S-XXX/, outside every source root and test discovery path. Every
file the Developer creates or modifies must fall under this path — see orchestrated-developer's Scoped
Confinement for Spike-Type Packets. The full gate and Graphify exclude it.>

## Approaches to Try
<optional — specific candidates to try, or "explore freely" if there's no starting hypothesis>

## Platform
<platform name>

## Developer Quality Gate
- Format: <command, scoped to Spike Directory — or "none" when its files have no formatter, e.g. SQL only>
- Lint:   <command, scoped to Spike Directory — or "none">
- Run:    <with no formatter or linter: each script runs as saved, read-only for a data spike>

## Constraints
- Never create or modify a file outside `## Spike Directory`.
- Never touch the real test suite's discovery path, and add no test config in the Spike Directory.
- Do not run the test suite. Format and Lint only, scoped to the Spike Directory.
<other constraints from Architecture/PRD that apply, if any>

## Expected Output (for the Orchestrator's Spike Log)
A findings write-up: what was learned, and one explicit recommendation — promote to the Feature Backlog /
abandon / needs more investigation. Plus the list of Files Created, all scoped to Spike Directory. There is
no Reviewer for this packet type — see Spike Flow.
```

---

## Spike Flow

Reached instead of Step 1.3, immediately after Step 1.2's Developer Agent spawn, for any `Type: Spike`
packet. There is no acceptance criteria to gate against by design, so nothing below this point resembles
the Feature/Bug loop:

1. The Developer Output *is* the deliverable — Findings (what was learned, a recommendation: promote to
   the Feature Backlog / abandon / needs more investigation), plus Files Created scoped to the Task
   Packet's Spike Directory (see `orchestrated-developer`'s **Scoped Confinement for Spike-Type Packets**). The Developer returns its findings in its Output and writes no report file; the Orchestrator saves them verbatim as `findings.md` in the Spike Directory from the saved Developer Output.
2. **No Reviewer spawn.** A Spike has no Acceptance Criteria for a Reviewer to check against — inventing a
   verdict for open-ended exploration would defeat the point of the pathway.
3. **No retry loop, no Manual Verification Gate, no Integration, no escalation path.** `loop_count` never
   increments for a Spike; there is nothing to retry against and no human checkpoint before this is
   considered final. This is a deliberate, accepted risk — every other work-item type in this pipeline has
   at least one human checkpoint before being final; Spike does not, because that's what makes it fast
   enough to be worth having.
4. Spawn a single `orchestrated-finalizer` sub-agent, Task = `Spike Log`, `model: "sonnet"` (see **Model
   Assignment**), scoped to this one Spike (`Scope: spike:<ID>`), with the `project-management-doc` path, once no P0 lane (with its
   commit if any) is open (one PMBook writer at a time — P0 step 4). It writes exactly one row to the PMBook's `## Spike Log` table
   (`ID | Question | Recommendation | Spike Directory | Follow-up`), creating that section if it doesn't
   exist yet. **A planned spike** (its own PMBook row) also gets that row's `Status → Done` and each
   done-when the row names (e.g. `recorded in architecture §3.5`), as extra Task-Specific Inputs. No other Finalizer task runs — no Graphify, no Handoff Update, no Revision+Changelog, no Test
   Runbook, no Commit Messages, since nothing was integrated or shipped.
5. **Commit the docs, never the spike code.** The Orchestrator commits the governed-doc edits the Spike
   Log Finalizer made (Step 3.6's rules and trailers), plus any query files the findings rest on, kept
   in a tracked work folder (Shaw work: record the query a finding rests on). Spike code stays exactly
   where the Developer left it, inside its Spike Directory, uncommitted — the Orchestrator neither
   commits it (see **Git Restrictions**) nor deletes it. What happens to it next —
   promoted into a real Feature Task Packet, or abandoned in place — is the user's call after reading the
   Spike Log row.
6. Log `🔎 S-XXX <question> — Findings recorded, see Spike Log`; this is its terminal state, so append
   its metrics row and save run-state with status `findings recorded`; move to the next work item; when none remain and the run has no
   Feature and no non-P0 Bug, go to close-out (otherwise Phase 2). A Spike-only run still ends with
   close-out (see **Pipeline Telemetry** in SKILL.md).

## P0 Hotfix Fast-Lane Finalization

Triggered only from Step 1.5's `verified` branch, and only when the Task Packet carries `## Priority: P0`.
The work itself — Developer fix, Step 1.4's full retry loop, Step 1.5's Manual Verification Gate — is
completely unchanged from a normal Bug; only what happens *after* a genuine `verified` differs. The idea:
keep every gate that proves the reported incident is actually resolved, defer only the slow, whole-codebase
part that isn't needed to answer that specific question.

1. Spawn the same parallel `orchestrated-finalizer` Tasks used in Phase 3 (Graphify — see step 3 — /
   PMBook Update / Handoff Update / Revision + Changelog / Test Runbook), then the 1 sequential Commit Messages Task after
   they return — identical roles and models to **Model Assignment**, but Task-Specific Inputs scoped to
   this single Bug only, not a batch. Decide the Release label first, as Phase 3's intro says, saved
   under the scope `lane:<ID>`.
2. **PMBook Update**, for this item specifically: pass `P0 fast lane: <B-ID>, Hotfixed On <date>` and
   `Regression test: <path>`. It writes the `## Bug Log` row with `Status: Hotfixed — Integration Pending`
   (not `Fixed`), and appends a new row to `## Deferred Integration` (`Bug ID | Hotfixed On | Status:
   Pending`, with the regression test path), creating that section if it doesn't exist yet. See the
   Enforcement Rules' named exceptions to "NEVER skip a phase" and "NEVER run graphify before Integration
   passes."
3. **Graphify runs here**, before Phase 2 has validated this item — an accepted, named exception (see
   Enforcement Rules), since the fast lane's entire purpose is shipping before the full-suite gate runs.
   **Except in a multi-item run whose queue holds a Feature or non-P0 Bug:** skip it there; the run's
   own Phase 3 builds the graph. When it does run, Step 3.1's no-change skip applies here too.
4. **One PMBook writer at a time:** a P0 lane's Finalizers (Commit Messages included), a Spike Log
   Finalizer and another P0 lane never run concurrently; each waits for the open one — a lane, with its
   commit if any — to finish.
5. The lane is a run-state unit (see **Run-State Checkpointing** in SKILL.md): its steps are Finalizers →
   commit (Step 3.6) → done, each saved when it starts and ends; the commit step's file list is that Bug's
   run-state `files` plus its lane Finalizers' files, and its Finalizers get `Scope: lane:<ID>`. Move to the next work item; when none remain and the run has no Feature and no non-P0 Bug, go to
   close-out (otherwise Phase 2). The Deferred Integration row this lane wrote stays `Pending` until a
   Phase 2 re-validates it — this run's, when it has one (Step 2.1 re-reads the row), or a later run's (see **Phase 2 — Integration** in SKILL.md). This
   subsection does not end the run by itself.
