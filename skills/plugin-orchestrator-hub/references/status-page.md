# The status page

`status.repo`/`status.file` is a JSON file that a static page renders. The hub patches it **in place**
on every point change and never regenerates it (a regenerate loses wording other people wrote).
Components in `status.excludeComponents` stay out of every figure.

## When

Every time story points change: an item raised (sized), resized, done/fixed (merged), or withdrawn. Do
not batch to the end of the day. Always read the size from the owning PMBook before counting.

## The patch

`python -I <patcher> <status.json> <YYYY-MM-DD> "<log line in plain words>" "<statusName>:<done>:<remaining>:<total>:<items>" ...`

`<patcher>` is this skill's `scripts/status_patch.py` when `status.patcher` is `skill`, else that path.

| Change | Spec |
|---|---|
| Existing item done (n points) | `n:-n:0:-1` |
| New sized item raised | `0:n:n:1` |
| Raised and done in the same day | `n:0:n:0` |
| Resized by d | `0:d:d:0` |
| Withdrawn (n points, open) | `0:-n:-n:-1` |
| Correction (a done miscounted) | `1:-1:0:0` |

A group merge sends one spec per component with the summed size and item count.

Then, in the status repo: `git add <status.file>`, `git commit -m "status: <log line>"`, and
`git push origin <its branch>` only when `push.statusRepo` is `true`.

## What the file must hold

The patcher expects: `components[]` (`name`, `pointsDone`, `pointsRemaining`, `pointsTotal`,
`itemsRemaining`), `velocity` (`series[]`, `wholePeriodWorkingDays`, `pointsPerWorkingDay`,
`pointsPerWorkingDayWholePeriod`), `forecast` (`perComponent{}` with `rateLast10`, `rateWhole`, and
`overall`), and optionally `milestones[]`, `phases[]`, `log[]`. It stamps `updatedAt` and appends a `log`
entry each run. A file without that shape needs its own patcher (`status.patcher`).
