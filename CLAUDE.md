# claude-stash

The source of the team's Claude Code setup: skills, agents, rules, memory, mods, hooks, output styles
and the global instructions. `install.ps1` copies it into `~/.claude`; `publish-to-prod.ps1` copies it
to the shared folder that `create-symlinks.bat` links other machines to. `README.md` has the layout.

## Working rules

1. **Work on `main`.** No branches. Commit only when the user says so; never push.
2. **Fix it here, never in `~/.claude`.** Anything under `~/.claude` that this repo installs is
   overwritten by the next install. Edit the repo, then run `install.ps1` when the user says so.
3. **`global/CLAUDE.md` is the global instruction file** (installed as `~/.claude/CLAUDE.md`). This file
   is only this repo's own instructions.
4. **`rules/shaw-estate.md` keeps the `<DB_PASSWORD>` placeholder.** The installer carries the real
   password over from the installed copy; never write it into a tracked file or into chat.
5. **After an install,** compare `~/.claude/settings.stash.json` with `settings.json`; delete the stash
   file when nothing in it is missing from `settings.json`, else list what is.

## Editing skills and agents

1. **Bump the version** of a changed orchestrator skill: the `version` in its `SKILL.md` and the
   `vX.Y.Z` in its `mermaid/README.md`. Other skills with a `version:` field bump it too.
2. **`agents/orchestrated-developer.md` is the source** of `plugin-orchestrated-developer-high.md` and
   `-xhigh.md`. After editing it, run `pwsh scripts/build-developer-agents.ps1`, then the same with
   `-Check`.
3. **The plain and plugin variants move together.** A change to `orchestrator-development-pattern`
   usually needs the same change in `plugin-orchestrator-development-pattern` (and likewise for
   `idea-triage` and `init-adlc-repo`).
4. **Checks before a commit:** `git diff --check`, no CR characters in changed files, and the
   build-developer-agents check.
5. **Scratch scripts** for bulk edits go in the session scratchpad, never in the repo.

## Taking effect

A skill change needs `/reload-skills` in each session. An agent change needs the session restarted, so
parked runs resume at safe points (`docs/metrics/skill-rounds.md` records how the rounds go).
