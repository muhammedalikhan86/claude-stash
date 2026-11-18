# Timers: check-ins, limit resumes and other crons

The hub owns every timer in the run. Workers and helpers make none. All of them are session crons
(`CronCreate`): they die when the hub session closes or restarts, and they fire in the machine's local
time, the same clock the limit messages use.

## Rules for every timer

1. **`CronList` before every `CronCreate`.** Same purpose and time already there → keep it, create
   nothing. That is how duplicates and strays are avoided.
2. **Check when it really fires.** After creating one, read its next run in `CronList`. The scheduler
   can land a recurring cron well off its expression (about 30 minutes has been seen); note the real
   offset in the hub operations file once, not the expression.
3. **The session note lists every live timer** (purpose, expression or one-shot time, what it does), so a
   restart or a new hub can recreate them. The heartbeat is listed as "hub.json `watch.heartbeatCron`",
   never by its expression.
4. **A timer that wakes a worker checks it is live first** (`ListAgents`). A message to a closed session is
   lost without an error: reopen the worker (`scripts/launch-workers.ps1`) and brief it from its handoff.
5. **The task bar and the queue file** are updated in any timer pass that moved something (`SKILL.md`
   §Task bar, §Queue file).

## Heartbeat (the check-in)

1. **Created** at start-up and Resume, recurring, from hub.json `watch.heartbeatCron`, never from a note.
2. **One pass:** one `ListAgents`; merge whatever is ready; green counts; answer open questions; nudge any
   worker idle without a reason (with its next step); patch the status page if points moved; update the
   task bar and the queue file if anything moved. It is a fallback, not a poll.
3. **A pass that finds nothing says nothing** to the user. A pass that acted reports only decisions,
   escalations and milestones, one line each.

## Usage-limit resume timers (the 5-hour limit)

1. **How the hub learns of a limit.** A worker's message or idle notice that says it hit the limit, or
   `ListAgents` showing a worker idle with a step half done and its last output naming the limit. The
   hub's own limit is known only from the user or from the hub's own limit message.
2. **The reset time** comes from the limit message ("resets at HH:MM", local time). Not given → the next
   5-hour boundary the user or the hub operations file names; still unknown → ask the user.
3. **One one-shot timer per distinct reset time**, at reset + 5 minutes, naming the workers that hit that
   reset. A later worker with the same reset joins that timer (note it in the session note); a different
   reset gets its own timer. **Never a recurring resume timer**: it fires when nobody is limited and
   wastes a pass.
4. **When it fires:** for each named worker, check it is live (rule 4 above), read its live state
   (`references/state-and-switch.md` §Where state lives), and tell a parked or idle worker to carry on
   from its handoff's next step, or a worker that stopped mid-step to resume that step. Subscribe to each
   one's idle notice. Then run one heartbeat pass, and tell the user in one line who resumed.
5. **Reset already past** (found at Resume or after a restart) → create nothing; resume those workers now.
6. **The hub itself near its limit.** Its timers cannot do anything useful while it is limited. Before a
   limit it can see coming, tell every worker what to do alone: finish the current group's gate, commit,
   send "parked", and stop. Then set the resume timer for the hub's reset; when it fires, the hub runs a
   full heartbeat pass first, then resumes the workers as in step 4.
7. **The weekly limit is not a timer job.** It is an account switch
   (`references/state-and-switch.md` §Account switch), started about an hour before the limit, so every
   worker reaches a safe stop in time.

## Other timers

1. **Designer-log check** (`references/designer-loop.md` §"Designer is done", step 3): at most one, hourly.
   It reads `design.changeLogs`; when the round's row IDs appear, it starts the sync and deletes itself.
   Recreated at Resume only while that round is still out.
2. **Nightly layout and parity crawl** (`references/merging.md` §Full run after merge, hub.json `testing.onDemand`): only when hub.json
   `watch.nightlyCron` is set, at that time; it runs the crawl and reports reds to the owners. No key →
   no crawl timer; the crawls run when the user asks.

## Start-up, Resume, `/clear` and the account switch

1. **Start-up and Resume:** `CronList`; then create the heartbeat from hub.json, the designer-log check if
   its round is still out, `watch.nightlyCron` if set, and each resume timer from the session note whose
   reset + 5 minutes is still ahead (one already past → resume those workers now).
2. **After a `/clear`** the crons are still running, but the hub no longer knows why. `CronList`; keep each
   one that matches hub.json or the session note; delete the rest.
3. **Account switch:** cancel every timer (`CronList`, then `CronDelete` each) before the old session
   closes. A timer left on the old account keeps firing and spends that account's limit. The hand-over
   lists the one-shots by time and purpose, and the heartbeat as "hub.json `watch.heartbeatCron`".
4. **The new hub** checks the old hub session is closed (`ListAgents`) before it recreates anything, so
   the same timer never runs on two accounts. Still open → ask the user to close it first.
