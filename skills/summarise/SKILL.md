---
name: summarise
description: "Save a session checkpoint before a context reset: a small navigational summary (docs/sessions/latest.md) plus durable topic files (docs/sessions/knowledge/*.md), then tell the user to type /clear. After /clear, the session-clear-restore hook loads latest.md only. Run only when the user types /summarise."
disable-model-invocation: true
version: 1.0.0
---

# /summarise

Checkpoint the session so the user can `/clear` and carry on with a small context.

- `docs/sessions/latest.md` is a **small navigational index**: objective, done, open, next, and links
  to topic files. It is what gets reloaded.
- `docs/sessions/knowledge/<topic>.md` holds **durable topic detail**. Topic files are never
  reloaded automatically. They are loaded on demand (`/reload @docs/sessions/knowledge/<topic>.md`,
  or when the work needs one).

Claude cannot run `/clear` itself. This skill writes the checkpoint, arms the restore hook, and tells
the user to type `/clear`. The hook (`~/.claude/hooks/session-clear-restore.sh`, SessionStart matcher
`clear`) then injects `latest.md` into the fresh session.

## Rules

1. **Index, not archive.** Never reproduce the conversation. Write only what is needed to carry on.
2. **No duplication.** Detail lives in exactly one topic file. The summary links to it.
3. **No secrets.** Never write passwords, keys, tokens or connection strings, and no real pay, book
   or client figures.
4. **Governed docs win.** If the repo has governed docs (PRD, Architecture, PMBook, ADRs, a handoff
   doc), link to them rather than copying their content into a topic file.
5. **Fail closed.** If any step fails, stop, say what failed, do **not** write the restore flag, and
   tell the user not to `/clear` yet. Their context is still intact.

## Steps

All paths are relative to the current working directory (the project root).

### 1. Prepare

1. Get the timestamp from the shell: `date +%Y-%m-%d-%H%M` (and `date "+%Y-%m-%d %H:%M"` for display).
2. Create `docs/sessions/`, `docs/sessions/knowledge/` and `docs/sessions/archive/` if missing.
3. If the folder is a git repo and `.gitignore` has no line ignoring `docs/sessions/`, append
   `docs/sessions/` to `.gitignore` (create the file if needed). Mention it in the reply the first time.

### 2. Topic files (semantic, not keyword)

1. List `docs/sessions/knowledge/`. For each existing file read only its first 3 lines (title and
   scope line), not the whole file.
2. Name the distinct topics this session produced lasting knowledge about: domain rules,
   architecture, decisions and their reasons, constraints, how a subsystem works, gotchas. Skip
   chit-chat, dead ends that taught nothing, and anything already in a governed doc.
3. Match each topic **by meaning** to an existing file. Same subject under another name is the same
   topic (e.g. "auth flow" and "sign-in" → one file). Keep existing names stable; never rename a
   topic file just to fit new wording.
4. For a match, read that file in full and **merge**: update stale facts in place, add new ones,
   drop what is now wrong. Do not append a dated log of changes.
5. For a genuinely new topic, create `docs/sessions/knowledge/<kebab-case-topic>.md`. Prefer a broad,
   durable name (`warehouse-domain`, `pricing-rules`) over a session-specific one (`fix-tuesday-bug`).
6. If two existing files turn out to be one topic, merge them into the better-named file, delete the
   other, and fix any links to it in `latest.md`.
7. Topic file shape, kept under about 150 lines (consolidate rather than grow):

   ```markdown
   # <Topic title>
   > Scope: <one line: what this file covers and what it does not>
   Updated: <YYYY-MM-DD>

   ## Key facts
   ## Decisions (with the reason)
   ## Constraints and gotchas
   ## Open questions
   ```

   Leave out empty sections.

### 3. Session summary

Write `docs/sessions/<YYYY-MM-DD-HHMM>-session-summary.md`. Aim for under 60 lines. Use terse
bullets. Carry forward still-open items from the previous `latest.md` (read it if it exists), and drop
the ones that are done.

```markdown
# Session checkpoint: <YYYY-MM-DD HH:MM>
Summary file: docs/sessions/<YYYY-MM-DD-HHMM>-session-summary.md

## Objective
<one or two lines>

## Done
- ...

## Decisions
- <only decisions not already in a topic file; otherwise "see knowledge/<topic>.md">

## Assumptions and constraints
- ...

## Files touched
- `path`: <what changed, a few words>

## Open tasks
- [ ] ...

## Open questions
- ...

## Next action
<the single most useful next step>

## Topics (load on demand: /reload @docs/sessions/knowledge/<file>)
| File | Covers |
|---|---|
| knowledge/<topic>.md | <one line> |
```

Leave out empty sections. List every topic file in the Topics table, not just the ones touched this
session, so the index stays complete.

### 4. latest.md

Write `docs/sessions/latest.md` as a **full copy** of the new summary (not a link), so a reload is one
read.

### 5. Archive

Keep the 10 newest `*-session-summary.md` files in `docs/sessions/`. Move older ones into
`docs/sessions/archive/`.

### 6. Verify

Check that the summary file, `latest.md` and every topic file you wrote exist and are non-empty
(`ls -l`). If not, follow rule 5.

### 7. Arm the restore hook

Write `docs/sessions/.pending-reload` containing one line: the summary file's path. The hook loads
`latest.md` on the next `/clear` (within 2 hours) and then deletes this file.

### 8. Reply

Keep it short:

1. The summary file path, and topic files created or updated.
2. The line: **Type `/clear` now.** After it, `latest.md` loads by itself. Load a topic later with
   `/reload @docs/sessions/knowledge/<file>.md`.
