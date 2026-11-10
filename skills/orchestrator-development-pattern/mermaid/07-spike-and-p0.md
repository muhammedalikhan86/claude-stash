# 07 — Spike Flow and P0 Hotfix Fast Lane

Both are named exceptions to specific steps, not separate pipelines (`references/spike-and-p0.md`).

## Spike Flow

```mermaid
flowchart TD
    Ask(["User asks for a spike"])
    Intake["Step 0.1c: question,<br/>next S-XXX, Spike Directory<br/>default repo-root spikes/S-XXX/,<br/>outside source roots and tests"]
    Dev{{"Step 1.2 Developer<br/>sonnet, no escalation;<br/>writes only in Spike Directory"}}
    Find["Developer Output =<br/>Findings + recommendation"]
    Log{{"Spike Log Finalizer<br/>sonnet, solo,<br/>Scope spike:ID"}}
    Row["One PMBook Spike Log row:<br/>ID, Question, Recommendation,<br/>Directory, Follow-up"]
    Keep["Spike code stays<br/>uncommitted in place"]
    Term["Terminal: Findings recorded;<br/>🔎 S-XXX, metrics row,<br/>run-state saved"]
    Next(["Next item, or Phase 2 /<br/>close-out if none, see 01"])

    Ask --> Intake --> Dev --> Find --> Log --> Row --> Keep --> Term --> Next
```

No Reviewer, retry loop, Manual Verification Gate, Integration, other Finalizer or escalation;
`loop_count` never moves. Whether the spike code is promoted or abandoned is the user's call. A
Spike-only run skips Phases 2–3 and still runs close-out. On resume, a Spike with a Developer Output
and no Spike Log goes to its Spike Log Finalizer, never a Reviewer (02).

## P0 Hotfix Fast-Lane Finalization

```mermaid
flowchart TD
    In(["Step 1.5: verified,<br/>Priority: P0"])
    Label["Decide Release label<br/>as Phase 3 does, saved as<br/>decisions lane:ID"]
    Fin{{"Phase 3 parallel Finalizers,<br/>scoped to this one Bug;<br/>Graphify per 06"}}
    PM["PMBook Update: Bug Log<br/>Hotfixed — Integration Pending;<br/>Deferred row Pending, test path"]
    CM{{"Commit Messages<br/>after its own Finalizers"}}
    Log["Commit per decisions.commit:<br/>Bug's files + lane Finalizers'<br/>files still uncommitted;<br/>log 🐛 then 🚑 B-XXX; lane done"]
    More{"More work items?"}
    Loop(["Back to Phase 1<br/>see 03"])
    Left{"Any Feature or non-P0<br/>Bug in the run?"}
    P2(["Phase 2 after every P0 lane<br/>finishes; re-validates this<br/>P0 as a Deferred ID, see 05"])
    Close(["Skip Phases 2–3;<br/>close-out"])
    Later["Later run: Step 0.4 warns;<br/>its Phase 2 re-validates ID;<br/>Step 3.2 flips to Resolved"]

    In --> Label --> Fin
    Fin --- PM
    Fin --> CM --> Log --> More
    More -->|yes| Loop
    More -->|no| Left
    Left -->|yes| P2
    Left -->|no| Close
    Close -.-> Later
```

Graphify in the fast lane: skipped when the queue holds a Feature or non-P0 Bug (the run's own Phase 3
builds the graph); otherwise it runs before Integration — a named exception — subject to the same
no-change skip as Step 3.1. Every gate up to Step 1.5 is unchanged for a P0; only full-suite Integration
is deferred, never skipped. One PMBook writer at a time: a P0 lane's Finalizers, a Spike Log Finalizer
and another P0 lane never run concurrently; each waits for a lane, with its commit if any. The lane is a
run-state unit with steps Finalizers → commit → done, each saved when it starts and ends; a resume rejoins
a lane not `done` at its recorded step and then carries on with the remaining items (02). Its commit
step's file list is the Bug's run-state `files` plus its lane Finalizers' files, and it commits whatever of
that list `git status` still shows uncommitted; Phase 2 takes this P0's files from run-state, and commit ids
from `git log --grep "Run-Id: <run id>"` only when any exist.
