---
name: local-fixes-vs-repo-fixes
description: "When fixing setup or environment problems, always report exactly which files changed and flag anything that should become a repo-level fix for other developers."
metadata: 
  node_type: memory
  pinned: true
  originSessionId: 2e445efb-dcdb-4952-b584-238b013162b0
  modified: 2026-09-11T03:52:36.742Z
---

# Separate machine-local patches from repo-level fixes

When getting a project working — a fresh checkout, a broken build, an environment
problem — the user wants two distinct things reported, not one:

1. **Exactly which files were created or modified on this machine**, including
   gitignored ones. A clean `git status` is not the whole answer, because the
   fix may live entirely in files git does not track.
2. **Whether any of those fixes belong in the repository instead**, so that other
   developers do not have to rediscover and hand-apply the same fix on their own
   machines.

The reasoning the user gave: "if there are changes that need to be made on the
other developers end then we need to adjust those in the code." A fix that only
exists on one developer's machine is an onboarding trap for everyone else, and
documenting it in a README or CLAUDE.md is weaker than automating it in a setup
script or a `make` target that people already run.

So when a setup fix turns out to be per-machine (a gitignored settings file, an
environment variable, a local path pin), do not treat the task as finished once
the build is green. Say plainly that the fix is machine-local, and propose the
repo-level change — a new setup target, a committed template file, a check in an
existing install script — that would stop the next developer from hitting it.
