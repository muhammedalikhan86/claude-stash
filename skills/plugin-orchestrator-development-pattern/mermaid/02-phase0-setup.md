# 02 — Phase 0: setup (Steps 0.0a–0.4)

## Step 0.0a — resolve the component

The ladder stops at the first rung that resolves. There is never a default component.

```mermaid
flowchart TD
    S0("Start") --> T{"components: table in<br/>.claude/SKILLS.md?"}
    T -->|"no"| NotPlugin("Stop: not a plugin repo,<br/>use orchestrator-development-pattern")
    T -->|"yes"| L1{"Rung 1<br/>user named it?"}
    L1 -->|"yes"| Valid{"Name in<br/>components?"}
    Valid -->|"no"| ListNames("Stop, list<br/>the valid names")
    Valid -->|"yes"| Block
    L1 -->|"no"| L2{"Rung 2<br/>ID prefix, e.g.<br/>OFA-F-003?"}
    L2 -->|"yes"| Block
    L2 -->|"no"| L3{"Rung 3<br/>exactly one unfinished<br/>run id in run-state?"}
    L3 -->|"yes, means a resume"| Block
    L3 -->|"no"| L4{"Rung 4<br/>branch segment matches<br/>exactly one name?"}
    L4 -->|"yes"| Block
    L4 -->|"no"| L5{"Rung 5<br/>dirty tree under one<br/>component's roots?"}
    L5 -->|"yes"| Block
    L5 -->|"no"| L6["Rung 6 ask: list components,<br/>tranche, open items"]
    L6 --> Block["Print confirmation block:<br/>component, rung, docs,<br/>code, graph"]
    Block --> Vars["Resolve templated variables<br/>shared: adr-directory,<br/>platform arch, source dir"]
    Vars --> Span{"Two components<br/>that must land together?"}
    Span -->|"yes"| Linked("Read linked-runs.md now<br/>11")
    Span -->|"no"| Next("Step 0.0")
```

Nodes: 17. Work that spans two components is always split into one item per component, linked by
`Depends on:`; the decision above is whether those items must land together. A linked item raised
mid-run runs Steps 0.0, 0.0a, 0.2, 0.3 and 0.3b for its component before its first spawn (`11`).

## Step 0.0 — dependencies and resume

```mermaid
flowchart TD
    In("From Step 0.0a") --> Hard{"Hard deps exist?<br/>PMBook, source dir,<br/>architecture-doc"}
    Hard -->|"no"| AskDeps("Stop and ask")
    Hard -->|"yes"| Res{"run-state-file exists<br/>and not complete?"}
    Res -->|"yes"| AskRes{"Ask: resume it,<br/>or start fresh?<br/>never silently"}
    AskRes -->|"resume"| Rebuild("Rejoin where the<br/>file says, Phase 0<br/>not re-run, 13")
    AskRes -->|"fresh"| Held
    Res -->|"no: none, or<br/>old run complete"| Held["Held intakes, if any:<br/>announce, add to<br/>the new queue"]
    Held --> Def["Hold Pending Deferred<br/>Integration rows<br/>for the announcement"]
    Def --> TC{"test-cases-doc<br/>exists?"}
    TC -->|"no"| Draft["Draft it from the<br/>phase's features, register"]
    TC -->|"yes"| Thin{"Covers every feature<br/>in scope?"}
    Thin -->|"no"| Own{"Writing them is a<br/>work item's own job<br/>this run?"}
    Own -->|"yes"| Note["Note the gap in<br/>decisions, no question"]
    Own -->|"no"| AskGap["Tell user the gaps:<br/>proceed, draft, or pause"]
    Note --> Entry
    Thin -->|"yes"| Entry
    Draft --> Entry("Entry point<br/>0.1, 0.1b, 0.1c, 0.1d")
    AskGap --> Entry
```

Nodes: 16. Soft dependencies (handoff, changelog, revision, runbook, audit command, ADR folder,
graphify directories, run-state, metrics) are created or skipped later and never stop the run.

## Steps 0.1–0.4 — platform, skill, waves, announce

```mermaid
flowchart TD
    In("After the entry point<br/>0.1 PMBook, 0.1b Bug,<br/>0.1c Spike") --> Plat{"0.2 one clear<br/>platform marker?"}
    Plat -->|"none, or several"| AskPlat["Ask the user"]
    Plat -->|"yes"| Prof["Platform Profile:<br/>Format, Lint, Test full,<br/>Test component, audit"]
    AskPlat --> Prof
    Prof --> Stack["Record Stack line:<br/>up, down, check,<br/>static servers"]
    Stack --> Conv["0.3 Coding conventions"]
    Conv --> Skill["0.3b Specialist skill,<br/>chosen once, may be None"]
    Skill --> Hold["Design rows hold: UI item<br/>whose rows are not Done waits;<br/>no rows + new layout → write<br/>them in the open round;<br/>old layout → migration guide"]
    Hold --> Waves["0.4 Build waves<br/>Step 1.0 rules, below"]
    Waves --> Ann["Announce: full block, or<br/>one line for Bug or Spike<br/>mode, + Deferred line"]
    Ann --> UIq{"A planned packet<br/>touches a UI?"}
    UIq -->|"yes"| UIB["Read ui-packets.md,<br/>check UI bindings,<br/>look in repo, then ask<br/>once if missing<br/>04"]
    UIq -->|"no"| RS
    UIB --> RS["Fix run id, runs/ and<br/>gate-logs/ folders,<br/>write run-state-file"]
    RS --> Base["0.4b Baseline test run<br/>on the untouched tree,<br/>save baseline.reds;<br/>skipped for P0, Spike,<br/>UI Iteration, mid-run intake"]
    Base --> P1("Phase 1<br/>03")
```

Nodes: 14. The UI bindings are checked after the announcement and before Phase 1, in the order Step
0.4 lists them.

## Step 1.0 — may an item join this wave?

Waves are planned at Step 0.4 by Step 1.0's rules. When in doubt, serialize.

```mermaid
flowchart TD
    I("Next item") --> D1{"Every dependency Done,<br/>or passed Review<br/>this run?"}
    D1 -->|"no"| Later("Later wave")
    D1 -->|"yes"| D2{"Spike?"}
    D2 -->|"yes: passes rules 2–4,<br/>its directory is disjoint"| D4
    D2 -->|"no"| D3{"Shares a file, build unit,<br/>root file or artboard<br/>with a wave item?"}
    D3 -->|"yes"| Later
    D3 -->|"no"| D4{"Wave already<br/>holds 3 items?<br/>Spikes count"}
    D4 -->|"yes"| Later
    D4 -->|"no"| Join("Joins this wave")
```

Nodes: 7.

## Open questions

None.
