# 08 — Spike Flow and P0 fast lane

Full procedure: `references/spike-and-p0.md`. Both need the user to actually say so; never inferred.

## Spike (Step 0.1c and the Spike Flow)

```mermaid
flowchart TD
    S0("Explicit ask:<br/>spike this") --> ID["Assign COMPONENT-S-XXX,<br/>next after highest,<br/>else S-001"]
    ID --> Dir["Spike Directory, default<br/>repo-root spikes/ID/,<br/>outside roots and tests"]
    Dir --> Ann["Steps 0.2–0.4, run-state,<br/>one-line Spike Mode"]
    Ann --> Wave["Joins a wave: passes the<br/>overlap rules, counts<br/>toward the limit of 3"]
    Wave --> Dev{{"Developer<br/>developer-high, opus,<br/>never escalates"}}
    Dev --> Out["Output is the deliverable:<br/>Findings + recommendation"]
    Out --> Fin{{"Spike Log Finalizer, sonnet;<br/>waits for any open<br/>PMBook writer"}}
    Fin --> Row["One Spike Log row<br/>in the PMBook"]
    Row --> Keep["Code stays uncommitted;<br/>save run-state"]
    Keep --> More{"Other items<br/>left?"}
    More -->|"yes"| Next("Next work item<br/>03")
    More -->|"no"| Close("Phase 2 if the run has a<br/>Feature or non-P0 Bug, 06;<br/>else Step 3.6 close-out, 07")
```

Nodes: 12. No Reviewer, retry loop, Manual Verification, Integration or escalation; `loop_count`
never moves.

## P0 hotfix fast lane

```mermaid
flowchart TD
    S0("Bug with Priority P0,<br/>Reviewer PASS; its wave<br/>keeps running") --> Now["Step 1.5 now,<br/>on its own"]
    Now --> Ans{"User reply"}
    Ans -->|"reports a failure"| Loop("Back to Step 1.4, verify<br/>again after the next<br/>PASS, 03")
    Ans -->|"verified"| Lane["Wait for any open PMBook<br/>writer: a P0 lane with its<br/>commit if any, or a<br/>Spike Log Finalizer"]
    Lane --> Label["Release label by Phase 3's<br/>rule, saved in decisions<br/>as lane:ID"]
    Label --> Single{"Single-item run, or<br/>only Spikes remain?"}
    Single -->|"yes"| BatchG{{"4 Finalizers in parallel,<br/>Graphify included, early"}}
    Single -->|"no"| Batch3{{"3 Finalizers in parallel,<br/>Graphify skipped: the run's<br/>Phase 3 builds it"}}
    BatchG --> PM
    Batch3 --> PM["Bug Log: Hotfixed —<br/>Integration Pending,<br/>+ Deferred row Pending"]
    PM --> Commit["Commit what of the Bug's<br/>files + lane Finalizer files<br/>is still uncommitted; Run-Id<br/>and Items trailers; push on a go"]
    Commit --> Next{"Items left?"}
    Next -->|"yes"| Back("Next work item, 03")
    Next -->|"no"| Has{"Run has a Feature<br/>or non-P0 Bug?"}
    Has -->|"yes"| P2("Phase 2, once every lane<br/>is done: the P0 is a<br/>Deferred ID, re-validated, 06")
    Has -->|"no"| Stop("Step 3.6 close-out")
    Stop -.->|"a later run"| Later("Phase 2 re-validates it at<br/>full: Deferred Resolved,<br/>Bug Log Fixed")
```

Nodes: 17. A question in reply is answered and the gate asked again. The close-out runs once, at the
end of the run, and writes the P0's metrics row there; the 🏁 summary prints each P0's status as it
stands after Step 3.2. The lane's steps (`finalizers → commit → done`) are saved as each starts and
ends; a resume re-runs a step found `started`, and a re-run commit step skips a group with nothing
left uncommitted (`git status`; no git-log check). Graphify's change check counts a root changed when it
has uncommitted changes or a file in `git log --grep "Run-Id: <run id>" --name-only`.

## Open questions

None.
