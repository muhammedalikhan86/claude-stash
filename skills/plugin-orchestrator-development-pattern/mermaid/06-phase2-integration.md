# 06 — Phase 2: Integration (Steps 2.0–2.3)

## Test scope (Step 2.0)

```mermaid
flowchart TD
    S0("Every Feature passed,<br/>every non-P0 Bug verified,<br/>and every P0 lane done") --> Only{"Run has a Feature<br/>or non-P0 Bug?"}
    Only -->|"no: only Spikes,<br/>fast-laned P0s"| NoP2("Skip Phases 2–3,<br/>Step 3.6 close-out<br/>07")
    Only -->|"yes"| Diff["2.0 git status, ignore<br/>docs and graphify-out"]
    Diff --> Full{"Shell, out-of-root change,<br/>no component command,<br/>Deferred row re-validated,<br/>user ask, or Linked Runs?"}
    Full -->|"yes"| F["Test scope: full"]
    Full -->|"no"| C["Test scope: component<br/>+ its scenarios<br/>+ contract tests"]
    F --> Print["Write scope to Platform<br/>Profile, print it"]
    C --> Print
    Print --> Next("Step 2.1<br/>below")
```

Nodes: 8. A P0 fast-laned earlier in this run is not a work item here, but its `Pending` Deferred row
is passed for re-validation, which forces `full`.

## The Integration agent (Step 2.1)

The order the agent works in, from `orchestrated-integration.md`'s Core Workflow.

```mermaid
flowchart TD
    Snap("Orchestrator: snapshot<br/>status and diff --stat;<br/>pass Known Reds<br/>at Baseline, 0.4b") --> Int{{"Integration agent<br/>sonnet, opus at loop 3"}}
    Int --> Guard{"Diff Guard, this run's files<br/>only: one in another component's<br/>roots, or platform arch file?"}
    Guard -->|"yes"| GF["Stop: no gate, no fix,<br/>Overall Status FAIL"]
    GF --> XC("Orchestrator: cross-<br/>component route, no<br/>loop_count change, 11")
    Guard -->|"no, out-of-root<br/>files justified"| Gate["Gate once at Test scope,<br/>output to log files"]
    Gate --> Fails{"A failing test?"}
    Fails -->|"no"| E2E
    Fails -->|"yes"| Iso{"Isolated re-run"}
    Iso -->|"fails again, 2/2"| Caused{"Did this run<br/>cause it?"}
    Iso -->|"passes, 1/2"| Loc{"Locators and waits<br/>read: cause found?"}
    Loc -->|"yes"| Caused
    Loc -->|"no"| Flaky["Flaky Tests Detected"]
    Caused -->|"yes"| Fix["Root-cause fix, or flag<br/>a design decision;<br/>bounded re-run"]
    Caused -->|"no"| KR["Known-Reds: owner, tracked<br/>by ID, accepted, or<br/>untracked; git evidence"]
    KR --> E2E
    Flaky --> E2E
    Fix --> E2E["E2E, then Drift Check:<br/>each finding fixed or handed<br/>to a Finalizer; test cases doc<br/>always to Test Runbook"]
    E2E --> SC["Self-Check, every<br/>line ticked or fixed"]
    SC --> Out("Integration Output: Known-Reds,<br/>Work Items Covered,<br/>gate log paths")
```

Nodes: 16. The Diff Guard checks only this run's files (Developer Outputs, a UI Iteration's file set, its
own fixes); any other dirty path is listed `not this run's`, never a FAIL. An out-of-root file passes
only when the prompt's `Out-of-root files` line gives its justification. A known-red named in the
prompt's `## Accepted Known-Reds` keeps the agent's own owner and takes its status from that line. Flaky tests and known-reds are reported,
never passed silently; the agent never invents a tracking ID.

## Reviewer-Integration and the loop (Steps 2.2, 2.3)

```mermaid
flowchart TD
    In("Integration Output, saved verbatim:<br/>runs/run id/integration-<br/>output-passN.md") --> Untr{"Any known-red<br/>untracked?"}
    Untr -->|"yes"| AskU["Pause, ask the user per test:<br/>raise COMPONENT-OI-NNN in<br/>Open Items now, or accept;<br/>list in run-state"]
    AskU --> Clean
    Untr -->|"no"| Clean{"Clean first pass?<br/>all 6 conditions below"}
    Clean -->|"yes"| SkipRI["Record the skip as this<br/>step's verdict in run-state;<br/>print: Reviewer-Integration<br/>skipped, clean first pass"]
    Clean -->|"no, or unsure"| RI{{"2.2 Reviewer-Integration<br/>sonnet, opus at loop 3, +<br/>Known-Reds, Deferred IDs"}}
    SkipRI --> P3("Phase 3<br/>07")
    RI --> V{"Verdict"}
    V -->|"PASS"| P3
    V -->|"UNVERIFIED"| U["Fix or respawn unchanged,<br/>escalate on the 3rd"]
    U --> RI
    V -->|"FAIL"| At3{"Was this<br/>loop_count 3?"}
    At3 -->|"yes: this FAIL<br/>takes it past 3"| DnC("Divide-and-Conquer,<br/>or Template 1 if it<br/>already escalated, 09")
    At3 -->|"no"| Inc["loop_count + 1"]
    Inc --> Kind{"Every issue only<br/>docs or the report?"}
    Kind -->|"yes"| Doc["Doc-only retry: resume same<br/>spawn, keeps its model;<br/>docs only, gate carried forward"]
    Kind -->|"no"| Normal{{"Normal retry: fresh<br/>Integration, fixes,<br/>re-runs gate once"}}
    Doc --> Changed["Orchestrator lists files<br/>the retry changed: any code,<br/>test or config is a FAIL"]
    Changed --> Untr
    Normal --> Untr
```

Nodes: 16. A retry, a pass resumed after escalation, or a pass re-run after a crash is never a skip candidate:
Reviewer-Integration always checks it. It gets the Integration Output as its saved file's path (Step 2.1;
a Divide-and-Conquer sub-problem's file has `-sub<K>`), never a summary; a background spawn's task output
file is a transcript, never the Output. It also gets `## Deferred Integration` (the Step 2.1 IDs, or `None`). The untracked
known-red pause comes before every Reviewer-Integration spawn, retries and Divide-and-Conquer included,
and every later Integration spawn gets the ruled list as `## Accepted Known-Reds`.

The six skip conditions (Step 2.2), all mechanical:

1. First pass (`loop_count` 0, not a resume after escalation, not a pass re-run after a crash) and Overall Status `PASS`.
2. `Fixes Applied` is `None`, and `git status --porcelain` and `git diff --stat` match the Step 2.1
   snapshot (apart from a tracking item raised at the pause). Drift handed to a Finalizer (the test
   cases doc's always is) is not a fix.
3. The gate ran this pass at the set Test scope, the counts match each gate log's summary line, and
   every failure in the log is under `Known-Reds` or `Flaky Tests Detected`.
4. Every Self-Check line ticked; `Flaky Tests Detected` and `Unresolvable Issues` are `None` (apart from
   a recorded E2E skip for a missing test-cases doc).
5. Each known-red passes a quick look: `tracked by` an ID that starts an open `## Open Items` row's
   Item cell in the owner's live PMBook, or
   `accepted by the user` on the accepted list, the status matching its ruled line, and its file under
   the owner the agent named.
6. `Work Items Covered` names every Feature and Bug passed as this run's, each `PASS`, and no Deferred
   Integration ID (those sit only under `Deferred Integration Re-Validated`).

## Open questions

None.
