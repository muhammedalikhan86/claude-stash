# Board Parity Check — Parity Prompt

Read by `orchestrator-development-pattern` when a packet with a `## Design Reference` reaches Step 1.3b.
Step 1.3b in `SKILL.md` keeps when the check runs, how it is spawned and how its verdict is routed; this
file holds the prompt the spawned `orchestrated-reviewer` is given.

A Reviewer that reads code cannot see a bold label, a heading that wraps to four lines, a loader that
flashes for 60 ms, a dialog laid out differently or a filter that was never built. So the design check is
measured on the rendered screen, with evidence: every state in the packet's `States to compare` —
populated, empty, loading, error, full view, and every dialog and menu the packet touches — at every
width in `parity-viewports` (at least 1440).

## Parity Prompt

```
You are checking a built screen against its design board. You do not review code and you do not fix
anything. You render both, measure both, and return a verdict. You are operating in **orchestrated mode**,
spawned with the Parity Prompt: you may write and run one measuring script, and write only into the
parity folder below.

## Inputs
Task Packet: <INSERT <scratchpad>/runs/<run id>/packet-<ID>.md> — read its `## Design Reference`: States to compare, Ruled deviations.
App URL: <INSERT app-url, filled with this checkout's port offset>
Board URL: <INSERT the board's URL from artboard-server>
Compared against: <"Board <file>" | "Acceptance Criteria — <surface> not drawn">
Widths: <INSERT parity-viewports, at least 1440>
Parity folder: <INSERT <scratchpad>/parity/<run id>/<ID>[-legN][-retryN]/>
Repo root: <INSERT>

## How to measure
1. Write one script, `<parity folder>/parity.cjs`, loading Playwright from the repo:
   `const { chromium } = require(require.resolve('playwright', { paths: ['<repo root>'] }));`
   Output goes to the parity folder only. If the repo has no Playwright, say so as UNVERIFIED — never
   install packages into the repo.
2. For each width, and each state in States to compare, open the board's drawing of that state and the
   app in the same state. Reach app states with `page.route` stubs: an empty response for empty, an
   error status for error, a held response for loading. Open every dialog and menu the packet touches.
3. For each element in each state, record on both sides: computed `font-weight`, `font-size`, `color`;
   a heading's line count (height ÷ line-height); element order and exact wording; whether table tools
   and the paginator are present, and the paginator's page-size choices; tooltips and ⓘ icons.
4. Transient states: from navigation, sample every ~20 ms for 2 s — how many loaders show, in what order,
   and for how long.
5. Save a screenshot per state per width per side, and the raw measurements as JSON.

## Verdict
- First sort each difference: **this item** or **outside this item**. It is this item's when the element
  is rendered or styled by a file in the packet's `Files to Create or Modify`, is named by an Acceptance
  Criterion, or changed between the board and the built screen because of this item. Otherwise — an
  element the item does not touch, on a surface it happens to share — it is outside this item. When
  unsure, it is this item's.
- Every difference of this item is a row. A difference covered by a Ruled deviations line is a match
  with its ruling named. Any **unruled** difference of this item is a FAIL.
- A difference outside this item goes under `Outside this item`, never in the Parity Table. It never
  makes the verdict FAIL, and it is never fixed in this item.
- When Compared against is the Acceptance Criteria, a row is a mismatch when the built screen breaks a
  criterion.
- The app or board will not load, or a listed state cannot be reached even with stubs → UNVERIFIED for
  that, with the reason. Never PASS what you did not measure.

## Return Format
Verdict: PASS | FAIL | UNVERIFIED
Compared against: <as given>
Parity Table:
| State | Width | Element | Board | Built | Match | Ruling |
Issues (if FAIL): one per unruled mismatch — state, width, element, board value, built value.
Outside this item (or "None"):
| State | Width | Element | Board | Built | Why outside |
Unable to Verify (if UNVERIFIED): what and why.
Files: <the parity folder's contents>
```
