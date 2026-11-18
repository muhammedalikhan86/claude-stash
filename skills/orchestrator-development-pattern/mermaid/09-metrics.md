# 09 — Metrics: which event writes which row

The Orchestrator appends to `metrics-log-file` itself, never overwriting (SKILL.md Pipeline Telemetry).
Every row kind uses the same 18-cell header; `—` where a cell does not apply.

```mermaid
flowchart TD
    Item["Work item terminal: PASS<br/>(Feature: row at close-out,<br/>Bug on 'verified'), Escalated,<br/>Findings recorded, or Dropped<br/>(when the drop is saved)"]
    Int["Phase 2 terminal:<br/>PASS or Escalated"]
    Close["Close-out, always —<br/>also Spike-only and P0-only;<br/>run-state marked complete"]
    Pause["Escalation pause:<br/>run-state saved,<br/>NOT marked complete"]
    Mis["Step 0.1b: design mismatch<br/>on a built screen, noted;<br/>written after Step 0.4<br/>saves run-state and event time"]
    RowI["Item row: loop_count minus<br/>loopCountAtEscalation, UNVERIFIED<br/>and Parity mismatches for this<br/>leg, from run-state"]
    RowInt["Integration row: Test scope affected or full,<br/>Divide-and-Conquer?, Known-reds"]
    RowRun["RUN row: Type Run; Verdict<br/>Complete at 🏁, or Paused (escalation)<br/>at a pause; Phase times P0 · P1 · MV · P2 · P3"]
    Commit["User says commit"]
    Ids["Set commit ids from<br/>git log --grep Run-Id<br/>on this run's latest RUN row"]
    RowM["Append Mismatch row:<br/>Type Mismatch, count 1"]
    Hdr{"File header<br/>matches current?"}
    New["Add From date section<br/>with current header"]
    App(["Timestamp = saved event time;<br/>same Run ID, Item ID, Timestamp<br/>already there: leave it, skip;<br/>else append; check 18 cells"])

    Item --> RowI
    Int --> RowInt
    Close -->|"an item with no row<br/>for its current leg<br/>(a Dropped row counts)"| RowI
    Close -->|"Complete"| RowRun
    Pause -->|"Paused (escalation)"| RowRun
    Mis --> RowM
    Commit --> Ids
    RowRun -->|"when written: close-out<br/>or escalation pause"| Ids
    RowI --> Hdr
    RowInt --> Hdr
    RowRun --> Hdr
    RowM --> Hdr
    Hdr -->|"yes, or new file"| App
    Hdr -->|no| New --> App
```

The Integration row is written only if Phase 2 ran; the RUN row always. A dropped item gets one row,
Verdict `Dropped`, when the drop is saved, using the saved event time. An Escalated row is appended at
the moment of escalation; a resumed item gets a second row at its next terminal state. A resumed run
ends with a second RUN row, `Complete`. A RUN row takes this run's commit ids from `git log --grep
"Run-Id: <run id>"` when written and after each later commit (never another run's row). Writes are
repeat-safe: every row kind takes its Timestamp from the event time saved in run-state before the row is
written (an event time already saved is reused on a re-run, never read again), and rows are write-once: a row with the same Run ID, Item ID and Timestamp already in the log is left
unchanged, so a re-run skips it (legs, Paused vs Complete and second mismatch reports have different event times, so
all survive). Final loop_count on every row (an Escalated row included) is
`loop_count` minus `loopCountAtEscalation`, 0 when never escalated; an Escalated row takes it from run-state's
saved `escalationFinalLoopCount`, so a re-run writes the same value. Stored UNVERIFIED and Parity mismatch counts are
cleared once an item's row is written, so each leg counts only its own. The RUN row's
Wave, Final loop_count, Escalated? and UNVERIFIED count are `—`, and Started / Finished are the run's
start and end. An old row takes only one edit: the RUN row's appended commit ids. A mismatch is always its own appended row.

**Step rows.** Besides the rows above, one row per step (each agent spawn, and each wait on the user,
a usage limit), appended the moment the step ends: Type `Step: <role>` or `Wait: <what>`,
Started from run-state's `steps`, Finished = Timestamp, Final loop_count = the attempt, Phase times = its
length in minutes. A step cut off is written on resume as `interrupted`. Close-out and the retry
counters ignore step rows (`SKILL.md` **Pipeline Telemetry**).
