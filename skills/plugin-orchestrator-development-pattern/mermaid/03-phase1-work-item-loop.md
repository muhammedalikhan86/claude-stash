# 03 — Phase 1: the work-item loop (Steps 1.0–1.4)

## Running a wave (Step 1.0)

```mermaid
flowchart TD
    W("Wave starts,<br/>up to 3 items") --> Spawn["Spawn each item's first<br/>agent in one message"]
    Spawn --> Ret["As each returns: save<br/>run-state, spawn that<br/>item's next step"]
    Ret --> EscQ{"An item<br/>escalated?"}
    EscQ -->|"yes"| Sib("Siblings finish current<br/>spawn, then pause<br/>09")
    EscQ -->|"no"| Fin{"Every item passed,<br/>queued or escalated?"}
    Fin -->|"no"| Ret
    Fin -->|"yes"| Col{"Collision check:<br/>two items touched<br/>the same file?"}
    Col -->|"yes"| Re["Respawn both Reviewers<br/>on current tree,<br/>no loop_count change"]
    Re --> Ser["Serialize those two<br/>in any later retry"]
    Ser --> Next
    Col -->|"no"| Next("Next wave, or<br/>Step 1.5 when none left")
```

Nodes: 10. A P0 that passes Review takes its fast lane (`08`) while the rest of its wave keeps
running.

## One item: packet to verdict (Steps 1.1–1.3)

```mermaid
flowchart TD
    S0("Item starts<br/>loop_count 0") --> TP["1.1 Task Packet<br/>from templates.md"]
    TP --> SaveP["Save packet-ID.md,<br/>full packet in run-state<br/>if added to"]
    SaveP --> UIq{"Touches a UI?"}
    UIq -->|"yes"| DG("1.1b Design Gate,<br/>re-save packet<br/>04")
    UIq -->|"no"| RO
    DG --> RO{"Mode<br/>review-only?"}
    RO -->|"yes"| BR["Build Record in place of<br/>Developer Output:<br/>files, summary"]
    BR --> Save
    RO -->|"no"| Dev{{"1.2 Developer<br/>developer-high, opus<br/>xhigh at loop 3"}}
    Dev --> Save["Save output verbatim<br/>devout-ID-legN-retryN.md,<br/>run-state"]
    Save --> Q{"Open question<br/>inside packet scope?"}
    Q -->|"yes"| Rule["Orchestrator rules,<br/>scope change: user rules"]
    Rule -->|"SendMessage, same spawn,<br/>no loop_count change"| Dev
    Q -->|"no"| Sp{"Type Spike?"}
    Sp -->|"yes"| SpOut("Spike Flow<br/>08")
    Sp -->|"no"| Up["Bug with E2E regression<br/>test: stack up first"]
    Up --> Rev{{"1.3 Reviewer<br/>sonnet, opus at loop 3"}}
    Rev --> Out("Verdict<br/>next diagram")
```

Nodes: 16. The Reviewer gets the packet path, the verbatim Developer Output path and any ruling,
marked binding. On a Bug it runs the one named regression test.

## Handling the verdict (Steps 1.3, 1.3b, 1.4)

```mermaid
flowchart TD
    V{"Reviewer verdict,<br/>run-state saved"} -->|"UNVERIFIED"| U{"unverified_count<br/>above 2?<br/>unverifiedTotal + 1"}
    U -->|"yes"| EscV("Escalate: Verification<br/>Blocked, 09")
    U -->|"no"| Fix["Fix what it points at,<br/>else respawn unchanged"]
    Fix --> V
    V -->|"FAIL"| Where{"Issues in another<br/>component's files?"}
    Where -->|"all of them, or<br/>a linked sibling's"| XC("No retry here,<br/>loop_count unchanged<br/>11")
    Where -->|"none, or some:<br/>ask to raise linked item"| Free{"Free FAIL? review-only<br/>first FAIL, all issues<br/>overruled, or Reviewer's<br/>own miss once"}
    Free -->|"all overruled:<br/>PASS by ruling"| DR
    Free -->|"review-only first FAIL"| First("First Developer: packet,<br/>Review Findings to Fix,<br/>no Previous Attempt")
    Free -->|"own miss"| Retry
    Free -->|"no"| Over{"loop_count<br/>already 3?"}
    Over -->|"yes: this FAIL<br/>takes it past 3"| Esc("Escalate, loop_count<br/>stays 3, pause, 09")
    Over -->|"no"| Inc["loop_count + 1"]
    Inc --> Retry("Fresh Developer: packet,<br/>issues, previous files<br/>loop 3: xhigh + opus Reviewer")
    V -->|"PASS"| DR{"Packet has a<br/>Design Reference?"}
    DR -->|"yes"| Par{{"1.3b Board Parity Check<br/>04"}}
    Par -->|"FAIL: mismatches are the<br/>issues, marked verified<br/>by 1.3b for the Reviewer"| Where
    DR -->|"no"| Kind{"Item type"}
    Par -->|"PASS"| Kind
    Kind -->|"Feature"| Feat("Passed in run-state,<br/>PMBook Done at Phase 3")
    Kind -->|"Bug, not P0"| Queue("Queued for batched<br/>Step 1.5, 05")
    Kind -->|"Bug, P0"| P0("Step 1.5 now, then<br/>fast lane; wave<br/>keeps running, 08")
```

Nodes: 18. UNVERIFIED never touches `loop_count`; nor does a spawn that returns no Output (one nudge,
then a respawn). The free FAILs and the overrule guard are Step 1.4's three rules, checked before the escalation check; a Reviewer's
`Outside this item` findings never enter this loop — they go to the item's `outsideItem` list. A Parity FAIL whose mismatch lies in another
component's files (e.g. the shell's theme) takes the same cross-component route as a code FAIL.

## Who sends what to whom

```mermaid
sequenceDiagram
    participant O as Orchestrator
    participant D as Developer, opus
    participant R as Reviewer, sonnet
    participant P as Parity Reviewer, sonnet
    participant U as User
    O->>O: save packet-ID.md, run-state
    alt review-only item
        O->>O: write the Build Record to devout-ID.md, run-state
    else
        O->>D: Task Packet, Developer Agent Prompt
        D-->>O: Developer Output
        O->>O: save it verbatim to devout-ID[-legN][-retryN].md, run-state
    end
    opt open question inside packet scope
        O->>D: ruling, SendMessage to the same spawn
        D-->>O: updated Developer Output
    end
    O->>R: packet path, devout path, binding ruling, loop_count
    R-->>O: PASS, FAIL with issues, or UNVERIFIED
    alt FAIL
        O->>D: fresh spawn with packet, issues, previous files
    else PASS on a packet with a Design Reference
        O->>P: Parity Prompt with packet path, app URL, board URL, widths
        P-->>O: Parity Table and verdict
        opt Parity FAIL
            O->>D: fresh spawn, mismatches as issues
            O->>R: parity items marked verified by Step 1.3b, not by you
        end
    end
    opt Bug items awaiting verification, once every item is through Review
        O->>U: one Manual Verification message
        U-->>O: verified, a question (answered, asked again), or a reported failure
    end
```

## Open questions

None.
