# 11 — Cross-component FAIL and Linked Runs

Full procedure: `references/linked-runs.md`.

## A FAIL in another component's files (Steps 1.4, 1.3b, 2.1)

```mermaid
flowchart TD
    F("Reviewer FAIL, Parity FAIL,<br/>or Diff Guard FAIL") --> Where{"Where do the<br/>issues lie?"}
    Where -->|"all in own<br/>component"| Normal("Normal retry,<br/>Step 1.4, 03")
    Where -->|"in a sibling already<br/>linked in this run"| Sib("Sibling FAIL: its loop_count<br/>+ 1, its Developer respawns;<br/>after its PASS, respawn<br/>this Reviewer, no change")
    Where -->|"all in another<br/>component's roots"| NoRetry["No retry,<br/>loop_count unchanged,<br/>pause the item"]
    Where -->|"some"| Both["Retry own issues<br/>as normal"]
    NoRetry --> Tell["Tell the user, ask<br/>to raise a linked item"]
    Both --> Tell
    Tell --> OK{"User OK?"}
    OK -->|"no"| Esc("Escalate, Template 1,<br/>naming the dependency;<br/>after any retry in flight, 09")
    OK -->|"yes"| Raise["Raise linked item in the<br/>owner's PMBook,<br/>Depends on both ways"]
    Raise --> Mid["New component: 0.0 deps,<br/>0.0a block, 0.2, 0.3, 0.3b;<br/>own run-state, same run id,<br/>linkedRuns in every file"]
    Mid --> LR("Linked Runs<br/>below")
```

Nodes: 12. Issues tagged `[cross-component: <owner>]` by the Reviewer (only for files in another
component's roots) count as lying elsewhere; a file outside every root is a justified-deviation check. A
Diff Guard FAIL's files go to the linked item, and Step 2.1 re-runs once it passes Review.

## Linked Runs through the phases

```mermaid
flowchart TD
    S0("Linked items, one<br/>per component") --> Own["Each keeps its own block,<br/>packet, docs, graph; one<br/>run-state each, same run id"]
    Own --> Disj{"Files disjoint?"}
    Disj -->|"yes"| Par["Phase 1 per item,<br/>in parallel"]
    Disj -->|"no"| Seq["Phase 1 per item,<br/>depended-on first"]
    Par --> Resp
    Seq --> Resp["Raised from a FAIL: once the<br/>linked item passes Review,<br/>respawn the first Reviewer"]
    Resp --> MV["One batched Step 1.5<br/>for every linked bug"]
    MV --> Int["ONE combined Phase 2,<br/>Test scope component (each),<br/>full suite suggested to hub,<br/>Diff Guard per item"]
    Int --> Met["Integration metrics row<br/>in each component's file:<br/>linked with other component"]
    Met --> Fin["Each component's Finalizers,<br/>as apply, all in one message"]
    Fin --> Commit["One commit per component,<br/>depended-on first,<br/>push only on a go"]
    Commit --> Close("3.6 close-out: RUN row in<br/>each component's file; every<br/>run-state with the run id complete")
```

Nodes: 11. The Reviewer respawn after the linked item passes does not increment `loop_count`. On
resume, finding any incomplete run-state file resumes every file with that run id.

## Open questions

None.
