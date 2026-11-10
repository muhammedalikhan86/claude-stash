# Design files — layout, formats, bindings

The one description of a repo's design folder. `sync-artboards`, `idea-triage`, `plugin-idea-triage`
and both orchestrators read it; none of them restates it.

## Layout

```
docs/design/                         design-directory
  brief.md                           standing rules for the designer (below)
  rows/<page>.md                     design-rows-directory — the change ledger, rows only
                                     (plugin repo: rows/<component>/<page>.md)
  rounds/round-NNN.md                design-rounds-directory — one file per round
  artboards/<component>/             artboards-directory — synced boards, never edited by hand
  artboards/<component>/changes/     the designer's change logs, synced in with the boards
```

A single-component repo uses one artboards folder; name it after the app. Rows files are per page —
a page is one board file (one screen, or one screen family drawn together).

## `brief.md` — the standing rules

Written once (by triage, or by hand) and sent with the first round; later rounds point to it.

```markdown
# Designer brief — <app>

## Build rules
- Every control must be buildable from <the repo's UI library — Shaw work: Angular Material / CDK>.
  Draw the component, not a look-alike. A control the library lacks is a question, not a drawing.
- Use the design system's tokens; no one-off colours, sizes or fonts.

## States to draw for every screen
Populated, empty, loading, error, and every dialog, menu and pop-up the screen opens. Long text,
many rows and no rows. The widths in parity-viewports (default 1440).

## Your change log
Keep one change log per page in the design project, at `project/docs/<page>-changes.md`. Each round,
add a section headed with the round number and date; for every row ID in the round write
`Built` or `Not done — <why>`, and list any file you added, moved or removed. Add to it; never rewrite
an earlier round's section. The sync reads this log to know what to check.
```

## `rows/<page>.md` — the ledger

```markdown
# Design rows — <page>

| ID | Change | Source | Round | Status |
|---|---|---|---|---|
| P1 | Empty state: "No portfolios yet" panel with the Add button | F-012 AC3 | 001 | Done 2026-11-14 |
```

1. **ID** — a letter per screen plus a number (`P1`, `P2`, `D1` …). The letter is fixed per screen
   for the life of the repo; numbers only go up. **Never renumber, never reuse.**
2. **Change** — what is drawn or changed, in plain words, with the check that proves it.
3. **Source** — where it came from: a work item and AC, a ruling (who, date), a meeting, a sync finding.
4. **Round** — the round it was sent in (`001`), or `open` while it waits in the open round.
5. **Status** — `Open`, `Done YYYY-MM-DD` (checked by a sync), or `Withdrawn YYYY-MM-DD — <why>`.

The ledger holds rows only. Narrative (why a batch was raised, validation notes) goes in the round file.

## `rounds/round-NNN.md` — one round

```markdown
# Design round NNN

Status: open | sent YYYY-MM-DD | back YYYY-MM-DD
Rows: P4, P5, D2

## Summary (for <user>)
<Never sent. A few plain lines: what changes on screen, where, before and after, any assumption.
Its job is to let the user catch an ask that is not what they want before sending it.>

## Detailed prompt (paste to the designer)
<In a code block. Stands alone: the brief's path or its rules, every row ID with its change and its
check, the files to open, and the change-log instruction from brief.md, restated.>

## Sync findings, YYYY-MM-DD
<Written by sync-artboards: rows Done, rows still Open and why, follow-up rows raised, test counts.>
```

## Rules for rows and rounds

1. **One open round at a time.** New rows go into the open round (`Round: open`, and listed under
   `Rows:`), and its Summary and Detailed prompt are rewritten to include them. When the user says it
   is sent, set `Status: sent <date>` and each row's Round to the number. The next row starts a new
   round file.
2. **Never raise a row against an ask the user sent the designer directly** — that ask is settled.
3. **Never invent client-facing wording.** Use a visible placeholder (`<label text — to confirm>`).
4. **Both texts are shown to the user** in the reply, Summary first, whenever a round is written or
   changed.
5. A row that needs a test gets it in the same commit, if the repo binds `design-row-tests`.

## Bindings (`.claude/SKILLS.md`)

| Binding | Default | What it is |
|---|---|---|
| `design-directory` | `./docs/design` | the folder above |
| `artboards-directory` | `./docs/design/artboards` (plugin: `/{component}`) | where boards land |
| `design-rows-directory` | `./docs/design/rows` (plugin: `/{component}`) | the ledgers |
| `design-rounds-directory` | `./docs/design/rounds` | the round files |
| `design-source` | — | where the designer works: an Artifact URL plus its root (`project/`), or a design project id |
| `artboard-server` | — | command and port that serve the boards |
| `design-validate-command` | — | tests run against the boards after a sync |
| `design-row-tests` | — | how a row is tied to a test: tag, skip marker, any known-differences list |
| `design-post-sync` | — | anything run after a sync (e.g. refresh a demo repo), and whether Claude may push it |
| `ui-contract` | `brief.md` §Build rules | the full UI contract, if the repo has one |

Unbound and not found in the repo's `CLAUDE.md` or design README: `design-source` is asked for once
(it cannot be guessed), then offered for `SKILLS.md`; every other one skips its step and the report
says so. The folder bindings fall back to the defaults above.

## Old layout

Signs: ledgers named `review-<page>.md` inside the artboards folder (rows, narrative and stored
prompts in one file), prompts kept outside the repo, or boards present with no `rows/` and `rounds/`.
Skills keep working with it (see `sync-artboards` §Old layout) and **suggest** the move, once per
session; they never move anything themselves. The move: `references/migrate-design-layout.md`.
