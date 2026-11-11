# Sizing work items

Every PMBook work item (feature, bug, spike) carries a size in points: **1, 2, 3, 5 or 8**. Both
triage skills size the rows they write; both orchestrators size any row that has none, and every bug
or spike taken at intake. The size measures the work, not the clock: how much changes, and how much is
still unknown.

## The scale

| Points | Feature or bug fix | Spike |
|---|---|---|
| **1** | One small change in one place, no unknowns: a label, a config value, a field added to an existing query. | One fact to check (does X support Y?). |
| **2** | A few files in one layer, following a pattern the repo already has. | Compare two known options on paper or in a few lines. |
| **3** | One slice across layers (API + UI, or query + endpoint), or a pattern new to the repo used once. Small unknowns. | A small prototype in one layer. |
| **5** | Several slices, a new data source or integration, or a screen with several states. Real unknowns the Developer can settle while building. | A prototype across layers, or one against a live system. |
| **8** | **Too big or too unknown for one packet. Never built as it stands** (below). | **The question is too broad:** narrow it or split it. |

## How to size

1. **Read the item, its acceptance criteria and the architecture**, and for an existing repo look at
   the code it will touch. Count the layers and files it changes, the acceptance criteria, new
   dependencies or data sources, and a screen's states.
2. **Unknowns push the size up one step:** an unfamiliar library, a data source nobody has queried yet, a
   board not yet Done. A bug whose cause is not yet known is at least 3.
3. **Pick the lower size when torn.** Two sizes apart means the item is not understood yet: ask, or
   size it 8.
4. **Never hours or days.** Points compare items with each other; how long an item actually took is
   recorded by the orchestrator's metrics, beside its size.

## An 8 is never built

1. **Triage:** no row leaves the PMBook gate at 8. Split it into rows of 5 or less (new stable IDs,
   `Depends on:` between them), or put a spike row before it that answers the unknown.
2. **Orchestrator:** an item sized 8 is held out of the run. Propose the split (or the spike first) to
   the user with a size for each part. Build nothing of it until the user says yes; the rest of the run
   carries on.

## Where the size is written

1. **Feature Backlog:** the `Size` column, between `Priority` and `Status`.
2. **Bug Log and Spike Log:** a `Size` column after `ID`. An existing table without one gets the column
   added; rows already there get `—` unless this run sizes them.
3. **A size is not changed once building starts.** If the work turns out bigger, say so in the
   Developer Output's Assumptions and Deviations; the metrics row keeps the planned size, so planned and actual can be
   compared.
