---
name: plugin-init-adlc-repo
description: Initialise a PLUGIN-BASED repo for the ADLC (AI Development Life Cycle) workflow, or add one component to a repo already initialised. Scaffolds .claude/ settings, a session-orientation pointer file, a project-local run skill, a `components:` table with templated skill bindings, a per-component docs/<component>/ governed-doc structure (including history/ and archive/), and a CLAUDE.md written from what the repo actually contains. Stack-agnostic. Invoke via /plugin-init-adlc-repo to initialise, or /plugin-init-adlc-repo add <component> to scaffold a further component. Use plain init-adlc-repo for a single-component repo.
license: MIT
metadata:
  author: https://github.com/mak100186
  version: "1.1.0"
  forked-from: "init-adlc-repo@1.0.0 (2026-09-10)"
  domain: repo-bootstrap
  triggers: init repo, initialise repo, set up claude, scaffold .claude, new repo, adlc setup, bootstrap project, add component, add plugin, new plugin
  role: platform-engineer
  scope: pre-development
  related-skills: plugin-idea-triage, plugin-orchestrator-development-pattern, graphify, find-skills
---

# Initialise Plugin-Based ADLC Repo

> **Forked from `init-adlc-repo` v1.0.0 on 2026-09-10.** Everything in that skill still applies
> except where this document says otherwise. The differences: a second **add-a-component** mode, a
> per-component `docs/<component>/` scaffold with `history/` and `archive/`, a `components:` table
> with templated bindings in `.claude/SKILLS.md` wired to the `plugin-*` skills, and a CLAUDE.md
> shape that reflects all of it. Use plain `init-adlc-repo` for a single-component repo.

## Two modes

**`/plugin-init-adlc-repo`** — initialise the repo. Runs Steps 0–9 below.

**`/plugin-init-adlc-repo add <component>`** — scaffold one further component in a repo already
initialised. Runs **only** Step 5b, then reports. This is the mode `plugin-idea-triage` Step 0
calls when a new plugin is triaged. It never touches `.claude/settings.json`, `CLAUDE.md`, or any
existing component.

## What a component is

One independently-buildable unit — the platform shell, or one plugin — together with its own
backend service if it has one. Each owns a complete governed-doc set and its own tranche line, so
tranches advance independently: the shell can sit at v2 while a plugin is still on v1.

**The shell is special in exactly one way:** its architecture document is the single home for every
cross-cutting contract (plugin loading, plugin context, manifest schema, message bus, shared
theming, auth). Plugin architecture documents reference it and never restate it. When initialising,
the first component created should be the platform/shell.

# What it bootstraps

A git repository for the **plugin-idea-triage → plugin-orchestrator-development-pattern → graphify**
workflow. Stack-agnostic: every stack-specific value is read from a manifest that actually exists in
the repo, or asked for — never guessed.

Supersedes the deprecated `/init-claude-settings` slash command. Slash commands still work but are on
Anthropic's deprecation path; skills are the supported extension surface, so this scaffold both *is*
a skill and *generates* a skill rather than a command.

---

## What this creates

| Path | Purpose |
|---|---|
| `.claude/settings.json` | Permissions, default mode, effort level. **No hooks**: they are wired once, globally |
| `.mcp.json` | Project-scoped MCP servers (Playwright, Context7) — committed, team-shared |
| `.claude/memory.md` | Session-orientation **pointer file** — no content of its own |
| `.claude/skills/run-app/SKILL.md` | Project-local launch skill (not a slash command) |
| `.claude/SKILLS.md` | Variable bindings consumed by the global skills |
| `.gitignore` | Knowledge-graph ignore block appended — created only if absent, never overwritten |
| `scripts/graph.ps1` | The standard knowledge-graph build script, copied in — reads the `components:` table, so it has no list of its own |
| `CLAUDE.md` | Operating guidance, written only from verified facts |
| `docs/adr/` | **Shared** ADR home (`.gitkeep`'d) - one folder, component-prefixed IDs |
| `docs/<component>/` | One governed-doc folder per component, each with `history/` and `archive/` |

It does **not** create a diagram render pipeline — see *Diagram convention* below.

---

## Step 0 — Confirm scope and pick the mode

Run `git rev-parse --is-inside-work-tree`. If this is not a git repo, stop and tell the user to run
it inside one (offer `git init`).

Then branch on how you were invoked:

| Invocation | Mode | What runs |
|---|---|---|
| `/plugin-init-adlc-repo` | **init** | Steps 1–9, in order |
| `/plugin-init-adlc-repo add <component>` | **add** | Step 5b only, then Step 9 |

### Add mode — the early exit

In **add** mode you are extending a repo that is already initialised. Do this and nothing else:

1. Confirm `.claude/SKILLS.md` exists and declares a `components:` table. If it does not, this repo
   was not initialised by this skill — stop, and offer to run init mode instead.
2. Confirm `<component>` is not already in that table. If it is, stop and say so; re-scaffolding
   over a live component's docs would destroy them.
3. Run **Step 5b** for `<component>`.
4. Report (Step 9).

**Add mode must not touch** `.claude/settings.json`, `.mcp.json`, `.claude/memory.md`,
`.claude/skills/run-app/`, `CLAUDE.md`, `docs/adr/`, `scripts/graph.ps1`, or any other component's
folder. Those are shared or already correct; rewriting them to add one plugin is how a scaffold
clobbers a team's work. The only two writes are the new `docs/<component>/` tree and one appended row
in `.claude/SKILLS.md`.

**The graph script needs no edit for a new component.** The standard `scripts/graph.ps1` (Step 3d)
reads the `components:` table every time it runs, so the appended row is all it takes:
`scripts/graph.ps1 -Component <component>` works as soon as the row is in and its roots are on disk
(until then it skips that component with a note and exits 0). **One exception — an older repo whose
`scripts/graph.ps1` keeps its own hard-coded component list** (look for a `$Components = [ordered]@{`
block in it). That script does not see the new row, so `-Component <component>` exits 1 with
"Unknown component". Say so in the Step 9 report and offer to replace it with the standard script
(Step 3d) — never edit or replace it without the user's yes, since it is outside add mode's two writes.

Everything below this point is **init mode**.

## Step 1 — Check existing state

Check for `.claude/settings.json`, `.mcp.json`, `.claude/memory.md`, `.claude/SKILLS.md`,
`.claude/skills/`, `.claude/commands/`, and `CLAUDE.md`.

If any exist, **show the user what's there and ask before touching it.** Merge or append; never
clobber unless they explicitly say to replace. For `CLAUDE.md` specifically, prefer suggesting
improvements to the existing file over rewriting it.

If `.claude/commands/run.md` exists from the old `/init-claude-settings` scaffold, offer to migrate
it to `.claude/skills/run-app/SKILL.md` and delete the command. Likewise, if
`.claude/scripts/render-diagrams.ps1` or `docs/diagrams/` exist from that scaffold, offer to remove
them — see *Diagram convention*.

## Step 2 — Detect the stack

Look for signal files. Do not hardcode; check what is actually present:

| Signal | Stack | Read for commands |
|---|---|---|
| `package.json` | Node/JS/TS | `scripts` — dev/start/test/lint/build |
| `angular.json` | Angular | `scripts` first, else `ng` CLI; note the dev port and `proxy.conf.json` |
| `requirements.txt` / `pyproject.toml` | Python | `pytest`, `ruff`, `black`, entry point |
| `Cargo.toml` | Rust | `cargo run` / `cargo test` |
| `go.mod` | Go | `go run .` / `go test ./...` |
| `*.csproj` / `*.sln` | .NET | `TargetFramework`, `Properties/launchSettings.json` |
| `Gemfile` | Ruby | `bin/rails server` |
| `pom.xml` / `build.gradle*` | Java/Kotlin | wrapper scripts |
| `Makefile` | any | **check first** — a `run`/`up`/`dev` target usually *is* the entrypoint |
| `docker-compose.y*ml` | any | note whether Compose is driven directly or wrapped by a Makefile |

**A `Makefile` or equivalent wrapper outranks the raw toolchain command.** If `make up` exists, that
is the entrypoint, and `docker compose up` is the anti-pattern to warn about — record that in
`CLAUDE.md` (see Step 7).

**No match → ask the user.** A repo with no commits and no manifest cannot be detected from. Ask what
the stack will be and what the run/test commands are; do not infer from the repo name.

Also detect whether the repo is **multi-toolchain** (e.g. an SPA + an API). If so, every quality
claim must cover both halves — a green run on one says nothing about the other. Record that.

## Step 3 — `.claude/settings.json`

Write, if absent, starting from this base (permissions + identity fields; no `hooks` block, see Step 3a):

```json
{
  "permissions": {
    "allow": [
      "Read(*)",
      "Bash(*ls*)",
      "Bash(*cat*)",
      "Bash(*cd*)",
      "Bash(*mkdir*)",
      "Bash(*mv*)",
      "Bash(*cp*)",
      "Bash(*echo*)",
      "Bash(*curl * http://127.0.0.1*)",
      "Bash(*curl * http://localhost*)",
      "Bash(*git log*)",
      "Bash(*git status*)",
      "Bash(*git diff*)",
      "Bash(*git add*)",
      "Bash(*git commit*)",
      "Bash(*git branch*)"
    ],
    "deny": [
      "Bash(*git push --force*)",
      "Bash(*git push -f *)",
      "Bash(*git reset --hard *)",
      "Bash(*git stash*)",
      "Bash(*git checkout*)",
      "Bash(*git switch -c*)",
      "Bash(*git switch -C*)",
      "Bash(*git switch --create*)",
      "Bash(*git switch --force-create*)",
      "Bash(*rm -rf *)"
    ],
    "defaultMode": "auto",
    "additionalDirectories": []
  },
  "effortLevel": "high"
}
```

Then append allow-patterns **only** for tooling the detected stack actually uses — e.g.
`Bash(*npm*)`/`Bash(*node*)` for Node, `Bash(*dotnet*)` for .NET, `Bash(*cargo*)` for Rust,
`Bash(*make*)` for a Makefile-driven repo. Validate the file parses as JSON before moving on.

**`git stash`, `git checkout` and branch-creating `git switch` (`-c`, `-C`, `--create`,
`--force-create`) are denied, deliberately — do not "fix" this by moving any of them back to
`allow`.** The first two discard uncommitted work silently, and a sub-agent has no way to signal
that it did so: the only trace is a `git status` that comes back cleaner than it should. This is
not hypothetical, and it matters more here than in a single-component repo, because
`plugin-orchestrator-development-pattern` runs five sub-agent roles against one working tree. On
2026-09-11, during that pipeline's first run, a Developer sub-agent finished a bug fix and a
Reviewer sub-agent executed its regression test and confirmed it passed; one of them then ran a
bare `git stash` — most plausibly to demonstrate the new test failed against the pre-fix code —
and never restored it. The entire fix vanished and had to be redone. It was caught only because
the Orchestrator noticed `git status --porcelain` was clean when two files should have been
modified.

`git switch -c` is denied for a related reason: it silently relocates the working tree onto a
branch the human never asked for, carrying their uncommitted changes with it, so the next commit,
push or PR lands somewhere they did not choose. In a plugin repo that also crosses a component
boundary — work is meant to stay on one branch per component — so an agent inventing a branch can
strand a fix where no one is looking for it. Creating a branch is the user's decision: an agent
asks for it rather than taking it. Plain `git switch <existing-branch>` is not in the deny list
only because `git checkout` already covers moving between existing branches; do not read its
absence as permission to add a switch-based workaround.

A prompt-level prohibition does not hold here, which is why this belongs in `deny`. A sub-agent is
a cold spawn that reasons independently, and "temporarily revert the file to prove the test is
coupled to the fix" is a reasonable-sounding thing for a careful agent to invent unprompted. The
deny list is the only layer that holds regardless of what any individual agent concludes.

The supported alternative, worth stating wherever agents are told to verify a regression test:
copy the file to the session scratchpad, edit the copy, and run the assertion against both. Every
read-only git command — `git status`, `git diff`, `git log`, `git rev-parse` — stays allowed, and
verification should lean on those.

### Step 3a — No `hooks` block in the project

**Do not add a `hooks` block to the project's `.claude/settings.json`.** The org's hook scripts in
`~/.claude/hooks` are already wired in each user's global `~/.claude/settings.json` (the
`claude-stash` installer writes them there from `settings.template.json`). Claude Code runs hooks
from every settings file that declares them, so wiring the same scripts in the project as well makes
every one of them run twice on every matching event. That is not harmless: `loop-detection.sh` counts
each edit twice and warns on every edit, and `db-guard.sh` and `auto-verify-fix.sh` do their work
twice.

1. **New `settings.json`:** write it with no `hooks` key.
2. **Existing `settings.json` that already has a `hooks` block** (from an earlier run of this skill):
   list every entry whose `command` runs a script in `~/.claude/hooks` (any spelling of that path:
   `~/.claude/hooks`, `$HOME/.claude/hooks`, `C:/Users/<user>/.claude/hooks`, or a share it links to).
   Those duplicate the global wiring. Show the user the list and, once they confirm, remove those
   entries, then remove any event array or the whole `hooks` key that is left empty. Keep any hook
   whose script is not one of the global ones: that is a genuine project hook.
3. **A project that needs a hook of its own** (a script that lives in the repo and only makes sense
   there) is the one case for a project `hooks` block. Point its `command` at the repo's script,
   never at `~/.claude/hooks`.
4. **Check the global wiring exists.** Read `~/.claude/settings.json`. If it has no `hooks` block, or
   no entry for a script in `~/.claude/hooks`, do not fix that here: say in the Step 9 summary which
   scripts are not wired globally and that re-running the `claude-stash` installer (or merging its
   `settings.stash.json`) wires them.
5. Validate the resulting `settings.json` still parses as JSON.

## Step 3b — `.mcp.json`: Playwright + Context7

Write, if `.mcp.json` is absent at the repo root:

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest"]
    },
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "Authorization": "Bearer ${CONTEXT7_API_KEY}"
      }
    }
  }
}
```

This file is meant to be **committed** — that's the point of using project-scoped `.mcp.json`
instead of a per-machine entry in `~/.claude.json` (which is keyed by absolute project path and
doesn't travel with the repo). Never write a real Context7 API key into this file: use the
`${CONTEXT7_API_KEY}` environment-variable reference shown above, and in the Step 9 summary tell
the user to set `CONTEXT7_API_KEY` in their own shell/OS environment (get a key from
https://context7.com). Playwright needs no secret and works as-is.

Mention in the summary that Claude Code will show a one-time trust prompt for the project's MCP
servers the first time the repo is opened — that's expected, not a sign anything is misconfigured.

If `.mcp.json` already exists, show the user its current `mcpServers` keys and ask before adding or
overwriting `playwright`/`context7` entries — never clobber an existing server config silently.

## Step 3c — `.gitignore`: the knowledge-graph block

**Create or append. Never overwrite.** A repository that already has a `.gitignore` has one for
reasons you cannot see, and replacing it is how a scaffold step turns into a data-loss step. If the
file exists, append the block below to the end of it; if it does not, create it with the block as its
only content. If the block is already present — test for the `graphify-out` line — change nothing and
say so.

```gitignore
# Knowledge graph (graphify)
#
# One graph per component: graphify-out/<component>/. Only GRAPH_REPORT.md is
# committed - it is what humans and later agents read. graph.json, graph.html,
# manifest.json, cost.json, the AST cache and .graphify_analysis.json are
# regenerable, large, rewritten in full on every run, and unmergeable when two
# branches finish work on two components at once.
#
# .graphify_root is ignored too: it records an absolute path from the machine
# that built the graph, so committing it breaks every other clone.
graphify-out/**
!graphify-out/
!graphify-out/*/
!graphify-out/*/GRAPH_REPORT.md
.graphify_root
```

The four lines have to be in that order and all four are needed. `graphify-out/**` excludes
everything; git will not look inside an excluded directory, so the two `!` directory lines are what
re-admit the path far enough for the fourth line to match the report itself. Drop either and nothing
is committed at all.

Tell the user in the Step 9 summary that `scripts/graph.ps1` (Step 3d) is what regenerates these, and
that a fresh clone has no graph until it runs.

## Step 3d — `scripts/graph.ps1`: the graph build script

Copy `~/.claude/skills/init-adlc-repo/templates/graph.ps1` to `scripts/graph.ps1` in the target repo,
byte for byte. (It lives under the single-component skill because both init skills share it; it is
installed with the skills.) If that template is missing, stop this step and say so in Step 9 — do not
write a script from memory.

**Create only.** If `scripts/graph.ps1` already exists, show the user how it differs from the template
and ask before replacing it. A hand-made one with a hard-coded component list is the usual case; the
standard script replaces it with no loss, but it is the user's call.

What the copy does, so the summary can say it plainly:

- Reads `.claude/SKILLS.md` each run: the `components:` table for each component's `code` roots, and
  the `graphify-out` binding (`./graphify-out/{component}`) for where each graph goes. **It holds no
  component list**, so a new component (add mode) needs no edit to it.
- `scripts/graph.ps1` builds every component; `-Component <name>` builds one. The second is the exact
  command `plugin-orchestrator-development-pattern` runs in its Graphify step:
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1 -Component <component>`.
- Runs `graphify update` once per root (no LLM, no API cost) with an absolute `GRAPHIFY_OUT`, so a
  component's roots merge into one graph at `graphify-out/<component>/`, then stamps
  `GRAPH_REPORT.md` with `> Component:`, `> Built at commit: <sha>` (plus `+ uncommitted working tree`
  when the roots have uncommitted changes) and `> Code roots:`.
- `-Root <root>` rebuilds only those roots of a component whose `graph.json` already exists;
  `-DryRun` parses `SKILLS.md` and prints what it would build, writing nothing.
- A component whose roots are not on disk yet is skipped with a note (exit 0). Exit 1 means an
  unknown component, graphify not on PATH, or a failed build.
- Works under Windows PowerShell 5.1 (`powershell`) and PowerShell 7.

If the repo has a `Makefile`, offer a `graph` target that calls it (`graph:` →
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1 $(if $(C),-Component $(C))`),
but do not add one to a repo without a `Makefile`. After the copy, run it once with `-DryRun` and put
its output in the Step 9 summary — it proves the table parses.

## Step 4 — `.claude/memory.md`

This file is deliberately a **pointer, not a store**. Once plugin-idea-triage and
plugin-orchestrator-development-pattern are wired in, each component's PRD, Architecture doc, PMBook
and handoff doc are the one governed home for their kind of information. Duplicating decisions,
architecture, or status here would give the repo two versions of the same fact with no way to tell
which is current — exactly the failure those docs exist to prevent.

In a plugin-based repo it has a second job: it is the **first place a new session learns that this
repo is split per component**, and that there is no such thing as "the PRD" — only
`docs/<component>/prd.md`. So the routing table is written once with `<component>` left as a
literal placeholder, followed by the live component list.

~~~markdown
# Project — Session Orientation

> Read this first in a new session, then follow the pointers below to
> the actual source of truth. This file intentionally holds no
> decisions, architecture, or status of its own — update the linked doc,
> never this file, when any of that changes.

---

## Identity

- Name: <TODO>
- Owner: <TODO>
- Type: plugin-based — a platform shell plus independently-developed plugins

---

## This repo is split per component

Every governed document lives under `docs/<component>/`. There is no repo-wide PRD,
architecture doc, PMBook or handoff — each component owns its own set and its own
tranche line, so components close out independently and teams can work parallel
branches without fighting over one file.

| Component | Docs | Code |
|---|---|---|
| `<shell>` | `docs/<shell>/` | `apps/<shell>`, `services/<Shell.Api>` |
| `<plugin1>` | `docs/<plugin1>/` | `apps/<plugin1>` |

The authoritative list is the `components:` table in `.claude/SKILLS.md`. If the two
disagree, `.claude/SKILLS.md` wins — the skills read it, not this file.

---

## Where to Look

| Topic | Source of truth |
|---|---|
| Problem, goals, scope | `docs/<component>/prd.md` |
| System design for one component | `docs/<component>/architecture.md` |
| **Cross-cutting platform contracts** | `docs/<shell>/architecture.md` — plugins read it, never edit it |
| Why a specific technical decision was made | `docs/adr/` — shared, IDs are `<COMPONENT>-ADR-NNN` |
| Feature backlog, phases, status | `docs/<component>/project-management.md` |
| Current implementation state, what's next | `docs/<component>/handoff.md` |
| Version history (moved out of the live docs) | `docs/<component>/history/` |
| Closed tranches | `docs/<component>/archive/v<N>/` |
| Release history | `docs/<component>/changelog.md`, `docs/<component>/revision.md` |
~~~

Leave the `<TODO>`s. Never invent identity details. Replace `<shell>` / `<plugin1>` with the real
component names created in Step 5b; leave `<component>` as a literal placeholder — it is the point.

## Step 5 — `docs/` scaffolding

Two parts: the shared layer, then one component.

### Step 5a — the shared layer

```
docs/
├── adr/          .gitkeep — one folder for the whole repo
└── stash/        .gitkeep — working notes, discovery records, anything not governed
```

`adr-directory` is deliberately **shared, not per component**: a decision often binds more than one
of them, and one searchable folder beats four tidy ones. New ADR IDs are component-prefixed
(`SHELL-ADR-001`, `OFA-ADR-001`) so two developers on two branches cannot claim the same number.

**Do not create `docs/diagrams/`.** See *Diagram convention*.

### Step 5b — one component

Ask for the component's name (kebab-case) and its source roots, then create:

```
docs/<component>/
├── history/
│   └── .gitkeep
└── archive/
    └── .gitkeep
```

**Create the folders. Do not stub the documents.** `plugin-idea-triage` writes `prd.md`,
`architecture.md` and `project-management.md`; `plugin-orchestrator-development-pattern` writes
`handoff.md`, `changelog.md`, `revision.md`, `test-cases.md` and `test-runbook.md`. An empty
governed doc reads as "this was filled in" and is worse than an absent one. The two empty folders
are the exception — a `history/` that does not exist invites a Finalizer to write a history table
back into a live document, which is exactly the bloat this structure removes.

The eight documents that will live there, for reference:

| File | Written by | Reset at closeout? |
|---|---|---|
| `prd.md` | plugin-idea-triage | no — snapshot-copied, stays living |
| `architecture.md` | plugin-idea-triage | no — snapshot-copied, stays living |
| `project-management.md` | plugin-idea-triage | **yes** |
| `test-cases.md` | orchestrator | no — snapshot-copied, stays living |
| `test-runbook.md` | orchestrator | no — snapshot-copied, stays living |
| `handoff.md` | orchestrator | **yes** |
| `changelog.md` | orchestrator | trimmed to a pointer |
| `revision.md` | orchestrator | trimmed to a pointer |
| `history/*-history.md` | both | **yes** |

Finally, append the component to the `components:` table in `.claude/SKILLS.md` (Step 8) with its
source roots. In **add mode** this is the only step that runs; report the created paths and the
updated table, and stop. `scripts/graph.ps1` picks the new row up on its next run — see *Add mode*
above for the one case where it does not.

## Step 6 — `.claude/skills/run-app/SKILL.md`

A **project-local skill**, not a slash command. The built-in `run` skill explicitly looks for a
project skill covering app launch before falling back to its generic per-platform patterns, so this
is the intended customization point.

This is not redundant with the orchestrator: its Integration Agent runs format/lint/test/audit as
automated gates but never starts an interactive dev server for a human to look at.

Write it with this frontmatter, then a body tailored to the detected stack:

```yaml
---
name: run-app
description: Launch this project's app locally and verify it comes up. Use when asked to run, start, serve, or smoke-check the app, or to confirm a change works in the real app rather than only in tests.
---
```

The body must cover:

1. **Detect before starting** — re-derive the entrypoint from the repo rather than trusting the paths
   this scaffold recorded; layouts move. If a `Makefile`/wrapper is the entrypoint, say so and name
   the raw command it replaces as the thing *not* to run.
2. **Prerequisites** — toolchain versions, installed dependencies, and any local service the app
   needs (database, cache, model server, upstream API). Warn before starting, not mid-boot.
3. **Start order** — for a multi-process app, start the backend first; a frontend dev-server proxy
   fails its first requests if the API isn't listening yet.
4. **Verify, don't assume** — `curl` the actual URLs. "Process still alive" is not "app came up";
   a frontend dev server that fails to compile never binds at all.
5. **Report** — the URLs, plus startup warnings that look benign but aren't: compile warnings,
   pending-migration notices, CORS/proxy errors.
6. **A fast-iteration path**, if the repo has one. If the normal entrypoint rebuilds a container
   image on every change, find and document the bare/hot-reload alternative, which ports change, and
   what to stop first so two processes don't fight over the same state. This is one of the
   highest-value things the file can carry.

Guardrails to include: don't scaffold a missing half unasked; suggest the install command rather than
assuming one; never kill an existing listener to free a port; never apply database migrations as part
of "starting the app".

## Step 7 — `CLAUDE.md`

Only write this if absent. If present, suggest improvements instead.

### The rule that matters

**Every command and every architectural claim in this file must come from a file you actually read,
or from the user. Nothing inferred, nothing typical-for-this-stack.** A fabricated build command
costs more than an absent one: an absent command gets asked about, a wrong one gets run.

If the repo is pre-code, say so plainly and keep the file short. A CLAUDE.md that honestly says
"no code yet, commands unverifiable" is a correct CLAUDE.md.

### Required prefix

Begin with exactly:

```
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
```

### Shape

~~~markdown
## Project status

<One or two sentences: what this is, the stack, the deployment shape.> Phases
<N-M> (<what they covered>) are complete; Phase <N> (<scope>) has not started.
See `docs/<component>/handoff.md` for each component's current build state and
what's next, and `docs/<component>/project-management.md` for its feature backlog.

## Starting the stack — always use `<entrypoint>`, not `<raw command>`

```bash
<entrypoint>          # the single starting point for operators and Claude Code sessions
<status command>      # check what's currently running
<stop command>        # stop it
<logs command>        # tail logs
```

<What the entrypoint actually does that the raw command doesn't — dependency checks,
service startup, model loading. Point at the setup doc for one-time prerequisites
and at the ADR explaining any non-obvious infrastructure choice.>

<Any platform-specific requirement — a required binary, a path assumption, a shell
the recipes force.>

**<The fast-iteration path, if one exists>** — when the normal entrypoint is too slow
for a tight edit-verify loop, what to run instead, which ports change, and what to
stop first so two processes don't fight over the same state.

## Build / test commands

<Per toolchain, in its own fenced block with the working directory named.>

## Architecture

<One paragraph of the big picture — the shape that requires reading several files to
work out. Name the pattern and the notable technology choice, especially where it
differs from the default a reader would assume.> Full component breakdown, technology
decisions, and rationale live in `docs/<component>/architecture.md` and `docs/adr/` —
read those before a structural or technology change, and add or amend an ADR when you
make one. Cross-cutting contracts live in `docs/<shell>/architecture.md`.

Governed docs are specs the code must satisfy, not side artifacts — keep them in
sync with any structural change in the same session, not as a follow-up.

## Components

This repo is plugin-based: a platform shell plus independently-developed plugins. Every
governed doc lives under `docs/<component>/`, and each component has its **own tranche
line** — one can close out v1 while another is mid-v2. There is no repo-wide PRD,
architecture doc, PMBook or handoff.

| Component | Docs | Code | Tranche |
|---|---|---|---|
| `<shell>` | `docs/<shell>/` | `apps/<shell>`, `services/<Shell.Api>` | v<N> open |
| `<plugin1>` | `docs/<plugin1>/` | `apps/<plugin1>` | v<N> open |

**`docs/<shell>/architecture.md` owns every cross-cutting contract** — plugin loading,
plugin context, the manifest schema, the message bus, theming, auth. A plugin's own
architecture doc *references* those; it never restates them, and a plugin branch never
edits them. Work that needs a contract change becomes a shell work item that the plugin
item depends on.

## Governed docs — per component

| Topic | Source of truth |
|---|---|
| Problem, goals, scope | `docs/<component>/prd.md` |
| System design | `docs/<component>/architecture.md` |
| Cross-cutting contracts | `docs/<shell>/architecture.md` |
| Why a decision was made | `docs/adr/` — shared; new IDs are `<COMPONENT>-ADR-NNN` |
| Backlog, phases, status | `docs/<component>/project-management.md` |
| Current state, what's next | `docs/<component>/handoff.md` |
| Test cases / manual verification | `docs/<component>/test-cases.md`, `docs/<component>/test-runbook.md` |
| Release history | `docs/<component>/changelog.md`, `docs/<component>/revision.md` |
| Version history tables | `docs/<component>/history/` — the live docs keep a one-line pointer |
| Closed tranches | `docs/<component>/archive/v<N>/` — written only at that component's closeout |
~~~

### What to leave out

- Anything discoverable in seconds — full file trees, every component, obvious conventions.
- Generic engineering advice ("write tests", "handle errors", "don't commit secrets").
- Invented sections — "Common Development Tasks", "Tips", "Support" — unless a file you read says it.
- **The architecture itself.** One paragraph plus a pointer to `docs/<shell>/architecture.md`. A
  full description here becomes a second, competing source of truth that drifts silently.
- **A Scope-subheading convention.** Single-document repos split sections into `### Platform` /
  `### <Plugin>` subheadings inside one PRD and one architecture doc. This scaffold does not: the
  folder split replaces it, and describing both conventions in one CLAUDE.md guarantees someone
  follows the wrong one. Do not emit that section.

### What earns its place

Operational facts that cost a session's time to rediscover: the one true entrypoint and the
plausible-looking wrong one; the slow-path/fast-path split; a tool whose exit code lies; a
platform-specific requirement; which of two processes must start first.

Also fold in the important parts of any existing `README.md`, `.cursorrules`, `.cursor/rules/`, or
`.github/copilot-instructions.md`.

## Step 8 — Wire the skills: `.claude/SKILLS.md`

Verify each skill exists at `~/.claude/skills/<name>/SKILL.md` before wiring it. Skip and report any
that aren't installed.

The whole file is driven by **one `components:` table**. That table is the keystone: it resolves
every governed-doc path, scopes each component's knowledge graph, and tells the orchestrator whose
source a diff touched. Adding a component is one row plus one `docs/<name>/` folder — nothing else.

~~~markdown
# Available Skills

This file binds project-specific variable values to skills that accept parameters.
Claude reads this file to know which skills are active and what paths to inject.

**Stack:** <detected stack>

---

## Components

This is a plugin-based repository: a platform shell plus independently-developed plugins, each
owning its own governed documents and its own tranche line. Every `{component}` below resolves
against this table.

components:
  <shell>:   code: - "<./apps/shell>"   - "<./services/Shell.Api>"
  <plugin1>: code: - "<./apps/plugin1>" - "<./services/Plugin1.Api>"

There is deliberately **no `default-component`.** A skill that cannot resolve the component asks;
guessing wrong writes a feature into the wrong PMBook, changelog, handoff and graph.

---

## Plugin Orchestrator Development Pattern

Skill: `plugin-orchestrator-development-pattern` (located at `~/.claude/skills/plugin-orchestrator-development-pattern/SKILL.md`)
Trigger: `/plugin-orchestrator-development-pattern <component>` or when the user says "start development", "implement", "build".

The orchestrator resolves the component first (Step 0.0a), then the platform, at runtime.

values:
  docs-directory: "./docs"
  project-management-doc: "./docs/{component}/project-management.md"
  handoff-doc: "./docs/{component}/handoff.md"
  architecture-doc: "./docs/{component}/architecture.md"
  test-cases-doc: "./docs/{component}/test-cases.md"
  test-runbook-location: "./docs/{component}/test-runbook.md"
  changelog-file: "./docs/{component}/changelog.md"
  revision-file: "./docs/{component}/revision.md"
  history-directory: "./docs/{component}/history"
  archive-directory: "./docs/{component}/archive"
  run-state-file: "./docs/{component}/.orchestrator-run-state.json"
  metrics-log-file: "./docs/{component}/orchestrator-metrics.md"
  graphify-directories: "{component}.code"
  graphify-out: "./graphify-out/{component}"
  source-code-directory: "./"
  adr-directory: "./docs/adr"
  platform-architecture-file: "./docs/<shell>/architecture.md"
  snyk-command: "<dependency audit command(s) for the detected stack>"

---

## Plugin Idea Triage

Skill: `plugin-idea-triage` (located at `~/.claude/skills/plugin-idea-triage/SKILL.md`)
Trigger: `/plugin-idea-triage <component>` or when the user presents a new idea before any code exists.

values:
  docs-directory: "./docs"
  prd-file: "./docs/{component}/prd.md"
  architecture-file: "./docs/{component}/architecture.md"
  project-management-doc: "./docs/{component}/project-management.md"
  handoff-doc: "./docs/{component}/handoff.md"
  changelog-file: "./docs/{component}/changelog.md"
  revision-file: "./docs/{component}/revision.md"
  history-directory: "./docs/{component}/history"
  archive-directory: "./docs/{component}/archive"
  adr-directory: "./docs/adr"
  platform-architecture-file: "./docs/<shell>/architecture.md"

---

## Add a Component

Skill: `plugin-init-adlc-repo` (located at `~/.claude/skills/plugin-init-adlc-repo/SKILL.md`)
Trigger: `/plugin-init-adlc-repo add <component>`

Scaffolds `docs/<component>/` and appends the row above. `plugin-idea-triage` calls this itself
when a new plugin is triaged.

---

## Graph-Assisted Context

One graph per component, at `graphify-out/<component>/`, **built by `scripts/graph.ps1`** — not by
the `/graphify` skill:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1                          # every component
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1 -Component <component>   # one
```

The script reads the `components:` table above, so a new component needs no edit to it. It runs
`graphify update` per `code` root (no LLM) and stamps `GRAPH_REPORT.md` with the commit it was built
at. The orchestrator's Graphify step runs the same command.

Only `GRAPH_REPORT.md` is committed; `graph.json`, `graph.html`, `manifest.json`, `cost.json` and
`.graphify_analysis.json` are regenerable and gitignored — a committed whole-repo graph is an
unmergeable conflict on every parallel run. A fresh clone therefore has no graph until the script
runs. If a report's `> Built at commit:` is not `git rev-parse HEAD` and the diff since touches that
component's `code` roots, it is stale: rebuild before relying on it.

Skill: `graphify` (located at `~/.claude/skills/graphify/SKILL.md`)
Trigger: `/graphify query "<topic>"` — to ask a built graph a question. Run `/graphify` over one
root by hand only when the LLM-enriched graph (inferred edges, named communities) is wanted.

---

## Find Skills

Skill: `find-skills` (located at `~/.claude/skills/find-skills/SKILL.md`)
Trigger: `/find-skills` or `/find-skills <query>`

---

## Shared-Path Invariant

plugin-idea-triage's `architecture-file` and the orchestrator's `architecture-doc` are the
**same physical file** — triage writes it, the orchestrator reads it — but each skill names its
own variable so either stays usable without the other installed. The same applies to
`project-management-doc`, `handoff-doc`, `changelog-file`, `revision-file`, `history-directory`,
`archive-directory` and `adr-directory`.

Both blocks use the same `{component}` templates, so the **component table is defined once** and a
new component is one row. But a change to a *path shape* is still two edits — change it in both
blocks, or the two skills will silently disagree about which file is authoritative.

Three variables are shared and never templated: `adr-directory` (one folder, component-prefixed
IDs), `platform-architecture-file` (the shell's architecture, home of every cross-cutting
contract, read-only to every plugin), and `source-code-directory` (stays the repo root, because
platform detection needs the root-level manifests).
~~~

Fill `snyk-command` from the detected stack (`npm audit`, `pip-audit`, `cargo audit`,
`dotnet list package --vulnerable`, …). For a multi-toolchain repo, bind **all** of them, and record
any that report findings without a non-zero exit code — `dotnet list package --vulnerable` is the
common offender, and gating on its exit code makes that half of the audit decorative.

## Step 9 — Summarize

Report what was created, what was skipped and why, and any `<TODO>` left for the user. Remind them
these are project conventions meant to be committed, not local config.

### In add mode

Keep it to four lines — nothing else changed:

```
Added component: <name>
  Docs:   docs/<name>/  (history/, archive/ — documents are written by plugin-idea-triage)
  Code:   <roots from the components: row>
  Wired:  .claude/SKILLS.md components: table
  Graph:  scripts/graph.ps1 -Component <name>  (no script edit needed)

Next: /plugin-idea-triage <name>
```

### In init mode

Explicitly call out:

- **The component list**, and that `.claude/SKILLS.md`'s `components:` table is the authority.
  Adding another is `/plugin-init-adlc-repo add <name>` — one row and one folder, nothing else.
- **That the governed documents were not stubbed.** `docs/<component>/` holds only `history/` and
  `archive/`. `plugin-idea-triage` writes the PRD, architecture doc and PMBook, in that order, from
  a real conversation. An empty template PRD reads as a real one and is worse than no file.
- **That version history lives in `history/`, not in the documents.** Each live doc carries a
  two-line pointer; the tables live in `history/<doc>-history.md`. This is what keeps the live docs
  small enough to load into a context window.
- **That tranches are per component.** A closeout snapshot-copies that component's docs into
  `archive/v<N>/` and touches no other component.
- That the project `settings.json` has no `hooks` block (or which duplicate entries were removed from an
  existing one, and which project-only hooks were kept), and any `~/.claude/hooks` script that is not
  wired in the user's global `~/.claude/settings.json`.
- **That `scripts/graph.ps1` builds the knowledge graphs** (or why it was not copied), with its
  `-DryRun` output, and that a fresh clone has no graph until it runs.
- That `.mcp.json` was created with `playwright` and `context7`, and that `CONTEXT7_API_KEY` needs
  to be set in the user's environment before the Context7 server will authenticate.
- **The suggested next command:** `/plugin-idea-triage <shell>` — the shell is triaged first,
  because its architecture doc holds the contracts every plugin is written against.

---

## Diagram convention

Diagrams are **fenced `mermaid` code blocks written directly in the governed docs.** GitHub, GitLab,
Azure DevOps, and VS Code all render them natively.

This scaffold deliberately creates **no** `docs/diagrams/` directories and **no** render script. The
earlier `.mmd` → PNG pipeline required a global `mmdc` (`@mermaid-js/mermaid-cli`) install plus a
headless Chromium via Puppeteer — a heavy dependency, an extra build step, and a stale-image failure
mode where a doc cites a PNG that no longer matches its source. Inlining removes all three: the
source *is* the render, so it cannot go stale.

Consequently `diagrams-mmd-dir`, `diagrams-img-dir`, and `diagram-render-script` are **not** bound in
`SKILLS.md`. The orchestrator's Documentation Drift Check treats unset diagram paths as "skip the
diagram check and note the gap", so leaving them unbound is the supported configuration.

Diagram *type* selection still matters and is unchanged — that guidance lives in plugin-idea-triage §2.3.

---

## Guardrails

- Never overwrite an existing `.claude/` file or `CLAUDE.md` without explicit confirmation.
- Never invent identity details in `memory.md` — leave `<TODO>`s.
- Never add a decision, architecture, status, or open-question entry to `memory.md`. It is a pointer
  file. That content belongs in the PRD / Architecture / ADRs / PMBook / handoff doc; putting it in
  both places creates two versions of one fact with no way to tell which is current.
- Never add a permission allow-pattern for tooling the repo doesn't use.
- Never write a build, test, or run command into `CLAUDE.md` that you did not read out of a manifest
  or receive from the user.
- Never describe the architecture in `CLAUDE.md` beyond one orienting paragraph — it belongs in
  `docs/<component>/architecture.md`.
- Never create a `docs/diagrams/` tree or a render script.
- **Never overwrite an existing `.gitignore`.** Step 3c appends its block or creates the file; it
  does not replace one. The rules already in there were put there deliberately, and losing them is
  invisible until something secret or enormous shows up in a commit.
- **Never write `scripts/graph.ps1` from memory or edit the copy.** Copy the standard template
  (Step 3d); a component list or root written into the script is a second copy of the `components:`
  table that drifts from it silently. Never replace an existing script without the user's yes.
- **Never stub a component's governed documents.** Step 5b creates `history/` and `archive/` and
  stops. `plugin-idea-triage` writes the PRD, architecture doc and PMBook from a real conversation.
- **Never run anything but Step 5b in add mode.** Settings, MCP config, `memory.md`, `CLAUDE.md`,
  `docs/adr/` and every other component's folder are shared or already correct; rewriting them to
  add one plugin clobbers work that is not yours.
- **Never re-scaffold over a component already in the `components:` table.** Stop and say so.
- **Never bind a `default-component`.** A skill that cannot resolve the component must ask. A wrong
  guess writes a feature into another component's PMBook, changelog, handoff and graph — silently.
- **Never emit the Scope-subheading convention into `CLAUDE.md`.** The folder split replaces it.
- **Never create a second ADR directory per component.** One shared `docs/adr/`, component-prefixed
  IDs (`<COMPONENT>-ADR-NNN`).
- Generate a project **skill**, not a slash command, for app launch.
- **Never wire a `~/.claude/hooks` script in the project's `settings.json`.** The user's global settings
  already run it, so a project copy makes it run twice (Step 3a). A project `hooks` block holds only
  hooks whose scripts live in the repo.
- Never write a real Context7 API key (or any other secret) into `.mcp.json` — it's a committed
  file. Use `${VAR}` environment-variable expansion and tell the user to set the variable locally.
- This skill touches `.claude/`, `.mcp.json`, `.gitignore`, `scripts/graph.ps1`, `CLAUDE.md`,
  `docs/adr/` and `docs/<component>/`. It does not modify application code.
