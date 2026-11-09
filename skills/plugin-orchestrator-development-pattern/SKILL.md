---
name: plugin-orchestrator-development-pattern
description: Multi-agent development orchestrator for a PLUGIN-BASED repository — one whose `.claude/SKILLS.md` declares a `components:` table, where a platform shell and its plugins are developed independently, each with its own governed documents and its own tranche line. Resolves which component the work belongs to, then runs the same Developer→Reviewer→Integration→Finalization pipeline as `orchestrator-development-pattern`, scoped to that component's docs, source roots and knowledge graph. Invoke only when the user explicitly wants the full pipeline run end-to-end (e.g. "orchestrate a fix for X", "run the orchestrator on this bug", "build this from the PMBook", "spike this", "this is a P0", "hotfix this") — not for a plain "debug X" / "fix this" question. A Spike work item skips the Reviewer/Integration gates entirely; a P0 Bug fast-lanes straight to its own Finalization. A UI Iteration (e.g. "let me iterate on the UI", "tweak mode", or a look-and-feel ask once the skill is in use) lets the user make a run of small look-and-feel tweaks with no gates, then runs the gates once when they say "done". Language and platform agnostic. For a single-component repo use `orchestrator-development-pattern` instead.
license: MIT
metadata:
  author: https://github.com/mak100186
  version: "1.6.0"
  forked-from: "orchestrator-development-pattern@2.9.0 (2026-09-10)"
  domain: development-workflow
  triggers: implement, build, develop, orchestrate, start development, run orchestrator, orchestrate a fix, run the orchestrator on this bug, run a spike, spike this, P0, hotfix
  role: orchestrator
  scope: multi-agent-development
  related-skills: plugin-idea-triage, plugin-init-adlc-repo, graphify
  variables: [
    docs-directory,
    components,
    project-management-doc,
    handoff-doc,
    source-code-directory,
    graphify-directories,
    graphify-out,
    revision-file,
    changelog-file,
    snyk-command,
    test-runbook-location,
    architecture-doc,
    platform-architecture-file,
    test-cases-doc,
    history-directory,
    archive-directory,
    adr-directory,
    artboards-directory,
    run-state-file,
    metrics-log-file
  ]
---

# Plugin Orchestrator Development Pattern

## Task bar

If you have a task-list tool (`mcp__task-bar__set_tasks`, or `TodoWrite`), keep it current: send the
whole list when work starts (one task per phase or work item), again whenever a task starts or finishes
or the plan changes, all `completed` at the end, then an empty list once the user has seen it. If you
have neither tool, carry on without; do not mention it.

> **Forked from `orchestrator-development-pattern` v2.9.0 on 2026-09-10**, and since diverged. This
> document is self-contained for plugin repos: component resolution first (**Step 0.0a**), docs and graph
> scoped to that component, a `Component` field on every Task Packet, a cross-component diff guard, a
> component-scoped test run where it is safe, parallel work-item waves, and a Developer on Opus at
> escalating reasoning effort.

The Orchestrator resolves the **component**, reads its PMBook, detects the platform, turns work into Task
Packets, and runs Developer → Reviewer per work item — several items at once where they cannot collide.
After every item passes review, one Integration Agent runs the quality gate and fixes failures, a
Reviewer-Integration gate checks that, and Finalization runs as four parallel Finalizers plus the
Orchestrator's own commits (pushed only on a go — see Git Restrictions).

**Three work-item types share this pipeline:** planned **Features** from the PMBook's Feature Backlog;
reactive **Bugs**, which can be taken ad hoc (Step 0.1b); and exploratory **Spikes** (Step 0.1c). Spike
and P0 are documented exceptions to specific steps — see `references/spike-and-p0.md`. A **UI
Iteration** (Step 0.1d) is a third exception: the user makes a run of small look-and-feel tweaks with
no gates, then says "done", and the gates run once over the whole change — see
`references/ui-iteration.md`.

## Side files

Read each only when its trigger occurs. They are part of this skill.

| File | Read when |
|---|---|
| `references/templates.md` | Once, at the start of Phase 1 — Task Packet formats and every sub-agent prompt template |
| `references/spike-and-p0.md` | The run contains a Spike, or a Bug with `Priority: P0` |
| `references/escalation.md` | A work item or Integration is about to escalate, or Divide-and-Conquer triggers |
| `references/ui-iteration.md` | A UI Iteration is opened (Step 0.1d) or found open on resume |
| `references/version-pointer-sweep.md` | Never by you — its path is handed to the PMBook Update Finalizer when a `> Version:` header moved |

## Invocation boundary

The pipeline needs an explicit ask — "orchestrate a fix for X", "run the orchestrator on this bug",
"build this from the PMBook", "spike this", "this is a P0". A plain "debug X" is a normal debugging
conversation. Spike and P0 likewise need the user to actually say so; never infer them from tone or
severity. Keep this description, the parent skill's, and the global CLAUDE.md entry in sync.

**Sticky per conversation:** once this skill has entered Phase 0 in a conversation, a later plain "debug
X" / "fix X" in the same conversation becomes a new Bug Fix Intake item, and "let's try X" a new Spike
Intake item. A plain look-and-feel ask ("make that button smaller") opens a UI Iteration (Step 0.1d)
instead; it is never a bug. A new conversation starts back at the high bar.

**UI Iteration** opens on an explicit ask ("let me iterate on the UI", "tweak mode") or, when sticky,
on a look-and-feel ask. It closes on the user's "done". Between the two, no phase runs.

## Key design principles

- **Developers write tests but do not run the suite.** Several Developers may be working at once against
  an incomplete codebase; the Integration Agent owns test execution and build health.
- **Parallel where it cannot collide, serial where it can.** Independent work items run as waves
  (Step 1.0). Anything sharing a file, a build unit or a root manifest runs one after another.
- **Cold spawns, paths not contents.** Every sub-agent is a fresh single-purpose spawn. Retries spawn
  fresh with the packet, the issues and the previous file list. Docs are passed as paths. After each item
  the Orchestrator keeps only its one-line result; the durable record is on disk.

---

## Roles

Each role is a global agent in `~/.claude/agents/`, spawned by its dedicated `subagent_type` — never a
generic agent.

| Agent | Responsibility | `subagent_type` |
|-------|----------------|-----------------|
| **Orchestrator** (this skill) | Resolves component, reads PMBook or intakes a bug/spike, detects platform, builds packets and waves, dispatches, tracks state, commits (pushes/pulls only on a go), escalates | — |
| **Developer** | Implements one work item inside one component, writes tests, runs scoped Format + Lint | `plugin-orchestrated-developer-high` / `plugin-orchestrated-developer-xhigh` (thin shims over `orchestrated-developer`) |
| **Reviewer** | Gates Developer Output against the packet; on Bug packets also runs the single named regression test | `orchestrated-reviewer` |
| **Integration** | Diff guard, quality gate at the run's Test scope, fixes, audit, E2E, drift check | `orchestrated-integration` |
| **Reviewer-Integration** | Gates the Integration Output; read-only `git diff` on risky fixes | `orchestrated-reviewer-integration` |
| **Finalizer** | One Phase 3 Task (or a named bundle) per spawn; four run in parallel. A Spike gets one solo Spike Log Task instead | `orchestrated-finalizer` |

**Before every spawn** print `→ Spawning <Role> agent — <item ID> — model: <model>[, effort: <effort>]`,
and pass `model` explicitly from **Model Assignment**. The agent's own frontmatter model is only its
standalone default.

### Model Assignment

Edit this table to change a model; nothing else needs to change. Values are tier aliases (`opus` /
`sonnet` / `haiku`), which is all the `Agent` tool's `model` parameter accepts.

| Role / Task | Base (loop_count 1–2) | Escalated (loop_count 3) |
|------|-------|-------|
| Developer | `opus`, effort `high` — `plugin-orchestrated-developer-high` | `opus`, effort `xhigh` — `plugin-orchestrated-developer-xhigh` |
| Reviewer | `sonnet` | `opus` |
| Integration | `sonnet` | `opus` |
| Reviewer-Integration | `sonnet` | `opus` |
| Finalizer — Graphify | `haiku` | — (no retry loop) |
| Finalizer — PMBook Update | `haiku`; `sonnet` when it also runs the Version Pointer Sweep | — |
| Finalizer — Handoff Update | `haiku` | — |
| Finalizer — Revision + Changelog, Test Runbook (bundle) | `haiku` | — |
| Finalizer — Spike Log | `haiku` | — |

- **The Developer escalates by effort, not model.** Effort lives in agent frontmatter and cannot be
  passed per spawn, so the two effort levels are two sibling definitions chosen by `subagent_type`. Still
  pass `model: "opus"`. `xhigh` needs extended thinking on; without it, it runs as `high`.
- **Finalizers run on `haiku` because they get an Edit List** (changed 2026-11-09, Phase 3): the
  Orchestrator says what changes where, and the Finalizer finds the spot and edits it. The Version Pointer
  Sweep is the exception — moving version lines across many components takes judgement, so the PMBook
  Finalizer goes up to `sonnet` in a run that needs the sweep.
- **Reviewers run on `sonnet`, not `haiku`** (changed 2026-11-03). They gate Opus work against long
  rulebooks, and a wrong FAIL costs a whole Opus Developer round. Revisit with `metrics-log-file` data.
- Escalation applies only at loop_count == 3 — the one attempt before a human is paged. Finalizers have
  no retry loop. A Spike's Developer never escalates.

---

## Workflow Overview

```
[0.0a] Resolve component → print confirmation block
[UI ITERATION, Step 0.1d] tweak → look → tweak … no gates → "done" → Design Gate (after) →
       one Reviewer → Integration → Finalize → commit   (references/ui-iteration.md)
[INIT] Verify deps → Read PMBook (or Bug/Spike Intake) → Platform + Test commands → Conventions
       → Specialist skill → Plan waves → Announce
  │
  ▼
[FEATURE LOOP] Wave by wave; up to 3 items in flight at once, each on its own chain:
  │   [Design Gate if UI] → [DEVELOPER] → Spike? → Spike Log → done
  │                              ▼
  │                        [REVIEWER] PASS / FAIL (retry ≤3, escalate) / UNVERIFIED (respawn ≤2)
  │                              ▼
  │        Feature → passed (PMBook written at Finalization)
  │        Bug, not P0 → queued for the batched Manual Verification Gate
  │        Bug, P0 → verify now → P0 Fast-Lane Finalization
  ▼
[MANUAL VERIFICATION GATE] all queued Bugs in one message → "verified" / still broken → retry loop
  ▼
[INTEGRATION] Test scope decided (component or full) → [INTEGRATION AGENT] diff guard, gate (output to
              log files), fixes, audit, E2E, drift, self-check → [REVIEWER-INTEGRATION, skipped on a
              clean first pass] → retry ≤3 (doc-only retry: no gate re-run) → Divide-and-Conquer → escalate
  ▼
[FINALIZE] 4 parallel Finalizers: Graphify | PMBook (+sweep) | Handoff | Revision+Changelog+Runbook
  ▼
[ORCHESTRATOR] Commits made (pushed only on a go) → Close-out checklist → [DONE]
```

---

## Phase 0 — Initialization

### Step 0.0a — Resolve the Component

**Runs before everything**, including Step 0.0 — every governed-doc and graph path is a template
resolved against a component.

A **component** is one independently-buildable unit — the shell, or one plugin — with its own backend
service if it has one. `.claude/SKILLS.md` declares them in a `components:` table mapping each name to its
`code` roots. If there is no `components:` table, this is not a plugin repo — say so and point the user
at `orchestrator-development-pattern`.

**Resolution ladder — stop at the first hit:**

| # | Signal | How to read it |
|---|---|---|
| 1 | **The user named it** | Must appear in `components:`; if not, stop and list the valid names. |
| 2 | **Work item ID prefix** | `OFA-F-003` → `ofa`. Case-insensitive, the segment before `-F-` / `-B-` / `-S-` / `-PM-`. A bare `F-031` resolves nothing. |
| 3 | **An unfinished run-state file** | Glob `docs/*/.orchestrator-run-state.json`. **Exactly one** with `"complete": false` resolves it and means a resume (Step 0.0's Resume check). |
| 4 | **Branch name** | A path segment exactly matching one component name. Two matches resolve nothing. |
| 5 | **Working-tree diff** | `git status --porcelain`: dirty, and every changed path under exactly one component's roots (paths outside all roots ignored). Two components' roots → resolves nothing; raise it. |
| 6 | **Ask** | List each component with its tranche and open-item count. |

**Never fall back to a default** — there is deliberately no `default-component` binding. **Always show
the work** before Step 0.0 and before any spawn:

```
Component:   ofa
Resolved by: work item ID prefix "OFA-F-003"   (ladder rung 2)
Docs:        docs/ofa/            tranche v1, 24 open items
Code:        apps/ofa, services/OFA.WebAPI
Graph:       graphify-out/ofa/
```

Then resolve every templated variable (`project-management-doc`, `architecture-doc`, `handoff-doc`,
`test-cases-doc`, `test-runbook-location`, `changelog-file`, `revision-file`, `history-directory`,
`archive-directory`, `artboards-directory`, `run-state-file`, `metrics-log-file`, `graphify-directories`,
`graphify-out`). Three are shared and never templated: `adr-directory` (one folder; new IDs are
component-prefixed), `platform-architecture-file` (the shell's architecture doc — read-only for every
other component), and `source-code-directory` (the repo root, for platform detection).

**One component per work item.** Work that spans two is split into one work item per component, linked
by `Depends on:`. Enforced by the Cross-Component Diff Guard. When linked items must land together — one
breaks without the other — run them as **Linked Runs** (below), not one after the other.

### Linked Runs

Two components' items are linked when one cannot pass Integration without the other — typically a
plugin change that breaks a test or contract the shell owns. They run in one orchestration:

- **Each item keeps its own component:** its own confirmation block, packet, `run-state-file` (each
  naming the other under `linkedRuns`), docs and graph. The Diff Guard checks each file against the
  component of the item that changed it.
- **Phase 1** runs per item as normal; the dependency orders them (the depended-on item first, or in
  parallel when their files are disjoint).
- **Step 1.5** is one batched message covering every linked run's Bugs.
- **Phase 2 runs once, combined**, at `Test scope: full`, over the whole tree.
- **Phase 3** spawns four Finalizers per component, all in one message — their files are disjoint.
- **Commits:** one per component; the depended-on component's is made first.

### Step 0.0 — Verify Hard Dependencies

**Must exist:** `project-management-doc`, `source-code-directory`, `architecture-doc`. If any is missing,
stop and ask. Ad-hoc Bugs and Spikes need these documents too; they just don't need a pre-existing PMBook
row.

**Soft (created or skipped later):** `handoff-doc`, `changelog-file`, `revision-file`,
`test-runbook-location` (created at Phase 3); `snyk-command` (else the platform default audit);
`adr-directory` (else skip the ADR check and say so); `graphify-directories` (else the component's `code`
roots); `run-state-file` and `metrics-log-file` (auto-created).

**Resume check:** if `run-state-file` exists and is not complete, ask: "Found an incomplete run from
`<timestamp>`, last at `<item>` — resume it, or start fresh?" Never resume silently.

**Deferred Integration check:** if the PMBook has `## Deferred Integration` rows with `Status: Pending`,
hold them for Step 0.4's announcement. Never blocks.

**Test Cases Doc:** if absent, draft it now from the current phase's features (at least one concrete E2E
or smoke scenario per feature, covering edge cases and regression-sensitive flows), save it, and register
the path. If present, check it covers every feature in scope with concrete scenarios; if it is thin, tell
the user what is missing and ask whether to proceed, have you draft the gaps, or pause.

### Step 0.1 — Read the PMBook

Identify the current phase and every feature `Planned` or `In Progress` in it, with acceptance criteria
and dependencies.

### Step 0.1b — Bug Fix Intake (alternate entry point)

1. **No PMBook row needed.** Take from the user: what's broken, how to reproduce, expected vs actual, and
   suspected files if known. Ask for anything missing.
2. **Assign a Bug ID.** If the bug already has a `## Bug Log` row (Status `Open`), use that ID and that
   row's description as the report. Otherwise: if the Bug Log states the next ID (e.g. "The next bug is
   `SHELL-B-005`"), use exactly that; else next after the highest `<COMPONENT>-B-XXX` in `## Bug Log`;
   `B-001` if none. A grep for IDs also matches the "next ID" line itself — read the table, not the grep.
3. **Several bugs at once** are queued in the order given. Step 1.0 decides which can share a wave.
4. **P0** only when the user actually says "P0", "hotfix", "prod is down" or equivalent → set
   `## Priority: P0` and read `references/spike-and-p0.md`.
5. Go to Step 0.2. Announce with one line: `Bug Fix Mode — B-XXX: <description>` (or
   `Bug Fix Mode [P0] — …`).

### Step 0.1c — Spike Intake (alternate entry point)

Only on an explicit ask. Read `references/spike-and-p0.md` and follow its Spike Intake.

### Step 0.1d — UI Iteration (alternate entry point)

On an explicit ask, or a look-and-feel ask while the skill is sticky (see **Invocation boundary**). Read
`references/ui-iteration.md` and follow it. In short:
1. The Orchestrator makes each tweak itself, with only scoped Format and Lint, and logs it in
   `run-state-file`.
2. Nothing else runs until the user says "done".
3. Then the gates run once over the whole change: the Design Gate (after the code, this once), one
   Reviewer, Integration, the Finalizers, the commit and the close-out.

### Step 0.2 — Detect Platform and Test Commands

Probe `source-code-directory` for markers and set the **Platform Profile**, injected into every packet.

| Marker | Platform | Format (scoped) | Lint (scoped) | Test (full) | Security audit |
|--------|----------|--------|------|------|----------------|
| `package.json` | Node / TypeScript | `npx prettier --write <files>` | `npx eslint <files>` (or `npm run lint`) | `npm test` | `npm audit` |
| `pyproject.toml` / `requirements.txt` | Python | `ruff format <files>` | `ruff check <files>` | `pytest` | `snyk-command` |
| `go.mod` | Go | `gofmt -w <files>` | `golangci-lint run <pkgs>` | `go test ./...` | `govulncheck ./...` |
| `Cargo.toml` | Rust | `cargo fmt` | `cargo clippy` | `cargo test` | `cargo audit` |
| `*.csproj` / `*.sln` | .NET | `dotnet format <project> --include <files>` | `dotnet build <project>` | `dotnet test` | `dotnet list package --vulnerable` |

No marker, or several platforms with no clear primary → ask. `snyk-command` overrides the audit.

**Component test command.** Also record how to run *only this component's* tests — derived from what
the repo actually has, e.g. `npx nx run-many -t test -p <projects under the component's roots>`, or
`dotnet test <the component's test projects>`. Record it in the Platform Profile as
`Test (component): <command>`. If no reliable component-scoped command exists, record `none` — every run
then uses the full suite.

**Stack lifecycle.** If any gate needs the app running (E2E, a Bug whose regression test is E2E) or
stopped (a build or test run that a running process would lock), record it in the Platform Profile as
`Stack: up <command> · down <command> · check <command>`, with which gates need which state. Take the
commands from `.claude/SKILLS.md` bindings `stack-up` / `stack-down` / `stack-check` when present, else
from the repo's own run skill or `CLAUDE.md`. `none` when nothing needs a running stack. Include any
**static server a test target needs** (e.g. business tests against design artboards need the artboards
folder served): its command and port, from the `artboard-server` binding or the tests' README. Before
using a port, check what it serves — another process may already hold it with the wrong folder; if so,
start your own on a free port and pass that URL to the tests. The Orchestrator
brings the stack to the right state before spawning a Reviewer or Integration Agent that needs it, and
passes the order (e.g. "E2E first while up, then down, then build") in the Integration prompt.

### Step 0.3 — Detect Coding Conventions

Scan for `.editorconfig`, `.prettierrc`, `[tool.ruff]`, `.eslintrc`, `golangci.yml` and similar;
summarise them for every packet.

### Step 0.3b — Choose the Specialist Skill

Pick, once, the installed specialist skill matching the component's stack (e.g. `angular-architect`,
`csharp-developer`; check the available-skills listing, never guess a name). A component with a frontend
and a backend may name two. Write it into every packet's `## Specialist Skill`, and into the Integration
and Reviewer-Integration prompts. Sub-agents use exactly what is named and skip their own search.
`None` is a valid answer.

### Step 0.4 — Plan Waves and Announce

Build the waves (Step 1.0), then print:

```
🎯 Orchestrator Initialized — <component>

Platform:  <detected platform>
Phase:     <current phase>
Specialist skill: <name(s) or None>
Work items (<N>), in waves:
  Wave 1: <ID> — <name> | <ID> — <name>
  Wave 2: <ID> — <name>   (depends on <ID>; shares <file/build unit> with <ID>)
  ...

Developer Quality Gate (per item):  Format: <command>  Lint: <command>
Integration Quality Gate:           Test (full): <command>  Test (component): <command or none>
                                    Audit: <command>

Estimated spawns: best <B> · typical ~<T> · worst <W>
  By tier: Opus ~<x> (every Developer) · Sonnet ~<y> · Haiku ~<z>

⚠ Deferred Integration outstanding (<N>): <IDs> — hotfixed without a full-suite run. (only if found)

Type STOP at any time to pause the orchestrator.
```

**Estimated spawns:** N items. Best = N × 2 (Developer + Reviewer) + 1 (Integration; Reviewer-Integration
is skipped on a clean first pass, Step 2.2) + 4 (Finalizers), plus one Design Gate spawn per UI item whose artboard needs an edit. Typical = Best ×
1.3, or the observed retry rate from `metrics-log-file` if it has rows. Worst = N × 6 + 2 × 3 + 4. Every
Developer spawn is Opus; Reviewers and Integration are Sonnet (Opus only at loop_count 3); Graphify is
Haiku.

Write `run-state-file` now.

---

## Phase 1 — Feature Loop

Read `references/templates.md` once, now. Track `loop_count` per item (starts at 0).

### Step 1.0 — Waves

Items run in **waves**. Items in the same wave run at the same time, each on its own Developer → Reviewer
chain. An item may join a wave only when all of these hold:

1. Every dependency is satisfied — `Done` in the PMBook, or passed Review earlier in this run.
2. Its `Files to Create or Modify` overlaps no other item in the wave.
3. It shares no **build unit** with another item in the wave (a `.csproj`, an Nx project, a
   `package.json` workspace) — concurrent builds of one unit lock each other's output.
4. It touches no shared root file another item in the wave touches (root `package.json`, lockfile,
   `scripts/`, `deploy/`, CI config), and no artboard another item touches.
5. The wave holds at most **3** items.

When in doubt, serialize — a collision costs more than the time saved. Spikes always qualify (their
Spike Directory is disjoint by construction).

**Running a wave:** spawn each item's first agent in the same message (background agents). As each one
returns, spawn that item's next step straight away — never wait for the slowest item before advancing
the others. The next wave starts when every item in this one has passed Review, been queued for manual
verification, or escalated.

**Collision check:** when a wave finishes, compare the Developer Outputs' real `Files Created or
Modified`. If two items touched the same file, respawn both Reviewers against the current tree (this does
not increment loop_count) and serialize those two items in any later retry.

**Escalation inside a wave:** see `references/escalation.md` — let siblings finish their current spawn,
then pause.

### Step 1.1 — Generate Task Packet

Fill the matching shape from `references/templates.md`, including `## Specialist Skill` and the scoped
Format/Lint commands. This is the single source of truth for Developer and Reviewer.

### Step 1.1b — Design Gate (UI-touching packets only)

**Before the Developer is spawned, never after.** Skip for packets that touch no user interface. The one
exception is a UI Iteration: the user approved each tweak on the live screen, so the gate runs once at
"done" and the artboard catches up (`references/ui-iteration.md`).

An artboard is a **specification, not a record**: the design is settled in the artboard first, and the
Developer builds to it. A Developer who decides the design while coding has made a product decision
inside an implementation task, and nothing downstream can tell it apart from an agreed design.

1. **Resolve the artboard** in `artboards-directory` (per component). If the binding is absent, say so and
   skip this step.
2. **Compare it with the Acceptance Criteria.** If they agree, print
   `Design Gate: <artboard> already matches — no change` and go on.
3. **If they disagree, update the artboard first** — spawn one agent to make that edit and nothing else.
4. **Author one if none exists**, following the artboards folder's README.

   **Designer-owned artboards are the exception to 3 and 4.** Read the artboards folder's README (and
   `.claude/SKILLS.md`) for who authors them. If an outside designer owns them — e.g. they are synced
   down from a design tool, so a repo edit is overwritten on the next sync — **never edit or author one**.
   Instead: if the surface is drawn and agrees, go on; if it is not drawn, or disagrees, and the change is
   small and fully described by the Acceptance Criteria (a label, a tooltip, a state of an existing
   control), print `Design Gate: <surface> not drawn — designer-owned; Acceptance Criteria are the spec`,
   tell the user a designer ask is owed, and go on. A **new or changed layout** with no drawing halts the
   item until the designer has drawn it.
5. **Name the component behind every surface** — each interactive or structural region as the Angular
   Material or CDK component that renders it (`mat-card`, `mat-table`, `matButton`, `cdkDropList`) — in
   the packet's `## Design Reference`.
6. **A surface that cannot be a Material component halts the item.** Plain HTML beyond text, layout and
   landmarks needs the user's written sign-off in the project's UI contract first. Print
   `Design Gate: HALTED — <surface> has no Material component and no signed-off exception` and stop that
   item (other wave items continue). Only this point blocks.
7. **Say where each surface's styling comes from** — shared theme, existing class vocabulary, a new
   shared class (its own work item), or local CSS.
8. **Print the diff** before the Developer is spawned.

### Step 1.2 — Invoke Developer Agent

`subagent_type: "plugin-orchestrated-developer-high"`, `model: "opus"`, Developer Agent Prompt with the
full packet. At loop_count 3, `plugin-orchestrated-developer-xhigh` instead — that swap is the
escalation.

Returns a **Developer Output**: files touched, implementation summary, test files written (not run),
Format and Lint PASS, assumptions and deviations.

**Save it verbatim** to a file (scratchpad, `devout-<ID>[-retryN].md`) before anything else. The
Reviewer gets that path, never a summary: a section dropped in a hand-over (DOM hooks, a list of
retired checks) comes back as a false FAIL and a wasted Opus round. Combine a resumed spawn's
hand-backs into the same file.

**An open question inside the packet's scope.** If the Developer Output asks the Orchestrator to decide
something the packet left open but did not put out of scope (e.g. a check whose subject is gone and
that the packet did not name as retired), decide it — a ruling that changes scope or a product decision
goes to the user — and **resume the same Developer spawn** (`SendMessage` to its ID) with the ruling.
No cold retry, no `loop_count` change. Pass the ruling to the Reviewer as binding.

**`Type: Spike`** → Spike Flow in `references/spike-and-p0.md`, not Step 1.3.

### Step 1.3 — Invoke Reviewer Agent

`subagent_type: "orchestrated-reviewer"`, `model: "sonnet"`, Reviewer Agent Prompt with the packet path and
the path of the verbatim Developer Output file (Step 1.2), plus any Orchestrator ruling. Returns `PASS`, `FAIL` (numbered, actionable issues tied to criteria) or `UNVERIFIED`
(what couldn't be checked and why).

If the Bug's regression test needs the app running (an E2E test), bring the stack up first with the
Platform Profile's `Stack` commands (and its check command) — a stack that is down turns the run into an
avoidable UNVERIFIED.

### Handling an UNVERIFIED Verdict

Applies to every Reviewer and Reviewer-Integration spawn. UNVERIFIED is not the Developer's fault, so it
never touches `loop_count`:

```
unverified_count = 0
WHILE verdict == UNVERIFIED:
  unverified_count += 1
  IF unverified_count > 2 → escalate "Verification Blocked" (references/escalation.md), pause
  Fix whatever the Unable to Verify report points at that you can fix (e.g. a wrong path in the packet);
  otherwise respawn unchanged — same inputs, same model.
```

### Step 1.4 — Review Loop

```
WHILE verdict == FAIL:
  loop_count += 1
  IF loop_count > 3 → escalate (references/escalation.md), pause until "resume"

  developer_agent = (loop_count == 3) ? "plugin-orchestrated-developer-xhigh"
                                      : "plugin-orchestrated-developer-high"     # model always "opus"
  reviewer_model  = (loop_count == 3) ? "opus" : "sonnet"

  Spawn Developer: original packet + issues list ("Reviewer Issues") + previous Files Created or
    Modified ("Previous Attempt"). Fix only the listed issues.
  Spawn Reviewer: packet + new Developer Output + loop_count + previous issues ("Retry Context").
  Update run-state-file.
```

**FAIL — cross-component dependency.** When every FAIL issue lies in a file the Developer may not touch
— another component's roots (for example a test the shell owns that the plugin change breaks) — a
Developer retry cannot fix it and would only burn strikes. Then: do **not** retry and do **not**
increment `loop_count`. Pause the item, tell the user, and with their OK raise a linked item in the owning
component's PMBook (`Depends on:` both ways). Run the two as **Linked Runs**. Once the linked item has
passed Review, respawn this item's Reviewer against the current tree — that respawn does not increment
`loop_count` either. If only some issues lie elsewhere, retry the rest as normal and raise the linked item
alongside.

On `PASS`:
- **Feature:** record it as passed in `run-state-file` and log
  `✅ <ID> <name> — PASS after <N> iteration(s)`. **Do not write the PMBook now** — the PMBook Update
  Finalizer sets `Done` at Phase 3, after Integration has passed. A feature is not Done until then.
- **Bug, not P0:** queue it for the Manual Verification Gate (Step 1.5) and move on.
- **Bug, P0:** run Step 1.5 for this bug immediately, then the fast lane in
  `references/spike-and-p0.md`.

### Step 1.5 — Manual Verification Gate (Bug packets only)

**Batched.** Once every item in the run has passed Review (or escalated), post **one** message covering
every queued Bug, so the user tests them in one sitting and the loop never sits idle waiting on a single
check. A P0 is the exception: it is verified on its own, straight after its Reviewer PASS.

```
🔍 Manual Verification Required — <N> bug fix(es)

Each regression test was run by the Reviewer and passes. Before these count as fixed, please check them:

B-XXX <title>
  Steps:    1. <from the Bug Report>  2. ...
  Expected: <from the Bug Report>

B-YYY <title>
  ...

Reply per bug: "verified", or describe what's still wrong.
```

**PAUSE** until the user answers. Then, per bug:
- **`verified`** → log `🐛 B-XXX <title> — PASS after <N> iteration(s), manually verified`; it joins
  Integration. (A P0 goes to its fast lane instead.)
- **Still broken** → back into Step 1.4's loop with the user's description as the issues list;
  `loop_count` increments, same 3-strike rule. Rejected bugs can run as a wave. Re-post the gate for just
  those bugs when they pass Review again.

Integration does not start until every non-P0 Bug in the run is verified or escalated.

---

## Phase 2 — Integration

Entered when every Feature has passed Review and every non-P0 Bug is verified. P0 Bugs already
fast-laned are excluded; if one was the only item, Phase 2 does not run. Spikes never reach Phase 2.

### Step 2.0 — Decide the Test Scope

Run `git status --porcelain` and ignore paths under `docs-directory` and `graphify-out` (docs don't change
test outcomes). Then:

- **`full`** if any of these is true: the component is the **shell** (every plugin builds against it);
  any changed path lies outside this component's `code` roots (root manifest, lockfile, shared `libs/`,
  CI config); `Test (component)` is `none`; a `## Deferred Integration` row is being re-validated; or the
  user asked for a full run.
- **`component`** otherwise — use `Test (component)` from Step 0.2, plus this component's scenarios in
  `test-cases-doc`, plus any contract or conformance tests `platform-architecture-file` names.

This does not weaken the gate: the Cross-Component Diff Guard proves no other component's code changed,
and every change that could reach another component forces `full`. Write the result into the Platform
Profile as `Test scope: <full|component> — <command> — <reason>`, and print it.

### Step 2.1 — Invoke Integration Agent

`subagent_type: "orchestrated-integration"`, `model: "sonnet"`, Integration Agent Prompt, passing the
Platform Profile with its Test scope line, the specialist skill, the component and its roots, completed
features and verified bugs with their files, and the **paths** (never the contents) of `test-cases-doc`,
`architecture-doc`, `platform-architecture-file`, `project-management-doc`, `test-runbook-location` and
`adr-directory` — each "None provided" when absent — plus any Pending Deferred Integration IDs, and a
**gate log directory** (`<scratchpad>/gate-logs/<run id>/`).

**Before spawning, snapshot the tree:** save `git status --porcelain` and `git diff --stat` (Step 2.2
compares against them).

The Integration Agent:
0. Runs the **Cross-Component Diff Guard** first — a violation invalidates the rest of the pass.
1. Runs the quality gate at the given scope — once. A green first run is final. **Every gate command's
   output goes to a log file** in the gate log directory; the agent reads only the summary and the
   failure blocks, never a whole log. Test output is the largest token cost in this phase.
2. Fixes test and build failures at the root (never by weakening a check).
3. Runs the security audit.
4. Runs E2E/smoke scenarios from `test-cases-doc` (in scope), or records the skip in two places.
5. Checks cross-feature integration and dead code.
6. Runs the **Documentation Drift Check** — this component's docs plus a read-only pass over
   `platform-architecture-file`. Drift is a defect, FAIL-worthy like a broken test.
7. Runs its **Self-Check** — the bookkeeping checks Reviewer-Integration used to fail most first passes
   on (every doc path has a drift line, every drift finding placed, every known-red's three facts, every
   skip in both places, scope stated, numbers consistent) — and fixes its own Output before returning.
8. Returns an **Integration Output**, with the Self-Check and the gate log paths.

**Cross-Component Diff Guard:** inside this component's roots — fine. Outside every component's roots —
allowed, each named with a one-line justification. Inside another component's roots — **FAIL**; the fix is
a `Depends on:` work item in the owning component's PMBook, never a cross-border edit and never a quiet
revert. `platform-architecture-file` modified — **FAIL**, always.

### Step 2.2 — Invoke Reviewer-Integration Agent (skipped on a clean first pass)

Reviewer-Integration exists to catch a gamed fix and a dropped finding. When Integration fixed nothing,
there is no fix to have gamed, and the Self-Check covers the findings — so the Orchestrator checks the
pass itself and spawns no reviewer.

**Skip it only when every one of these holds** (all mechanical, all from what the Orchestrator holds or
can read in seconds):

1. It is the first pass (`loop_count` 0), and the Integration Output's Overall Status is `PASS`.
2. `Fixes Applied` is `None`, and the tree matches the Step 2.1 snapshot: `git status --porcelain` and
   `git diff --stat` are unchanged. Any file the agent changed, even a doc, means a spawn.
3. The gate ran in this pass at the Test scope that was set (not narrowed, nothing carried forward), and
   the summary line in each gate log agrees with the reported numbers (`0 failed` beside each PASS).
4. Every Self-Check line is ticked, and `Flaky Tests Detected` and `Unresolvable Issues` are `None`
   (apart from a recorded E2E skip for a missing test-cases doc).
5. Each known-red, if any, passes a quick look: its ID is in the owning component's live PMBook and
   still open, and the failing file's path lies under that component's roots.

Then print `Reviewer-Integration: skipped — clean first pass, no fixes, tree unchanged` and go to Phase 3.
If any condition fails, or you are unsure, spawn it.

**Otherwise spawn it:** `subagent_type: "orchestrated-reviewer-integration"`, `model: "sonnet"`, with the
Integration Output, the condensed packets, the Test scope line, the doc paths that were given to the
Integration Agent, and the gate log directory. Returns `PASS` / `FAIL` / `UNVERIFIED` (UNVERIFIED
handled as in Phase 1).

### Step 2.3 — Integration Loop

Same as Step 1.4: loop_count 1–2 at base models, loop_count 3 at the Escalated Model (Integration and
Reviewer-Integration both `opus`). On a retry the Integration Agent gets loop_count, the issues, and its
prior Output, and does not redo drift sections already cleared. A retry is never a skip candidate for
Step 2.2 — Reviewer-Integration always checks a retry.

**Doc-only retry — no gate re-run.** Sort the FAIL issues first. If **every** issue concerns only the
report or the docs — a missing or unplaced drift line, a wrong known-red tracker or owner, a skip
recorded in one place, wording in a governed doc — and none questions a gate result, a fix, a test, code
or config, mark the retry `Doc-only retry` in its Retry Context. The Integration Agent then fixes only
the docs and its Output, edits no code, test or config file, and **does not re-run the gate**; it carries
the gate results forward, marked `carried forward from pass <N>`, with the same log paths.
Snapshot the tree before the retry (as in Step 2.1), compare after it, and pass Reviewer-Integration the
list of files the retry changed — a plain `git diff` also shows the Developers' earlier work, so it cannot
tell. Reviewer-Integration FAILs the retry if that list holds any code, test or config file. Any issue about code, tests or gate numbers makes it a normal retry, which re-runs the gate once
after its fixes.

Prefer **resuming the same Integration spawn** (`SendMessage` to its ID) with the issues for a doc-only
retry — it already holds the docs and logs, so a cold re-read is wasted. If it is no longer available,
spawn fresh with the Retry Context.

If loop_count 3 still fails, run **Divide-and-Conquer** from `references/escalation.md` before escalating.

**Known-red.** A failure that this run did not cause and that another work item already tracks is a
**known-red**, not a FAIL. It is accepted only when the Integration Output gives all three: the tracking
item's ID (found by searching every component's PMBook), the owning component (from the failing file's
path against `components:`, not from the test's name), and evidence that this run did not cause it (the
same failure on the base commit, or `git` showing the run never touched what fails). Reviewer-Integration
checks each of the three. A failure with no tracking item is reported to the user — they decide whether
to raise one; it is never silently accepted. Known-reds are listed in the final summary and in the
Integration metrics row. Accepting one is recording it, never silencing it: the test still runs and stays
red.

---

## Phase 3 — Finalization

Entered only on Reviewer-Integration `PASS`, or on a skip under Step 2.2's rule (except a P0 fast lane, which runs this phase early for one
Bug — see `references/spike-and-p0.md`). A Spike gets only its Spike Log.

Spawn **four Finalizers in parallel** — four `Agent` calls in one message, each
`subagent_type: "orchestrated-finalizer"` with its `model` from **Model Assignment** and the Finalizer
Agent Prompt. They write disjoint files. All four write only this component's docs, except the Version
Pointer Sweep's permitted header edits; none touches `platform-architecture-file`.

Each component has its own semver; version history rows go to `history-directory`, never into a live doc.

**Edit Lists — the Orchestrator says what changes where.** A Finalizer used to read whole governed docs
to work out its edits; a PMBook Finalizer once took 20 minutes. The Orchestrator already holds every
fact, so it hands each doc Finalizer (all but Graphify) an **Edit List**: one line per edit, as
`<file> — <anchor> — <change>`.

- **Anchor:** something the Finalizer can find with one search — a row's ID (`OFA-F-003`), a section
  heading (`## Bug Log`), or `end of <section>` for an append.
- **Change:** the facts, short — `Status → Done`, `new row: OFA-B-012 | <one-line description> |
  2026-11-09 | Fixed | Unreleased`, `entry under [Unreleased] → fix: OFA-B-012 <one line>`. Facts, not
  finished paragraphs: writing the prose is the Finalizer's job, and an Opus-written paragraph costs
  more than the Haiku spawn saves.
- **Complete:** every edit the Finalizer must make is on the list. The Finalizer does no edit that is
  not on it; anything else it notices goes under Notes.
- Build the lists from what you already hold — the packets, the Developer Outputs, the Integration
  Output (its drift findings handed to a Finalizer become list lines) and the Release label. Do not read
  the docs in full to build them; a `Grep` for an anchor you are unsure of is enough.

**Release label — decided once, before the spawn.** The PMBook Finalizer writes "Fixed In <label>" while
the Changelog Finalizer writes the entry under that label, at the same time — so neither may pick it.
Before spawning, read `changelog-file`: if it keeps an `[Unreleased]` section, the label is
`Unreleased` and entries go there; otherwise take the newest released version and bump it (minor for any
Feature, patch for Bugs only). Pass the same label to both Finalizers as `Release label:`, and print it.

### Step 3.1 — Graphify (Finalizer, `haiku`)

**Mandatory and automatic.** Skip only when no code changed **inside the component's `code` roots** —
e.g. every change sits in a shared library or test folder outside all roots, which the component's graph
does not scan. Then spawn no Graphify Finalizer, print `Graphify: skipped — <reason>`, and pass the same
line to the Handoff Finalizer and the close-out summary.

- **Task-Specific Inputs:** the component name; `graphify-directories` = this component's `code` roots;
  output directory `graphify-out/<component>/`; whether `graph.json` already exists there (first run vs
  `--update`).
- One graph per component, never the project root (planning docs would pollute a code-structure graph,
  and a shared graph file can't be merged across branches). Several roots → one run per root, the later
  ones with `--update`.
- The Finalizer stamps `GRAPH_REPORT.md` with the component, `git rev-parse HEAD` and the roots, and
  reports only `GRAPH_REPORT.md` as committable. Everything else in that folder is gitignored.
- The graph is built before the commit, so the stamp also says `+ uncommitted working tree`: it describes
  the tree as it will be committed, not the stamped commit.
- Before relying on a report you did not build, compare its stamped commit with `HEAD`: if the
  component's roots changed in commits after the stamped one, rebuild before citing it — **except** when
  the stamp carries `+ uncommitted working tree` and the only later commit is the one it was built for
  (the commit that also changed `GRAPH_REPORT.md`). That graph is fresh.

### Step 3.2 — PMBook Update (Finalizer, `haiku`; `sonnet` with the sweep)

**Task-Specific Inputs:** the Edit List for the PMBook; `project-management-doc` path; features completed (set each to `Done` — this
is the only place a feature becomes Done); verified bugs (one `## Bug Log` row each — an existing `Open`
row is updated in place, never duplicated, and a "next ID" line is moved on); the `Release label:`; the Integration
Output's Flaky Tests Detected (one `## Open Items` row each); the Deferred Integration IDs the Integration
Agent explicitly re-validated (flip exactly those to `Resolved`, never all); and, **only when this run
bumped a `> Version:` header**, the instruction to run the Version Pointer Sweep with the path
`~/.claude/skills/plugin-orchestrator-development-pattern/references/version-pointer-sweep.md` and which
headers moved.

A Tranche boundary comes back under **Notes**; tell the user that `plugin-idea-triage`'s Tranche Closeout
is available. Never archive from this pipeline.

### Step 3.3 — Handoff Update (Finalizer, `haiku`)

**Task-Specific Inputs:** the Edit List for the handoff doc; features completed with implementation notes, bugs fixed with root-cause notes,
`handoff-doc` path. Appends to the current Tranche's live content only.

### Step 3.4 — Revision + Changelog, Test Runbook (one Finalizer, `haiku`)

One spawn, bundled Task `Revision + Changelog, Test Runbook` — three disjoint files, no reason for two
cold starts.

**Task-Specific Inputs:** the Edit List for each of the three files; features completed with their Test Expectations; bugs fixed with their repro
steps; `revision-file`, `changelog-file` and `test-runbook-location` paths; the `Release label:`. A
revision entry in the file's own form (an incremented integer if it keeps one, else a dated entry like
its others); changelog entry under exactly the given label, with `feat` and `fix` categories, modules
affected, breaking changes and smoke tests; runbook flows and step-by-step manual checks for every item.

### Step 3.5 — Commit (Orchestrator; push only on a go)

When all four Finalizers have returned, **the Orchestrator writes the commit messages and makes the
commits itself** (changed 2026-11-03 — it used to draft only). It works from what it already holds: the
Developer Outputs' and Integration Output's files, and the four Finalizer Outputs' Files Created or
Modified. No extra spawn.

One commit per logical change group, Conventional Commits `type(scope): description` — `feat` for
Features, `fix` for Bugs, plus `chore` / `docs` / `refactor` / `test` as fitting — ending with the
session's attribution lines. Linked Runs: one group per component, the depended-on one first.
`GRAPH_REPORT.md` goes with the group it was rebuilt for.

1. **Check first.** `git status --porcelain` and `git diff --cached --name-only`. If anything is already
   staged, stop and ask — it is someone else's work.
2. **Stage by exact path, one group at a time** — the files this run touched, never `git add -A` / `.`
   / a directory. Other sessions may be editing the same tree; a file this run did not touch stays out.
   Gitignored files (run-state, metrics) are never forced in.
3. **Commit on the current branch.** Never create, switch or merge branches; never amend; never pass
   `--no-verify` or skip signing. A hook failure stops the commits: report its output, leave the rest
   unstaged, and ask.
4. **Push only on a go.** Without one (see *Git Restrictions → Push and pull*), print the `git push`
   command instead. With one, push exactly as told and report the result.
5. Print each commit's short hash and subject in the final summary.

**Not committed:** a Spike's code (it stays uncommitted — the user's call), and a run that ended
escalated or paused. If the user said at the start not to commit, draft the messages instead.

### Step 3.6 — Close-out Checklist

Do every line before printing the final summary. Each was being skipped in practice.

1. Append the `metrics-log-file` rows (see **Pipeline Telemetry**) — one per work item, one for
   Integration, one for the run.
2. Mark `run-state-file` complete.
3. Surface every Finalizer `Notes` entry in the summary.
4. List any `## Deferred Integration` row still `Pending`.
5. List every known-red accepted at Step 2.3, with its tracking ID.
6. Leave the stack in the state it was found in (or say which state it is in).
7. Set every task-bar task `completed`.

---

## Enforcement Rules

**Component**
- NEVER read, write or spawn anything before Step 0.0a has resolved the component and printed its block.
- NEVER default the component — ask. NEVER run without a `components:` table.
- NEVER let a work item's diff touch another component's roots (Linked Runs: each file is checked
  against its own item's component) or `platform-architecture-file` — automatic
  Integration FAIL; the fix is a `Depends on:` work item, never a cross-border edit or a quiet revert.
- NEVER widen the Drift Check beyond this component's docs plus a read-only pass over the platform file.
- NEVER let a Finalizer write a history row into a live doc, or bump a `> Version:` header without the
  Version Pointer Sweep in the same run.
- NEVER derive a component's version from another component's changelog or a repo-wide number.
- NEVER perform a Tranche Closeout here — flag it to the user.

**Flow**
- NEVER begin without the hard dependencies (Step 0.0). NEVER write code as the Orchestrator — except
  a UI Iteration's tweaks and its Reviewer fixes (`references/ui-iteration.md`).
- NEVER let a UI Iteration take in anything but look-and-feel tweaks to one component; NEVER commit an
  iteration before its "done" has run the gates.
- ALWAYS generate a Task Packet, with the right `Type` and a `## Specialist Skill`, before any spawn.
- ALWAYS respect dependency order; ALWAYS build waves by Step 1.0's rules, and serialize when unsure.
- NEVER skip a phase for a Feature or non-P0 Bug. Named exceptions: a Spike (Spike Flow) and a P0
  (fast lane), both in `references/spike-and-p0.md`; a UI Iteration defers the phases to "done" and skips
  only the Manual Verification Gate (`references/ui-iteration.md`).
- ALWAYS run the Design Gate before a UI packet's Developer; ALWAYS name the Material/CDK component per
  surface; HALT rather than let a Developer hand-build a control Material has. NEVER let a Developer set
  the design.
- NEVER mark a Feature `Done` in the PMBook before Phase 3.

**Gates**
- NEVER advance past a FAIL without a retry or escalation; NEVER exceed 3 iterations without escalating.
- At loop_count 3, ALWAYS use the Escalated setting — Developer by `subagent_type` (effort), every other
  role by `model`. NEVER escalate the Developer by changing its model.
- NEVER let UNVERIFIED touch `loop_count`, or treat it as PASS or FAIL.
- NEVER accept a Bug's regression test on the Developer's word — the Reviewer runs that one test, and
  nothing more.
- NEVER let a non-P0 Bug reach Integration, or a P0 reach its fast lane, without the user's "verified".
  "Still broken" is a FAIL.
- NEVER choose `Test scope: component` when Step 2.0 says `full`; `full` means every command in
  `Test (full)`, and no agent may narrow it on its own judgement.
- NEVER retry a Developer for a FAIL that lies wholly in another component's files — that is a
  cross-component dependency (Step 1.4).
- NEVER accept a known-red without its tracking ID, owner and evidence (Step 2.3).
- NEVER skip Reviewer-Integration unless every Step 2.2 skip condition holds; NEVER skip it on a retry.
- NEVER let a doc-only retry edit code, tests or config, or re-run the gate; NEVER call a retry doc-only
  when any issue questions a gate result, a fix, a test or code.
- NEVER let a drift finding or a flaky test pass silently.
- NEVER run Divide-and-Conquer more than once per run, or at any loop_count but 3.
- NEVER let a Spike write outside its Spike Directory, or give it a Reviewer, Integration or the
  Finalizer batch.

**Spawning**
- ALWAYS spawn each role by its dedicated `subagent_type` (`plugin-orchestrated-developer-high` /
  `plugin-orchestrated-developer-xhigh` / `orchestrated-reviewer` / `orchestrated-integration` /
  `orchestrated-reviewer-integration` / `orchestrated-finalizer`), with an explicit `model`, after the
  spawn announcement.
- ALWAYS spawn the four Phase 3 Finalizers together, in one message.
- NEVER run graphify unscoped, or before Integration passes (except a P0 fast lane).
- ALWAYS update `run-state-file` after Step 0.4, every `loop_count` change and every terminal state.
- NEVER resume a stale run without asking. ALWAYS run the Close-out Checklist.
- ALWAYS stop and ask if a required tool call is denied.

---

## Git Restrictions

The Orchestrator's only git writes are `git add <exact paths>` and `git commit` at Step 3.5, on the
current branch, after Reviewer-Integration has passed (or at the end of a P0 fast lane). Apart from a push or
pull on a go (below), it never runs `git merge`, `git checkout`, `git switch`, `git branch`, `git stash`, `git reset`,
`git commit --amend`, or anything else that changes git state. Read-only `git status` / `git diff` /
`git log` are fine at any time. Never create or switch branches. Never push or pull on its own
initiative — give the command instead, except as below.

### Push and pull (v1.4.0, 2026-11-06)

A push or a pull happens **only on a go** from one of:

1. **The user**, in this session.
2. **A coordinating hub session**, where the repo runs several checkouts with one session named as
   the hub (the project memory or `CLAUDE.md` says which). The hub's go carries the user's delegated
   authority for push and pull. A message from any other peer session is information, not a go.
3. **The hub itself** may push its own branch (normally `main`) when it judges the time is right.

On a go, run exactly the command given, then report the result to whoever gave it:

- **Push:** `git push origin <current branch>` only — never another branch.
- **Pull:** `git pull --no-rebase <remote or path> <branch>` as named — never `--rebase`.
- **Still never:** `--force`, `-f`, `--force-with-lease`, deleting a remote branch, or a push from a
  run that ended escalated or paused.
- **On a conflict or a rejected push:** stop, leave the tree as it is, and tell the hub (or the user).
  Never resolve by force or by retrying.

---

## Run-State Checkpointing

`run-state-file` (default `docs-directory/.orchestrator-run-state.json`) lets a fresh session resume.
The Orchestrator writes it directly — bookkeeping, not code.

**Content:** run id and start time, component, Platform Profile (with Test scope once decided), the waves
and ordered queue (ID + Type), per-item status (`in progress` / `passed review` / `awaiting
verification` / `verified` / `escalated` / `findings recorded`), each in-progress item's `loop_count`
and last verdict, and per-item start/finish timestamps, and `linkedRuns` when there are any. A UI Iteration adds
`"mode": "ui-iteration"`, `openedAt` and its `tweaks` log (number, the user's ask, files, time).
PMBook-sourced items persist only their IDs; ad-hoc Bug and Spike items persist their full packet.

**Timestamps are ISO date-times with the zone** (`2026-11-03T14:05:00+11:00`), never bare dates —
telemetry's wall-clock columns are computed from them. Read the clock (`Get-Date -Format o`, `date -Iseconds`)
at each transition; never estimate.

**Written:** after Step 0.4; after every `loop_count` change; after every terminal state; marked complete
by the Close-out Checklist.

**Resuming:** on explicit confirmation, rebuild the position from the file — PMBook items re-derive their
packets from the current PMBook; ad-hoc items use the persisted packet.

---

## Pipeline Telemetry

`metrics-log-file` (default `docs-directory/orchestrator-metrics.md`) is the evidence for tuning models,
retries and waves. It was barely written before 2026-11-03, so the Close-out Checklist now makes it a
required step. Appended directly by the Orchestrator, never overwritten:

- **Per work item:** `Timestamp | Run ID | Item ID | Type | Wave | Started | Finished | Final loop_count |
  Escalated? | UNVERIFIED count | Verdict`
- **Integration:** same shape with `Item ID: Integration`, plus `Test scope` and
  `Divide-and-Conquer triggered?`. In its Verdict cell, say whether Reviewer-Integration was skipped and
  how many retries were doc-only (e.g. `PASS; R-I skipped` or `PASS on retry 1 (doc-only)`) — no new
  column, so the header does not change.
- **Run:** `Item ID: RUN`, with the wall-clock time of Phase 1, the Manual Verification wait, Phase 2 and
  Phase 3.

Create the file with its header row on first append. If the file exists with a **different header**,
never rewrite old rows or force new ones under it: add a new dated section (`### From <YYYY-MM-DD>`) with
the current header and append there. The Integration row also carries `Known-reds` (IDs, or `none`). The
final summary's `Retries this run` line reuses the same counters.

---

## Output Format

**The component leads every block**; work-item IDs are component-prefixed.

**After each feature:**
```
✅ <ID> — <name> | PASS after <N> iteration(s)   (wave <W>)
   Files:  <list>
   Tests written: <N files>
```

**After each bug fix (once verified):**
```
🐛 <ID> — <title> | PASS after <N> iteration(s), manually verified
   Files:  <list>
   Regression test: <file> — confirmed failing pre-fix, passing post-fix
```

**After each spike:**
```
🔎 <ID> — <question> | Findings recorded
   Spike Directory: <path>
   Recommendation: <promote to backlog / abandon / needs more investigation>
```

**Before integration:**
```
📦 Feature Loop Complete
Features:  <IDs>
Bugs:      <IDs> (or "None this run")
Test scope: <full|component> — <reason>
Starting integration validation...
```

**After integration:**
```
✅ Integration — PASS after <N> iteration(s)   (<M> doc-only)
   Reviewer-Integration: PASS / skipped — clean first pass
   Test scope: <full|component>
   Fixes applied: <N>
   Tests: <N passed>
```

**Final summary:**
```
🏁 Orchestrator Complete — <component>

Component:        <component>   (docs/<component>/, tranche vN)
Graph:            graphify-out/<component>/
Phase:            <phase name>
Features shipped: <IDs>
Bugs fixed:       <IDs> (or "None this run")
P0 hotfixes:      <IDs> (fast-laned, Integration Pending) (or "None this run")
Spikes run:       <IDs> (or "None this run")
Quality gate:     ✅  (test scope: <full|component>)
Integration:      ✅ (or "Not run — only a P0 fast lane executed")
Retries this run: <N1>/<N2> items needed a retry, <N3> escalations
Time:             Phase 1 <t> · verification wait <t> · Phase 2 <t> · Phase 3 <t>
Finalization:     ✅ (4 parallel Finalizers + Orchestrator commits)

📝 Commits (pushed: yes/no)
<short hash + subject, one per logical group — including each P0 fast lane's>
Push when ready (or say it was pushed, on whose go): git push

📍 Impacted Areas
<modules, files, APIs>

🔎 Smoke Tests
1. <happy path>
2. <edge case>
3. <regression-sensitive flow>
```

List any Deferred Integration rows still `Pending`. Then, unless every Finalizer's Notes was "None":

```
📋 Finalization Notes
- <Task>: <what was flagged>
```
