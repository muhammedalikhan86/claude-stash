# 05 — Bug Fix Intake and Manual Verification

## Bug Fix Intake (Step 0.1b)

```mermaid
flowchart TD
    S0("Explicit bug ask, or a<br/>plain fix X while sticky") --> LF{"Only a look-and-feel<br/>ask?"}
    LF -->|"yes, never a bug"| UI("UI Iteration<br/>10")
    LF -->|"no"| Info["1 Collect: what broke,<br/>repro, expected vs actual,<br/>suspected files"]
    Info --> Row{"2 Open Bug Log<br/>row exists?"}
    Row -->|"yes"| UseRow["Use its ID<br/>and description"]
    Row -->|"no"| NextQ{"Bug Log states<br/>the next ID?"}
    NextQ -->|"yes"| UseNext["Use exactly that ID"]
    NextQ -->|"no"| High["Highest COMPONENT-B<br/>plus one, else B-001"]
    UseRow --> Mis
    UseNext --> Mis
    High --> Mis{"4 Design mismatch<br/>on a built screen?"}
    Mis -->|"yes"| MRow["Note the item that built it;<br/>its metrics row waits for<br/>run-state and the saved<br/>event time, 12; fix it<br/>as this Bug"]
    Mis -->|"no"| P0q
    MRow --> P0q{"5 User said P0,<br/>hotfix, prod down?"}
    P0q -->|"yes"| P0["Priority P0,<br/>read spike-and-p0.md"]
    P0q -->|"no"| Go
    P0 --> Go("6 Steps 0.2–0.4,<br/>one-line Bug Fix Mode,<br/>run-state written; 7 mid-run:<br/>same run id, next wave")
```

Nodes: 15. Several bugs at once are queued in the order given; Step 1.0 decides which share a wave.
A mid-run intake (a bug or spike while a run is open) keeps the run id and run-state file and joins
the next wave; once Phase 2 has started its packet is saved in run-state's `decisions.heldForNextRun`
and the next run's Step 0.0 announces it and puts it into its queue (whether the old run completed
or the user chose to start fresh).

## Manual Verification Gate (Step 1.5)

```mermaid
flowchart TD
    S0("Bug Review PASS,<br/>and Parity if UI:<br/>awaiting verification") --> P0q{"Priority P0?"}
    P0q -->|"yes"| Now["Verify this bug now,<br/>on its own, after<br/>every Review PASS"]
    P0q -->|"no"| Queue["Queue for the batched<br/>gate: status awaiting<br/>verification (never passed<br/>review), run-state saved"]
    Queue --> All{"Every item in the run<br/>passed or escalated?"}
    All -->|"no"| Wait("Feature loop<br/>carries on, 03")
    All -->|"yes"| Msg["Post ONE message:<br/>steps, expected,<br/>Parity Table if UI"]
    Msg --> Waiver{"decisions.mvWaiver<br/>active? (non-P0 only)"}
    Waiver -->|"no"| Pause["PAUSE until<br/>the user answers"]
    Waiver -->|"yes"| Deleg["Send the gate block to the<br/>delegate; it approves on<br/>Reviewer PASS + Board Parity<br/>PASS (non-UI: Reviewer only);<br/>verification: waived by …"]
    Deleg -->|"approved"| P0v
    Deleg -->|"reports a failure,<br/>or waiver ended"| Pause
    Now -->|"P0: never waived"| Pause
    Pause --> Ans{"Per bug"}
    Ans -->|"a question"| Answer["Answer it,<br/>ask again"]
    Answer --> Pause
    Ans -->|"reports a failure,<br/>or not fixed"| Retry["Back to 1.4: user text<br/>is the issues list,<br/>loop_count + 1"]
    Retry -->|"passes Review again,<br/>re-post for those bugs"| S0
    Ans -->|"verified"| P0v{"P0?"}
    P0v -->|"yes"| Fast("P0 fast lane<br/>08")
    P0v -->|"no"| Join["Log PASS, manually<br/>verified, joins Integration"]
    Join --> Gate{"Every non-P0 bug<br/>verified or escalated?"}
    Gate -->|"no"| Wait
    Gate -->|"yes, and every<br/>P0 lane done"| P2("Phase 2<br/>06")
```

Nodes: 18. Only a reply that reports a failure (or says it is not fixed) is a rejection; a question
is answered and the gate asked again; a new bug is a mid-run intake, not a rejection. Rejected bugs can run as a wave. With Linked Runs, one message covers every linked run's bugs.
A verified Bug's PMBook row is written `Fixed` at Phase 3 (a P0's `Hotfixed — Integration Pending`).

## Open questions

None.
