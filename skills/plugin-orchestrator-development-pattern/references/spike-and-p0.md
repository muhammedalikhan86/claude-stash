# Spike Flow and P0 Hotfix Fast Lane

Read by `plugin-orchestrator-development-pattern` only when the run contains a Spike or a `Priority: P0`
Bug. Both are named exceptions to specific steps, not parallel pipelines.

---

## Spike Intake (Step 0.1c, alternate entry point)

Triggered instead of Step 0.1 only when the user explicitly asked for a spike — "spike this", "run a
spike on X" — never inferred from exploratory-sounding language.

1. **No PMBook row needed beforehand** (an ad-hoc spike): once step 2 sizes it, write its `## Spike Log`
   row (Size, Recommendation `In progress`; `SKILL.md` §Sizing). Take the question directly from the user, plus any approaches to try
   ("explore freely" is a valid answer). If the question is unclear, ask.
2. **Assign a Spike ID.** Next number after the highest `<COMPONENT>-S-XXX` in the PMBook's `## Spike Log`
   or among the IDs run-state's queue or `heldForNextRun` already holds; start at `<COMPONENT>-S-001` if none.
   IDs are stable once assigned. **A planned spike** — a PMBook row typed `Spike` (in the Feature Backlog or elsewhere) — keeps that row's ID; never mint a new one for it. Its question and done-when come from the row. **Size it** as a spike (`~/.claude/skills/idea-triage/references/sizing.md`); a planned spike keeps its row's size. An 8 means the
   question is too broad: narrow it with the user before going on.
3. **Assign a Spike Directory.** Default repo-root `spikes/<ID>/`, outside every component's source
   roots and test discovery, unless the user says otherwise. Mandatory. No test config goes there; the
   full gate and Graphify exclude it. If `spikes/` is not in `.gitignore`, say so once and suggest the line (init adds it); until then stage every commit by path so the spike code never rides along.
4. Go to Step 0.2. Steps 0.2–0.4 all run, including Step 0.4's `run-state-file` write (a mid-run intake
   skips that write, `SKILL.md` Step 0.1b item 7); only the announcement differs — one line in place of
   Step 0.4's block, `Spike Mode — <COMPONENT>-S-XXX (<size> pts): <one-line question>`, then the
   `⚠ Deferred Integration outstanding` line if Step 0.0 found any.

## Spike Flow

Reached instead of Step 1.3, right after the Spike's Developer spawn (always
`plugin-orchestrated-developer-high`; a Spike never escalates).

1. The Developer Output *is* the deliverable — Findings plus a recommendation (promote to the Feature
   Backlog / abandon / needs more investigation), with every file inside the Spike Directory. The Developer returns its findings in its Output and writes no report file; the Orchestrator saves them verbatim as `findings.md` in the Spike Directory from the saved Developer Output.
2. **No Reviewer, no retry loop, no Manual Verification Gate, no Integration, no escalation path.**
   `loop_count` never moves. This is a deliberate, accepted risk — it is what makes a Spike fast.
3. Spawn one `orchestrated-finalizer`, Task = `Spike Log`, its `model` from **Model Assignment**, scoped to this Spike, its prompt carrying
   `Scope: spike:<ID>` and its `Size: <pts>`. It
   writes one row to the PMBook's `## Spike Log` (`ID | Size | Question | Recommendation | Spike Directory |
   Follow-up`), creating the section if needed. **A planned spike** also gets Edit List lines for its
   own row: `Status → Done`, and each done-when its row names (e.g. `recorded in architecture §3.5` →
   a line for that file and section). No other Finalizer runs. It waits for any open PMBook writer (below).
4. **Commit the docs, never the spike code.** The Orchestrator commits the governed-doc edits the Spike
   Log Finalizer made (Step 3.5 rules, `Run-Id:` and `Items:` trailers), plus any query files the
   findings rest on, kept in a tracked work folder (Shaw work: record the query a finding rests on). The
   spike code stays where the Developer left it, uncommitted. What happens to it next is the user's call.
5. Print the 🔎 block (`SKILL.md` **Output Format**); save `run-state-file`;
   move to the next work item; when none remain and the run has no Feature and no non-P0 Bug, go to
   Step 3.6's close-out (otherwise Phase 2). The close-out always runs.

A Spike may share a wave with other items (Step 1.0) — its Spike Directory is disjoint from everything by
construction.

---

## P0 Hotfix Fast-Lane Finalization

Triggered only from Step 1.5's `verified` branch, and only for a packet with `## Priority: P0`. Everything upstream —
Developer, the full retry loop, the Manual Verification Gate — is unchanged from a normal Bug; only what
happens after a genuine `verified` differs.

**One PMBook writer at a time.** A P0 lane's Finalizers, a Spike Log Finalizer and another P0 lane
never run concurrently: each waits until the open one has finished (a lane, with its commit if any), then
starts.

1. Run the same Phase 3 batch (Graphify / PMBook Update / Handoff Update / Revision + Changelog, Test
   Runbook — in parallel, models per **Model Assignment**), with Task-Specific Inputs scoped to this one
   Bug, and the PMBook Finalizer's carrying `P0 fast lane: <COMPONENT>-B-XXX, Hotfixed On <date>` and
   `Regression test: <path>` (from the Developer Output's Test Files Written). Its
   `Release label:` comes from Phase 3's **Release label** rule in `SKILL.md`, decided now and saved
   as `decisions` `lane:<ID>`; each Finalizer prompt carries `Scope: lane:<ID>`. The Orchestrator then makes this fast lane's commit itself (Step 3.5,
   with its `Run-Id:` and `Items:` trailers), pushing only on a go. The lane's steps are
   `finalizers → commit → done`, each saved as it starts and ends (`SKILL.md`, **Run-State Checkpointing**).
   **Inside a wave** the other items keep running throughout; stage only this Bug's files.
2. **PMBook Update** for this item: write the `## Bug Log` row with `Status: Hotfixed — Integration
   Pending`, and append a `## Deferred Integration` row (`Bug ID | Hotfixed On | Status: Pending`),
   creating that section if needed.
3. **Graphify** runs here only in a single-item run, or when only Spikes remain (the run has no Feature
   and no non-P0 Bug, and no other P0 still to fast-lane) — before Phase 2 has validated this item, an
   accepted, named exception to "graphify only after Integration passes". Otherwise skip it here: the
   run's own Phase 3 (or the last P0 lane) builds the graph once, over everything, with Step 3.1's
   change check (over the run's own file set, committed or not).
4. **Then move to the next work item; when none remain and the run has no Feature and no non-P0 Bug,
   go to Step 3.6's close-out (otherwise Phase 2).** A lane resumed after a crash does the same: once it
   is `done`, the resume carries on with the remaining items (`references/resume.md`, **Where a resumed run rejoins**,
   rule 8, then rules 9–10). With no Phase 2 to follow, the Deferred Integration
   row stays `Pending` until a later run's Phase 2 re-validates it — that run's Bug Log row then becomes
   `Fixed` and the Deferred row `Resolved` (Step 3.2).
5. When Phase 2 does follow, it waits until every P0 lane has finished. The P0 is not one of this
   run's Phase 2 work items (nor among Reviewer-Integration's packets): Step 2.1 re-reads the PMBook's
   Pending Deferred rows then, so it passes the P0 as a Deferred ID (forcing `Test scope: component` and
   `Full suite: suggested`, Step 2.0) and this
   run's Phase 3 can resolve it. The 🏁 summary prints each P0's status as it stands after Step 3.2.
   Step 3.6 runs once, at the end of the run, and writes the P0's metrics row (terminal state
   `verified`) there.

Output line, right after the 🐛 line:

```
🚑 <COMPONENT>-B-XXX — P0 Fast-Lane Finalization complete
   Status: Hotfixed — Integration Pending
   Deferred Integration row added — full-suite validation still owed
```

A P0 forces `Test scope: component` the next time its Deferred Integration row is re-validated — it
shipped without any suite run at all — and that run flags `Full suite: suggested — P0 <ID>` to the hub
(or, solo, asks the user), who decides on the entire suite (Step 2.0).
