---
name: init-adlc-repo
description: Initialise a repo for the ADLC (AI Development Life Cycle) workflow — scaffolds .claude/ settings, a session-orientation pointer file, a project-local run skill, skill variable bindings, the docs/ governed-doc structure, and a CLAUDE.md written from what the repo actually contains. Stack-agnostic; detects language/platform from whatever manifest is present. Invoke via /init-adlc-repo, or when the user asks to "set up this repo for Claude", "initialise the ADLC workflow", "scaffold .claude", or is starting a new repo that will use idea-triage → orchestrator-development-pattern → graphify.
license: MIT
metadata:
  author: https://github.com/mak100186
  version: "1.6.1"
  domain: repo-bootstrap
  triggers: init repo, initialise repo, set up claude, scaffold .claude, new repo, adlc setup, bootstrap project
  role: platform-engineer
  scope: pre-development
  related-skills: idea-triage, orchestrator-development-pattern, graphify, find-skills
---

# Initialise ADLC Repo

Bootstraps a git repository for the **idea-triage → orchestrator-development-pattern → graphify**
workflow. Stack-agnostic: every stack-specific value is read from a manifest that actually exists in
the repo, or asked for — never guessed.

Replaces the deprecated `/init-claude-settings` slash command. Slash commands still work but are on
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
| `scripts/graph.ps1` | The standard knowledge-graph build script, copied from this skill's `templates/` |
| `CLAUDE.md` | Operating guidance, written only from verified facts |
| `docs/adr/` | ADR home (`.gitkeep`'d) |
| `docs/design/` | UI repos only: `rows/`, `rounds/`, `artboards/` (`.gitkeep`'d) and a short `README.md` pointer |

It does **not** create a diagram render pipeline — see *Diagram convention* below.

---

## Step 0 — Confirm scope

Run `git rev-parse --is-inside-work-tree`. If this is not a git repo, do not just stop: offer to make it
one with `git init -b main`, and if the user gives a remote URL, `git remote add origin <url>` as well.
Run them only on the user's yes, then carry on from Step 1. If they decline, stop.

Invoked as `/init-adlc-repo upgrade`, run *Upgrade mode* below instead of Steps 1–9.

### Upgrade mode — bring an older repo up to the current template

`/init-adlc-repo upgrade` is for a repo this skill (or an older version of it) already initialised. The init
steps only write what is missing, so a repo set up from an older template keeps its old shapes. This
mode finds each drift, lists it, and changes only what the user says yes to (one yes for the whole
list, or item by item). It reads everything first and writes nothing until then.

1. **Allow and deny rules** in `.claude/settings.json`: a wrap-around rule (`Bash(*ls*)`, `Bash(*npm*)`)
   matches any command that merely contains the word, so it allows far more than it names. Propose the
   prefix form from Step 3 (`Bash(ls *)`, `Bash(npm run *)`), keeping each project-specific rule's
   intent. Never narrow a deny rule: a deny stays at least as broad as before. Offer any deny rule
   Step 3's template has that the file lacks (adding a deny only blocks more).
2. **`.gitignore`** has every line of Step 3c's block, `.claude/settings.local.json` included. If
   `.claude/settings.local.json` is tracked, offer `git rm --cached .claude/settings.local.json`.
3. **Hooks** in `.claude/settings.json` that point at a path missing on this machine (another user's
   home folder, say) fail on every tool call: flag each, and offer Step 3a's shape.
4. **`.claude/SKILLS.md`** has every block the current Step 8 writes (e.g. the Sync Artboards
   bindings): add a missing block with its defaults. Never change a value already bound. With no
   `SKILLS.md` at all, offer to write it as Step 8 does, its paths fitted to the docs the repo
   actually has (`docs/pmp.md`, say, not the default name).
5. **`.claude/memory.md`** has the current Step 4 shape: pointers only, no status. A `<TODO>` in
   Identity is filled only from the repo or the user, never guessed.
6. **`CLAUDE.md`** gets suggestions only, as Step 7 says for an existing file: the Required prefix; the
   `shaw-estate` line for Shaw work, replacing any copied estate facts (servers, feeds, deployment
   rules, the UI standard); dated test counts and known-red lists moved out (Step 7, *What to leave
   out*); and any claim the repo now contradicts ("pre-code" when code exists).

7. **Ports** are registered in `~/.claude/ports.md` (Step 2's *Ports* paragraph); register any that
   are missing, and flag any this checkout shares with another.
8. **`Makefile`** has every target in `~/.claude/skills/init-adlc-repo/references/makefile.md` (Step 3e): offer each missing one, wired to the
   stack. Flag, as suggestions, an existing target that falls short of the standard (an `audit`
   that exits 0 with findings; a `deploy` that can write outside the app's folder, or has no dry
   run, tag or local copy; a `rollback` that isn't by tag). Add the standard's `ask` rules if
   missing.

**Nested `.claude` folders** (a workspace whose projects each have their own `.claude/`): run every
item over each one, and list the drift per folder.

**Deliberate differences** (spike code tracked on purpose, graphify dropped from the project): report
the item as declined with its reason, and don't offer it again.

**A stale run skill:** `.claude/skills/run-app/` is never rewritten here, but flag one that still says
pre-code or holds `<TODO>`s once code exists (or that the real run skills live in nested project
folders), so the user can fix it.

Upgrade mode never touches `docs/`, the governed docs, `.claude/skills/run-app/` or `.mcp.json`
beyond the checks above. Report each item as changed, declined or already current.


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

Also settle the **code roots** — the folders that hold source and tests (`src/<Project>`,
`tests/<Project>.Tests`, `app/`, …), read from the manifests found above. They become
`graphify-directories` (Step 8), which `scripts/graph.ps1` (Step 3d) builds the knowledge graph from.
Never the repo root: a graph of `./` pulls `docs/` and every planning document into a code graph. A
pre-code repo has none to read: ask the user where the code will live, or, if they don't know yet,
bind placeholder roots (e.g. `./src`, `./tests`) with a `# placeholder — no code yet` note on its own
line above the binding in `SKILLS.md`, and list them in Step 9. That is safe: `scripts/graph.ps1 -DryRun` reports a missing
root as "would skip" and the build skips it.

**Ports.** Read `~/.claude/ports.md`, the machine's one port registry, and follow the orchestrator
skills' **Ports** section, case by case: an existing repo registers the ports its config uses; a new
clone of a registered repo clashes and takes a free offset, without asking unless there is a real
conflict; a new project picks free ports from the
registry before writing them into config. Never take a port registered to another checkout. With no
file, create it.

## Step 3 — `.claude/settings.json`

Write, if absent, starting from this base (permissions + identity fields; no `hooks` block, see Step 3a):

```json
{
  "permissions": {
    "allow": [
      "Read(*)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(cd *)",
      "Bash(mkdir *)",
      "Bash(mv *)",
      "Bash(cp *)",
      "Bash(echo *)",
      "Bash(curl * http://127.0.0.1*)",
      "Bash(curl * http://localhost*)",
      "Bash(git log *)",
      "Bash(git status *)",
      "Bash(git diff *)",
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git branch *)"
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
    "ask": [
      "Bash(*make deploy*)",
      "Bash(*make rollback*)",
      "Bash(*deploy.ps1*)",
      "Bash(*rollback.ps1*)",
      "PowerShell(*make deploy*)",
      "PowerShell(*make rollback*)",
      "PowerShell(*deploy.ps1*)",
      "PowerShell(*rollback.ps1*)"
    ],
    "defaultMode": "auto",
    "additionalDirectories": []
  },
  "effortLevel": "high"
}
```

Then append allow-patterns **only** for tooling the detected stack actually uses — e.g.
`Bash(npm *)`/`Bash(node *)` for Node, `Bash(dotnet *)` for .NET, `Bash(cargo *)` for Rust,
`Bash(make *)` for a Makefile-driven repo. **Allow rules are prefixes**: the command first, then a
wildcard. Never wrap an allow rule in `*…*` — `Bash(*cd*)` matches any command that merely contains
"cd" anywhere. The deny list above keeps its `*…*` forms on purpose: there, matching more is the
safe direction. Validate the file parses as JSON before moving on.

**`git stash`, `git checkout` and branch-creating `git switch` (`-c`, `-C`, `--create`,
`--force-create`) are denied, deliberately — do not "fix" this by moving any of them back to
`allow`.** The first two discard uncommitted work silently, and a sub-agent has no way to signal
that it did so: the only trace is a `git status` that comes back cleaner than it should. This is
not hypothetical. On 2026-09-11 an orchestrated Developer sub-agent finished a bug fix, a Reviewer
executed its regression test and confirmed it passed, and one of them then ran a bare `git stash`
— most plausibly to demonstrate the new test failed against the pre-fix code — and never restored
it. The entire fix vanished and had to be redone.

`git switch -c` is denied for a related reason: it silently relocates the working tree onto a
branch the human never asked for, carrying their uncommitted changes with it, so the next commit,
push or PR lands somewhere they did not choose. Creating a branch is the user's decision — an
agent asks for it rather than taking it. Plain `git switch <existing-branch>` is not in the deny
list only because `git checkout` already covers moving between existing branches; do not read its
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
4. **Check the global wiring exists.** Read `~/.claude/settings.json`. Each hook script
   says how it is wired: `# <file> — <Event> hook (matcher: <regex>)` on its header line (the first comment after any `source` line), with `(matcher: "")` for one
   wired with no matcher. A file whose header says `helper (sourced, not a hook)` (e.g. `lib-python.sh`) is sourced by
   the hooks, not a hook: skip it. If `settings.json` has no `hooks` block, or no entry for a hook
   script in `~/.claude/hooks`, do not fix that here: say in the Step 9 summary which
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
# One graph, at graphify-out/. Only GRAPH_REPORT.md is committed - it is what
# humans and later agents read. graph.json, graph.html, manifest.json,
# cost.json, the AST cache and .graphify_analysis.json are regenerable, large,
# and rewritten in full on every run. Rebuild them with scripts/graph.ps1.
#
# .graphify_root is ignored too: it records an absolute path from the machine
# that built the graph, so committing it breaks every other clone.
graphify-out/**
!graphify-out/
!graphify-out/GRAPH_REPORT.md
.graphify_root

# Orchestrator run-state: local resume data, rewritten by every run, never committed.
**/.orchestrator-run-state.json
**/.orchestrator-work/

# Spike Directories: throwaway spike code, never committed (findings go to the PMBook).
# Leave this line out if the repo tracks its spike code on purpose.
spikes/

# Local Claude settings: per-user permissions and env, never committed.
.claude/settings.local.json
```

The three `graphify-out` lines have to be in that order. `graphify-out/**` excludes everything; git
will not look inside an excluded directory, so `!graphify-out/` is what re-admits the folder far
enough for the third line to match the report. Drop it and nothing is committed at all. (This is the
one-graph shape of `plugin-init-adlc-repo`'s block, which keeps a graph per component in
`graphify-out/<component>/`.)

## Step 3d — `scripts/graph.ps1`: the graph build script

Copy `~/.claude/skills/init-adlc-repo/templates/graph.ps1` (this skill's own `templates/graph.ps1`)
to `scripts/graph.ps1` in the target repo, byte for byte. If the template is missing, stop this step
and say so in Step 9 — do not write a script from memory.

**Create only.** If `scripts/graph.ps1` already exists, show the user how it differs from the template
and ask before replacing it.

What the copy does, so the summary can say it plainly:

- Reads `.claude/SKILLS.md` each run. With no `components:` table it treats the repo as one
  component: the roots are `graphify-directories` (falling back to `source-code-directory`, which it
  refuses if that is the repo root), and the output folder is `graphify-out` (`./graphify-out`).
  **It holds no list of roots**, so changing a root is a `SKILLS.md` edit only.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1` runs `graphify update`
  once per root (no LLM, no API cost) with an absolute `GRAPHIFY_OUT`, so the roots merge into one
  graph, then stamps `GRAPH_REPORT.md` with `> Built at commit: <sha>` (plus
  `+ uncommitted working tree` when the roots have uncommitted changes). The orchestrator's Graphify
  step finds this script and runs it (its route 1).
- `-DryRun` parses `SKILLS.md` and prints what it would build, writing nothing. Exit 1 means graphify
  is not on PATH or the build failed.
- Works under Windows PowerShell 5.1 (`powershell`) and PowerShell 7.

The `Makefile`'s `graph` target calls it (Step 3e). After the copy, run it once with `-DryRun` and put its output in the Step 9 summary.

## Step 3e — `Makefile`: the standard targets

Every repo gets a root `Makefile` with the standard targets in `~/.claude/skills/init-adlc-repo/references/makefile.md`: `help`, `install`, `up`, `down`,
`restart`, `status`, `logs`, `build`, `test`, `lint`, `format`, `audit`, `check`, `publish`, `deploy`,
`rollback`, `ports`, `graph`, `docs-check`, `clean`. Read that file before writing one: it says what
each target must do, how `deploy` ships only the app's own files (tag, local copy, dry run, keep list)
and how `rollback` works by tag.

1. **No `Makefile`:** write one, each target wired to the stack Step 2 detected. A target that doesn't
   apply prints `<target>: not used in this repo`.
2. **A `Makefile` exists:** add only the missing targets. Never change what an existing target does
   without the user's yes; list any that fall short of the standard (an `audit` that exits 0 with
   findings, a `deploy` with no dry run, tag or local copy) as suggestions.
3. **Settings:** add the standard's `ask` rules to `.claude/settings.json` (Step 3), so `deploy` and
   `rollback` always prompt.
4. Run `make help` once and put its output in the Step 9 summary.

## Step 4 — `.claude/memory.md`

This file is deliberately a **pointer, not a store**. Once idea-triage and
orchestrator-development-pattern are wired in, the PRD, Architecture doc, ADRs, PMBook, and handoff
doc are each the one governed home for their kind of information. Duplicating decisions, architecture,
or status here would give the repo two versions of the same fact with no way to tell which is current
— exactly the failure those docs exist to prevent.

So it holds only static identity (which never goes stale) and a routing table:

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
- Type: <TODO>

---

## Where to Look

| Topic | Source of truth |
|---|---|
| Problem, goals, scope | `docs/prd.md` |
| System design, components, tech decisions | `docs/architecture.md` |
| Why a specific technical decision was made | `docs/adr/` |
| Feature backlog, phases, status | `docs/project-management.md` |
| Current implementation state, what's next | `docs/handoff.md` |
~~~

Leave the `<TODO>`s. Never invent identity details.

## Step 5 — `docs/` scaffolding

Create `docs/adr/` with a `.gitkeep` so the convention exists (and survives a clone) before the first
ADR is written. idea-triage creates `prd.md`, `architecture.md`, and `project-management.md` itself;
the orchestrator creates `handoff.md`. Do not stub those — an empty governed doc reads as "this was
filled in" and is worse than an absent one.

**A repo with a user interface also gets `docs/design/`** — the design folder described in
`~/.claude/skills/sync-artboards/references/design-files.md`: `rows/`, `rounds/` and `artboards/`,
each with a `.gitkeep`, plus a `docs/design/README.md` of a few lines that says what each folder holds
and points to that file and to the `sync-artboards` skill. Do not write `brief.md`, a rows file or a
round: idea-triage writes them when a PMBook item first changes a screen. If the repo already has
boards with `review-<page>.md` ledgers (the old layout), create nothing here; say so in Step 9 and
point to `~/.claude/skills/sync-artboards/references/migrate-design-layout.md`.

**Do not create `docs/diagrams/`.** See *Diagram convention*.

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

### Shaw & Partners repos: link to the knowledge base, don't copy it

If the repo is Shaw & Partners work (a Shaw remote, `Shaw.*` packages, or the user says so), add one
line to CLAUDE.md: *"For Shaw estate facts — code, `Shaw.*` packages, databases, hosting, identity,
sign-in, UI standard — load the `shaw-estate` skill."* Don't copy estate facts (servers, feeds,
connection strings, deployment rules) into CLAUDE.md; they live in that skill and are maintained there.

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
See `docs/handoff.md` for the current build state and what's next, and
`docs/project-management.md` for the full feature backlog.

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
decisions, and rationale live in `docs/architecture.md` and `docs/adr/` — read those
before a structural or technology change, and add or amend an ADR when you make one.

Governed docs (`docs/prd.md`, `docs/architecture.md`, `docs/project-management.md`,
`docs/adr/`, `docs/handoff.md`) are specs the code must satisfy, not side artifacts —
keep them in sync with any structural change in the same session, not as a follow-up.
~~~

### What to leave out

- Anything discoverable in seconds — full file trees, every component, obvious conventions.
- Generic engineering advice ("write tests", "handle errors", "don't commit secrets").
- **Test counts, known-red lists and dated baselines.** They change daily and drift between
  branches. They go in `docs/dev-environment.md` or the test runbook; CLAUDE.md points there.
- Invented sections — "Common Development Tasks", "Tips", "Support" — unless a file you read says it.
- **The architecture itself.** One paragraph plus a pointer to `docs/architecture.md`. A full
  description here becomes a second, competing source of truth that drifts silently.

### What earns its place

Operational facts that cost a session's time to rediscover: the one true entrypoint and the
plausible-looking wrong one; the slow-path/fast-path split; a tool whose exit code lies; a
platform-specific requirement; which of two processes must start first.

Also fold in the important parts of any existing `README.md`, `.cursorrules`, `.cursor/rules/`, or
`.github/copilot-instructions.md`.

## Step 8 — Wire the skills: `.claude/SKILLS.md`

Verify each skill exists at `~/.claude/skills/<name>/SKILL.md` before wiring it. Skip and report any
that aren't installed.

~~~markdown
# Available Skills

This file binds project-specific variable values to skills that accept parameters.
Claude reads this file to know which skills are active and what paths to inject.

**Stack:** <detected stack>

---

## Orchestrator Development Pattern

Skill: `orchestrator-development-pattern` (located at `~/.claude/skills/orchestrator-development-pattern/SKILL.md`)
Trigger: `/orchestrator-development-pattern` or when the user says "start development", "implement", "build".

The orchestrator detects the platform at runtime.

values:
  project-management-doc: "./docs/project-management.md"
  handoff-doc: "./docs/handoff.md"
  source-code-directory: "./"
  revision-file: "./REVISION.md"
  changelog-file: "./CHANGELOG.md"
  snyk-command: "<dependency audit command(s) for the detected stack>"
  # known-red-baseline: "<optional — a file listing failures and audit findings the repo already accepts>"
  test-runbook-location: "./docs/testing/<FEATURE-ID>-<short-name>.md"
  architecture-doc: "./docs/architecture.md"
  test-cases-doc: "./docs/test-cases.md"
  adr-directory: "./docs/adr"
  archive-directory: "./docs/archive"
  graphify-directories:
    - "<./src/Project>"
    - "<./tests/Project.Tests>"
  graphify-out: "./graphify-out"
  # User interface — omit these when the repo has no UI (see "UI bindings" below the template)
  design-directory: "./docs/design"
  design-rows-directory: "./docs/design/rows"
  design-rounds-directory: "./docs/design/rounds"
  artboards-directory: "<./docs/design/artboards>"
  app-url: "<http://localhost:{4200+offset}>"
  artboard-server: "<command and port that serve artboards-directory>"
  parity-viewports: "1440"
  # parity-command: "<optional — the repo's checked-in parity harness, e.g. npx playwright test business-tests/layout/parity.spec.ts>"
  # design-source: "<optional — where the designer works, e.g. an Artifact URL and its root folder; sync-artboards asks if unset>"

`graphify-directories` keeps the knowledge graph on the code roots (Step 2); `source-code-directory`
stays the repo root for platform detection. `scripts/graph.ps1` reads both bindings — change a root
here and nowhere else.

---

## Idea Triage

Skill: `idea-triage` (located at `~/.claude/skills/idea-triage/SKILL.md`)
Trigger: `/idea-triage` or when the user presents a new idea before any code exists.

values:
  docs-directory: "./docs"
  prd-file: "./docs/prd.md"
  architecture-file: "./docs/architecture.md"
  project-management-doc: "./docs/project-management.md"
  handoff-doc: "./docs/handoff.md"
  adr-directory: "./docs/adr"
  archive-directory: "./docs/archive"
  # User interface — omit when the repo has no UI; same values as the orchestrator block
  artboards-directory: "<./docs/design/artboards>"
  design-directory: "./docs/design"
  design-rows-directory: "./docs/design/rows"
  design-rounds-directory: "./docs/design/rounds"

---

## Sync Artboards

Skill: `sync-artboards` (located at `~/.claude/skills/sync-artboards/SKILL.md`)
Trigger: "sync artboards", "sync and validate the artboards", "the designer is done".
Omit this block when the repo has no UI. Spec: `~/.claude/skills/sync-artboards/references/design-files.md` §Bindings.

values:
  design-directory: "./docs/design"
  design-rows-directory: "./docs/design/rows"
  design-rounds-directory: "./docs/design/rounds"
  artboards-directory: "<./docs/design/artboards>"
  artboard-server: "<command and port that serve artboards-directory>"
  # Optional — unset, sync-artboards asks for design-source once and skips the step of each other one:
  # design-source: "<where the designer works, e.g. an Artifact URL and its root folder>"
  # design-validate-command: "<tests run against the boards after a sync>"
  # design-row-tests: "<how a row is tied to a test: tag, skip marker, known-differences list>"
  # design-post-sync: "<anything run after a sync, and whether Claude may push it>"
  # ui-contract: "<the full UI contract, if the repo has one; default brief.md §Build rules>"

---

## Graph-Assisted Context

One graph of the `graphify-directories` roots, at `graphify-out/`, **built by `scripts/graph.ps1`** —
not by the `/graphify` skill:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1
```

The script reads `graphify-directories` and `graphify-out` above, runs `graphify update` per root
(no LLM) and stamps `GRAPH_REPORT.md` with the commit it was built at. The orchestrator's Graphify
step runs the same script. Only `GRAPH_REPORT.md` is committed; `graph.json`, `graph.html` and the
cache are regenerable and gitignored, so a fresh clone has no graph until the script runs. If the
report's `> Built at commit:` is not `git rev-parse HEAD` and the diff since touches a code root, it
is stale: rebuild before relying on it.

Read `graphify-out/GRAPH_REPORT.md` before starting any feature that touches multiple modules.

Skill: `graphify` (located at `~/.claude/skills/graphify/SKILL.md`)
Trigger: `/graphify query "<topic>"` — to ask the built graph a question. Run `/graphify` over a
root by hand only when the LLM-enriched graph (inferred edges, named communities) is wanted.

---

## Find Skills

Skill: `find-skills` (located at `~/.claude/skills/find-skills/SKILL.md`)
Trigger: `/find-skills` or `/find-skills <query>`

---

## Shared-Path Invariant

idea-triage's `architecture-file` and the orchestrator's `architecture-doc` are the
**same physical file** — idea-triage writes it, the orchestrator reads it — but each
skill names its own variable so either stays usable without the other installed.
The same applies to `project-management-doc`, `handoff-doc`, `adr-directory`,
`archive-directory` (where Tranche Closeout puts each closed version's docs), `artboards-directory`
and the three `design-*` folders.
If any of these paths changes, change it in **both** blocks, or the two skills will
silently disagree about which file is authoritative.
~~~

Fill `snyk-command` from the detected stack (`npm audit`, `pip-audit`, `cargo audit`,
`dotnet list package --vulnerable`, …). For a multi-toolchain repo, bind **all** of them, and record
any that report findings without a non-zero exit code — `dotnet list package --vulnerable` is the
common offender, and gating on its exit code makes that half of the audit decorative.

**UI bindings.** The orchestrator's Board Parity Check needs `app-url` and `artboard-server` for every
UI packet, and stops to ask when they are unbound. Fill them now from what the repo already says: the
root `CLAUDE.md`, the run skill, the stack config (dev-server port, port offset per checkout), and the
README of whatever serves or tests against the boards. If those name a checked-in parity or layout
spec, uncomment `parity-command` with the command that runs it; otherwise leave it commented. Write `app-url` as a pattern with `{offset}` in
it, never one checkout's fixed port. `artboards-directory` is the folder of design boards, if one
exists. The three `design-*` bindings point at the folders Step 5 made; leave their defaults. If the
repo's design README or `CLAUDE.md` says where the designer works, uncomment `design-source` with it.
Anything not found stays a `<TODO>` and is listed in Step 9. A repo with no user interface
drops all the UI lines, in both blocks.

## Step 9 — Summarize

Report what was created, what was skipped and why, and any `<TODO>` left for the user. Remind them
these are project conventions meant to be committed, not local config. Explicitly call out:

- That the project `settings.json` has no `hooks` block (or which duplicate entries were removed from an
  existing one, and which project-only hooks were kept), and any `~/.claude/hooks` script that is not
  wired in the user's global `~/.claude/settings.json`.
- The UI bindings that were filled (and the file each came from), any left as `<TODO>`, or that the
  repo has no user interface and they were left out.
- The design folder: that `docs/design/` was made (idea-triage writes the brief, rows and first round
  when a screen change is planned; `sync-artboards` brings the designer's boards back), or that an old
  layout was found and left alone, with the path to the migration guide.
- That `.mcp.json` was created with `playwright` and `context7`, and that `CONTEXT7_API_KEY` needs
  to be set in the user's environment before the Context7 server will authenticate.
- **That `scripts/graph.ps1` builds the knowledge graph** (or why it was not copied), with its
  `-DryRun` output, the `graphify-directories` it read, and that a fresh clone has no graph until it
  runs.

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

Diagram *type* selection still matters and is unchanged — that guidance lives in idea-triage §2.3.

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
  `docs/architecture.md`.
- Never create a `docs/diagrams/` tree or a render script.
- **Never overwrite an existing `.gitignore`.** Step 3c appends its block or creates the file.
- **Never write `scripts/graph.ps1` from memory or put roots in it.** Copy the template (Step 3d);
  the roots live in `graphify-directories`, and a second list in the script drifts from it silently.
  Never bind `graphify-directories` to the repo root.
- Generate a project **skill**, not a slash command, for app launch.
- **Never wire a `~/.claude/hooks` script in the project's `settings.json`.** The user's global settings
  already run it, so a project copy makes it run twice (Step 3a). A project `hooks` block holds only
  hooks whose scripts live in the repo.
- Never write a real Context7 API key (or any other secret) into `.mcp.json` — it's a committed
  file. Use `${VAR}` environment-variable expansion and tell the user to set the variable locally.
- This skill touches `.claude/`, `.mcp.json`, `.gitignore`, `scripts/graph.ps1`, `CLAUDE.md`, and
  `docs/adr/`. It does not modify application code.
