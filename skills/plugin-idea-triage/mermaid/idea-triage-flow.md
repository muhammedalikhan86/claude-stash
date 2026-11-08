# Idea Triage Flow

```mermaid
flowchart TD
    Start([Idea]) --> D0{"Does this automate or replace\na process that already exists?"}
    D0 -->|No| TrancheCheck
    D0 -->|Yes| P0["Phase 0: Discovery\nbuild the record from evidence,\nask business + technical questions,\nwrite analysis notes"]
    P0 --> Q{"Any open question left\nin either question document?"}
    Q -->|"Yes - ask, get answers,\nmove them into the record"| P0
    Q -->|No| G0A{"GATE 0a\nUser approves: record finalised?"}
    G0A -->|No| P0
    G0A -->|Yes| PROP["Proposal:\nas-is vs to-be, what we can\ndeliver, with options"]
    PROP --> G0B{"GATE 0b\nUser approves the option?"}
    G0B -->|No| PROP
    G0B -->|Yes| PACK["Packaging:\nproposed packages,\ndependencies, tranches"]
    PACK --> G0C{"GATE 0c\nUser approves packaging?"}
    G0C -->|No| PACK
    G0C -->|"Yes - the governed-doc folder\nopens here, not before"| TrancheCheck
    TrancheCheck{"PMBook ACTIVE &\nall Phases Done?"}
    TrancheCheck -->|Yes| Closeout["Tranche Closeout:\narchive PMBook + handoff,\ncarry forward open items,\nbump Tranche vN+1"]
    Closeout --> B
    TrancheCheck -->|No| B[Phase 1: Draft PRD]

    B --> G1{User approves PRD?}
    G1 -->|No| B
    G1 -->|Yes| C["Phase 2: Draft Architecture\n(+ ADR per Technology Decision)"]
    C --> G2{"User approves Architecture?\n(pre-checks: unresolved High/High\nrisk, Unaddressed Security row)"}
    G2 -->|"No / unresolved\nissue not accepted"| C
    G2 -->|"Yes, or accepted\nas trade-off"| D[Phase 3: Draft PMBook]
    D --> G3{User approves PMBook?}
    G3 -->|No| D
    G3 -->|Yes| E([Done — hand off to\norchestrator-development-pattern])

    C -->|Ripple from PRD change| R1["Review downstream impact\n(+ Decommissioning Rule for\nDone/In-Progress features)"]
    D -->|Ripple from Architecture change| R2["Review downstream impact\n(+ Decommissioning Rule for\nDone/In-Progress features)"]
    R1 --> U1[Ask user whether to update docs]
    R2 --> U2[Ask user whether to update docs]
    U1 -->|Yes| C
    U1 -->|No| D
    U2 -->|Yes| D
    U2 -->|No| E

    C -.->|"Downstream finding\ninvalidates a PRD\nassumption/goal"| UP1["Upward Ripple:\nre-read PRD, ask user\nupdate or accept trade-off"]
    D -.->|"Downstream finding\ninvalidates PRD or\nArchitecture assumption"| UP2["Upward Ripple:\nre-read upstream doc(s),\nask user update or\naccept trade-off"]
    UP1 -.->|Update PRD| B
    UP1 -.->|Accept trade-off| C
    UP2 -.->|Update PRD| B
    UP2 -.->|Update Architecture| C
    UP2 -.->|Accept trade-off| D

    C -.->|"Finding contradicts\nthe discovery record"| P0
    D -.->|"Finding contradicts\nthe discovery record"| P0

    classDef gate fill:#fff3cd,stroke:#ffb703,color:#000000;
    classDef phase fill:#e8f0fe,stroke:#1a73e8,color:#000000;
    classDef done fill:#e8f5e9,stroke:#2e7d32,color:#000000;
    classDef tranche fill:#e6ccff,stroke:#7700cc,color:#000000;
    classDef discovery fill:#fff0e6,stroke:#e07000,color:#000000;
    class P0,PROP,PACK discovery;
    class D0,Q,G0A,G0B,G0C gate;
    classDef upward fill:#ffe0cc,stroke:#cc6600,color:#000000;

    class G1,G2,G3 gate;
    class B,C,D,R1,R2,U1,U2 phase;
    class E done;
    class TrancheCheck,Closeout tranche;
    class UP1,UP2 upward;
```

**Notes:**
- Solid arrows are the normal forward path and downward ripple (PRD → Architecture → PMBook). Dashed arrows are Upward Ripple — a downstream finding (most often an Architecture-phase research spike, but PMBook triage can trigger it too) that invalidates an upstream goal, non-goal, constraint, or assumption. Upward Ripple never applies to a routine technology choice that stays within what the PRD already scoped.
- `TrancheCheck` runs at the start of every triage session when new ideas are presented, not just on an explicit "close out" request — see Tranche Lifecycle.
- `G2`'s pre-checks (unresolved `Impact: High` + `Likelihood: High` risk row, or an `Unaddressed` Security & Compliance Checklist row when §9 is present) are soft gates: surface and ask, never silently block or silently pass.
- Every document change on every edge above increments that document's `Version` and adds a `Version History` row labeled `Triage edit`, `Gate approval`, `Ripple from <Doc> vN`, `Upward ripple from <Doc> vN`, or `Tranche closeout`, per the Versioning rules.
