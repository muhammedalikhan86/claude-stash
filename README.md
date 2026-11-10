# claude-stash

Shaw & Partners' shared Claude Code setup: skills, agents, hooks, rules, memory, mods and output
styles, plus the lessons learned building them. Clone it, run the installer, and a new developer
gets the same Claude Code that the rest of the team already uses.

This repo is the source. The `\\sic2tfs1\Claude\Prod` share is where it is published for the team.

```
claude-stash repo  --publish-to-prod.ps1-->  \\sic2tfs1\Claude\Prod  <--links--  each person's ~/.claude
   (edit here)          (maintainer)            (shared copy)          create-symlinks.bat (every account)
```

There are two ways to set up a machine:

1. **Linked to the share (the team default).** Run `create-symlinks.bat`. Your `~/.claude` links to
   the share, so you get updates as soon as they are published, and every Claude Code account on
   your machine shares one copy. Needs the network or VPN while you work. See
   [docs/share/README.md](docs/share/README.md), which is also the share's own README.
2. **Local copy.** Run `install.ps1` (below). Real files, no network needed, updated when you
   `git pull` and run it again. For working offline, or for trying changes before publishing.

You can switch between them any time; each one backs up what it replaces.

## Publish to the share (maintainers)

```powershell
.\publish-to-prod.ps1 -WhatIf     # preview; changes nothing
.\publish-to-prod.ps1             # publish
.\publish-to-prod.ps1 -Target \\sic2tfs1\Claude\Dev -ShareRoot ""   # try it on Dev first
```

1. It refuses to run if the repo has uncommitted changes, the generated developer agents are stale,
   or `rules/shaw-estate.md` holds a real password instead of the `<DB_PASSWORD>` placeholder.
2. It copies everything to a staging folder on the share, then swaps each item in, moving the old
   one into `\\sic2tfs1\Claude\Backups\publish-<date-time>\`. An item someone has open is skipped and
   reported; run it again later.
3. Besides the shared items, it puts `install.ps1`, `retired.txt` and `settings.template.json` in
   `Prod`, and `create-symlinks.bat` and [docs/share/README.md](docs/share/README.md) at the share root.
4. It lists anything on the share that this repo doesn't hold, and leaves it alone.
5. To undo: `.\publish-to-prod.ps1 -Rollback "\\sic2tfs1\Claude\Backups\publish-<date-time>"`.

After publishing, people pick up changes the next time Claude Code starts. A new skill, memory file
or rule needs them to run `create-symlinks.bat` again, so it gets linked too.

## Install a local copy

Needs: Windows, Claude Code, Git Bash (`bash` on PATH) and Python 3 (the hooks use both).

```powershell
git clone <this-repo-url> "$env:USERPROFILE\source\repos\claude-stash"
cd "$env:USERPROFILE\source\repos\claude-stash"
.\install.ps1 -Context7Key <your-context7-key>
```

Preview first, then install. Nothing is changed by the preview:

```powershell
.\install.ps1 -WhatIf
.\install.ps1
```

What the installer does:

1. **Backs up first.** Everything it replaces or deletes is copied to
   `~/.claude-backups/install-<account>-<date-time>/`, with a `manifest.json` of every change, written as it goes.
2. Copies each skill, agent, agent task file, hook, rule, memory, mod and output style this repo holds
   into `~/.claude`, replacing the old copy. Your own skills and other items are left alone.
3. Replaces old symlinks to `\\sic2tfs1\Claude\Prod` with real files. Only the link is removed; the
   share is never written to. Anything in a linked folder that this repo lacks is kept.
   If the share can't be reached, it stops before changing anything.
4. Deletes items listed in `retired.txt` (renamed or retired; backed up first).
5. Copies `CLAUDE.md`. If yours is a hard link shared with another account's folder, yours gets its
   own copy and the other one keeps its text.
6. Keeps your Shaw database password from your old `rules/shaw-estate.md`.
7. Writes `settings.json` from `settings.template.json` if you have none. If you have one, it
   writes `settings.stash.json` beside it for you to merge by hand.

To undo an install, pass its backup folder (the installer prints the exact command at the end):

```powershell
.\install.ps1 -Rollback "$env:USERPROFILE\.claude-backups\install-claude-<date-time>" -WhatIf   # preview
.\install.ps1 -Rollback "$env:USERPROFILE\.claude-backups\install-claude-<date-time>"
```

Rollback puts back every file and link, including the symlinks to the share. Making a symlink needs
an administrator window (or Developer Mode with PowerShell 7). If a link can't be made, the folder's
old contents come back as real files instead, so nothing is lost, and it prints the command to run
as administrator. Before it removes anything, rollback saves what is there now (including edits made
since the install) in a `before-rollback-<date-time>` folder inside the backup folder.

Then do these by hand:

1. **Context7 key**: if you did not pass `-Context7Key`, put it in `settings.json` under
   `env.CONTEXT7_API_KEY`. Get a free key at https://context7.com.
2. **Shaw database password**: ask the team lead, then replace `<DB_PASSWORD>` in
   `~/.claude/rules/shaw-estate.md`. It is kept out of git on purpose.
3. **graphify**: `uv tool install graphifyy` (or `pip install graphifyy`).
4. **Public skills**: see below.
5. Restart Claude Code.

To update later: `git pull`, then `.\install.ps1`.

## What is in here

| Folder | Goes to | What it is |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Global instructions: when to use which skill, mod conventions |
| `rules/` | `~/.claude/rules/` | Always-on rules: Context7 use, Shaw estate (code, Angular Material, databases), memory index |
| `memory/` | `~/.claude/memory/` | Lessons learned, one per file (Shaw.DataAccess not EF Core, library review flow, exec briefs …) |
| `skills/` | `~/.claude/skills/` | Our own skills (see list below) |
| `agents/` | `~/.claude/agents/` | Developer / Reviewer / Integration / Finalizer agents used by the orchestrator skills |
| `agent-notes/` | `~/.claude/agent-notes/` | Each agent's standalone rules (read when a human calls it directly, with no orchestrator), plus background and examples it reads when a rule is unclear |
| `scripts/` | — | `build-developer-agents.ps1` regenerates `agents/plugin-orchestrated-developer-*.md` from `orchestrated-developer.md`. Re-run it after editing that file |
| `hooks/` | `~/.claude/hooks/` | Guard and helper hooks, wired up in `settings.template.json` |
| `commands/` | `~/.claude/commands/` | Slash commands (`/init-claude-settings`) |
| `output-styles/` | `~/.claude/output-styles/` | `ELI5` and `terse` reply styles |
| `mods/` | `~/.claude/mods/` | Claude Code UI mods (see below) |
| `claude-plugin-marketplace/` | — | A plugin marketplace with the `web-dotnet-toolkit` plugin. See its own README |
| `docs/lessons/` | — | Write-ups of fixes and what was learned |
| `docs/share/README.md` | `\\sic2tfs1\Claude\README.md` | The share's README: how team members run `create-symlinks.bat` |
| `install.ps1` | — | Local copy (`install.ps1`) or links to the share (`install.ps1 -Link`), with backup and rollback |
| `create-symlinks.bat` | `\\sic2tfs1\Claude\` | Runs `install.ps1 -Link` for one user's accounts, from an administrator Command Prompt |
| `publish-to-prod.ps1` | — | Publishes this repo to `\\sic2tfs1\Claude\Prod`, with backup and rollback |
| `settings.template.json` | `~/.claude/settings.json` | Hooks, permissions, plugins, env vars. No secrets |

### Skills

| Skill | Use |
|---|---|
| `idea-triage`, `plugin-idea-triage` | Idea → PRD → Architecture → PMBook, before any code |
| `orchestrator-development-pattern`, `plugin-orchestrator-development-pattern` | Developer → Reviewer → Integration → Finalizer pipeline |
| `init-adlc-repo`, `plugin-init-adlc-repo` | Set a repo up for the above. Both copy `skills/init-adlc-repo/templates/graph.ps1` into the repo as `scripts/graph.ps1`, the standard knowledge-graph build script (it reads its components and roots from the repo's `.claude/SKILLS.md`) |
| `graphify` | Build a knowledge graph of a codebase or docs |
| `llm-council` | Pressure-test a decision with five advisors |
| `dont-lie` | Strict accuracy / no invented sources |
| `shaw-dotnet-estate` | How to build against the Shaw .NET estate and `Shaw.*` NuGet packages |
| `sync-artboards` | Pull designer artboards into `shaw-plugin-dashboard` |
| `claude-account-switcher` | Switch between team Claude Code accounts on Windows |
| `pdf-to-markdown` | Convert PDFs to Markdown before Claude reads them |
| `context7-mcp`, `find-skills`, `developing-with-streamlit` | Helpers |

### Mods

| Mod | State |
|---|---|
| `answer-buttons` | **On.** Buttons under Claude's questions. Loaded through `CLAUDE_CODE_PLUGIN_DIRS` |
| `task-bar` | Off by default. Task list pinned above the prompt |
| `comment-on-response` | Off by default. `/comment` on selected reply text |

To turn on an extra mod for one session: `claude --plugin-dir "$env:USERPROFILE\.claude\mods\task-bar"`.

The mods' `tsconfig.json` points at `.claude-plugin/types/`. Claude Code generates that folder, so
it is not in git. It only matters for editor type-checking, not for running the mod.

## Public skills

These come from public repos, so they are installed from there, not copied here. They stay up
to date that way.

```powershell
# 66 language / framework expert skills (angular-architect, csharp-developer, sql-pro, the-fool …)
npx skills add jeffallan/claude-skills -g -y

# .NET review skills
npx skills add github/awesome-copilot@dotnet-best-practices -g -y
npx skills add github/awesome-copilot@dotnet-design-pattern-review -g -y

# Diagrams, idea graveyard, CLI catalog, book → skill
npx skills add tt-a1i/archify -g -y
npx skills add Shubhamsaboo/awesome-llm-apps@project-graveyard -g -y
npx skills add HKUDS/CLI-Anything@cli-hub-meta-skill -g -y
npx skills add virgiliojr94/book-to-skill -g -y

# Angular: use the official skills (the old angular-* ones are deprecated)
npx skills add angular/skills -g -y
```

Plugins (`understand-anything`, `vercel`) are listed in `settings.template.json` and install from
inside Claude Code with `/plugin`.

## Keeping this repo clean

1. **No secrets.** API keys and passwords go in your own `~/.claude`, never here.
2. **No machine paths.** Use `~/.claude/...` or `%USERPROFILE%\...`, not `C:\Users\<name>\...`.
3. **No runtime junk.** Sessions, history, caches, snapshots, credentials and backups stay in
   `~/.claude`. `.gitignore` blocks the usual ones.
4. Changed a skill in your `~/.claude`? Copy it back here and open a pull request.
