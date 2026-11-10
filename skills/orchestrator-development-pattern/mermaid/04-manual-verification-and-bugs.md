# 04 — Manual Verification Gate and the Bug path

## A Bug from intake to the gate

```mermaid
flowchart TD
    Ask(["User asks to<br/>orchestrate a fix"])
    Intake["Step 0.1b Intake:<br/>repro, expected, actual;<br/>ask if missing"]
    Id["Next B-XXX from PMBook,<br/>run-state queue and<br/>heldForNextRun"]
    P0{"User said P0<br/>or hotfix?"}
    Flag["Packet gets<br/>Priority: P0"]
    State["One-liner announced;<br/>run-state written with<br/>the full packet"]
    Tests["Note on Tests: regression<br/>test path or 'Developer<br/>names it'; one-test command"]
    Loop["Phase 1 loop, see 03:<br/>Reviewer runs that one test,<br/>path from Test Files Written"]
    Gate(["Step 1.5 gate<br/>diagram below"])

    Ask --> Intake --> Id --> P0
    P0 -->|yes| Flag --> State
    P0 -->|no| State
    State --> Tests --> Loop
    Loop -->|"code PASS,<br/>Parity PASS if UI"| Gate
```

Several bugs at once run in the order given; two likely to touch the same files are said so and
serialized.

## Step 1.5 — Manual Verification Gate

```mermaid
flowchart TD
    In(["Bug packet PASS:<br/>status awaiting verification"])
    Post["Post gate: repro steps,<br/>expected behaviour,<br/>Parity Table if UI bug"]
    Pause["PAUSE: run-state holds<br/>'awaiting verification';<br/>spawn nothing"]
    Reply{"User reply?"}
    Answer["Answer it;<br/>ask again"]
    NewBug["Mid-run intake:<br/>append to queue,<br/>ask again"]
    Detail{"Says what<br/>is wrong?"}
    AskOnce["Ask once for<br/>what is wrong"]
    P0{"Priority: P0?"}
    Hold["Terminal PASS: hold in run-state<br/>with regression test path;<br/>🐛 B-XXX, metrics row"]
    Lane(["P0 Fast-Lane<br/>Finalization, see 07"])
    Next(["Next work item,<br/>or Phase 2 if none, see 01"])
    LC["Reply = issues list;<br/>status in progress"]
    Max{"loop_count already 3?<br/>this FAIL takes it past 3"}
    Esc(["🚨 Escalate<br/>see 08"])
    Dev(["Developer retry,<br/>Step 1.4, see 03"])

    In --> Post --> Pause --> Reply
    Reply -->|"verified:<br/>status verified"| P0
    Reply -->|"a question"| Answer --> Pause
    Reply -->|"a different,<br/>new bug"| NewBug --> Pause
    Reply -->|"reports a failure<br/>or not fixed"| Detail
    Detail -->|yes| LC
    Detail -->|no| AskOnce --> LC
    LC --> Max
    P0 -->|no| Hold --> Next
    P0 -->|yes| Lane
    Max -->|"yes: stays 3"| Esc
    Max -->|"no: loop_count += 1"| Dev
```

A question is answered and the gate asked again; it is not a rejection. Nor is a report of a different
bug: that is a mid-run intake (same run, appended to the queue). A rejection is handled the same whether or not the Bug is P0; the fast lane only changes what follows a
genuine "verified". Features never pass through this gate. Step 3.2 writes a non-P0 Bug's `## Bug Log`
row with Status `Fixed` and the regression test path in its Description (06).
