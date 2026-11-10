# 08 — Escalation

Three situations pause for a human (SKILL.md Escalation; `references/escalation.md`). Spike work items
never reach any of them.

```mermaid
flowchart TD
    T1["A real FAIL takes loop_count<br/>past 3 (it stays 3): any item,<br/>or Integration"]
    T2["Reviewer, Parity Check or<br/>Reviewer-Integration<br/>UNVERIFIED a 3rd time, or<br/>any spawn's Output missing<br/>twice in a row"]
    T3["Divide-and-Conquer<br/>confirmation still FAILs"]
    IntQ{"Integration?"}
    Ran{"Divide-and-Conquer<br/>already run this batch?"}
    DC(["Divide-and-Conquer first,<br/>see 05"])
    Save["First save run-state, not complete:<br/>event time, status escalated<br/>(integration block escalated: true),<br/>escalationFinalLoopCount,<br/>loopCountAtEscalation,<br/>blockedGate on Report 2"]
    Rec["Then append metrics row Escalated<br/>(Final loop_count as saved)<br/>and RUN row Paused (escalation)"]
    R1["Report 1: Implementation —<br/>last issues verbatim,<br/>Escalated Model tried"]
    R2["Report 2: Verification Blocked —<br/>last Unable to Verify verbatim,<br/>or Missing Outputs: 2 and<br/>what the spawn last said"]
    R3["Report 3: Integration after<br/>Divide-and-Conquer —<br/>still-failing only"]
    Pause["⏸ Orchestrator is PAUSED.<br/>Waiting for instruction."]
    Wait{"User types resume or<br/>gives explicit instruction?"}
    Kind{"Report 2?"}
    Unp["Status back to in progress<br/>(clear the block's flag);<br/>save run-state at once"]
    Again(["Read blockedGate, respawn that gate:<br/>Reviewer, Parity Check or<br/>Reviewer-Integration (or, for missing<br/>Outputs, that role); unverified_count 0;<br/>then clear blockedGate"])
    Reset["loop_count 0 and<br/>loopCountAtEscalation 0,<br/>escalation's issues as<br/>Previous Issues, priorLoops += 3"]
    Go(["Respawn Developer, or<br/>Integration for Phase 2"])
    Drop(["Status dropped, saved at once<br/>with the event time: terminal, out of<br/>Phase 2's entry rule and the resume rules;<br/>one metrics row, Verdict Dropped;<br/>in 🏁 summary"])

    T1 --> IntQ
    IntQ -->|"no: work item"| Save
    IntQ -->|yes| Ran
    Ran -->|"yes: Report 1"| Save
    Ran -->|"no, splittable"| DC
    Ran -->|"no, not splittable"| Save
    T2 --> Save
    T3 --> Save
    Save --> Rec
    Rec -->|"real FAIL"| R1
    Rec -->|"3rd UNVERIFIED or<br/>2nd missing Output"| R2
    Rec -->|"after Divide-and-Conquer"| R3
    R1 --> Pause
    R2 --> Pause
    R3 --> Pause
    Pause --> Wait
    Wait -->|"no: stay paused"| Pause
    Wait -->|resume| Unp --> Kind
    Wait -->|"drop or defer"| Drop
    Kind -->|yes| Again
    Kind -->|no| Reset --> Go
```

A Manual Verification rejection counts as a FAIL toward `loop_count` (04), so it reaches Report 1; the
`loop_count` 3 attempt always ran on the Escalated Model, whichever kind of FAIL led there. A resumed
item gets a second metrics row at its next terminal state, whose Final loop_count is that leg's count
(09). Every row's Final loop_count, the Escalated row's included, is `loop_count` minus run-state's
`loopCountAtEscalation` (0 when never escalated), read before this escalation overwrites it. Run-state
(event time, `escalated` status, `escalationFinalLoopCount` — the Escalated row's Final loop_count, so a
re-run writes the same value — and `loopCountAtEscalation`) is saved before the rows are appended. An
explicit user "drop" or "defer" sets the item `dropped` instead of resuming it, and writes its one
metrics row (Verdict `Dropped`, Timestamp the saved event time), which close-out counts. Resuming
Report 2 leaves `loop_count`, `priorLoops` and Previous Issues as they were; a restart at `loop_count` 0
also sets `loopCountAtEscalation` to 0. The pause is not close-out:
run-state stays incomplete, and the resumed run's close-out appends a second RUN row, `Complete`.
