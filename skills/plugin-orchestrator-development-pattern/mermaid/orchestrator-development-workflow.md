# Plugin Orchestrator Development Pattern — Flow Diagram

Reference only; `SKILL.md` is the source of truth. Updated 2026-11-10 for v1.9.0 (Board Parity Check, Step 1.3b). Earlier, 2026-11-06 for v1.4.0 (push and pull allowed on a go from the user or a hub session). Earlier, 2026-11-03 for v1.3.0 (UI Iteration, third diagram). v1.2.0 added (linked runs, the
cross-component-dependency FAIL path, known-red failures, the stack lifecycle, the release label decided
before Phase 3, designer-owned artboards, the Orchestrator commits by itself and never pushes). v1.1.0 added waves, batched manual verification, test scope,
four Finalizers and Orchestrator-drafted commit messages.

## Main flow

```mermaid
flowchart TD
    Start([Start]) --> Resolve["Step 0.0a: resolve component\n(ladder, never a default)\nprint confirmation block"]
    Resolve --> Deps["Step 0.0: hard deps, resume check,\nDeferred Integration check,\ntest-cases-doc check"]
    Deps --> Entry{"Entry point"}
    Entry -->|PMBook| Read["0.1 Read PMBook"]
    Entry -->|Bug| BugIntake["0.1b Bug Fix Intake\nexisting Bug Log row → reuse its ID\nelse the 'next ID' line wins"]
    Entry -->|Spike| SpikeIntake["0.1c Spike Intake"]
    Entry -->|"UI tweaks"| UIIter["0.1d UI Iteration\n(see the UI Iteration diagram)"]
    Read --> Platform
    BugIntake --> Platform
    SpikeIntake --> Platform
    Platform["0.2 Platform + scoped Format/Lint\n+ component test command\n+ Stack: up · down · check"] --> Conv["0.3 Conventions\n0.3b Specialist skill (once)"]
    Conv --> Plan["0.4 Plan waves (≤3, disjoint files\nand build units) + announce\nrun-state: ISO date-times"]

    Plan --> Wave["Phase 1: run a wave\n(each item on its own chain)"]
    Wave --> DG{"UI packet?"}
    DG -->|no| Dev
    DG -->|yes| Owner{"Artboards\ndesigner-owned?"}
    Owner -->|no| Design["1.1b Design Gate\nedit or author the artboard"]
    Owner -->|"yes, small change"| ACSpec["Acceptance Criteria are the spec\nflag a designer ask"]
    Owner -->|"yes, new layout, not drawn"| Halt["HALT item\nuntil the designer draws it"]
    Design --> Dev["1.2 Developer\nopus high (xhigh at loop 3)"]
    ACSpec --> Dev
    Dev -->|Spike| SpikeLog["Spike Log Finalizer"]
    Dev --> StackR{"Bug with an\nE2E regression test?"}
    StackR -->|yes| Up1["stack up + check"] --> Rev
    StackR -->|no| Rev["1.3 Reviewer\nsonnet (opus at loop 3)"]
    Rev -->|"FAIL, own files, loop ≤3"| Dev
    Rev -->|"FAIL, loop >3"| Esc["Escalate, pause"]
    Rev -->|"FAIL, only in another\ncomponent's files"| XC["Cross-component dependency\nno retry, loop_count unchanged\nraise linked item (user OK)"]
    XC --> Linked["Run as Linked Runs\n(see second diagram)"]
    Linked -->|"linked item passed review"| Rev
    Rev -->|UNVERIFIED ≤2| Rev
    Rev -->|"PASS, UI packet"| Parity["1.3b Board Parity Check (sonnet)\nrender app + board, measure\nevery listed state and width"]
    Parity -->|"FAIL: unruled mismatch, loop ≤3"| Dev
    Parity -->|"FAIL, loop >3"| Esc
    Parity -->|UNVERIFIED ≤2| Parity
    Parity -->|PASS| Kind{"Item type"}
    Rev -->|"PASS, no UI"| Kind
    Kind -->|Feature| Passed["passed review\n(PMBook written at Phase 3)"]
    Kind -->|Bug| Queue["queued for verification"]
    Kind -->|P0| P0["verify now → P0 fast lane"]
    Passed --> More{"More waves?"}
    Queue --> More
    SpikeLog --> More
    More -->|yes| Wave
    More -->|no| MV["1.5 Batched Manual Verification\n(one message, all bugs,\nall linked runs, Parity Tables)"]
    MV -->|still broken| Dev
    MV -->|all verified| Scope["2.0 Test scope:\nfull if shell / out-of-root change /\nno component command / linked runs;\nelse component"]
    Scope --> Int["2.1 Integration (sonnet)\ndiff guard per owning item,\nevery Test (full) command,\nstack order: E2E while up → down → build"]
    Int --> Red{"Failure this run\ndid not cause?"}
    Red -->|"tracking ID + owner by path\n+ git evidence"| KR["Known-red: recorded,\nnot silenced"]
    Red -->|"no tracking item"| AskU["Report to the user;\nthey decide whether to raise one"]
    Red -->|none| Clean
    KR --> Clean{"Clean first pass?\nno fixes, tree unchanged,\nself-check all ticked,\nlogs agree"}
    AskU --> Clean
    Clean -->|"yes: Orchestrator checks,\nno spawn"| Label
    Clean -->|no| RI["2.2 Reviewer-Integration (sonnet)\nread-only git diff + gate logs\nchecks scope + each known-red"]
    RI -->|"FAIL, docs/report only"| DocRetry["Doc-only retry\n(resume same spawn)\nno gate re-run"]
    DocRetry --> RI
    RI -->|FAIL ≤3| Int
    RI -->|FAIL at 3| DnC["Divide-and-Conquer once"]
    DnC -->|still failing| Esc
    RI -->|PASS| Label["Orchestrator decides the\nrelease label per component\n(Unreleased or next version)"]
    DnC -->|PASS| Label
    Label --> Fin["Phase 3: 4 parallel Finalizers per component\nGraphify (stamp + uncommitted tree) |\nPMBook (+sweep, Bug Log row in place) |\nHandoff | Revision+Changelog+Runbook"]
    Fin --> Commit["3.5 Orchestrator commits\nby exact path, pushes only on a go\n(depended-on component first)"]
    Commit --> Close["3.6 Close-out checklist:\nmetrics (new dated section if header changed),\nrun-state, notes, known-reds, stack state"]
    Close --> Done([Done])
```

## Linked Runs

Two components' items that must land together — one breaks without the other. Each item keeps its
own component, docs, run-state file and graph; the Integration is shared.

```mermaid
flowchart TD
    A["Item A (plugin)\nReviewer FAIL in a file\nthe shell owns"] --> Raise["User OK → raise linked item B\nin the owning component\nDepends on: both ways"]
    Raise --> B["Item B (shell)\nown packet, own run-state\nlinkedRuns names A"]
    B --> BDev["B: Developer → Reviewer"]
    BDev -->|PASS| ARev["A: Reviewer respawned\nagainst the current tree\n(loop_count unchanged)"]
    ARev -->|PASS| MV["One batched Manual Verification\nfor A and B"]
    MV --> Int["ONE combined Integration\nTest scope: full\nDiff Guard: each file vs its own item"]
    Int --> RI["Reviewer-Integration"]
    RI -->|PASS| Fin["4 Finalizers × 2 components\nall in one message\n(disjoint files)"]
    Fin --> Commit["Commits:\nB first, then A\n(pushed only on a go)"]
```

## UI Iteration (Step 0.1d)

Small look-and-feel tweaks with no gates per tweak; the gates run once at "done".
Full procedure: `references/ui-iteration.md`.

```mermaid
flowchart TD
    Open["Open: explicit ask, or a look-and-feel ask
while the skill is sticky"] --> Res["0.0a resolve component
Format + Lint detected
stack check (offer make up)"]
    Res --> Ask{"Next ask"}
    Ask -->|"look-and-feel tweak"| In{"Inside this component
and the UI contract?"}
    In -->|yes| Edit["Orchestrator edits directly
scoped Format + Lint
log the tweak in run-state"]
    Edit --> Look["User looks at the live screen"] --> Ask
    In -->|no| Out["Say so; it becomes a linked item
or needs sign-off"] --> Ask
    Ask -->|"not a tweak (behaviour, data,
new control or layout)"| Offer["Offer: end iteration,
take it as a Feature or Bug"]
    Ask -->|"undo that"| Undo["Edit the last tweak back
(never git checkout / stash)"] --> Ask
    Ask -->|"cancel"| Stop["Stop: nothing committed,
list the files"]
    Ask -->|"done"| Done["Read back the tweak list
file set = the tweak log only
take the next F-ID"]
    Done --> DG["Design Gate, once, after:
designer-owned → designer ask owed
repo-owned → one agent updates artboard"]
    DG --> Assert["Update assertions the tweaks
made stale"]
    Assert --> Rev["One Reviewer (sonnet)
over the whole change"]
    Rev -->|"FAIL ≤3"| Fix["Orchestrator fixes
(asks first if the look changes)"] --> Rev
    Rev -->|PASS| Rest["Integration → R-I → 4 Finalizers
→ commit (pushed only on a go) → close-out
(no Manual Verification Gate)"]
```
