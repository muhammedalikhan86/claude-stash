# 05 — Phase 2: Integration

Three diagrams: the Integration loop (Steps 2.1–2.3, Known-reds), how a failing test is triaged (flaky
rule, Enforcement Rules), and Divide-and-Conquer (`references/escalation.md`). Skipped entirely when the
run holds no Feature and no non-P0 Bug (01).

## Steps 2.1–2.3 — Integration loop

```mermaid
flowchart TD
    In(["Every Feature and non-P0 Bug<br/>terminal; every P0 lane finished;<br/>Spikes and dropped items excluded"])
    Int{{"Step 2.1 Integration<br/>orchestrated-integration<br/>sonnet, opus at 3"}}
    KR{"Any Known-Red<br/>'— untracked'?"}
    Ask["Pause; per test the user:<br/>raise a tracking item OI-NNN<br/>(PMBook Open Items, Item cell)<br/>or accept it; save run-state"]
    RI{{"Step 2.2 Reviewer-Integration<br/>haiku, sonnet at 3"}}
    V{"Verdict?"}
    LC["loop_count += 1"]
    Max{"loop_count already 3?<br/>this FAIL takes it past 3"}
    Model["Pick model:<br/>Escalated if == 3"]
    UV["unverified_count += 1<br/>loop_count unchanged"]
    UVMax{"unverified_count > 2?"}
    Fix["Fix what Orchestrator can;<br/>respawn unchanged"]
    DC(["Divide-and-Conquer<br/>diagram 3"])
    Esc(["🚨 Escalate<br/>see 08"])
    P3(["Integration row in metrics;<br/>Phase 3, see 06"])

    In --> Int --> KR
    KR -->|yes| Ask --> RI
    KR -->|no| RI
    RI --> V
    V -->|PASS| P3
    V -->|FAIL| Max
    V -->|UNVERIFIED| UV --> UVMax
    Max -->|"yes: stays 3"| DC
    Max -->|no| LC --> Model
    Model -->|"loop_count, issues,<br/>prior Output's file path"| Int
    UVMax -->|yes| Esc
    UVMax -->|no| Fix --> RI
```

The Integration Agent gets paths, never file contents: Platform Profile, completed Features and Bugs,
`source-code-directory`, a Module Map of "None" (a known-red's owner is the top-level folder or module
holding the test), `test-cases-doc`, `architecture-doc`, PMBook, `test-runbook-location`,
`adr-directory`, Pending Deferred Integration IDs with their regression test paths (re-read from the
PMBook at Step 2.1, so this run's fast-laned P0s are among them), and the
`## Accepted Known-Reds` and `## Known Reds at Baseline` lines (Step 0.3b; both on every retry and
Divide-and-Conquer spawn). A test red at baseline and still red goes under Known-Reds, not into flaky
triage as new; a test green at baseline and red now is this run's. It runs the full
suite, fixes failures, runs the security audit and E2E/smoke tests, and checks Documentation Drift, which
is a FAIL-worthy defect. It fixes code, never the test-cases doc: each gap there is handed to the Test
Runbook Finalizer (Step 3.5) as a `— handed to Test Runbook` drift line, and never writes an ADR: a
needed one comes back as `Drift: new ADR — … — handed to PMBook Update`, numbered by the Orchestrator and
written by the PMBook Finalizer (Step 3.2). Its Output lists `### Known-Reds` (each `tracked by <ID>`, `accepted by the
user`, or `untracked`) and `### Work Items Covered` (this run's Features and Bugs only; Deferred IDs go
under `Deferred Integration Re-Validated`).

Every Integration Output is saved verbatim to `<scratchpad>/runs/<run id>/integration-output-pass<N>.md`
(a Divide-and-Conquer sub-problem's with `-sub<K>`), its path kept in run-state's
`integration.outputPaths`; a background spawn's task output file is a transcript, never the Output.
The Reviewer-Integration gets the Integration Output's file path (never a summary), condensed packets of the Features Completed and
Bugs Fixed only, the Platform Profile with Test
scope `full`, the same doc paths, the Deferred Integration IDs and the same `## Accepted Known-Reds` and
`## Known Reds at Baseline` lines, and checks no still-red baseline test was dropped. Every
known-red is listed, as its line reads, in the 🏁 summary and the Integration metrics row (09).

## Integration Agent — triaging a failing test

```mermaid
flowchart TD
    Fail(["A test fails<br/>in the full run"])
    Rerun{"Fails again in one<br/>isolated re-run?"}
    Real["Real failure:<br/>root-cause and fix"]
    Read["Read the test's<br/>locators and waits"]
    Cause{"Cause found?"}
    Flaky["List under<br/>Flaky Tests Detected"]
    Log(["Step 3.2 writes an<br/>Open Items row, see 06"])

    Fail --> Rerun
    Rerun -->|yes| Real
    Rerun -->|"no: passed"| Read --> Cause
    Cause -->|yes| Real
    Cause -->|no| Flaky --> Log
```

"Passed on retry" is never accepted unless the test runner itself has retries configured. A failure the
run did not cause goes under Known-Reds instead; every failure in the log is listed under one or the
other.

## Divide-and-Conquer — last attempt before escalation

```mermaid
flowchart TD
    In(["FAIL taking loop_count<br/>past 3; it stays 3"])
    Ran{"run-state divideAndConquer<br/>other than not run?"}
    Sep{"Failures split along file and<br/>module boundaries into<br/>independent sub-problems?"}
    Esc1(["🚨 Report 1<br/>Implementation, see 08"])
    Split["Split succeeded:<br/>set divideAndConquer: running,<br/>save run-state"]
    Subs{{"One Integration per sub-problem,<br/>parallel, opus, Sub-problem section;<br/>self-verify only, no commit"}}
    Agg{{"ONE aggregate Integration, opus,<br/>Aggregate pass: full gate,<br/>complete Integration Output"}}
    KR["Settle any '— untracked'<br/>known-red with the user"]
    Conf{{"divideAndConquer: confirmation pass;<br/>Reviewer-Integration once,<br/>sonnet; loop_count unchanged"}}
    V{"Verdict?"}
    P3(["Phase 3<br/>see 06"])
    Esc3(["🚨 Report 3<br/>still-failing only, see 08"])
    UV["Integration's unverified_count;<br/>re-run the confirmation pass,<br/>Report 2 on the 3rd"]

    In --> Ran
    Ran -->|"yes: Report 1"| Esc1
    Ran -->|no| Sep
    Sep -->|"no: stays not run"| Esc1
    Sep -->|yes| Split --> Subs --> Agg --> KR --> Conf --> V
    V -->|PASS| P3
    V -->|FAIL| Esc3
    V -->|UNVERIFIED| UV --> Conf
```

Runs at most once per batch; run-state's `divideAndConquer` is set to `done` once the confirmation
returns PASS or FAIL, and a Report 2 resume re-runs the confirmation pass. Its stages are Phase 2 steps:
a resume after a crash (not an escalation) at `running` re-runs the aggregate pass, at `confirmation pass`
the confirmation. Sub-problems still failing in the aggregate pass stay "Still Failing";
the rest are "Resolved (Divide-and-Conquer)", uncommitted until the user says "commit".
