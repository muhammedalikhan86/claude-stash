# Moving a repo to the design-folder layout

For a repo whose design work predates `references/design-files.md`: per-page `review-<page>.md`
ledgers in the artboards folder (rows, narrative and stored prompts mixed in one file), and round
prompts kept outside the repo (e.g. `designer-rows-N.md` on the Desktop).

**Never automatic.** A skill that finds the old layout points here and suggests the move; the move
runs only on the user's yes, as its own commit, at a time no design round is out with the designer
(the designer's next change log should name rows the new files already hold).

## 0. Before — take a count

1. List every old ledger: `review-*.md` under the artboards folder.
2. For each, count rows by status: Open, Done (any `Done, checked …`), Withdrawn. Keep the counts and
   the full ID list (e.g. `C1…C145, P1…P59`) in the scratchpad, not the repo.
3. List the old prompts: in the ledgers (stored Summary / Detailed prompt blocks), and outside git
   (ask the user where — e.g. `Desktop\designer-rows-N.md`). Note each one's date and the IDs it names.
4. If the repo binds `design-row-tests`, list every test tag that names a row (e.g.
   `grep -rn "@review-" <tests folder>`) and every known-differences entry naming one.
5. Ask the user which earlier briefs are still in force (e.g. a `designer-brief-<date>.md`, a UI
   contract for designers).

## 1. Make the folders and bindings

Create `rows/` (plugin repo: `rows/<component>/`) and `rounds/` under the design folder, and set
`design-directory`, `design-rows-directory`, `design-rounds-directory` in `.claude/SKILLS.md`. Leave
`artboards-directory` where the boards already are; if one component's boards live in an oddly named
folder, record that in the binding (or the design README), not in prose only.

## 2. Rows — one ledger per page

For each `review-<page>.md`, write `rows/<page>.md` with `| ID | Change | Source | Round | Status |`:

1. **Every row, same ID.** Never renumber, never merge, never drop a Withdrawn row.
2. **Status:** `Done, checked YYYY-MM-DD` → `Done YYYY-MM-DD`; `Open` and `Withdrawn YYYY-MM-DD`
   as they are (add the reason after `—` if the old file gives one).
3. **Change:** the old row text, shortened only by removing narrative that is not the ask.
4. **Source:** from the old row or the batch prose around it (work item, ruling with who and date,
   meeting). Unknown → `pre-migration`.
5. **Round:** the round (step 3) whose prompt named the row; none → `pre-migration`. An Open row no
   sent prompt names gets `open` and goes into the open round.

## 3. Rounds — import old prompts as past rounds

Number the old prompts in date order as `round-001.md`, `round-002.md` …. Each gets `Status: sent
<date> | back <date>` (back = the next sync's date, if known), `Rows:`, the Summary and Detailed
prompt as they were sent (word for word), and under `## Sync findings, <date>` the old
`## Validation, <date>` notes and batch narrative that belong to it. Narrative that fits no round goes
into `rounds/round-000.md` (`Status: history`). Rows still Open after this become the next, open
round.

## 4. Brief and change logs

Write `brief.md` from the briefs still in force (step 0.5) plus the standing change-log instruction
(`references/design-files.md` §brief.md). If the designer already keeps change logs in the design
source, the next sync pulls them into `<artboards-directory>/changes/`; nothing to move by hand.

## 5. Tests

Row IDs are unchanged, so `@review-<ID>`-style tags need no change. Only if a tag or a comment points
at the old file (e.g. `see review-portfolio-services.md`) repoint it to `rows/<page>.md`.

## 6. After — check, then remove the old files

1. Row counts by status match step 0.2, page for page, and the ID lists are identical.
2. Every row in `rows/` with Round `NNN` is named in `round-NNN.md`'s `Rows:`, and back.
3. Every test tag from step 0.4 names an ID present in `rows/`.
4. Old prompts from outside git are in `rounds/` word for word.
5. Grep the repo (docs, skills bindings, README, CLAUDE.md, tests) for `review-` file references
   and repoint each.
6. Only then delete the old `review-*.md` files (`git rm`), in the same commit, and tell the user the
   Desktop copies can go. Show the counts from 1 in the report.
