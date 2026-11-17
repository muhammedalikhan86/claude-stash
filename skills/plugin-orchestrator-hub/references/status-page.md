# The status page

`status.repo`/`status.file` is a JSON file that a static page renders. The hub patches it **in place**,
numbers only, and never regenerates it (a regenerate loses the stakeholder wording other people wrote).
Components in `status.excludeComponents` stay out of every figure.

**The PMBook is the only source of sizes.** Every item is sized and has its PMBook row the moment it is
raised (the orchestrator's *Sized and on the PMBook the moment it is raised*), so the page is counted
from the PMBooks, never from numbers in a worker's message.

## When

After every merge to main that moves a PMBook (items raised, resized, done or fixed, withdrawn), and when
the user asks for a recount. Do not batch to the end of the day. The count follows main: an item raised
on a worker branch counts once that branch merges.

## The patch

`python -I <patcher> --hub <hub checkout> <YYYY-MM-DD> "<log line in plain words>" [<cross-check spec> ...]`

`<patcher>` is this skill's `scripts/status_patch.py` when `status.patcher` is `skill`, else that path.
It counts each component (`statusName`, not excluded) from its PMBooks on `hub.mainBranch`
(`components[].statusPmbooks`, else `pmbook`, plus each one's closed tranches under `archive/*/`) with
`scripts/pmbook_points.py`: done points, open points, open items. It writes those numbers, and the
change in done points since the last patch feeds the velocity series and rates.

1. **Cross-check (optional).** A spec the hub expected, `"<statusName>:<done>:<remaining>:<total>:<items>"`
   (e.g. a merged group of n points: `n:-n:0:-k`), changes nothing; a disagreement prints `CROSS-CHECK`.
   The PMBook wins. Look at why (an unsized row, a wrong Status), and fix the PMBook, not the page.
2. **Unsized rows** are printed every run (`unsizedOpen`, `unsizedDone`, `uncounted`). An open one
   breaks the size-when-raised rule: send it to its worker to size. A done one is sized at its next
   Finalization (retrospective).
3. **`--dry-run`** prints the counts and writes nothing. **`--rebase`** writes the counts without moving
   the series or rates: the first PMBook-counted patch on a page that was kept by hand, or a recount
   the user asked for. **`--status <file>`** patches a copy instead.
4. A page with no PMBooks behind it can still take hand deltas (the legacy form in the script's usage).

Try `python -I scripts/pmbook_points.py <hub checkout>` to see the counts and the unsized rows alone.

Then, in the status repo: `git add <status.file>`, `git commit -m "status: <log line>"`, and
`git push origin <its branch>` only when `push.statusRepo` is `true`.

## What the file must hold

The patcher expects: `components[]` (`name`, `pointsDone`, `pointsRemaining`, `pointsTotal`,
`itemsRemaining`), `velocity` (`series[]`, `wholePeriodWorkingDays`, `pointsPerWorkingDay`,
`pointsPerWorkingDayWholePeriod`), `forecast` (`perComponent{}` with `rateLast10`, `rateWhole`, and
`overall`), and optionally `milestones[]`, `phases[]`, `log[]`. It stamps `updatedAt` and appends a `log`
entry each run. A file without that shape needs its own patcher (`status.patcher`).
