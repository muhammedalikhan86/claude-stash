# 10 — UI Iteration (Step 0.1d)

Small look-and-feel tweaks with no gates per tweak; the gates run once at "done".
Full procedure: `references/ui-iteration.md`.

## Opening and the tweak loop

```mermaid
flowchart TD
    Open("Explicit ask, or look-and-<br/>feel ask while sticky") --> Res["0.0a resolve component<br/>from the named screen"]
    Res --> Light["0.0 hard deps, resume<br/>check, held intakes;<br/>0.2 Format + Lint only;<br/>the rest held to done"]
    Light --> Stack{"Stack check:<br/>up?"}
    Stack -->|"no"| Offer["Offer to bring it up"]
    Stack -->|"yes"| RS
    Offer --> RS["Write run-state: run id,<br/>complete false, mode<br/>ui-iteration, openedAt,<br/>empty tweaks"]
    RS --> Ask{"Next ask"}
    Ask -->|"done"| DoneOut("Run the gates<br/>next diagrams")
    Ask -->|"cancel, stop"| Stop("Nothing committed,<br/>list the files, mark<br/>run-state complete")
    Ask -->|"anything else"| Kind{"Tweak, undo,<br/>or not a tweak?"}
    Kind -->|"tweak"| In{"Inside component<br/>and UI contract?"}
    Kind -->|"undo that"| Undo["Edit the last tweak back,<br/>never git checkout or stash"]
    Kind -->|"behaviour, data,<br/>new control or layout"| NT["Say so, offer to end<br/>and take as Feature or Bug"]
    In -->|"yes"| Edit["Orchestrator edits,<br/>scoped Format + Lint,<br/>no tests, no agents"]
    In -->|"another component,<br/>or off-contract"| Out["Stop that tweak: linked<br/>item or sign-off needed"]
    In -->|"a file outside<br/>every root"| EndIt("End the iteration: the ask<br/>becomes a Feature or Bug<br/>item, not a linked item")
    Edit --> Log["Log the tweak in run-state,<br/>reply in 1–2 lines"]
    Log --> Ask
    Undo --> Ask
    NT --> Ask
    Out --> Ask
```

Nodes: 17. On resume before `doneAt`, ask: keep iterating, or call done? After `doneAt`, rejoin the
"done" steps where they stopped. No work-item ID is taken until "done"; the run id is written at
opening, with `"complete": false`, so the component ladder's run-state rung finds it.

## "done", part 1 — finish Phase 0 and settle the design

```mermaid
flowchart TD
    D("User says done:<br/>record doneAt") --> Read["1 Read back<br/>the tweak list"]
    Read --> Ph0["2 Finish Phase 0: test<br/>command, Stack line,<br/>0.3b skill, test-cases check"]
    Ph0 --> Files["3 File set: tweak log files,<br/>+ artboard edits, + assertion<br/>files, + fix files; out-of-root:<br/>1-line justification; others:<br/>not this run's"]
    Files --> ID["4 Work-item ID: named, or<br/>next COMPONENT-F; keep the<br/>opening run id, work-dir<br/>folders follow it"]
    ID --> Own{"5 Design Gate, after<br/>the code: designer-owned?"}
    Own -->|"yes"| DAsk["One designer ask for<br/>every tweak, owed"]
    Own -->|"no"| Agent{{"Artboard Edit Prompt,<br/>orchestrated-developer,<br/>sonnet, Target: tweak list;<br/>its edits join the file set"}}
    DAsk --> Name
    Agent --> Name["Name Material component<br/>per touched surface<br/>in Design Reference"]
    Name --> Assert["6 Update stale<br/>assertions, list each"]
    Assert --> Pkt["7 One Feature-shape<br/>Task Packet, saved"]
    Pkt --> Next("Review<br/>next diagram")
```

Nodes: 11.

## "done", part 2 — review, parity, the rest of the pipeline

```mermaid
flowchart TD
    In("Packet saved") --> Log["8 Tweak log, artboard edits,<br/>assertion files to devout-ID.md;<br/>Reviewer gets the not this<br/>run's list"]
    Log --> Rev{{"One Reviewer<br/>sonnet, opus at loop 3"}}
    Rev -->|"FAIL"| Over{"loop_count<br/>already 3?"}
    Over -->|"yes: this FAIL<br/>takes it past 3"| Esc("Escalate; resume<br/>returns to 9, never<br/>a Developer, 09")
    Over -->|"no"| Inc["loop_count + 1"]
    Inc --> Look{"Fix changes the<br/>approved look?"}
    Look -->|"yes"| AskU["Ask the user first"]
    Look -->|"no"| Fix["9 Orchestrator fixes it,<br/>adds files to the set,<br/>out-of-root ones justified"]
    AskU --> Fix
    Fix --> Rev
    Rev -->|"PASS"| DR{"Design Reference<br/>in the packet?"}
    DR -->|"yes"| Par{{"10 Parity Check once,<br/>sonnet, 04"}}
    Par -->|"unruled mismatch"| Rule{"User rules on it"}
    Rule -->|"accept"| Ruled["Ruled deviation,<br/>user ruling with date,<br/>in the packet"]
    Rule -->|"reject: a FAIL"| Over
    Ruled --> Rest
    Par -->|"PASS"| Rest
    DR -->|"no"| Rest("11 Phase 2, Phase 3, commit,<br/>close-out; no Manual<br/>Verification, 06, 07")
```

Nodes: 14. UNVERIFIED follows Step 1.3's rule, as for any Reviewer. The PMBook Finalizer adds the
item's row already `Done`, with the tweak list as its criteria.

## Open questions

None.
