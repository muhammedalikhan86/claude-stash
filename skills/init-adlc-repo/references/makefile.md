# The Makefile standard

Every ADLC repo has a `Makefile` at its root with the targets below. People and agents use the same
names in every repo, so nobody has to learn each repo's own commands. Both init skills write it, their
upgrade mode adds what is missing, and both orchestrators call it.

## Targets (all required)

| Target | Does | Agents run it |
|---|---|---|
| `help` | The default target. Lists every target, one line each. | yes |
| `install` | Restores packages on a fresh clone (npm, dotnet, …). | yes |
| `up` | Starts the stack on this checkout's ports from `~/.claude/ports.md`. | yes |
| `down` | Stops what `up` started, and only that: never another checkout's processes. | yes |
| `restart` | `down`, then `up`. | yes |
| `status` | What is running, on which ports, and whether it answers. | yes |
| `logs` | Shows the stack's logs. | yes |
| `build` | Debug build. | yes |
| `test` | The whole test suite. | yes |
| `lint` | Linters, no changes. | yes |
| `format` | Applies the formatter. | yes |
| `audit` | Dependency vulnerability scan. **Exits non-zero on any finding** (wrap tools that exit 0 with findings, like `dotnet list package --vulnerable`). | yes |
| `check` | The quality gate: format check, lint, test, audit. Exits non-zero if any part fails. | yes |
| `publish` | Builds release artefacts into a local folder. Never ships anything. | yes, except where a release build ships by itself (the `Shaw.*` libraries: their Release build pushes to the feed, so `publish` there is the user's only) |
| `deploy` | Ships a release. See below. | **only when the user asks for this deploy** |
| `rollback` | Puts a previous release back. See below. | **only when the user asks for this rollback** |
| `ports` | Prints this checkout's rows in `~/.claude/ports.md` and flags a clash. Never edits another checkout's rows. | yes |
| `graph` | Rebuilds the knowledge graph (`scripts/graph.ps1`). | yes |
| `docs-check` | The repo's governed-doc checks. | yes |
| `clean` | Deletes build output only (`bin/`, `obj/`, `dist/` …). Never source, data or config. | yes |

1. **A target that doesn't apply** still exists and prints `<target>: not used in this repo`, exit 0
   (no graph, no logs). `test` with no suite prints `no test suite` and exits 0; the orchestrator
   reports that as a gap, never as a pass.
2. **Plugin repos:** each target covers every component; `C=<component>` narrows it to one. A repo
   with several projects (web and API) does the same with `P=<project>`; `deploy` and `rollback`
   require it, so one project ships at a time.
3. **Ports:** `up`, `status` and `ports` read this checkout's rows in `~/.claude/ports.md`. No target
   hard-codes a port another checkout holds.
4. **`audit` that can't run fails.** A feed that refuses the vulnerability query (a 401 from a private
   feed) makes `audit` exit non-zero with a message saying why, never a silent pass.
5. **Windows:** GNU make runs recipes in `sh` or `cmd` depending on `PATH`. Either set
   `SHELL := bash` (Git Bash) and run each `cd` in a subshell, `(cd dir && …)` (with `.ONESHELL` a
   `cd` carries over), or keep the Makefile thin and send every target to one PowerShell
   script in the repo's scripts folder, so it behaves the same from any shell. Use the script option when
   `bash` on `PATH` is the WSL launcher (`C:\Windows\System32\bash.exe`), not Git Bash. Process ids and logs that `up` writes go in a
   gitignored `.run/` folder.

## `deploy`: ship only what is ours

1. **The user's call.** An agent runs `make deploy` only when the user asks for that deploy in so many
   words, never as a "next step". The settings `ask` rules below force a prompt in every mode.
2. **Clean and tagged.** It refuses with uncommitted changes. Before copying, it tags the commit
   `deploy/<env>/<version>`, or `deploy/<env>/<project>-<version>` in a repo with several deployable
   projects (TFVC: a label). The tag is local; pushing it is the user's call.
3. **A local copy first.** Before it changes anything, it copies what is on the server now into
   `%USERPROFILE%\deploy-backups\<repo>\<tag>\`, outside the repo.
4. **Only its own files.**
   1. The target is this app's own folder, set once in the Makefile. It refuses an empty target, a
      drive or share root, or a path that doesn't end in the app's folder name.
   2. A dry run comes first (`robocopy /L`, `rsync -n`) listing every file it would add, change or
      delete. It stops if any path is outside the app's folder or on the keep list.
   3. The keep list (files the server owns: deployed config such as `<ApiProject>.dll.config` or
      `appsettings.Production.json`, `logs/`, folders the app writes at runtime) is excluded from both
      the copy and the delete (`/XF`, `/XD` with `/MIR`).
5. **Shaw apps** also follow the IIS deployment standard, DEP-1 to DEP-10
   (`~/.claude/skills/shaw-estate/references/hosting-and-deployment.md`): scripts never stop IIS or a pool.
6. **After:** a smoke test, then it prints the tag and the backup folder.
7. **Where the checks live:** in the repo's deploy script (`deploy/deploy.ps1`), with `make deploy`
   only calling it, so a deploy started any other way gets the same dry run, copy and keep list. A
   step the standard makes interactive (DEP-1's typed `stopped`) stays interactive.

8. **A checkout the user doesn't deploy** (analysis only, or someone else, such as the product owner,
   ships it): don't wire `deploy` or `rollback`. Both print `<target>: not configured; <why, and who
   deploys and how>` and **exit 1**, unlike other unused targets, so no script or agent mistakes
   them for a deploy that ran. Leave the repo's own deploy scripts as committed, and keep the `ask`
   rules while those scripts exist. Record the choice in `CLAUDE.md`.

## `rollback`: by tag, keeping every copy

1. **The user's call**, as for `deploy`.
2. `make rollback` with no `TAG` lists the deploy tags with their backup folders, and stops.
   `make rollback TAG=<tag>` builds that tag from a clean checkout of it (a scratch worktree, never the
   working tree) and ships it through the same `deploy` path: same dry run, same keep list, and a new
   local copy of what it replaces.
3. If that tag can't be built, it offers the saved copy of that release: the backup the *next*
   deploy took when it replaced it (a tag's own backup folder holds what was there *before* it). It
   restores only after the user types `restore`, through the same checks.
4. It never deletes a tag or a backup folder. Pruning them is the user's call.

## Settings: `deploy` and `rollback` always ask

Add these to `.claude/settings.json` under `permissions.ask`. An `ask` rule prompts even in `auto` and
`bypassPermissions` mode. The wrap-around form catches `cd x && make deploy` too; the `deploy.ps1`
rules stop an agent going round `make`.

```json
"ask": [
  "Bash(*make deploy*)",
  "Bash(*make rollback*)",
  "Bash(*deploy.ps1*)",
  "PowerShell(*make deploy*)",
  "PowerShell(*make rollback*)",
  "PowerShell(*deploy.ps1*)"
]
```
