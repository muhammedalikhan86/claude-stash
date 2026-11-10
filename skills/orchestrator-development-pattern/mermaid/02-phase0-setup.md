# 02 — Phase 0: setup

Two diagrams: the Step 0.0 checks in their stated order, then the entry point and plan
(Steps 0.1–0.4).

## Step 0.0 — hard dependencies, resume, deferred integration, test cases

```mermaid
flowchart TD
    Start(["Phase 0 starts"])
    Deps{"Hard deps exist?<br/>PMBook, source dir,<br/>architecture-doc"}
    AskDeps["Stop and ask user<br/>for path or to create"]
    Resume{"run-state-file exists<br/>and not complete?"}
    AskResume["Ask: resume<br/>or start fresh?"]
    Rebuild["Rebuild queue position;<br/>re-write saved packets to the<br/>scratchpad; saved conventions<br/>for re-derived packets"]
    Order{"Latest phase first:<br/>which matches?"}
    RunP3(["Phase 3 at its recorded<br/>step, see 06"])
    RunP2(["Phase 2, at its recorded<br/>step if started, see 05"])
    RunLane(["P0 lane at its recorded<br/>step, see 07"])
    RunEsc(["Resuming after an escalation:<br/>status back to in progress;<br/>read blockedGate, respawn,<br/>then clear it; see 08"])
    Close(["Close-out, see 09"])
    SpLog(["Spike Log Finalizer,<br/>never a Reviewer, see 07"])
    P1{"Phase 1 rule:<br/>what remains?"}
    Phase1(["Phase 1 item at its first<br/>gate with no result, see 03"])
    Repost(["Post Step 1.5's gate<br/>again, see 04"])
    Held["Announce old file's<br/>heldForNextRun; put them<br/>in the new queue"]
    Deferred["Scan PMBook for<br/>Deferred Integration<br/>Pending rows, hold"]
    IsPMB{"PMBook entry<br/>(Features)?"}
    Cases{"test-cases-doc?"}
    Draft["Draft it from<br/>Feature Backlog"]
    AskCases["Say what is missing; ask:<br/>proceed, draft, or pause"]
    Next(["Entry point<br/>diagram below"])

    Start --> Deps
    Deps -->|missing| AskDeps --> Deps
    Deps -->|present| Resume
    Resume -->|yes| AskResume
    AskResume -->|resume| Rebuild --> Order
    Order -->|"item status escalated, or<br/>integration block<br/>escalated: true"| RunEsc
    Order -->|"Phase 3 done, or nothing<br/>unfinished and Phase 2<br/>not owed; run not complete"| Close
    Order -->|"Phase 3 started, or<br/>Reviewer-Integration PASS"| RunP3
    Order -->|"Phase 2 started"| RunP2
    Order -->|"none of these"| P1
    P1 -->|"verified P0 lane<br/>not done"| RunLane
    RunLane -->|"then continue,<br/>no stop"| P1
    P1 -->|"Spike with Developer<br/>Output, no Spike Log"| SpLog
    P1 -->|"Bug awaiting<br/>verification"| Repost
    P1 -->|"item with no<br/>recorded result"| Phase1
    P1 -->|"all terminal, no P0 lane<br/>unfinished, Phase 2 not<br/>started; Phase 2 owed"| RunP2
    P1 -->|"all terminal, no P0 lane<br/>unfinished; Phase 2<br/>not owed"| Close
    AskResume -->|"start fresh"| Held
    Resume -->|"no, or complete"| Held
    Held --> Deferred
    Deferred --> IsPMB
    IsPMB -->|"no: Bug or Spike,<br/>check skipped"| Next
    IsPMB -->|yes| Cases
    Cases -->|absent| Draft --> Next
    Cases -->|"thin or stale"| AskCases --> Next
    Cases -->|adequate| Next
```

Soft dependencies (`handoff-doc`, `changelog-file`, `revision-file`, `test-runbook-location`,
`snyk-command`, `adr-directory`, `graphify-directories`, `run-state-file`, `metrics-log-file`) are never
asked about here; each is created or used where its step needs it. On a Bug or Spike entry, Step 2.1
passes `test-cases-doc` if it exists, else "None provided".

## Steps 0.1–0.4 — entry point, platform, conventions, plan

```mermaid
flowchart TD
    Entry{"Which explicit ask?"}
    PMB["Step 0.1 Read PMBook:<br/>active phase, Planned or<br/>In Progress features"]
    Bug["Step 0.1b Bug Fix Intake:<br/>report, next free B-XXX<br/>(PMBook, run-state queue,<br/>heldForNextRun),<br/>P0 only if user says so"]
    Spk["Step 0.1c Spike Intake:<br/>question, next free S-XXX<br/>(PMBook, run-state queue,<br/>heldForNextRun),<br/>Spike Directory"]
    Plat{"Step 0.2<br/>one platform marker?"}
    AskPlat["Stop and ask user<br/>to confirm platform"]
    Conv["Step 0.3 Detect coding<br/>conventions; summary<br/>saved in run-state"]
    Ann["Step 0.4 Announce plan or<br/>Bug/Spike one-liner, Deferred<br/>warning; write run-state-file"]
    UI{"artboards-directory set,<br/>UI packet planned, app-url<br/>or artboard-server missing?"}
    AskUrl["Look in CLAUDE.md,<br/>run skill, READMEs;<br/>ask user once for<br/>what is not found"]
    Out(["Phase 1<br/>see 03"])

    Entry -->|"build from PMBook"| PMB
    Entry -->|"orchestrate a fix"| Bug
    Entry -->|"spike this"| Spk
    PMB --> Plat
    Bug --> Plat
    Spk --> Plat
    Plat -->|"none or several"| AskPlat --> Conv
    Plat -->|one| Conv
    Conv --> Ann --> UI
    UI -->|yes| AskUrl --> Out
    UI -->|no| Out
```

Bug and Spike intake replace the feature list in the Step 0.4 announcement with one line
(`Bug Fix Mode [P0] — B-XXX: …` / `Spike Mode — S-XXX: …`) and still print the Deferred Integration
warning and write `run-state-file`. A bug or spike asked for while a run is open is a mid-run intake
instead: same run id and run-state file, appended to the queue (or, once Phase 2 has started, saved in
`decisions.heldForNextRun` to seed the next run's queue). The run id is `<YYYY-MM-DD>-<first item id, lowercased>-<HHmm>` (start time), with `-2`, `-3`… if
`metrics-log-file` or `git log --grep "Run-Id: <id>"` already has it. A design
mismatch reported at Step 0.1b on a built screen is noted at intake and recorded in `metrics-log-file`
only after Step 0.4 has created run-state and saved the event time — see 09.

On resume, a step found `started` (not `done`) re-runs from its start; the rest of Phase 0 is skipped.
A P0 lane resumed at its recorded step does not end the resume: the Phase 1 rule carries on for the
remaining items, and once all are terminal (a Feature `passed review`, a Bug `verified`, a Spike `findings
recorded`, or any item `dropped`; and no P0 lane unfinished) Phase 2's entry rule picks Phase 2 or close-out. These
rules read each item's run-state `status` (`in progress | passed review | awaiting verification |
verified | findings recorded | escalated | dropped`, saved at each change); a `dropped` item is skipped,
and a Bug `awaiting verification` gets Step 1.5's gate posted again. Before any of
this, right after "run complete", an item with status `escalated` (or the `integration` block with
`escalated: true`) goes to **Resuming after an escalation** (08). Close-out is chosen early only when
Phase 3 is `done`, or nothing is left unfinished and Phase 2's entry rule says Phase 2 is not owed; a
Features run that crashed before Phase 2 falls through to the Phase 1 rule and so to Phase 2.
An old run-state's `heldForNextRun` packets (complete, or the user chose "start fresh") are announced
and join the new run's queue before Step 0.4 writes the new file, so the next-free-ID scan sees them.

"resume" means two things: here at Step 0.0 it picks an interrupted run back up; at an escalation (08) it
un-pauses the current run.
