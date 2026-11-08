# Spike Flow and P0 Hotfix Fast Lane

Read by `plugin-orchestrator-development-pattern` only when the run contains a Spike or a `Priority: P0`
Bug. Both are named exceptions to specific steps, not parallel pipelines.

---

## Spike Intake (Step 0.1c, alternate entry point)

Triggered instead of Step 0.1 only when the user explicitly asked for a spike — "spike this", "run a
spike on X" — never inferred from exploratory-sounding language.

1. **No PMBook row needed.** Take the question directly from the user, plus any approaches to try
   ("explore freely" is a valid answer). If the question is unclear, ask.
2. **Assign a Spike ID.** Next number after the highest `<COMPONENT>-S-XXX` in the PMBook's `## Spike Log`;
   start at `S-001` if none. IDs are stable once assigned.
3. **Assign a Spike Directory.** Default `spikes/S-XXX/` under `source-code-directory` unless the user says
   otherwise. Mandatory.
4. Go to Step 0.2 and Phase 1 with a Spike-type Task Packet. Announce with one line:
   `Spike Mode — S-XXX: <one-line question>`.

## Spike Flow

Reached instead of Step 1.3, right after the Spike's Developer spawn (always
`plugin-orchestrated-developer-high`; a Spike never escalates).

1. The Developer Output *is* the deliverable — Findings plus a recommendation (promote to the Feature
   Backlog / abandon / needs more investigation), with every file inside the Spike Directory.
2. **No Reviewer, no retry loop, no Manual Verification Gate, no Integration, no escalation path.**
   `loop_count` never moves. This is a deliberate, accepted risk — it is what makes a Spike fast.
3. Spawn one `orchestrated-finalizer`, Task = `Spike Log`, `model: "sonnet"`, scoped to this Spike. It
   writes one row to the PMBook's `## Spike Log` (`ID | Question | Recommendation | Spike Directory |
   Follow-up`), creating the section if needed. No other Finalizer runs and no commit is made.
4. Spike code stays where the Developer left it, uncommitted. What happens next is the user's call.
5. Log `🔎 S-XXX <question> — Findings recorded, see Spike Log`; move to the next work item.

A Spike may share a wave with other items (Step 1.0) — its Spike Directory is disjoint from everything by
construction.

---

## P0 Hotfix Fast-Lane Finalization

Triggered only from Step 1.5's `verified` branch, and only for a packet with `## Priority: P0`. A P0 is
verified immediately (it is never held for the batched Manual Verification Gate). Everything upstream —
Developer, the full retry loop, the Manual Verification Gate — is unchanged from a normal Bug; only what
happens after a genuine `verified` differs.

1. Run the same Phase 3 batch (Graphify / PMBook Update / Handoff Update / Revision + Changelog, Test
   Runbook — four parallel Finalizers, models per **Model Assignment**), with Task-Specific Inputs scoped to
   this one Bug. The Orchestrator then makes this fast lane's commit itself (Step 3.5), pushing only on a go.
2. **PMBook Update** for this item: write the `## Bug Log` row with `Status: Hotfixed — Integration
   Pending`, and append a `## Deferred Integration` row (`Bug ID | Hotfixed On | Status: Pending`),
   creating that section if needed.
3. **Graphify runs here**, before Phase 2 has validated this item — an accepted, named exception to
   "graphify only after Integration passes".
4. **Single-item run:** if this P0 was the only work item, the run ends after this Finalization. The
   Deferred Integration row stays `Pending` until a later run's Phase 2 re-validates it.
5. Otherwise return to the Feature Loop for the remaining items.

Output line, right after the 🐛 line:

```
🚑 B-XXX — P0 Fast-Lane Finalization complete
   Status: Hotfixed — Integration Pending
   Deferred Integration row added — full-suite validation still owed
```

A P0 forces `Test scope: full` the next time its Deferred Integration row is re-validated — it shipped
without any suite run at all.
