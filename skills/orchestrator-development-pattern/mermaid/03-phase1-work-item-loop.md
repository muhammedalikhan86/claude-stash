# 03 — Phase 1: the work-item loop

One work item at a time, in dependency order. `loop_count` starts at 0 per item. Models come from
SKILL.md's Model Assignment: base model at `loop_count` 1–2, Escalated Model at 3. `run-state-file` is
saved after every Developer return and every Reviewer or Parity verdict.

## Steps 1.1–1.4 — Developer, Reviewer, retries

```mermaid
flowchart TD
    Start(["Next work item:<br/>status in progress"])
    Packet["Step 1.1 Task Packet,<br/>saved to runs/run-id/<br/>packet-ID.md"]
    UI{"UI packet and<br/>artboards-directory set?"}
    Ref{"Board draws<br/>each surface?"}
    Halt["New layout, no board,<br/>criteria incomplete:<br/>item halts, ask user"]
    Dev{{"Step 1.2 Developer<br/>orchestrated-developer<br/>sonnet, opus at 3"}}
    IsSpike{"Type: Spike?"}
    ToSpike(["Spike Flow<br/>see 07"])
    Rev{{"Step 1.3 Reviewer<br/>orchestrated-reviewer<br/>haiku, sonnet at 3"}}
    V{"Verdict?"}
    LC["loop_count += 1;<br/>status in progress"]
    Max{"loop_count already 3?<br/>this FAIL takes it past 3"}
    Model["Pick model:<br/>Escalated if == 3"]
    UV["unverified_count += 1,<br/>unverifiedTotal += 1;<br/>loop_count unchanged"]
    UVMax{"unverified_count > 2?"}
    Fix["Fix what Orchestrator can;<br/>same inputs, same model"]
    Esc(["🚨 Escalate<br/>see 08"])
    Pass(["Code PASS<br/>diagram below"])

    Start --> Packet --> UI
    UI -->|no| Dev
    UI -->|"yes: fill Design Reference"| Ref
    Ref -->|"board, or not drawn:<br/>criteria are the spec"| Dev
    Ref -->|"neither"| Halt
    Halt -->|"board drawn:<br/>resume at Step 1.1"| Ref
    Halt -->|"user rules 'build to the AC':<br/>Ruled deviation"| Dev
    Dev --> IsSpike
    IsSpike -->|yes| ToSpike
    IsSpike -->|no| Rev
    Rev --> V
    V -->|PASS| Pass
    V -->|FAIL| Max
    V -->|UNVERIFIED| UV --> UVMax
    Max -->|"yes: stays 3"| Esc
    Max -->|no| LC --> Model
    Model -->|"packet, issues,<br/>prior file list"| Dev
    UVMax -->|yes| Esc
    UVMax -->|no| Fix --> Rev
```

On a retry the Reviewer also gets `loop_count` and the previous issues list (Step 1.4). A Bug packet's
Reviewer also runs the one regression test its `## Note on Tests` names (04). A packet the Orchestrator
added to (a Design Reference, a ruling) is stored in full in `run-state-file`.

## Code PASS → Board Parity Check → Done rules

```mermaid
flowchart TD
    Pass(["Code Reviewer PASS"])
    HasRef{"Packet has<br/>Design Reference?"}
    Up["Step 1.3b Bring up app<br/>and boards; fill app-url<br/>with port offset"]
    Parity{{"Board Parity Check<br/>orchestrated-reviewer<br/>Parity Prompt, sonnet"}}
    PV{"Parity verdict?"}
    Keep["Keep Parity Table path and<br/>unruled count in run-state-file"]
    Retry(["Unruled mismatches =<br/>issues list: FAIL path<br/>above, loop_count += 1,<br/>status in progress"])
    UV["Same unverified_count and<br/>unverifiedTotal as Reviewer"]
    UVMax{"unverified_count > 2?"}
    Esc(["🚨 Escalate<br/>see 08"])
    Kind{"Item type?"}
    Done["Feature terminal PASS:<br/>status passed review,<br/>PMBook Done, ✅ F-XXX,<br/>metrics row, run-state"]
    Next(["Next work item"])
    MV(["Manual Verification Gate<br/>Step 1.5, see 04"])

    Pass --> HasRef
    HasRef -->|no| Kind
    HasRef -->|yes| Up --> Parity --> PV
    PV -->|FAIL| Retry
    PV -->|UNVERIFIED| UV --> UVMax
    UVMax -->|"no: re-run the<br/>Parity Check"| Parity
    UVMax -->|yes| Esc
    PV -->|PASS| Keep --> Kind
    Kind -->|Feature| Done --> Next
    Kind -->|"Bug: status<br/>awaiting verification"| MV
```

A Parity FAIL retry goes Developer → code Reviewer → Step 1.3b again, under the same 3-strike rule; in
that retry's Reviewer Retry Context each parity issue is marked `verified by Step 1.3b, not by you`.
The Parity Check uses `sonnet` at every `loop_count`, and writes into
`<scratchpad>/parity/<run id>/<ID>[-legN][-retryN]/` (`-legN` from leg 2 on).

## Who sends what

```mermaid
sequenceDiagram
    participant O as Orchestrator
    participant D as Developer
    participant R as Reviewer
    participant P as Parity Reviewer
    participant U as User
    O->>D: Task Packet, plus issues and prior file list on retry
    D-->>O: Developer Output, Format and Lint PASS
    O->>R: Task Packet and Developer Output, plus loop_count and previous issues on retry
    R-->>O: PASS, FAIL with Issues, or UNVERIFIED with reason
    opt Packet has a Design Reference
        O->>P: Saved packet path, app URL, board URL, widths, parity folder
        P-->>O: Verdict and Parity Table
    end
    alt Feature
        O->>O: PMBook status Done, run-state, metrics row
    else Bug
        O->>U: Repro steps, expected behaviour, Parity Table if UI
        U-->>O: verified, a question (answered, asked again), or a reported failure = still broken
    end
```
