# 01 — Bird's-eye view

The whole run. Each box names its step numbers and the file that draws it in detail.
Linked Runs (two components that must land together) wrap this whole flow: see `11-linked-runs.md`.
`run-state-file` is written at every gate along the way (`13-run-state-and-resume.md`).

```mermaid
flowchart TD
    S0("Start: explicit ask") --> R["Step 0.0a resolve component<br/>Step 0.0 deps, resume check<br/>02, 13"]
    R --> E{"Entry point"}
    E -->|"PMBook"| ReadPM["Step 0.1 read PMBook<br/>phase, Planned items"]
    ReadPM --> Setup["Steps 0.2–0.4 platform,<br/>skill, waves, announce,<br/>write run-state<br/>02"]
    E -->|"Bug, P0 if user says so"| Bug["Step 0.1b Bug Fix Intake<br/>05"]
    E -->|"Spike"| Spike["Step 0.1c Spike Intake<br/>08"]
    E -->|"look and feel"| UI["Step 0.1d UI Iteration<br/>no gates until done<br/>10"]
    Bug --> Setup
    Spike --> Setup
    Setup --> Loop["Phase 1, Steps 1.0–1.4<br/>waves of up to 3,<br/>Developer → Reviewer,<br/>UI: Design Gate, Parity<br/>03, 04"]
    Loop -->|"a Spike"| SpEnd["Spike Log only,<br/>no commit<br/>08"]
    Loop -->|"a P0, verified"| P0["P0 fast lane: Finalizers<br/>and commit for that bug<br/>08"]
    SpEnd -.->|"next item, or<br/>Phase 2 / close-out"| Loop
    P0 -.->|"next item, or<br/>Phase 2 / close-out"| Loop
    Loop -->|"FAIL past loop_count 3,<br/>UNVERIFIED x3, or<br/>linked item declined"| Esc("Escalate: metrics row,<br/>run-state, pause<br/>09")
    Esc -.->|"resume at saved position:<br/>a Phase 1 item, 13"| Loop
    Esc -.->|"resume at saved<br/>position: Phase 2"| P2
    Loop -->|"all passed Review"| MV["Step 1.5 Manual Verification<br/>queued Bugs, if any<br/>05"]
    MV --> Left{"Run has a Feature<br/>or non-P0 Bug?"}
    Left -->|"yes"| P2["Phase 2, Steps 2.0–2.3<br/>Integration +<br/>Reviewer-Integration<br/>06"]
    UI -->|"done: rest of Phase 0,<br/>Design Gate, one Reviewer,<br/>Parity once"| P2
    P2 -->|"escalation (D-and-C,<br/>UNVERIFIED x3)"| Esc
    P2 --> P3["Phase 3, Steps 3.1–3.5<br/>parallel Finalizers,<br/>commit, push on a go<br/>07"]
    Left -->|"no: only Spikes,<br/>fast-laned P0s"| Close
    P3 --> Close("Step 3.6 close-out,<br/>every run: metrics,<br/>run-state complete<br/>07, 12")
```

Nodes: 17. The UI Iteration also runs Step 1.4's retry rules for its one Reviewer, which this view
folds into the "done" edge (`10-ui-iteration.md`).

## Open questions

None.
