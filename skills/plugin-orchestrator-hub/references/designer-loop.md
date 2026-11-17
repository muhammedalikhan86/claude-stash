# The designer loop

The designer works somewhere the hub cannot reach (`design.source`, often a claude.ai session). The user
pastes every prompt. The hub's job: collect what the designer owes, write the prompt, and pull the
round back in when it is done.

## Collect

1. Open design rows across components: the rows files or review ledgers `sync-artboards` describes
   (`references/design-files.md` in that skill). A row is open until a sync marks it done.
2. **Mid-build, send only functional rows** (a missing part, wrong words, a broken state). Look-only rows
   wait for the parity sweep.

## Row IDs (the hub hands them out)

Every design row ID in the project comes from the hub, so two workers never take the same one.

1. A worker that needs rows sends "row IDs: `<letter>` × `<count>`, for `<item>`" and waits for the reply
   before writing them.
2. The hub takes the highest number for that letter across every rows file or review ledger and every
   designer change log (`design.changeLogs`), on main **and** on each worker's branch, and the IDs it has
   already handed out (one line per letter in the hub operations file: `design IDs: P up to 79`). It
   hands out the next ones, updates that line, and replies with them.
3. **A collision already made:** the row the designer has already seen keeps its ID. Every other row
   with that ID gets a fresh one from step 2, in its ledger, round file and any unsent prompt, before
   the next prompt goes out. Record the mapping (`advisor P75 → P80`) in the rulings log.

## Write the prompt

Two parts, both in the reply:

1. **Summary for the user**: one line per row (component, row ID, what changes), and how many rows.
2. **The prompt to paste**, in a code block, standing alone (the designer keeps no history between
   chats): per row, the board file, what to draw, the rule or item it follows. Wording the business still
   owes is drawn as **lorem ipsum**, never invented. Also save it to `design.promptFile` under
   `## Prompt for the designer <date> — not yet sent`; mark it sent when the user says so.

## "Designer is done"

1. Start a background helper that runs `design.syncSkill` (`sync-artboards`, full mode) with the
   repo's bindings, and reports: rows done, rows still open, failing board tests split into stale tests
   (the owning worker updates the test) and boards that look wrong (a new row).
2. Hand each finding to its owning worker; new rows go in the next prompt.
3. Optional: a one-off hourly cron that reads `design.changeLogs` and starts the sync when the round's row
   IDs appear, then deletes itself.
