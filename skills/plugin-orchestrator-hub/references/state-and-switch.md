# State, resume and the account switch

## Where state lives (in order of trust)

1. **Live state** — always read first, always wins. Per checkout: `git log --oneline -10`,
   `git status --porcelain`, its PMBook queue (`components[].pmbook`) and its handoff
   (`components[].handoff`). Plus `ListAgents` for who is running.
2. **Session note** (`paths.sessionNote`, written by the `summarise` skill) — a small index: where the
   hub stopped, what is waiting on whom, crons to recreate.
3. **Hub operations file** (`paths.hubOperations`) — how this hub works on this project: commands that
   worked, gotchas, the worker plan in one paragraph, open hand-outs. Keep it under ~100 lines; prune
   what is done.
4. **Rulings log** (`paths.rulingsLog`) — every ruling, committed, read by workers and the next hub.

Notes go stale; live state does not. Never resume a worker from a note alone: check its checkout first.

## Rulings log format

```
## <YYYY-MM-DD>
- <rule in one line>. Ruled by <user|hub>. Items: <IDs>. Supersedes: <earlier line, or —>.
```

Newest day at the bottom. A worker that meets a question checks this file before asking.

## Resume (a new hub, same or another account)

1. Read hub.json.
2. If the user pointed you at the previous account's folder (e.g. `~/.claude-<old>/projects/<project>/memory`),
   read its `MEMORY.md` index and the entries it marks as hub entries. Do not copy them; read them in place.
3. Read live state for every component (above).
4. Read the session note, then the hub operations file, then the rulings log tail.
5. Recreate the crons the session note lists (heartbeat, designer-log check, and a usage-limit resume
   timer whose reset + 5 minutes is still ahead; one already past → resume the workers now instead).
6. Carry on from Start-up step 4 in `SKILL.md`.

## Account switch

Start early: before the limit, not at it. One worker group can take an hour to reach a safe stop.

1. **Tell every worker:** "Account switch coming. Reach a safe stop: finish the current gate, commit by
   path, update your PMBook and handoff, then send me `parked <hash>`. Don't start a new item." Subscribe
   to each one's idle notice.
2. **Wait for every `parked`.** A worker that goes idle without one gets one nudge with its live state.
3. **Merge** every parked branch (`references/merging.md`), green counts, status patch.
4. **Cancel the crons** (`CronList`, then `CronDelete` each).
5. **Write the hand-over** in the hub operations file under `## Hand-over <date>`: the old account, the new
   one, each worker's parked hash and next step, what is waiting on the user or the designer, open
   hand-outs. Then run `summarise` so `paths.sessionNote` points at it.
6. **Tell the user** (tiered):
   - 🔴 the push command for the main branch, if anything merged;
   - what to run: `./launch-as <new account>` in the hub checkout;
   - what the new hub reads: the old account's memory folder path, `paths.sessionNote`,
     `paths.hubOperations`, `paths.rulingsLog`;
   - what it must recreate: the crons, by expression.

The new hub then follows §Resume and opens the workers on the new account.
