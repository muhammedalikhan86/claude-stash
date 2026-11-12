---
name: reload
description: "Restore minimal working context from docs/sessions/latest.md, plus any extra files named as arguments (e.g. /reload @docs/sessions/knowledge/warehouse-domain.md). Never reloads transcripts or compacted history. Run only when the user types /reload."
disable-model-invocation: true
argument-hint: "[@file ...]"
version: 1.0.0
---

# /reload

Arguments: `$ARGUMENTS`

Load the smallest useful context to carry on work: the session checkpoint plus only the files the
user names.

## Steps

1. **Checkpoint.** Read `docs/sessions/latest.md`. Skip the read if this session already holds it
   (the restore hook injected it after `/clear`, or it was read earlier in this session).
2. **Extra files.** For each argument, strip a leading `@` and read that file. Skip any whose content
   is already attached to the message (an `@` mention may have attached it). Arguments add to the
   checkpoint, never replace it.
3. **Do not read** `CLAUDE.md` (Claude Code loads it already), old summaries, `docs/sessions/archive/`,
   transcripts or compacted history. Do not open topic files in `docs/sessions/knowledge/` unless
   they were named as arguments.
4. **Report**, short:

   ```
   Context restored

   Loaded:
   - docs/sessions/latest.md
   - <each extra file>

   Current objective: <from latest.md>
   Recommended next action: <from latest.md>
   ```

## If it fails

- `docs/sessions/latest.md` is missing: list the newest `docs/sessions/*-session-summary.md` (then
  `docs/sessions/archive/`). If one exists, say: "No latest.md. Newest checkpoint is `<path>`. Say
  'load it' to read it." If none exists, say there is no checkpoint and suggest `/summarise` at the
  end of the next session.
- An extra file is missing: report it as not found, load the rest, and carry on.
