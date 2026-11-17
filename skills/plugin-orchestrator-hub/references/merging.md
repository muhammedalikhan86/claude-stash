# Merging a worker branch

Merges go folder to folder on this machine, never through a remote. The hub merges into
`hub.workBranch` (in the hub checkout) and then moves `hub.mainBranch` up to it. A big or conflicted
merge goes to a background helper briefed with this file and the guardrails.

## Who is never merged

1. A worker with `inHubCheckout: true` commits straight onto `hub.workBranch`. There is nothing to
   merge; its commits are already there. Its **uncommitted** files sit in the hub checkout's working
   tree and belong to it. The hub never stages, edits, restores or deletes them.
2. A branch that carries an ungated commit (no Reviewer PASS for an item it touches). Its other commits
   wait with it.

## Steps

```
# 0. What is dirty here, and whose
git status --porcelain                     # every path you did not write this turn is someone else's

# 1. Fetch (no -q: a quiet run has lost FETCH_HEAD before)
git fetch <checkout> <branch>

# 2. Conflicts?
git merge-tree --write-tree HEAD FETCH_HEAD >/dev/null; echo rc=$?     # 0 clean, 1 conflict

# 3. What the merge really changes
git merge-tree --write-tree --name-only HEAD FETCH_HEAD | tail -n +2
```

4. **Scope check.** Every changed path must sit under that component's `roots` or match a
   `merge.ruledExceptions` entry. Anything else: stop, ask the worker why, and do not merge until it is
   explained or removed. (Use the merge-tree list, not a three-dot diff: once a branch has merged main
   back in, a three-dot diff lists main's own files too.)
5. **Dirty-file check.** If any changed path is also dirty in the hub checkout (step 0), stop. The
   merge would write over another session's work. Ask that session to commit first.
6. **Merge.** History is linear on top of HEAD → `git merge --ff-only FETCH_HEAD`. Otherwise
   `git merge --no-ff FETCH_HEAD -m "Merge <component>: <item IDs>"`.
7. **Conflict** (rc=1): only in a ruled-exception file, resolve as its reason says (e.g. take HEAD's
   version, re-apply only that component's change), `git add <that path>`, `git commit --no-edit`.
   Anywhere else: do not merge. Send the worker the conflicting paths and tell it to merge
   `hub.mainBranch` into its branch and resolve on its side.
8. **Move main up** (when `hub.workBranch` ≠ `hub.mainBranch`): run `hub.fastForwardMain`. It fails if
   main is not an ancestor; then stop and tell the user.
9. **After:** green counts (below), status patch (`references/status-page.md`), tell any worker waiting on
   these items that they are on main and it should pull, and tell the user the milestone. Then start
   the strict **after-group disparity check** for that component in a background helper
   (`references/priorities-and-groups.md` §After-group disparity check).
10. **Full test run** (when `testing.workerScope` is `affected`): the workers' gates ran only the
   affected tier, so the hub runs the full set (§Full run after merge), after this merge or once per
   batch (`testing.fullAfter`).

## Full run after merge

Workers under tiered testing gate only what their change affects. The full set runs here, in a
background helper, on the hub checkout (its port offset), never in a worker's checkout.

1. Run `testing.fullCommand` with each suite's output sent to a log file (summary lines and failures
   only, never a whole log). Leave out `testing.onDemand` suites.
2. **All green:** update the green counts (below). One ⚪ FYI line at most.
3. **A red:** re-run that one test once. Still red → find its owner: the component whose roots hold the
   test, else the component whose merge since the last green full run touched what it tests. Send that
   worker "red after merge: `<test>` — `<log path>`, raise it as a functional bug". It goes ahead of
   queued features. A known-red already on the list is not re-sent.
4. Main is not moved back. A red the owner can't fix in its next group goes on the known-red list with
   its bug ID.
5. The layout and parity crawls (`testing.onDemand`) run only when the user asks or on a nightly cron.

## Push

Never push the main branch. Give the user the command, e.g.
`git -C <absolute hub checkout path> push origin <mainBranch>`.

## Green counts and known-reds

`paths.devEnvironment` holds each test project's passing count and the list of known-red tests. After a
merge that moves them (the worker's report says so), update only those lines with a pattern-based edit,
never by line number, and commit that one path. If the hub checkout has that file dirty from another
session, build the commit without touching the working tree:

```
S='s/<old line>/<new line>/'
h=$(git show HEAD:<file> | sed "$S" | git hash-object -w --stdin)
git update-index --cacheinfo 100644,$h,<file>
git commit -m "chore: green counts after <component> <items>"
```

Workers leave that file out of their own commits and send the counts to the hub.
