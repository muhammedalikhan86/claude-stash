# 13 — Run-state and resume

`run-state-file` lets a fresh session resume. Full rules: `SKILL.md` **Run-State Checkpointing**
(what is saved, and when) and `references/resume.md` (where a resumed run rejoins).

## When it is written

```mermaid
flowchart TD
    E1("Step 0.4, which Bug and<br/>Spike intakes also run") --> W
    E2("A step starts, a step ends:<br/>Developer, gate, D-and-C stage,<br/>Finalizer batch, commit") --> W
    E3("Every verdict") --> W
    E4("Every user decision,<br/>before acting on it") --> D["decisions: commit, Release<br/>label per scope, known-red<br/>rulings, heldForNextRun,<br/>app-url, artboard-server"]
    D --> W
    E5("Each status change: in progress<br/>(start, FAIL, rejection, resume);<br/>Feature PASS: passed review;<br/>Bug PASS: awaiting verification,<br/>then verified; Spike: findings<br/>recorded; escalated; dropped") --> W
    E6("UI Iteration: opened, each<br/>tweak, doneAt, file set") --> W
    W["Write: each unit's step and<br/>state started or done, plus the<br/>outputs of done steps: Developer<br/>and Integration Outputs, Issues,<br/>verdicts, counters, Parity paths"]
    E8("Step 3.6 close-out") --> C("Mark complete")
```

Nodes: 10. A unit is a work-item attempt, a P0 lane, Phase 2 or Phase 3; a P0 lane's and Phase 3's steps
are `finalizers → commit → done`; a `done` Finalizers step keeps the commit step's file list (Step
3.5: in Phase 3 every in-scope item's `files`, the `integration` block's `files`, Artboard Edit and Finalizer files and
run-state's `orchestratorFiles`, each governed file the Orchestrator writes, appended when written; in a P0 lane that Bug's `files` plus its lane Finalizers' files).
Each item keeps `files`, the union of its Developer Outputs' files over every attempt. The file also holds the run id, the component, the Platform Profile,
Step 0.3's conventions summary, the waves and queue, timestamps (ISO, with the zone, read from the clock),
`linkedRuns`, and in full every packet that is not an unchanged PMBook item. Commits are not recorded
here: each message carries `Run-Id:` and `Items:` trailers, and `git log --grep "Run-Id: <run id>"`
gives the RUN row's commit ids, Step 3.1's roots and Deferred evidence; a commit step itself commits
what of its saved file list `git status` still shows uncommitted. Every governed-doc write updates an
existing entry for the same item (and run id and scope, `lane:<ID>` or `phase3`) instead of adding a second, and a metrics row with the same
Run ID, Item ID and Timestamp (the event time saved in run-state first) is left unchanged (rows are
write-once), so a re-run step is safe; a re-run reuses an event time already saved, never reading the clock again. The
`integration` block keeps Step 2.1's tree snapshot (and a doc-only retry's own "before" snapshot,
reused if that retry re-runs after a crash) and `files`, the union of changed files across every
Integration pass and Divide-and-Conquer sub-problem spawn.

## Resuming

```mermaid
flowchart TD
    S("run-state found, not<br/>complete; Linked: every<br/>file with that run id") --> Ask{"Ask: resume,<br/>or start fresh?"}
    Ask -->|"fresh"| Fresh("Start fresh: announce<br/>heldForNextRun, put it in the<br/>new queue; UI Iteration: copy<br/>it unchanged, no queue")
    Ask -->|"resume"| Pk["Read templates.md; fresh<br/>session: re-write packets,<br/>Developer Outputs, issues,<br/>Integration Output from run-state"]
    Pk --> Prof["Print 0.0a block, announce<br/>heldForNextRun; Profile, waves,<br/>queue from the file"]
    Prof --> Done{"Run complete?"}
    Done -->|"yes"| Nothing("Nothing to resume")
    Done -->|"no"| Esc{"An item with status<br/>escalated, or integration<br/>escalated: true?"}
    Esc -->|"yes"| Un["Status back to in progress<br/>(integration: flag cleared);<br/>save at once"]
    Un -->|"Verification<br/>Blocked"| ResV("Read blockedGate, respawn<br/>it: Reviewer, Parity or R-I;<br/>unverified 0, loop_count<br/>kept, no Developer; then<br/>clear blockedGate")
    Un -->|"other"| UIk{"UI Iteration, code-Reviewer<br/>FAIL or rejected Parity?"}
    UIk -->|"yes"| Step9("Its step 9: Orchestrator<br/>fixes, then the Reviewer, 10")
    UIk -->|"no"| Restart("loop_count and<br/>loopCountAtEscalation 0,<br/>priorLoops += old, issues as Previous Issues;<br/>Developer, or Integration 2.1")
    Esc -->|"no"| UIq{"mode ui-iteration?"}
    UIq -->|"yes"| UIr("ui-iteration.md A long pause:<br/>no doneAt: ask keep iterating<br/>or done; doneAt: rejoin the<br/>gates, 10")
    UIq -->|"no"| Order{"Latest phase first,<br/>first match"}
    Order -->|"Phase 3 done, or nothing<br/>unfinished and Phase 2<br/>not owed"| CO("Step 3.6 close-out:<br/>Spike-only, P0-only too")
    Order -->|"Phase 3 started, R-I PASS,<br/>or a recorded R-I skip"| P3("Phase 3 at its recorded<br/>step; started, not done:<br/>re-run it from its start")
    Order -->|"Phase 2 started"| P2("Its recorded step, saved<br/>snapshot (doc-only retry: its<br/>own), never an R-I skip;<br/>D-and-C running: aggregate;<br/>confirmation pass: its R-I")
    Order -->|"verified P0,<br/>lane not done"| P0("The lane's recorded step;<br/>not started: full lane;<br/>then carry on below")
    P0 --> Rest
    Order -->|"else"| Rest{"Every Phase 1 item terminal:<br/>Feature passed review, Bug<br/>verified, Spike findings recorded,<br/>or dropped; no P0 lane<br/>unfinished; Phase 2 not started?"}
    Rest -->|"yes"| P2E("Phase 2's entry rule:<br/>Phase 2, or close-out<br/>when not owed")
    Rest -->|"no"| P1("Phase 1, first match: awaiting<br/>verification: queue for batched 1.5; UI<br/>with no Design Gate result: 1.1b;<br/>Spike: Spike Log Finalizer;<br/>no verdict: Reviewer if Developer<br/>Output held, else Developer;<br/>UI code PASS: 1.3b")
```

Nodes: 23. Phase 0 is not re-run. An escalation pause is caught right after "run complete", then an
open UI Iteration, both before the phase order. A Step 2.2 skip is recorded in run-state as that step's verdict. A P0 lane is not a first-match stop: once it is done the resume
carries on with the remaining items. A complete run-state's `heldForNextRun` items are queued the same way
by the next run's Step 0.0. A re-run commit step obeys `decisions.commit` (`ask` or unset: ask again,
save the answer) and commits what of its saved file list is still uncommitted. A Spike with a Developer
Output and no Spike Log row gets its Spike Log Finalizer, never a Reviewer. Only a
Divide-and-Conquer escalation stops a second one in the run. A UI packet whose `app-url` or
`artboard-server` is missing asks for it again before Step 1.3b. Other items already terminal stay as
they are; a `dropped` item (the user's explicit "drop" or "defer", saved at once) is terminal and
never rejoined, and Phase 2's entry rule leaves it out. A PMBook item persisted by ID re-derives its packet from the current PMBook and the saved
conventions summary.

## Open questions

None.
