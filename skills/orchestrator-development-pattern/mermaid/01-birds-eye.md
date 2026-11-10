# 01 — Bird's-eye view

The whole run on one page. Each node names its step and the file that draws it in detail.
Hexagons are sub-agent spawns; diamonds are decisions; dotted edges lead to a human pause.

```mermaid
flowchart TD
    Start(["Start: explicit ask<br/>to run the pipeline"])
    Setup["Phase 0 setup<br/>Steps 0.0–0.4<br/>see 02"]
    Entry{"Entry point?<br/>see 02"}
    Loop["Phase 1 work-item loop<br/>Steps 1.1–1.4, 1.3b<br/>see 03"]
    Kind{"Item type?"}
    Spike["Spike Flow<br/>Spike Log only<br/>see 07"]
    MV["Manual Verification Gate<br/>Step 1.5, Bugs only<br/>see 04"]
    Lane["P0 Fast-Lane Finalization<br/>see 07"]
    More{"More work items?"}
    Left{"Any Feature or<br/>non-P0 Bug in the run?"}
    P2["Phase 2 Integration<br/>Steps 2.1–2.3<br/>see 05"]
    P3["Phase 3 Finalization<br/>Steps 3.1–3.6, then the<br/>commit step — see 06"]
    Close["Close-out, always:<br/>metrics rows, RUN row,<br/>run-state complete — see 09"]
    Done(["🏁 Final summary"])
    Esc["🚨 Escalation pause<br/>until resume<br/>see 08"]

    Start --> Setup --> Entry
    Entry -->|"PMBook, Step 0.1"| Loop
    Entry -->|"Bug, Step 0.1b<br/>may be P0"| Loop
    Entry -->|"Spike, Step 0.1c"| Loop
    Setup -->|"resume: saved<br/>Phase 1 item"| Loop
    Setup -->|"resume: saved<br/>Phase 2 step"| P2
    Setup -->|"resume: lane<br/>not done"| Lane
    Setup -->|"resume: all Phase 1<br/>terminal, Phase 2<br/>not started"| Left
    Setup -->|"resume: Phase 3<br/>step"| P3
    Loop --> Kind
    Kind -->|"Spike, after Developer"| Spike
    Kind -->|"Feature PASS"| More
    Kind -->|"Bug PASS"| MV
    MV -->|"verified, not P0"| More
    MV -->|"verified, P0"| Lane
    MV -->|"reports a failure"| Loop
    MV -->|"question: answered,<br/>asked again"| MV
    Spike --> More
    Lane --> More
    More -->|yes| Loop
    More -->|no| Left
    Left -->|yes| P2
    Left -->|"no: skip Phases 2–3"| Close
    P2 -->|"PASS"| P3
    P3 --> Close --> Done
    Loop -.->|"FAIL past loop_count 3<br/>or 3 UNVERIFIED"| Esc
    P2 -.->|"after Divide-and-Conquer<br/>or 3 UNVERIFIED"| Esc
    Esc -.->|"resume"| Loop
    Esc -.->|"resume, Integration"| P2
```

`run-state-file` is saved when each step starts and ends, at every verdict and every user decision, so an
interrupted run can be resumed from Step 0.0 (order in 02); a step found `started` re-runs from its start.
The commit (per `decisions.commit`) is the last step inside Phase 3 and inside each P0 lane, before
close-out; a resumed lane carries on through More to the remaining items. A fast-laned P0 counts as finalized: it does not by itself send the run to Phase 2. When Phase 2 runs, it
waits for every P0 lane to finish and re-validates each fast-laned P0 as a Deferred ID.
