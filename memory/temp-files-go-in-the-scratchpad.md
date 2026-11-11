---
name: temp-files-go-in-the-scratchpad
description: "Temp files (command output, scripts, screenshots) go in the session scratchpad, never the filesystem root, the repo or a tool's install folder; tell every sub-agent the exact scratchpad path."
metadata:
  type: feedback
---

# Temp files go in the session scratchpad

Every temporary file — captured command output, throwaway scripts, screenshots — goes in the session
scratchpad directory. Never `/`, the repo root, `C:\Program Files`, or a tool's install folder.

**Why:** on 2026-11-11 an orchestrated Reviewer wrote `prettier.txt` to the Git Bash root (`/`, which is
`C:\Users\muhammedali.khan\AppData\Local\Programs\Git\` on this machine) because a `$SCRATCH` variable
was unset, and a safety check then blocked its removal, so the user had to delete it by hand. They said
it should never have been created.

**How to apply:**
- Sub-agents don't know the scratchpad path. Put the exact absolute scratchpad path in every spawn
  prompt and say "temp files go only here; never rely on an env var that may be unset".
- Never build an output path from a variable that may be empty (`$SCRATCH/x` becomes `/x`).
- In Git Bash, `/` is the Git install folder, not `C:\`. Use `cygpath -w` before telling the user a
  Windows path.
