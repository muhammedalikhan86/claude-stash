# 09 — Escalation and Divide-and-Conquer

Full templates: `references/escalation.md`. A Spike never reaches any of this.

## Divide-and-Conquer — the last attempt for Integration

```mermaid
flowchart TD
    T3("Integration: the R-I FAIL<br/>that takes loop_count past 3") --> Ran{"Already escalated this run?<br/>run-state<br/>divideAndConquer done"}
    Ran -->|"yes"| E0("Template 1, Step<br/>Integration; escalate, below")
    Ran -->|"no"| One{"One root cause<br/>spans everything?"}
    One -->|"yes"| E1("Template 1, Step Integration,<br/>D-and-C not applicable, stays<br/>not run; escalate, below")
    One -->|"no"| Split["Split issues by file<br/>or module; dependent errors<br/>stay together; then set<br/>divideAndConquer running"]
    Split --> Subs{{"One Integration per<br/>sub-problem, opus, parallel:<br/>Sub-problem section,<br/>self-verify only that"}}
    Subs --> Sort{"Every sub-problem<br/>self-verified clean?"}
    Sort -->|"no"| E3("Template 3, scoped to<br/>still-failing sub-problems;<br/>escalate, below")
    Sort -->|"yes"| Agg{{"Aggregate pass: one<br/>Integration, opus, full gate<br/>at Test scope, full Output"}}
    Agg --> Untr{"Any known-red<br/>untracked?"}
    Untr -->|"yes"| Ask["Ask the user per test:<br/>raise item, or accept"]
    Ask --> RI
    Untr -->|"no"| RI{{"Reviewer-Integration once,<br/>opus, Normal retry,<br/>no loop_count change"}}
    RI -->|"PASS"| P3("Phase 3<br/>07")
    RI -->|"FAIL"| E3
```

Nodes: 14. Every sub-problem and the aggregate pass get the run's `## Accepted Known-Reds`.
Divide-and-Conquer runs only on the FAIL that takes loop_count past 3, and never again once it has
escalated. Run-state's `integration.divideAndConquer` records its stage (`running` only once the split
succeeds, `confirmation pass` at the aggregate pass, then `done` when it decides or escalates); a "not
splittable" escalation leaves it `not run`. A crash resumes it: `running` re-runs the aggregate pass,
`confirmation pass` respawns its Reviewer-Integration. Its resolved
sub-problems are recorded in the Integration Output, never committed. When it does not apply, the
Integration metrics row's `Divide-and-Conquer triggered?` is `No (one root cause)`.

## Escalating, pausing and resuming

```mermaid
flowchart TD
    T1("Item FAIL that takes<br/>loop_count past 3") --> Rec
    T4("User declines a<br/>linked item, 11") --> Rec
    T5("Divide-and-Conquer<br/>not applicable") --> Rec
    T2("Reviewer, Parity or R-I:<br/>UNVERIFIED 3rd in a row") --> Rec
    T3("D-and-C: sub-problem still<br/>failing, or aggregate FAIL") --> Rec
    Rec["First run-state: event time,<br/>status escalated (integration:<br/>escalated true), last Issues and<br/>Unable to Verify, loop_count,<br/>the row's Final loop_count, then<br/>loopCountAtEscalation, latest<br/>Output, blockedGate if UNVERIFIED x3;<br/>then metrics row escalated,<br/>Escalated? Yes, saved<br/>Final loop_count"] --> Which{"Which situation?"}
    Which -->|"real FAIL, declined<br/>link, no D-and-C"| E1["Template 1:<br/>Implementation"]
    Which -->|"UNVERIFIED x3"| E2["Template 2:<br/>Verification Blocked"]
    Which -->|"after D-and-C"| E3["Template 3: Integration<br/>after Divide-and-Conquer"]
    E1 --> Wave{"Inside a wave?"}
    E2 --> Wave
    E3 --> Wave
    Wave -->|"yes"| Sib["Siblings finish their<br/>current spawn, record"]
    Wave -->|"no"| Close
    Sib --> Close["Close-out lines 1–2: rows so far,<br/>RUN row Paused (escalation),<br/>run-state saved, not complete"]
    Close --> Pause("PAUSED until resume,<br/>or explicit instruction")
    Pause -->|"resume"| Un["Status back to in progress<br/>(integration: flag cleared);<br/>save at once"]
    Un -->|"Template 1 or 3"| Res("loop_count and loopCountAtEscalation<br/>0, priorLoops += old, issues as<br/>Previous Issues; respawn<br/>Developer, or Integration at 2.1;<br/>UI Iteration code-Reviewer or<br/>Parity FAIL: its step 9, 13")
    Pause -->|"drop or defer"| Drop("Status dropped, saved<br/>at once with event time;<br/>one Dropped metrics row;<br/>terminal, out of Phase 2's<br/>entry rule, in the summary")
    Un -->|"Template 2"| ResV("Read blockedGate, respawn<br/>that gate: Reviewer, Parity<br/>or R-I, on the saved Output<br/>(missing Outputs: that role);<br/>unverified 0, loop_count kept;<br/>then clear blockedGate")
```

Nodes: 19. Integration has no wave, so its escalations take the "no" edge. A Verification Blocked
resume keeps `loop_count` and `priorLoops`. Every metrics row, the escalation row included, has Final
loop_count = `loop_count` minus `loopCountAtEscalation` (0 when never escalated); the escalation saves it in run-state first, so a re-run writes the same value. The resumed run, when it finishes, adds a `Complete` RUN row. A declined linked item
with a retry in flight escalates once that retry returns.

## Open questions

None.
