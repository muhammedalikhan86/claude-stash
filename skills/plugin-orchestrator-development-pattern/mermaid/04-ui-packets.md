# 04 — UI packets: Design Gate and Board Parity Check

Full procedure: `references/ui-packets.md`. Before Phase 1, if `app-url` or `artboard-server` is
missing, the Orchestrator asks the user once; the Parity Check is never skipped for want of a URL.

## Design Gate (Step 1.1b) — before the Developer, never after

```mermaid
flowchart TD
    S0("UI packet,<br/>before Developer") --> AB{"1 artboards-directory<br/>binding present?"}
    AB -->|"no: say so,<br/>skip steps 1–4"| Name
    AB -->|"yes"| Own{"Designer-owned?<br/>artboards README,<br/>SKILLS.md"}
    Own -->|"no, repo-owned"| Agree{"2 Artboard exists<br/>and matches AC?"}
    Agree -->|"yes"| NoChange["Print: already<br/>matches, no change"]
    Agree -->|"no"| Edit{{"3, 4 edit or author it<br/>orchestrated-developer,<br/>sonnet, Artboard Edit Prompt;<br/>its files to run-state"}}
    Own -->|"yes, never edit"| Drawn{"Surface drawn<br/>and agrees?"}
    Drawn -->|"yes"| Name
    Drawn -->|"no"| Small{"Small change, fully<br/>in the AC?"}
    Small -->|"yes"| ACSpec["AC are the spec,<br/>designer ask owed"]
    Small -->|"no, new or<br/>changed layout"| Halt1("HALT item until<br/>designer draws it")
    NoChange --> Name
    Edit --> Name
    ACSpec --> Name["5 Name Material or CDK<br/>component per surface<br/>in Design Reference"]
    Name --> Mat{"6 Every surface Material,<br/>or signed-off exception?"}
    Mat -->|"no"| Halt2("HALT this item,<br/>other wave items go on")
    Mat -->|"yes"| Style["7 Styling source<br/>per surface"]
    Style --> Diff["8 Print the diff,<br/>re-save the packet"]
    Diff --> Dev("1.2 Developer<br/>03")
```

Nodes: 17. The designer-owned check is the exception to steps 3 and 4, so it is read before them. In
a UI Iteration this gate runs once, after the code, at "done" (`10-ui-iteration.md`).

## Board Parity Check (Step 1.3b) — after the code Reviewer's PASS

```mermaid
flowchart TD
    S0("Code Reviewer PASS,<br/>packet has Design Reference") --> Up["1 Bring up stack<br/>and board, check both,<br/>app-url with port offset"]
    Up --> Spawn{{"2 Parity check<br/>orchestrated-reviewer,<br/>sonnet, Parity Prompt"}}
    Spawn --> Measure["3 Measure every state<br/>at every width, min 1440,<br/>vs board, or AC if not<br/>drawn or no binding"]
    Measure --> Table["4 Parity Table:<br/>element, board, built,<br/>match, ruling"]
    Table --> V{"5 Verdict"}
    V --> Keep["6 Keep this run's table<br/>path in run-state,<br/>PASS or FAIL"]
    Keep --> Res{"Result"}
    Res -->|"PASS"| Pass("Step 1.4 On PASS<br/>03")
    Res -->|"FAIL: unruled mismatch"| Where{"Fix lies in another<br/>component's files?"}
    Where -->|"yes"| XC("Cross-component route<br/>11")
    Where -->|"no"| Fail("Mismatches = issues,<br/>loop_count + 1, Developer,<br/>code Reviewer, Parity again<br/>03")
    Res -->|"UNVERIFIED: app or<br/>board would not load"| Unv["Fix or respawn,<br/>max 2, then escalate"]
    Unv --> Spawn
```

Nodes: 12. Step 1.5 attaches the latest Parity Table; the metrics row counts the unruled mismatches
across every run's table.

## Open questions

None.
