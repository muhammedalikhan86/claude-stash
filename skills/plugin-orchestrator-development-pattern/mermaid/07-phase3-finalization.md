# 07 — Phase 3: Finalization (Steps 3.1–3.6)

## The parallel Finalizers (Steps 3.1–3.4)

```mermaid
flowchart TD
    S0("Reviewer-Integration PASS,<br/>a clean skip, or a<br/>P0 fast lane") --> Label["Release label, once, saved<br/>in decisions per scope:<br/>Unreleased, or bump<br/>minor feat, patch fix"]
    Label --> Lists["Edit List per doc Finalizer:<br/>file, anchor, change;<br/>no edit off the list"]
    Lists --> G{"Roots changed: uncommitted,<br/>or in git log for<br/>this Run-Id?<br/>P0 lane: single-item run,<br/>or only Spikes remain"}
    G -->|"no"| GS["Print Graphify skipped,<br/>tell Handoff + summary"]
    G -->|"yes"| GF{{"3.1 Graphify<br/>haiku, route below"}}
    Lists --> PM{{"3.2 PMBook Update<br/>haiku, sonnet with<br/>the sweep"}}
    Lists --> HO{{"3.3 Handoff Update<br/>haiku"}}
    Lists --> RC{{"3.4 Revision + Changelog,<br/>Test Runbook, haiku"}}
    GF --> Wait
    GS --> Wait
    PM --> Wait
    HO --> Wait
    RC --> Wait["All Finalizers returned"]
    Wait --> Commit("Step 3.5 commit<br/>below")
```

Nodes: 11. The spawns (four, or three when Graphify is skipped) go in one message and write disjoint
files. The PMBook and Changelog Finalizers both get `Release label:`; the PMBook one also gets
`P0 fast lane: <B-ID>, Hotfixed On <date>` when relevant and the `Deferred Integration Re-Validated`
list (those Deferred rows → `Resolved`, their Bug Log rows → `Fixed`). The PMBook Finalizer always
does its own phase-status, open-item and tranche-boundary checks, and is the only place a Feature
becomes `Done`. A Spike gets only its Spike Log (`08`).

## Graphify route (Step 3.1)

```mermaid
flowchart TD
    S0("Some root changed") --> Script{"scripts/graph.ps1<br/>at repo root?"}
    Script -->|"yes"| R1["Route 1: graph.ps1<br/>-Component name"]
    Script -->|"no"| Roots{"Several roots?"}
    Roots -->|"yes"| R2["Route 2: graphify update<br/>per changed root, every<br/>root if no graph.json"]
    Roots -->|"no"| R3["Route 3: /graphify skill<br/>scoped to that root"]
    R1 --> Out
    R2 --> Out
    R3 --> Out("graphify-out/component/<br/>GRAPH_REPORT.md goes<br/>in the same commit")
```

Nodes: 6. Always before the commit, never after; one graph per component.

## Version Pointer Sweep (inside 3.2, only when a version header moved)

```mermaid
flowchart TD
    S0("This run bumped a<br/>Version header") --> Own["Move PRD and Architecture<br/>pointers in this component's<br/>architecture-doc and PMBook"]
    Own --> Shell{"Component is<br/>the shell, its<br/>architecture bumped?"}
    Shell -->|"no"| Notes
    Shell -->|"yes"| Each["Each other component:<br/>move its Platform<br/>Architecture header"]
    Each --> Aff{"Contract-affecting<br/>for that component?"}
    Aff -->|"yes"| Raise["Raise work item in its PMBook,<br/>bump its architecture-doc,<br/>history row"]
    Aff -->|"no"| Notes
    Raise --> Notes("Report under Notes;<br/>other built-against lines<br/>reported, not moved")
```

Nodes: 7.

## Commit (Step 3.5)

```mermaid
flowchart TD
    S0("All Finalizers returned;<br/>decisions.commit ask or<br/>unset: ask, save answer") --> NoC{"decisions.commit<br/>is no?"}
    NoC -->|"yes"| Draft["Draft the messages<br/>only, no commit"]
    NoC -->|"no"| Staged{"A staged path outside<br/>the saved file list?"}
    Staged -->|"yes"| AskS("Stop and ask:<br/>someone else's work")
    Staged -->|"no: none, or all<br/>this run's own"| Stage["Stage exact paths still<br/>uncommitted: items' files,<br/>integration files, Artboard Edit,<br/>Finalizer, Orchestrator files; one group<br/>at a time, empty ones skipped"]
    Stage --> Cm["Commit on current branch<br/>type scope: description,<br/>Run-Id and Items trailers<br/>+ attribution"]
    Cm --> Hook{"Hook failed?"}
    Hook -->|"yes"| AskH("Report output, leave<br/>rest unstaged, ask")
    Hook -->|"no, more groups"| Stage
    Hook -->|"no, all done"| Go{"A go to push?<br/>push-and-pull.md"}
    Go -->|"yes"| Push["git push origin<br/>current branch, report"]
    Go -->|"no"| PrintCmd["Print the<br/>git push command"]
    Draft --> Close
    Push --> Close
    PrintCmd --> Close("3.6 Close-out<br/>below")
```

Nodes: 13. Linked Runs: one commit group per component, the depended-on one first. A Spike's code and
a run that ended escalated or paused are never committed. The file list, kept in run-state, is the
step's full staging source set: every in-scope item's `files` (every attempt), the `integration`
block's `files` (every Integration pass and Divide-and-Conquer spawn), the Artboard Edit files, every Finalizer's files and run-state's
`orchestratorFiles` (every governed file the Orchestrator wrote). A commit step commits whatever of that list `git status` still shows uncommitted,
grouped as usual; a group with nothing
left uncommitted is skipped. Staged paths all in that list are this run's own and are committed; only
a staged path outside it stops the step. A resumed commit step does the same, and asks again on
`decisions.commit: ask` (or unset).

## Close-out (Step 3.6) — every run

```mermaid
flowchart TD
    In("End of the run, or<br/>an escalation pause") --> Esc{"Escalation pause?"}
    Esc -->|"yes"| L12["Lines 1–2 only: rows so far,<br/>RUN row Paused (escalation),<br/>run-state saved, NOT complete"]
    L12 --> Paused("PAUSED<br/>09")
    Esc -->|"no"| L1["1 Metrics rows: items,<br/>Integration, RUN Complete<br/>+ commit ids; same Run ID,<br/>Item ID, Timestamp: update, 12"]
    L1 --> L2["2 Mark run-state complete;<br/>Linked: every file<br/>with this run id"]
    L2 --> L37["3–7 Finalizer Notes, Pending<br/>Deferred rows, known-reds,<br/>stack state, task bar done"]
    L37 --> Sum("Final summary")
    Sum -.->|"user later<br/>says commit"| Late["Save decisions.commit yes;<br/>ONE commit pass over the<br/>union of every commit step's<br/>file list: a code group per item,<br/>Items: that item; one docs/chore<br/>group for every other file,<br/>Items: all; draft messages<br/>first, trailers; refresh RUN<br/>row commit ids from git"]
```

Nodes: 8. A "commit" said after a commit step chose `no` first saves `decisions.commit: yes`, then runs
one commit pass over the union of every commit step's saved file list in the run, grouped as Phase 3
groups are: each item (Feature, Bug, P0) gets its own code group from its own `files`, `Items:` naming
only that item; every other file — governed docs, a file shared by more than one item, and any file in
no item's code group (an Integration fix outside every item, the graph report) — goes in one docs/chore
group whose `Items:` lists every item. The Orchestrator drafts the regrouped messages first, with the trailers. Refreshing the
commit ids is the second edit an old metrics row may take.
Line 4 also lists any `heldForNextRun` item; the next run's Step 0.0 queues it. The close-out runs once, at the end of the run — a
Spike-only or P0-only run, and one that skipped Phases 2–3, included. A P0 fast lane inside a
multi-item run does not run it.

## Open questions

None.
