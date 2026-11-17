---
name: plugin-orchestrator-development-pattern
description: Multi-agent development orchestrator for a PLUGIN-BASED repository — one whose `.claude/SKILLS.md` declares a `components:` table. Resolves which component the work belongs to, then runs the same Developer→Reviewer→Integration→Finalization pipeline as `orchestrator-development-pattern`, scoped to that component's docs, source roots and knowledge graph. Invoke only when the user explicitly wants the full pipeline run end-to-end (e.g. "orchestrate a fix for X", "run the orchestrator on this bug", "build this from the PMBook", "spike this", "this is a P0", "hotfix this") — not for a plain "debug X" / "fix this" question. A Spike skips the Reviewer/Integration gates; a P0 Bug fast-lanes to its own Finalization. A UI Iteration ("let me iterate on the UI", "tweak mode", or a look-and-feel ask once the skill is in use) runs tweaks ungated, gates once at "done". Language and platform agnostic. For a single-component repo use `orchestrator-development-pattern`.
license: MIT
metadata:
  author: https://github.com/mak100186
  version: "1.20.0"
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
    design-directory,
    design-rows-directory,
    design-rounds-directory,
    findings-directory,
    known-red-baseline,
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

**On a resume** (after a restart, a park or an escalation pause), send the list first, as soon as run-state is read and before you ask or do anything else: one task per item and phase still in the run, terminal ones `completed`, the rejoin point `in_progress`, everything queued (later waves, `heldForNextRun` items, Phase 2/3) `pending`. The user reads where the run stands from it. With nothing unfinished and nothing queued, send nothing.

## Ports: one registry per machine

Every port a checkout listens on (its stack, `artboard-server`, a parity before-side, a test server)
is recorded in `~/.claude/ports.md`, the machine's one list; no repo keeps its own. One row per port:
`| Port | Repo / checkout (folder) | Component | Serves | Since |`. A checkout is its folder: two clones
of one repo are two checkouts.

**Consult it every run, not only on a clash.** At Phase 0 (before the stack check), read it and match
this checkout's rows against the ports its config and run skill actually use. A port counts when
a config, script, launch profile or run skill names it (a reserved debug port too); one named only
as an example in prose does not. Spike code counts while it is in the checkout. Then, by case:

1. **Registered, and the rows match the config:** use them. Nothing else to do.
2. **An existing project not yet registered** (its config already names ports): register each one not
   registered to another checkout, and say so in one line.
3. **A clash** — a port the config names is registered to another checkout (a new clone of an existing
   repo always hits this): the checkout registered first keeps it. This one moves: pick a free offset
   or free ports (not in the registry and not in use: `netstat -ano | findstr :<port>` on Windows,
   `lsof -i :<port>` elsewhere). With an offset mechanism, move every port it moves, together. With
   fixed ports, move only the ports that clash. Apply the move through the repo's own offset mechanism;
   where the tool has none (an Angular `ng serve` port, say), edit the tracked config and every
   file that names the old port (launch profiles, `SKILLS.md`'s `app-url`, `CLAUDE.md`, READMEs,
   runbooks).
   - **Don't ask.** A port the registry shows free, with nothing listening on it, is this checkout's
     to take: that is what the registry is for. Register it at once (no `pending:` mark), make the
     change, then report in one line what moved and which files changed.
   - **Ask only on a real conflict:** no free port fits, an unknown process holds the port you would
     take, or the move is unusual (something outside the repo depends on the old port).
   - **A server already running** on the clashing port keeps running until its next restart; it
     restarts on the new port, never on the old one.
4. **A new project** (no ports chosen yet): choose them from the registry first — free ports, kept clear
   of other checkouts' blocks — register them, then write them into the config.
5. **A port in use that the registry does not list:** add it as `owner unknown — seen <date>`, and
   never take it.

Edit only this checkout's rows; never remove another's (a deleted checkout's rows go with it, by the
user or the session that deletes it). A missing file is created with the header and this checkout's
rows. `app-url`'s offset comes from this checkout's registered ports; if the stack config disagrees,
say so and use the registry's. Never start anything on a port registered to another checkout, even
when it is free right now: that checkout's session may start it at any moment.

## Make targets: one set of names in every repo

Every ADLC repo has the standard `Makefile` (`~/.claude/skills/init-adlc-repo/references/makefile.md`); a repo without one, or missing targets, gets
them from `init-adlc-repo upgrade` (plugin: `plugin-init-adlc-repo upgrade`), on the user's yes.

1. **Phase 0** uses `make status`, then `make up` when the stack is needed and down.
2. **The Integration gate is `make check`** (format check, lint, test, audit) when the target exists;
   add it to the Platform Profile as `Gate: make check` for the Integration Agent Prompt; the Test
   command stays `make test` (the baseline run uses it, and it is narrowed per item). `make test` printing `no test suite` is a gap to report, never a
   pass. When the repo has an `e2e` target (suites that need the running stack), run it after
   `make check`, with the stack up.
3. **`make deploy` and `make rollback` are never run** by the Orchestrator or any sub-agent unless the
   user asks for that deploy or rollback in so many words. Never offer either as a next step; the
   settings `ask` rules prompt for them anyway.
4. Missing targets are reported, not invented mid-run: the fallback is the bound commands in
   `.claude/SKILLS.md`.

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
| `references/resume.md` | A resume is confirmed at Step 0.0's Resume check, or the user types "resume" at an escalation pause — what to read first, where the run rejoins, resuming after an escalation |
| `references/ui-iteration.md` | A UI Iteration is opened (Step 0.1d) or found open on resume |
| `references/ui-packets.md` | A planned packet touches a user interface (Step 0.4) — UI bindings, Design rows hold and Data sources check (Step 0.4), Design Gate (Step 1.1b), Board Parity Check (Step 1.3b) |
| `references/linked-runs.md` | Work items in two components must land together (Step 0.0a), or a FAIL lies in another component's files (Step 1.4) |
| `references/push-and-pull.md` | Before any push or pull — a go arrives from the user or a hub session, or this session is the hub |
| `references/version-pointer-sweep.md` | Never by you — its path is handed to the PMBook Update Finalizer when a `> Version:` header moved |

## Invocation boundary

The pipeline needs an explicit ask — "orchestrate a fix for X", "run the orchestrator on this bug",
"build this from the PMBook", "spike this", "this is a P0", "orchestrate the findings in <file>". A plain "debug X" is a normal debugging
conversation. Spike and P0 likewise need the user to actually say so; never infer them from tone or
severity.

**Sticky per conversation:** once this skill has entered Phase 0 in a conversation, a later plain "debug
X" / "fix X" in the same conversation becomes a new Bug Fix Intake item, and "let's try X" a new Spike
Intake item. A plain look-and-feel ask ("make that button smaller") opens a UI Iteration (Step 0.1d)
instead; it is never a bug. A new conversation starts back at the high bar.

## Key design principles

- **Developers write tests and may run only their packet's `Tests you may run`, never the suite.**
  Several Developers may be working at once against an incomplete codebase; the Integration Agent owns
  test execution and build health.
- **Parallel where it cannot collide, serial where it can.** Independent work items run as waves
  (Step 1.0). Anything sharing a file, a build unit or a root manifest runs one after another.
- **Cold spawns, paths not contents.** Every sub-agent is a fresh single-purpose spawn. Retries spawn
  fresh with the packet, the issues and the previous file list. Docs are passed as paths. After each item
  the Orchestrator keeps only its one-line result; the durable record is on disk.
- **Settled rules decide; ask only where none applies.** Before asking the user or the hub, check what
  is already settled: the board, `decisions.rulings`, a packet's Ruled deviations, the ADRs, the
  project's `CLAUDE.md`, the PMBook (e.g. "follow the board", a naming rule). When one answers the
  question, decide it and name that rule in the item's result line. Ask only where none applies.
- **Spend tokens where they buy quality.** Read a governed doc by the section the step needs, never
  whole. Don't re-read this skill or a reference file mid-run unless it changed on disk. A status
  message to the hub or another session is one line (item, decision, commit hash), not a report.

## Working under a hub

When the repo has `.claude/hub.json` and a live hub session (`hub.sessionName`), this session is a
**worker** driven by the `plugin-orchestrator-hub` skill:

1. **Questions, gates and issues go to the hub**, never to the user in this session. Each question carries
   the default you would pick; keep working on the default (or on other items) while you wait.
2. **Any issue found mid-build** goes to the hub before you raise or take it on. The hub rules it
   functional (an item, ahead of queued features), UI-only (a line in the parity backlog, no item) or
   not recorded.
3. **Before each new group**, send the hub the proposed group plus your open queue, and wait for the go.
4. **Read the rulings log** (`paths.rulingsLog`) before asking; a ruling there is settled.
5. **When committed and gated**, send "ready to merge `<hash>`: `<item IDs>`, `<points>`, green counts
   `<changes>`". Leave the green-count file (`paths.devEnvironment`) out of your commits.
6. **On "safe stop" / account switch**: finish the current gate, commit by path, update the PMBook and
   handoff, send `parked <hash>`, and start nothing new.
7. A file outside your component's roots is asked of the hub, never changed here.

---

## Roles

Each role is a global agent in `~/.claude/agents/`, spawned by its dedicated `subagent_type` — never a
generic agent.

| Agent | Responsibility | `subagent_type` |
|-------|----------------|-----------------|
| **Orchestrator** (this skill) | Resolves component, reads PMBook or intakes a bug/spike, detects platform, builds packets and waves, dispatches, tracks state, commits (pushes/pulls only on a go), escalates | — |
| **Developer** | Implements one work item inside one component, writes tests, runs scoped Format + Lint | `plugin-orchestrated-developer-high` / `plugin-orchestrated-developer-xhigh` |
| **Reviewer** | Gates Developer Output against the packet; on Bug packets also runs the single named regression test | `orchestrated-reviewer` |
| **Integration** | Diff guard, quality gate at the run's Test scope, fixes, audit, E2E, drift check | `orchestrated-integration` |
| **Reviewer-Integration** | Gates the Integration Output; read-only `git diff` on risky fixes | `orchestrated-reviewer-integration` |
| **Finalizer** | One Phase 3 Task (or a named bundle) per spawn; up to four run in parallel. A Spike gets one solo Spike Log Task instead | `orchestrated-finalizer` |

**Before every spawn** print `→ Spawning <Role> agent — <item ID> — model: <model>[, effort: <effort>]`,
and pass `model` explicitly from **Model Assignment**. The agent's own frontmatter model is only its
standalone default.

Every spawn prompt also carries `Temp dir: <absolute path>`: the Orchestrator's own scratchpad, as its environment names it, written out in full. Sub-agents cannot discover it themselves, and one without it has written temp files into the Git install folder. Next to it goes the line `Build output: inside the repo (its gitignored build folders), never the
Temp dir`: a test that finds the repo root by walking up from its own build folder breaks when the
build lands outside the repo.

### Model Assignment

Edit this table to change a model; nothing else needs to change. Values are tier aliases (`opus` /
`sonnet` / `haiku`), which is all the `Agent` tool's `model` parameter accepts.

| Role / Task | Base (loop_count 1–2) | Escalated (loop_count 3) |
|------|-------|-------|
| Developer | `opus`, effort `high` — `plugin-orchestrated-developer-high` | `opus`, effort `xhigh` — `plugin-orchestrated-developer-xhigh` |
| Reviewer | `sonnet` | `opus` |
| Artboard edit (Step 1.1b, and a UI Iteration's "done") — `orchestrated-developer`, Artboard Edit Prompt | `sonnet` | — (no retry loop) |
| Board Parity Check (Step 1.3b) — `orchestrated-reviewer`, Parity Prompt | `sonnet` | `sonnet` |
| Integration | `sonnet` | `opus` |
| Reviewer-Integration | `sonnet` | `opus` |
| Finalizer — Graphify | `haiku` | — (no retry loop) |
| Finalizer — PMBook Update | `haiku`; `sonnet` when it also runs the Version Pointer Sweep | — |
| Finalizer — Handoff Update | `haiku` | — |
| Finalizer — Revision + Changelog, Test Runbook (bundle) | `haiku` | — |
| Finalizer — Spike Log | `sonnet` | — (no retry loop) |

- **The Developer escalates by effort (`subagent_type`), not model.** Still pass `model: "opus"`.
  `xhigh` needs extended thinking on; without it, it runs as `high`.
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
  │                        [PARITY] UI packets: measure built screen vs board → FAIL re-enters the loop
  │                              ▼
  │        Feature → passed (PMBook written at Finalization)
  │        Bug, not P0 → queued for the batched Manual Verification Gate
  │        Bug, P0 → verify now → P0 Fast-Lane Finalization
  ▼
[MANUAL VERIFICATION GATE] all queued Bugs in one message → "verified" / reports a failure → retry loop
  ▼
[INTEGRATION] Test scope decided (component or full) → [INTEGRATION AGENT] diff guard, gate (output to
              log files), fixes, audit, E2E, drift, self-check → [REVIEWER-INTEGRATION, skipped on a
              clean first pass] → retry ≤3 (doc-only retry: no gate re-run) → Divide-and-Conquer → escalate
  ▼
[FINALIZE] parallel Finalizers: Graphify (if code changed) | PMBook (+sweep) | Handoff | Revision+Changelog+Runbook
  ▼
[ORCHESTRATOR] Commits made (pushed only on a go) → Close-out checklist (every run) → [DONE]
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
| 3 | **An unfinished run-state file** | Glob `docs/*/.orchestrator-run-state.json`. **Exactly one** run id with `"complete": false` resolves it and means a resume (Step 0.0's Resume check) — a UI Iteration's file (`mode: ui-iteration`) included; Linked Runs' files share one run id and resume together. A file whose items are all terminal still resolves the component, but Step 0.0 offers its missed close-out, never a resume. |
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
`archive-directory`, `artboards-directory`, `design-rows-directory`, `findings-directory`, `run-state-file`, `metrics-log-file`,
`graphify-directories`, `graphify-out`). Three are shared and never templated: `adr-directory` (one folder; new IDs are
component-prefixed), `platform-architecture-file` (the shell's architecture doc — read-only for every
other component), and `source-code-directory` (the repo root, for platform detection).
**Per-component override:** a component's row in the `components:` table may set any templated binding by name, and that value wins over the `{component}` template for that component only — e.g. `artboards-directory: "./docs/design/artboards/ofa"` on a component whose boards live in another component's folder. Read the row before filling a template. Shared bindings (`adr-directory`, `platform-architecture-file`, `source-code-directory`) are never overridden.

**One component per work item.** Work that spans two is split into one work item per component, linked
by `Depends on:`. Enforced by the Cross-Component Diff Guard. When linked items must land together — one
breaks without the other — run them as **Linked Runs**, not one after the other: read
`references/linked-runs.md` now, before Step 0.0, and follow it through every phase.

### Step 0.0 — Verify Hard Dependencies

**Must exist:** `project-management-doc`, `source-code-directory`, `architecture-doc`. If any is missing,
stop and ask. Ad-hoc Bugs and Spikes need these documents too; they just don't need a pre-existing PMBook
row.

**Soft (created or skipped later):** `handoff-doc`, `changelog-file`, `revision-file`,
`test-runbook-location` (created at Phase 3); `snyk-command` (else the platform default audit);
`adr-directory` (else skip the ADR check and say so); `graphify-directories` (else the component's `code`
roots); `run-state-file` and `metrics-log-file` (auto-created).

**For UI packets:** `app-url`, `artboard-server`, `parity-viewports`, and the optional `parity-command` — checked at Step 0.4 per
`references/ui-packets.md` §UI bindings. `findings-directory` (optional; Step 1.3b's deferred minor gaps
and Step 0.1e): unset → `./docs/{component}/findings`.

**Resume check:** if `run-state-file` exists and is not complete, ask: "Found an incomplete run from
`<timestamp>`, last at `<item>` — resume it, or start fresh?" Never resume silently. On a confirmed resume, read
`references/resume.md` first; it says where the run rejoins.
**Finished, close-out missed:** if every item in that file is terminal (a Feature `passed review`, a Bug `verified`, a Spike `findings recorded`, or `dropped`; a legacy item status `done` from an older run-state file counts as terminal), and no phase or P0 lane is `started`, it is not a run to resume. Ask instead: "Run `<run id>` finished but its close-out never ran — run its close-out now, or mark it complete?" Do that (Step 3.6's close-out lines, or just mark it complete) before this run goes on. **Start fresh never loses an item:** before Step 0.4 replaces the file, name every item in it that is not terminal (`in progress`, `awaiting verification`, `escalated`) with its `parkedAt` folder, and put each into the new run's queue — its packet from `parkedAt`, or re-derived from its PMBook row — unless the user drops it. **Rejoining from a park folder:** the item's packet, latest output, last verdict and `loop_count` come from its `parkedAt` folder (`park.json`), and it rejoins at the gate it was parked at, as `references/resume.md` §Resuming after an escalation says. Also list any `.orchestrator-work/<ID>/` folder that no run-state entry names (a file replaced by an older version of this skill) and offer it the same way.

**Held intakes:** when the old `run-state-file` is complete, or the user chose "start fresh", announce
its `decisions.heldForNextRun` items now and put them into the new run's queue, before Step 0.4
writes the new file — the next-free-ID scan then sees them through the queue. In a UI Iteration
there is no queue: announce them and copy them unchanged into the new file's
`decisions.heldForNextRun`, never mixed into the iteration.

**Deferred Integration check:** if the PMBook has `## Deferred Integration` rows with `Status: Pending`,
hold them for Step 0.4's announcement (or the Bug/Spike intake one-liner). Never blocks.

**Test Cases Doc:** if absent, draft it now from the current phase's features (at least one concrete E2E
or smoke scenario per feature, covering edge cases and regression-sensitive flows), save it, and register
the path. If present, check it covers every feature in scope with concrete scenarios; if it is thin, tell
the user what is missing and ask whether to proceed, have you draft the gaps, or pause. **Do not ask when
writing or extending those test cases is a work item's own job in this run:** note the gap and that item
in run-state's `decisions` (`testCasesDoc`) and go on. A drafted or
extended doc's path is appended to run-state's `orchestratorFiles` once Step 0.4 writes it.

### Step 0.1 — Read the PMBook

Identify the current phase and every feature `Planned` or `In Progress` in it, with acceptance criteria
and dependencies.

**Review-only items.** An item the user says was already built outside the loop joins the run as
**review-only** — never on the Orchestrator's own judgement that its code looks present: its packet carries `Mode: review-only`, and
Step 1.2 writes a Build Record in place of the first Developer spawn. Include any item the user names as
review-only, whatever its PMBook status. Save `mode: review-only` on the item in run-state.

**Sizing** (`~/.claude/skills/idea-triage/references/sizing.md`). Every item the run builds needs a size. Size each `Planned` or `In Progress`
row whose `Size` is blank (no `Size` column yet: add it after `Priority`, `—` on `Done` rows), write
those cells into `project-management-doc` now (the Size cells only, no Version bump, as for a
Status cell), and show every size in Step 0.4's plan. Never change a size already there. **An item
sized 8 is held:** it joins no wave; Step 0.4 shows it with a proposed split, or a spike first,
each part sized. On the user's yes, add the parts as new Feature Backlog rows (next free IDs, sized,
`Depends on:` between them), set the old row's Status to `Split into <IDs>`, and queue the parts
that belong to this phase. Save each item's size in run-state; its metrics row carries it.

### Step 0.1b — Bug Fix Intake (alternate entry point)

1. **No PMBook row needed.** Take from the user: what's broken, how to reproduce, expected vs actual, and
   suspected files if known. Ask for anything missing.
2. **Assign a Bug ID.** If the bug already has a `## Bug Log` row (Status `Open`), use that ID and that
   row's description as the report. Otherwise: if the Bug Log states the next ID (e.g. "The next bug is
   `SHELL-B-005`"), use exactly that; else next after the highest `<COMPONENT>-B-XXX` in `## Bug Log`;
   `<COMPONENT>-B-001` if none. Either way, skip any ID run-state's queue or `heldForNextRun` already holds.
   A grep for IDs also matches the "next ID" line itself — read the table, not the grep. **Size it** (`~/.claude/skills/idea-triage/references/sizing.md`); an open Bug Log row that has a size keeps it.
   Save the size on the item in run-state. An 8 is held as in Step 0.1: propose a spike to find the
   cause, or a split, and wait for the user's yes.
3. **Several bugs at once** are queued in the order given. Step 1.0 decides which can share a wave.
4. **A design mismatch on a built screen** (the screen differs from its board): find the work item that
   built that surface (the PMBook or `git log` on its files) and note it now; record its `Mismatch` row
   per **Pipeline Telemetry**. Carry on with this intake: the mismatch is fixed as this Bug.
5. **P0** only when the user actually says "P0", "hotfix", "prod is down" or equivalent → set
   `## Priority: P0` and read `references/spike-and-p0.md`.
6. Go to Step 0.2. Steps 0.2–0.4 all run; the only difference is the announcement, which is one line
   in place of Step 0.4's block: `Bug Fix Mode — <COMPONENT>-B-XXX (<size> pts): <description>` (or
   `Bug Fix Mode [P0] — …`), then the `⚠ Deferred Integration outstanding` line if Step 0.0 found any.
   Step 0.4 still writes `run-state-file`.
7. **Mid-run intake** (a new bug or spike while a run is open): same run id and `run-state-file` — skip
   Step 0.4's run-id fix and run-state write — and append the item to the queue for the next wave. If
   Phase 2 has already started, save its full packet in run-state's `decisions.heldForNextRun` (its ID
   counts in the next-free-ID scan); announce it at resume and at close-out; the next run's Step 0.0
   puts it into that run's queue.

### Step 0.1c — Spike Intake (alternate entry point)

Only on an explicit ask. Read `references/spike-and-p0.md` and follow its Spike Intake.

### Step 0.1d — UI Iteration (alternate entry point)

On an explicit ask, or a look-and-feel ask while the skill is sticky (see **Invocation boundary**). Read
`references/ui-iteration.md` and follow it.

### Step 0.1e — Findings Intake (alternate entry point)

On an explicit ask to fold in a findings file (from `disparity-checker`, or Phase 3's deferred minor
gaps): "orchestrate the findings in <file>", "log the disparity findings". Read
`~/.claude/skills/disparity-checker/references/findings-intake.md` and follow it: each finding becomes
a Bug Log row (or a design row, or an Open Items row), the file is marked consumed, and the Bugs the
user picks are fixed in this run as Bug Fix Intake items.

### Step 0.2 — Detect Platform and Test Commands

Probe `source-code-directory` for markers and set the **Platform Profile**, injected into every packet.

| Marker | Platform | Format (scoped) | Lint (scoped) | Test (full) | Security audit |
|--------|----------|--------|------|------|----------------|
| `package.json` | Node / TypeScript | `npx prettier --write <files>` | `npx eslint <files>` (or `npm run lint`) | `npm test` | `npm audit` |
| `pyproject.toml` / `requirements.txt` | Python | `ruff format <files>` | `ruff check <files>` | `pytest` | `snyk-command` |
| `go.mod` | Go | `gofmt -w <files>` | `golangci-lint run <pkgs>` | `go test ./...` | `govulncheck ./...` |
| `Cargo.toml` | Rust | `cargo fmt` | `cargo clippy` | `cargo test` | `cargo audit` |
| `*.csproj` / `*.sln` | .NET | fix: `dotnet format <project> --include <files>` · gate: `dotnet format <project> --verify-no-changes --include <files>` | `dotnet build <project>` | `dotnet test` | `dotnet list package --vulnerable` |

No marker, or several platforms with no clear primary → ask. `snyk-command` overrides the audit.

**Format is scoped to the item's changed files, never repo-wide.** A repo-wide format rewrites files the
item never touched (line endings, old style drift) and drags them into its diff. Where the tool has a
check mode, the gate is that mode — it fails on unformatted code, where a plain format run never fails:
.NET `--verify-no-changes`, as in the table; for the others, `prettier --check`, `ruff format --check`,
`gofmt -l`, `cargo fmt --check`. The Developer runs the fix form, then the gate form.

**A scoped test command must actually scope.** Before putting one in a packet, check it once with a list-only run (Jest `--listTests`, `dotnet test --list-tests`). Through Nx, the runner's flags go after `--`: `npx nx test <project> -- --testPathPattern=<pattern>`; without the `--`, Nx runs the whole project. Quote a pattern that holds `|`, `(` or `\` (`--testPathPattern="(a|b)\.spec\.ts"`), or pass plain file paths; unquoted, the shell mangles it and the whole suite runs.

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
**The first `up` may be slow** (a cold build cache, e.g. a federated front end's first build): wait
longer on the first start, and if it times out, retry it once before calling the stack failed.

### Step 0.3 — Detect Coding Conventions

Scan for `.editorconfig`, `.prettierrc`, `[tool.ruff]`, `.eslintrc`, `golangci.yml` and similar;
summarise them for every packet, and save the summary in run-state (a resume uses it for re-derived
packets).

### Step 0.3b — Choose the Specialist Skill

Pick, once, the installed specialist skill matching the component's stack (e.g. `angular-architect`,
`csharp-developer`; check the available-skills listing, never guess a name). A component with a frontend
and a backend may name two. Write it into every packet's `## Specialist Skill`, and into the Integration
and Reviewer-Integration prompts. Sub-agents use exactly what is named and skip their own search.
`None` is a valid answer.

### Step 0.4 — Plan Waves and Announce

If a planned item changes what a user sees and `artboards-directory` is set, first follow
`references/ui-packets.md` §Design rows hold, then §Data sources check: a held item is in no wave. Then build the waves (Step 1.0),
and print:

```
🎯 Orchestrator Initialized — <component>

Platform:  <detected platform>
Phase:     <current phase>
Specialist skill: <name(s) or None>
Work items (<N>), in waves:
  Wave 1: <ID> — <name> (<pts>) | <ID> — <name> (<pts>)
  Wave 2: <ID> — <name> (<pts>)   (depends on <ID>; shares <file/build unit> with <ID>)
  ...
Held for design: <ID> — waits on <row IDs> (round <NNN>, open | sent <date>)   (or omit)
Too big (8):     <ID> — proposed: <part> (<pts>) + <part> (<pts>) | spike first — waits for your yes   (or omit)

Developer Quality Gate (per item):  Format: <command>  Lint: <command>
Integration Quality Gate:           Test (full): <command>  Test (component): <command or none>
                                    Audit: <command>

Estimated spawns: best <B> · typical ~<T> · worst <W>
  By tier: Opus ~<x> (every Developer) · Sonnet ~<y> · Haiku ~<z>

⚠ Deferred Integration outstanding (<N>): <IDs> — hotfixed without a full-suite run. (only if found)

Type STOP at any time to pause the orchestrator.
```

**Estimated spawns:** N items (a review-only item counts 1, a Reviewer only, in Best). Best = N × 2 (Developer + Reviewer) + 1 (Integration; Reviewer-Integration
is skipped on a clean first pass, Step 2.2) + 4 (Finalizers), plus one Design Gate spawn per UI item whose artboard needs an edit. Typical = Best ×
1.3, or the observed retry rate from `metrics-log-file` if it has rows. Worst = N × 8 (+ Design Gate
spawns) + 2 × 4 (Integration) + 4 (Finalizers), plus Divide-and-Conquer.

**A planned packet touches a user interface** → read `references/ui-packets.md` now, and check its UI
bindings before Phase 1.

Fix the run id (see **Run-State Checkpointing**); the **gate log directory** is
`<work dir>/gate-logs/<run id>/`. **The work dir** is `<folder of run-state-file>/.orchestrator-work/` — gitignored beside run-state, and it survives a session restart, which the scratchpad does not. Every file the run must keep goes under it: `runs/<run id>/` (packets, Developer Outputs, Integration Outputs), `gate-logs/<run id>/` (gate and Integration logs, raw before/after outputs) and `parity/<run id>/` (Parity Check folders), beside the `<ID>/` park folders. The scratchpad is only for throwaway files, such as a before-side worktree.
Write `run-state-file` now (held intakes: Step 0.0). A mid-run intake
skips both (Step 0.1b, item 7).

### Step 0.4b — Baseline Test Run

Before any spawn, run the tests once on the untouched tree, so a test that was already red is never
mistaken for this run's regression. Bring the stack to the state the tests need (Step 0.2's `Stack`
line). Run `Test (component)` — or `Test (full)` when the component is the shell or `Test (component)` is
`none` — writing the output to the gate log directory, not into context. Save every failing or flaky test
in run-state as `baseline.reds` (the test, how it failed, the command that ran it), and print
`Baseline: <N> red at start (<command>)`. Step 2.0 may later choose `full` after a component baseline:
then reds outside the component were not measured — say so in the Integration prompt.

**Skip it** for a P0-only or Spike-only run, a UI Iteration, and a mid-run intake (the run's baseline
already exists), and print `Baseline: skipped — <why>`. **A resume reuses the saved `baseline.reds`,
never re-runs it** (`references/resume.md`): the tree now holds this run's changes, so a fresh run would
count them as baseline.

**An item whose code is already in the tree** (a carried-over or rejoined item, e.g. from `parkedAt`):
reuse its old run's saved baseline when there is one. Otherwise, if that code is committed, take the
baseline in a temporary `git worktree` of the last commit before it (removed afterwards); if it is not
committed, run on the tree as it is and print `Baseline: includes <ID>'s uncommitted change`. Never
stash, reset or check out over the user's tree to get a baseline.

**A suite that needs the running stack** (business or e2e tests) and can't be brought up for the
baseline may take the repo's documented baseline (root `CLAUDE.md`'s figure) instead: print
`Baseline: <suite> — documented figure from <file>, not run`. Every other suite runs fresh.

A baseline red is not this run's regression, but it is not waved through either: it still follows the
known-red rule (Step 2.2 — an owner, and a tracking ID or the user's acceptance) and is listed in the
final summary. A baseline red that ends the run green is noted as fixed.

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

When in doubt, serialize — a collision costs more than the time saved. Spikes always pass rules 2–4
(their Spike Directory is disjoint by construction), but a Spike counts toward rule 5's limit of 3 like
any other item: it is a Developer spawn in flight.

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

**`Tests you may run:`** — set it in `## Note on Tests` only when the item is **alone in its wave**: the
filter that runs just the item's own new or changed test classes (e.g. `dotnet test <proj> --filter
FullyQualifiedName~<Class>`). It lets the Developer catch its own wrong expectations before review. In a
wave of two or more, write `None` — parallel test runs lock each other's build output. The Reviewer still
runs the tests itself either way.

Save it to `<work dir>/runs/<run id>/packet-<ID>.md` — the path the Reviewer and Parity prompts take.
Re-save it whenever you add to it (e.g. the Design Reference at Step 1.1b), and keep the full packet in
`run-state-file` (see **Run-State Checkpointing**).

### Step 1.1b — Design Gate (UI-touching packets only)

Packet touches a user interface → follow `references/ui-packets.md` §Design Gate now (read it first if
you have not), **before spawning the Developer**. Skip for packets that touch no user interface.

### Step 1.2 — Invoke Developer Agent

`subagent_type: "plugin-orchestrated-developer-high"`, its `model` from **Model Assignment**, Developer Agent Prompt with the
full packet. At loop_count 3, `plugin-orchestrated-developer-xhigh` instead — that swap is the
escalation.

Returns a **Developer Output**: files touched, implementation summary, test files written (not run,
except the packet's `Tests you may run:` filter when set), Format and Lint PASS, assumptions and deviations.

**Review-only item** (`Mode: review-only`, Step 0.1): spawn no Developer. Write a **Build Record** in the
Developer Output's shape — `Source: built outside the loop`, the files (from `git diff` / `git status`
against the item, or the user's list), a one-paragraph summary of what the code does, and `Format/Lint:
not run by a Developer` — and save it where the Developer Output would go (`devout-<ID>.md`). Go to
Step 1.3: the Reviewer reviews it like any Developer Output.

**Save it verbatim** to `<work dir>/runs/<run id>/devout-<ID>[-legN][-retryN].md` before anything else (`-legN` from the
second leg on — a resume after escalation starts a new leg; the same suffix goes on every per-loop
work-dir name, e.g. the parity folder). The
Reviewer gets that path, never a summary. Combine a resumed spawn's hand-backs into the same file.

**An open question inside the packet's scope.** If the Developer Output asks the Orchestrator to decide
something the packet left open but did not put out of scope (e.g. a check whose subject is gone and
that the packet did not name as retired), decide it — a ruling that changes scope or a product decision
goes to the user — and **resume the same Developer spawn** (`SendMessage` to its ID) with the ruling.
No cold retry, no `loop_count` change. Pass the ruling to the Reviewer as binding.

**A gap in a shared test another component owns** (e.g. `business-tests/layout`, owned by the shell):
never widen it from this item's branch. It is an outside item, `owner: <component>`; Phase 3 logs it
as a new item in the owning component's PMBook, and this item records `Depends on: <that ID>`
(`references/linked-runs.md`). The one exception is upkeep the shared test's own README lets any
component do (e.g. removing a stale KNOWN entry once its fix lands).

**A design ruling.** If the question is a difference from the board (the Developer's Assumptions say
the board cannot be built as drawn, e.g. no Material slot for it), rule on it — the user rules when it
changes what the user sees beyond the board's intent. A ruling that accepts the difference becomes a
`Ruled deviations` line in the packet's `## Design Reference`, with its source (`hub ruling, <date>` or
`user ruling, <date>`). Before the Reviewer spawn: **re-save the packet file** with that line, save the
full packet in `run-state-file`, and save the ruling in run-state's `decisions.rulings` (item, the
difference, the ruling, its source). The Reviewer and the Parity Check then read it from the packet.
Resume the Developer only when the ruling needs a code change; otherwise go straight to Step 1.3.
When an outside designer owns the boards and the ruling leaves the board wrong (it now draws something
the product will not have), the board change is owed: add it to `decisions.designRowsOwed` (item, surface,
the change, the ruling's source) — Phase 3's **Design rows owed** writes it.

**`Type: Spike`** → Spike Flow in `references/spike-and-p0.md`, not Step 1.3.

### Step 1.3 — Invoke Reviewer Agent

`subagent_type: "orchestrated-reviewer"`, its `model` from **Model Assignment**, Reviewer Agent Prompt with the packet path and
the path of the verbatim Developer Output file (Step 1.2), plus any Orchestrator ruling. Returns `PASS`, `FAIL` (numbered, actionable issues tied to criteria) or `UNVERIFIED`
(what couldn't be checked and why).

**Outside this item.** The Reviewer lists real defects it found outside the packet's scope under
`Outside this item` (e.g. a config value too long for its field, in code the item did not touch). They
are not part of the verdict and no retry fixes them. Check each is really outside — one in a file the
item changed is an issue of this item — then save the rest in the item's `outsideItem` list in run-state
(merged across reviews, one entry per file + defect). Phase 3 offers to log them before its Finalizers
run (**Outside items — asked before the Finalizers**); the final summary lists what was logged or declined.

### Step 1.3b — Board Parity Check (UI packets only)

After the code Reviewer's PASS on a packet with a `## Design Reference` → follow
`references/ui-packets.md` §Board Parity Check now (read it first if you have not, and check its UI
bindings), before the Manual Verification Gate and Integration.

### Handling an UNVERIFIED Verdict

Applies to every Reviewer and Reviewer-Integration spawn. UNVERIFIED is not the Developer's fault, so it
never touches `loop_count`:

```
unverified_count = 0                      # consecutive, for this verdict only
WHILE verdict == UNVERIFIED:
  unverified_count += 1
  unverifiedTotal  += 1                   # per item, in run-state; reset per Pipeline Telemetry
  IF unverified_count > 2 → escalate "Verification Blocked" (references/escalation.md), pause
  Fix whatever the Unable to Verify report points at that you can fix (e.g. a wrong path in the packet);
  otherwise respawn unchanged — same inputs, same model.
```

**A spawn that returns no Output.** Any spawn (Developer, Reviewer, Parity, Integration,
Reviewer-Integration, Finalizer) that ends without an Output in its role's template — or says it could
not hand back — is not a verdict. Send it one `SendMessage` asking for the Output in its template. If none
comes, respawn the same role with the same inputs and model. It never touches `loop_count`; it counts
toward `unverified_count` and `unverifiedTotal` as an UNVERIFIED does. Two missing Outputs in a row from
the same step → escalate "Verification Blocked" (`references/escalation.md`).

### Step 1.4 — Review Loop

```
WHILE verdict == FAIL:
  Apply the three rules below first. A free FAIL (rule 1, 3) skips the escalation check and the
  increment; a FAIL with every issue overruled (rule 2) leaves the loop as PASS by ruling.

  IF loop_count == 3 → escalate (references/escalation.md), pause until "resume"
                       # the FAIL that takes loop_count past 3; loop_count is recorded as 3
  loop_count += 1

  developer_agent = (loop_count == 3) ? "plugin-orchestrated-developer-xhigh"
                                      : "plugin-orchestrated-developer-high"     # model: Model Assignment
  reviewer_model  = (loop_count == 3) ? Escalated : Base                       # Model Assignment

  Spawn Developer: original packet + issues list ("Reviewer Issues") + previous Files Created or
    Modified ("Previous Attempt"). Fix only the listed issues.
  Spawn Reviewer: packet + new Developer Output + loop_count + previous issues ("Retry Context").
```

Three rules may change what a FAIL costs; the loop applies them before its escalation check. Each is
saved in run-state before the spawn it affects.

1. **Review-only item's first FAIL.** The FAIL on a Build Record (Step 1.2) is no Developer's failure:
   it does **not** increment `loop_count`. The first Developer spawn uses the normal Developer prompt —
   not the retry shape: no `Previous Attempt` — with the Reviewer's issues as `## Review Findings to Fix`.
   The Developer then has the full three attempts.
2. **Overrule a weak issue.** The Orchestrator may rule one Reviewer issue **not an issue**, with a
   written reason anyone can check (e.g. "the same account number appears in 8 existing test files"),
   **only when the issue cites no acceptance criterion, constraint, convention, failing test or failing
   gate**. Never overrule a failing test, a failing gate, or a Parity mismatch (those take a `Ruled
   deviations` line, Step 1.2). Save it in `decisions.rulings` (item, issue, reason) and list it on the
   final summary's `Overruled:` line. If every issue in a FAIL is overruled, the item goes on as PASS —
   printed `PASS by ruling` — with no `loop_count` change. Otherwise only the remaining issues go to the
   retry. In doubt, do not overrule; a product question goes to the user.
3. **The Reviewer's own miss.** An issue raised in review N+1 about code the Developer did not change
   since review N — one the Reviewer could have raised the first time — must still be fixed, but the
   retry it alone causes does **not** increment `loop_count`. At most once per item (`reviewerMissRetry: used`
   in run-state); a second such retry counts as usual. If the FAIL also has issues on changed code, it
   counts as usual.

**FAIL — cross-component dependency.** Any FAIL issue tagged `[cross-component: …]` or lying in another
component's roots (a file outside every component's roots is not this route: it is a deviation the
Reviewer checks against the Developer Output's justification) → before retrying, read `references/linked-runs.md` and follow its cross-component
FAIL section.

On `PASS`: **a UI packet's code PASS is not the item's PASS** — run Step 1.3b first. A Parity FAIL
re-enters this loop with its mismatches as the issues list (`loop_count` goes up as for any FAIL); the
retry goes to the code Reviewer, then Step 1.3b again. In that Reviewer's Previous Issues, mark each
parity mismatch `verified by Step 1.3b, not by you`: the code Reviewer checks only its own earlier
issues, and Step 1.3b re-measures the mismatches. Only a Parity PASS, or a packet with no
`## Design Reference`, goes on below.

- **Feature:** record it as passed in `run-state-file` and print the ✅ block (**Output Format**). **Do not write the PMBook now** — the PMBook Update
  Finalizer sets `Done` at Phase 3, after Integration has passed. A feature is not Done until then.
- **Bug, not P0:** queue it for the Manual Verification Gate (Step 1.5) and move on.
- **Bug, P0:** run Step 1.5 for this bug immediately, then the fast lane in
  `references/spike-and-p0.md`. The rest of its wave keeps running meanwhile. One PMBook writer at a
  time: a P0 lane's Finalizers and a Spike Log Finalizer never overlap (`references/spike-and-p0.md`).

### Step 1.5 — Manual Verification Gate (Bug packets only)

**Batched.** Once every item in the run has passed Review (or escalated), post **one** message covering
every queued Bug, so the user tests them in one sitting and the loop never sits idle waiting on a single
check. A P0 is the exception: it is verified on its own, straight after each Reviewer PASS (a "still
broken" retry included).

```
🔍 Manual Verification Required — <N> bug fix(es)

Each regression test was run by the Reviewer and passes. Before these count as fixed, please check them:

B-XXX <title>
  Steps:    1. <from the Bug Report>  2. ...
  Expected: <from the Bug Report>
  Parity (UI bugs only): what was compared, before you look —
    <the Step 1.3b Parity Table: State | Width | Element | Board | Built | Match | Ruling>
    Screenshots: <parity folder path>

B-YYY <title>
  ...

Reply per bug: "verified", or describe what's still wrong.
```

**When the user has waived manual checks** for a period (in their own words: in this session, or
quoted with its date by the hub they named), save it in run-state's `decisions.mvWaiver` (the user's
words, from, until, and the delegate who approves: the hub session or a person the user named). Until
it ends, a non-P0 Bug skips the pause: send the delegate the gate block above as one message, and it
approves on Reviewer PASS plus Board Parity PASS (a non-UI bug needs only the Reviewer PASS). Save the
item's `verification` as `waived by <user> <date>; approved by <who> on <evidence>` (evidence: the
Reviewer's regression-test run, the parity folder); it reaches the Bug Log row as measurements do. A P0
is never waived. An ended waiver, or a delegate who reports a failure, puts the bug back on this gate.

**PAUSE** until the user answers (or, under a waiver, the delegate). Then, per bug:
- **A question** (not a report) → answer it and ask again. It is not a rejection.
- **A new bug** (a different problem, not this fix failing) → a mid-run intake (Step 0.1b, item 7), not
  a rejection of this bug.
- **`verified`** → print the 🐛 block (**Output Format**); it joins Integration. (A P0 goes to its fast lane instead.)
  A `verified` reply may carry **measurements** (a timing, a hash, a before/after count): save them
  verbatim in run-state as the item's `verification`, and pass them to the Finalizers as the bug's
  `Verified with: <measurements>` line — the PMBook Finalizer puts it in the Bug Log row, the Test Runbook
  Finalizer in the bug's verification record.
  **Measuring the "before" side** (when the user asks for a before/after check, or offers to run one):
  1. **Pick the parent** — the commit just before this item's change, never a guess. Uncommitted change:
     `HEAD` is the before. Committed: the item's first commit's first parent (`<first commit>^1`). Merged:
     the merge's first parent (`<merge>^1`, the main line before it), never `^2`. Check it with
     `git show --stat <parent>`, `git log -1 <parent>` and `git diff <parent> HEAD -- <item files>`: the item's
     files must differ there, and only as the item changed them. Say which commit you picked and why.
  2. **Build it aside:** `git worktree add --detach <scratchpad>/before-<ID> <parent>`. Never check out, stash
     or reset the user's tree.
  3. **One side at a time on a port**, or the before side on its own port offset. Stop the after side before
     starting the before side on the same port, and restore the after side when done.
  4. **Same inputs on both sides.** Pin anything the result depends on — a date, a month, a seed, a data
     snapshot — and record it with the numbers. Save both raw outputs in the gate log folder.
  5. **Clean up:** `git worktree remove <scratchpad>/before-<ID>`. Hand the user both results, the parent
     commit and the pinned inputs; their `verified` reply carries them as above.
- **Still broken** (only a reply that reports a failure, or says it is not fixed) → back into Step 1.4's loop with the user's description as the issues list;
  `loop_count` increments, same 3-strike rule. Rejected bugs can run as a wave. Re-post the gate for just
  those bugs when they pass Review again.

Integration does not start until every non-P0 Bug in the run is verified or escalated.

---

## Phase 2 — Integration

Entered when every Feature has passed Review, every non-P0 Bug is verified, **and** every P0 is
verified with its fast lane (Finalizers, and its commit if any) finished — wait for an open lane. An
item with status `dropped` (the user's explicit "drop" or "defer") is left out of this rule and of
Phases 2–3 entirely; a run whose Features and non-P0 Bugs are all dropped has none, below. A P0
is never one of Phase 2's work items: its Deferred row is `Pending` by now, so Step 2.1 passes it as a
Deferred ID. Spikes never reach Phase 2. **If the run has no Feature and no non-P0 Bug
(only Spikes and fast-laned P0s), it skips Phases 2 and 3** and goes straight to Step 3.6's close-out.

### Step 2.0 — Decide the Test Scope

Decide from **the run's own file set** — the same set the Diff Guard reads: every item's run-state
`files` (every attempt; a UI Iteration's file set), the Pending Deferred IDs' files, and on a later pass
the `integration` block's `files`. Ignore paths under `docs-directory` and `graphify-out` (docs don't
change test outcomes). Then:

- **`full`** if any of these is true: the component is the **shell** (every plugin builds against it);
  any path in the run's file set lies outside this component's `code` roots (root manifest, lockfile,
  shared `libs/`, CI config); `Test (component)` is `none`; a `## Deferred Integration` row is being
  re-validated; or the user asked for a full run.

- **`component`** otherwise — use `Test (component)` from Step 0.2, plus this component's scenarios in
  `test-cases-doc`, plus any contract or conformance tests `platform-architecture-file` names.

**`git status --porcelain` is only a cross-check.** A path changed in the tree but in no file set of
this run belongs to another session or the user: list it as **foreign** (`<path> — foreign (another
session or the user)`) in run-state's `foreignPaths`, in the Integration prompt's `## Foreign Paths`
section, and in the final summary. A foreign path never forces `full`, and the Integration Agent neither
fixes nor reverts it.

This does not weaken the gate: the Cross-Component Diff Guard proves no other component's code changed,
and every change that could reach another component forces `full`. Write the result into the Platform
Profile as `Test scope: <full|component> — <command> — <reason>`, and print it.

### Step 2.1 — Invoke Integration Agent

`subagent_type: "orchestrated-integration"`, its `model` from **Model Assignment**, Integration Agent Prompt, passing the
Platform Profile with its Test scope line, the specialist skill, the component and its roots, completed
features and verified non-P0 bugs with their files (run-state `files`, every attempt; a fast-laned P0
comes only as a Deferred ID), and
per item each file outside every component's roots with its Developer Output's justification (a UI
Iteration: the one-line justification step 6 or 9 recorded; its file set, `references/ui-iteration.md`
step 3), the full
`components:` table from `.claude/SKILLS.md` (every component → its `code` roots — for the Diff Guard and
a failing file's owner), and the **paths** (never the contents) of `test-cases-doc`,
`architecture-doc`, `platform-architecture-file`, `project-management-doc`, `test-runbook-location` and
`adr-directory` — each "None provided" when absent — plus the Pending Deferred Integration IDs,
re-read from the PMBook's `## Deferred Integration` rows now (this run's fast-laned P0s are among
them), each with its files changed and commit ids — for this run's P0s, files from run-state (the
Bug's `files` plus its lane Finalizers' files) and commit ids from
`git log --grep "Run-Id: <run id>"` only when they exist (the lane may not have committed); for an
earlier run's ID, both from `git log --grep "<ID>" --name-only` (an older commit may lack the
`Run-Id:` trailer; the ID in its message is enough) — stated as
"these count as this run's changes" for known-red evidence, the
gate log directory (Step 0.4), `## Accepted Known-Reds` from the run's ruled list (Step 2.2; `None`
on a first pass), and `## Known Reds at Baseline` from run-state's `baseline.reds` (Step 0.4b; with the
command that ran, or `Baseline: skipped — <why>`), and `## Foreign Paths` from Step 2.0 (or `None`). Pass the same sections on every Integration retry
(resumed or fresh), to every Divide-and-Conquer spawn, and to Reviewer-Integration.

**Before spawning, snapshot the tree:** save `git status --porcelain` and `git diff --stat` (Step 2.2
compares against them) in run-state when Phase 2 starts. An Integration step re-run after a crash
reuses that saved snapshot; it never takes a new one.

The Integration Agent returns an **Integration Output** with the gate log paths. A **Cross-Component Diff Guard** FAIL
(`Overall Status: FAIL`, no gate run) is fixed by a `Depends on:` work item in the owning component,
never a cross-border edit or a quiet revert: the Orchestrator takes it as Step 1.4's cross-component FAIL
(`references/linked-runs.md`): no Integration retry, no `loop_count` change; with the user's OK the
files go to a linked item in the owning component, and Step 2.1 re-runs once that item passes Review.

**Save each Integration Output to a file, verbatim.** As soon as an Integration spawn returns, write
its final reply — exactly as returned, never a summary or an excerpt — to
`<work dir>/runs/<run id>/integration-output-pass<N>.md`. N counts Integration passes from 1: the
first pass, each retry, a crash re-run, a resume, Divide-and-Conquer's aggregate pass. A
Divide-and-Conquer sub-problem spawn K writes `integration-output-pass<N>-sub<K>.md`, N being the
aggregate pass it feeds. Append the path to run-state's `integration.outputPaths` (in order; the latest
Output is the last entry without `-sub`) and save run-state. Reviewer-Integration and an Integration
retry's Retry Context get that path, never a summary. The only edit ever made to the file is Step 2.2's
rewrite of an `— untracked` known-red line, made in the file as well as in the Output you hold. A
background spawn's task output file is a transcript of the whole spawn, not its Output: write the
agent's final reply, and never pass or cite the transcript. If the task output file reads empty, save the final reply from the completion notification verbatim instead; never re-spawn the agent to get it again.

### Step 2.2 — Invoke Reviewer-Integration Agent (skipped on a clean first pass)

**Documented baseline.** A repo may document failures it already lives with: the file the
`known-red-baseline` binding names, or else a known-red or baseline section in the root `CLAUDE.md`.
Read it before the first Integration spawn. Each test or audit finding it names is already ruled — the
user accepted it by writing it down — so it goes straight into the run's accepted known-red list as
`- <test or finding> — accepted by the user (baseline: <file>)`, and into run-state's
`decisions.acceptedKnownReds`, and the first `## Accepted Known-Reds` section already carries it. Such a
line never pauses the run. A failure the baseline does not name is ruled as below; the owner is still the Integration Agent's.

**Untracked known-reds first.** If any `### Known-Reds` line in the Integration Output ends
`— untracked`, pause before this step — and before every Reviewer-Integration spawn, including a
retry's and Divide-and-Conquer's — and ask the user, per test: raise a tracking item, or accept it?
Save each ruling in run-state's `decisions` (a raised one with its assigned ID) before any PMBook write.
A raised item is written into the owning component's PMBook `## Open Items` now, before any
Reviewer-Integration spawn, with ID `<COMPONENT>-OI-NNN` (the next free number in that PMBook) at the
start of the row's Item cell — or reuses an Open Items row already naming that test — and that PMBook's
path is appended to run-state's `orchestratorFiles`. Rewrite that line in the Output you hold as `— tracked by <new ID>` or
`— accepted by the user` (in the saved Output file too), and keep every ruled line as the run's **accepted known-red list** (in
`run-state-file`) — the `## Accepted Known-Reds` section passed to every later Integration and
Reviewer-Integration spawn. Never send Reviewer-Integration an `untracked` line.

Reviewer-Integration exists to catch a gamed fix and a dropped finding. When Integration fixed nothing,
there is no fix to have gamed, and the Self-Check covers the findings — so the Orchestrator checks the
pass itself and spawns no reviewer.

**Skip it only when every one of these holds** (all mechanical, all from what the Orchestrator holds or
can read in seconds):

1. It is the first pass (`loop_count` 0, not a resume after escalation, and not a pass re-run after a
   crash), and the Integration Output's Overall Status is `PASS`.
2. `Fixes Applied` is `None`, and the tree matches the Step 2.1 snapshot: `git status --porcelain` and
   `git diff --stat` are unchanged (apart from a tracking item you raised at the pause above). Any file
   the agent changed, even a doc, means a spawn. Drift handed to a Finalizer (`— handed to <Finalizer>`,
   the test cases doc's always) is not a fix: it does not block the skip.
3. The gate ran in this pass at the Test scope that was set (not narrowed, nothing carried forward), the
   counts in the Tests line match each gate log's summary line, and every failure in the log is listed
   under `Known-Reds` or `Flaky Tests Detected`.
4. Every Self-Check line is ticked, and `Flaky Tests Detected` and `Unresolvable Issues` are `None`
   (apart from a recorded E2E skip for a missing test-cases doc).
5. Each known-red, if any, passes a quick look: a `tracked by <ID>` starts the Item cell of an `## Open Items`
   row in the owning component's live PMBook, still open, an `accepted by the user` is on the accepted list, a ruled test's status matches
   its `## Accepted Known-Reds` line, and the failing file's path lies under the owner the agent named
   (its own field — the ruled line carries only the status).
6. `Work Items Covered` names every Feature and Bug you passed as this run's, each `PASS`, and no
   Deferred Integration ID (those appear only under `Deferred Integration Re-Validated`).

Then record the skip in run-state as this step's verdict, print `Reviewer-Integration: skipped — clean
first pass, no fixes, tree unchanged` and go to Phase 3.
If any condition fails, or you are unsure, spawn it.

**Otherwise spawn it:** `subagent_type: "orchestrated-reviewer-integration"`, its `model` from **Model Assignment**, with the
Integration Output's file path (Step 2.1), the condensed packets of only the Features and Bugs passed as this run's at Step
2.1 (never a P0's: it is a Deferred ID), the Test scope line, the doc paths that were given to the
Integration Agent, the gate log directory, the accepted known-red list with the owning component's
PMBook path for each `tracked by` line, `## Known Reds at Baseline` and `## Foreign Paths` (as given to Integration), and `## Deferred Integration` —
the entries given at Step 2.1, or `None`. Returns `PASS` / `FAIL` /
`UNVERIFIED` (UNVERIFIED handled as in Phase 1).

### Step 2.3 — Integration Loop

Same as Step 1.4: loop_count 1–2 at base models, loop_count 3 at the Escalated Model (**Model
Assignment**). On a retry the Integration Agent gets loop_count, the issues, and its
prior Output, and does not redo drift sections already cleared. A retry, or a pass resumed after an
escalation, is never a skip candidate for Step 2.2 — Reviewer-Integration always checks it.

**Doc-only retry — no gate re-run.** Sort the FAIL issues first. If **every** issue concerns only the
report or the docs — a missing or unplaced drift line, a wrong known-red tracker or owner, a skip
recorded in one place, wording in a governed doc — and none questions a gate result, a fix, a test, code
or config, mark the retry `Doc-only retry` in its Retry Context (the agent then does not re-run the gate).
Snapshot the tree before the retry (as in Step 2.1) and save that snapshot in run-state's
`integration` block — a doc-only retry re-run after a crash reuses it, never re-takes it — compare after it, and pass Reviewer-Integration the
list of files the retry changed. Any issue about code, tests or gate numbers makes it a normal retry, which re-runs the gate once
after its fixes.

Prefer **resuming the same Integration spawn** (`SendMessage` to its ID) with the issues for a doc-only
retry — it already holds the docs and logs, so a cold re-read is wasted. A resumed spawn keeps the model
it started on, so a doc-only retry at loop_count 3 does not move Integration to its Escalated Model (its
Reviewer-Integration still does). If it is no longer available, spawn fresh with the Retry Context, at
the model for its loop_count.

On the FAIL that takes loop_count past 3, run **Divide-and-Conquer** from `references/escalation.md`
before escalating.

---

## Phase 3 — Finalization

Entered only on Reviewer-Integration `PASS`, or on a skip under Step 2.2's rule (except a P0 fast lane, which runs this phase early for one
Bug — see `references/spike-and-p0.md`). A Spike gets only its Spike Log.

Spawn **the Step 3.1–3.4 Finalizers that apply, in parallel** (four, or three when Graphify is skipped)
— one `Agent` call each in one message, each `subagent_type: "orchestrated-finalizer"` with its `model`
from **Model Assignment** and the Finalizer Agent Prompt. They write disjoint files. All write only this
component's docs, except the Version
Pointer Sweep's permitted header edits; none touches `platform-architecture-file`.

**Outside items — asked before the Finalizers.** When any item's run-state `outsideItem` list
(Steps 1.3 and 1.3b) is not empty, settle them once, now, before spawning a Finalizer, so a yes lands
in this run's PMBook. **First sift them**, so only new defects reach the user: an entry a `Planned` or `In
Progress` PMBook item will build, or an open Bug Log row already covers, is `planned: <ID>`; one a
ruling covers (run-state's `decisions.rulings`, a packet's Ruled deviations, a design round's rows,
an ADR) is `ruled: <source>`; a `board may be wrong` entry that the design kit or a built sibling
contradicts is `board right: <what was checked>`. Show each sifted entry in one line and never offer
it as a Bug. **A remaining entry that differs from the board** (the board draws it; the build shows
something else) **is logged as a new Bug of this component without asking**, one per surface, and
listed in the summary. Never ask about an outside item mid-gate; every entry waits for this point.
List every entry no board or rule covers, and offer to log them as new Bugs: **one Bug per surface** (a
screen, or a file) **or one Bug grouping them all** — say which you propose and why. A board
difference where the board itself may be wrong is still a Bug, with `board may be wrong — needs a design
ruling` in its description. Save the answer in run-state's `decisions` as `outsideItemLog` (the grouping,
then each entry: `logged as <new ID>` or `declined`) before any Finalizer runs; a resume reuses it and
never asks again. On a yes, give each new Bug the next free ID and put it on Step 3.2's Edit List as a new
`## Bug Log` row: Status `Open`, `Fixed In` blank. Nothing else is logged without the user's yes. A P0 fast lane does
not ask; a run that never reaches Phase 3 lists the entries at close-out as `not logged — no
Finalization this run`.

**Deferred minor gaps — written before the Finalizers.** When any item's run-state `deferredGaps`
is not empty (Step 1.3b), the Orchestrator writes them, unasked, into one findings file in the format
of `~/.claude/skills/disparity-checker/references/findings-format.md`:
`<findings-directory>/<yyyy-mm-dd>-run-<run id>.md`, `Status: open`. One finding per element (its
states and widths listed), `Suggested type: Bug`, `Severity` Medium or Low as `disparity-checker`'s
step 5 says, `Component` this component, `Built by` the item, `Evidence` its parity folder. No IDs: a later
Findings Intake (Step 0.1e) logs them. Add the file to `orchestratorFiles` so Step 3.5 commits it, and
name it in the final summary. `findings-directory` unset → `./docs/{component}/findings`. A P0 fast lane writes its own
the same way; a run that never reaches Phase 3 writes it at close-out.

**Design rows owed — written before the Finalizers.** When `decisions.designRowsOwed` has an entry not
yet written (a drawing a design ruling, a "build to the Acceptance Criteria" ruling or a not-drawn surface
left owing — Steps 1.1–1.2 and the Design rows hold), the Orchestrator writes each as an `Open` row in the
open round per `~/.claude/skills/sync-artboards/references/design-files.md`: next ID for the screen's letter, Source the item and the ruling (who, date), Round
`open`; a new round file if the last one was sent. Then it rewrites the round's Summary and Detailed
prompt, marks each entry `written as <row ID>` in run-state, and adds the rows and round files to
the files Step 3.5 commits. Old layout → the old ledger, as the Design rows hold says. No design folder at all → the
entry stays `not written — no design folder`. A P0 fast lane writes its own entries the same way. The
final summary shows the round's two texts when any row was written. Never mark the round sent.

Each component has its own semver; version history rows go to `history-directory`, never into a live doc.

**Edit Lists — the Orchestrator says what changes where.** Hand each doc Finalizer (all but Graphify)
an **Edit List**: one line per edit, as `<file> — <anchor> — <change>`.

- **Anchor:** something the Finalizer can find with one search — a row's ID (`OFA-F-003`), a section
  heading (`## Bug Log`), or `end of <section>` for an append.
- **Change:** the facts, short — `Status → Done`, `new row: OFA-B-012 | <one-line description> |
  2026-11-09 | Fixed | Unreleased`, `entry under [Unreleased] → fix: OFA-B-012 <one line>`. Facts, not
  finished paragraphs: writing the prose is the Finalizer's job, and an Opus-written paragraph costs
  more than the Haiku spawn saves.
- **Complete:** every edit the Finalizer must make is on the list — including the content its own Task
  file requires, which the Orchestrator owns. Read the Task file before writing its list: the Revision +
  Changelog list carries a `smoke tests →` line (happy path, edge case, regression-sensitive flow; a
  Bug's is its repro), and the Test Runbook list says per feature which runbook steps are owed, or
  `no runbook steps owed`. Each file gets a line for **every section it keeps per entry**: `Grep` the
  file's headings first — a changelog that keeps its own `### Smoke tests` or `Files touched` gets a
  line for each, not only the revision file.
- **Every stale mention:** `Grep` each item ID across the governed docs (PMBook, handoff, changelog,
  revision, test runbook, test-cases doc). Every line that states the item's status, or calls it open,
  gets an Edit List line on the Finalizer that owns that file — a line no list names is left stale.
- Build the lists from what you already hold — the packets, the Developer Outputs, the Integration
  Output (its drift findings handed to a Finalizer become list lines) and the Release label. Do not read
  the docs in full to build them; a `Grep` for an anchor you are unsure of is enough.

**Release label — decided once, before the spawn, and saved in run-state's `decisions` as `phase3` (a
P0 lane's as `lane:<ID>`); a resume reuses only its own scope's.**
Before spawning, read `changelog-file`: if it keeps an `[Unreleased]` section, the label is
`Unreleased` and entries go there; otherwise take the newest released version and bump it (minor for any
Feature, patch for Bugs only). Pass the same label to both Finalizers as `Release label:`, and print it. Every Finalizer prompt also
carries `Scope: phase3` (a P0 lane's: `Scope: lane:<ID>`) next to its `Run ID:`, and a
`## Final Status per Item` section — every item in the run with its final status from run-state (e.g.
`OFA-F-013 — passed review → Done`, `OFA-B-007 — verified`, `OFA-S-002 — findings recorded`,
`OFA-F-014 — dropped`), so no Finalizer has to guess an item's state from the docs.

### Step 3.1 — Graphify (Finalizer)

**Runs only when this run changed code in the component's `code` roots.** Before Phase 3, decide from
**the run's own file set** (Step 2.0's: every item's run-state `files`, every attempt, plus the
`integration` block's `files`), never from raw `git status`: a foreign path under a root (another
session's or the user's uncommitted file, Step 2.0) does not make it changed. A root counts as changed
when a file in that set lies under it — committed earlier in this run or not. If no root
does (e.g. only docs, a shared library or a test folder outside
all roots changed — none of which the graph scans), spawn no Graphify Finalizer, print
`Graphify: skipped — no change in <roots>`, and pass the same line to the Handoff Finalizer and the
close-out summary. Otherwise keep the list of roots that did change: the routes below use it.

**Route — pick the first that applies, and name it in the Task-Specific Inputs** (the Finalizer's
Graphify procedure holds the mechanics):

1. **Repo graph script** — `scripts/graph.ps1` exists at the repo root. Command:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1 -Component <component>`, with
   no `-Root`: it builds every root of the component, because updating only some roots drops the edges
   that run between them.
2. **No script, several roots** — the `graphify update` command line for every root of the component,
   not just the changed ones (same reason). Never the `/graphify` skill once per root.
3. **No script, one root** — the `/graphify` skill, scoped to that root.

- **Task-Specific Inputs:** the component name; which of the three routes, with the exact command for 1;
  `graphify-directories` = this component's `code` roots; the changed roots (from the check above);
  output directory `graphify-out/<component>/` (absolute for route 2); for routes 2 and 3, whether
  `graph.json` already exists there.
- One graph per component, never the project root.
- **Always before the commit, never after it.** The Graphify Finalizer runs with the other Finalizers,
  and its `GRAPH_REPORT.md` (the only committable graph file) goes into the same commit as the code it
  describes (Step 3.5). No graph build after the commit and no separate graph commit.
- Before relying on a report you did not build, compare its stamped commit with `HEAD`: if the
  component's roots changed in commits after the stamped one, rebuild before citing it — **except** when
  the stamp carries `+ uncommitted working tree` and the only later commit is the one it was built for
  (the commit that also changed `GRAPH_REPORT.md`). That graph is fresh.

### Step 3.2 — PMBook Update (Finalizer)

**Task-Specific Inputs:** the Edit List for the PMBook; `project-management-doc` path; features completed (to `Done`); verified non-P0 bugs (a fast-laned P0 only as a Deferred ID), each with
`Regression test: <path>` from its Developer Output's Test Files Written; the
`Release label: <label>`; on a P0 fast lane, `P0 fast lane: <B-ID>, Hotfixed On <date>`; the
Integration Output's Flaky Tests Detected; the Integration Output's `Deferred
Integration Re-Validated` list; the new Bugs from `decisions.outsideItemLog` (as Edit List lines); the
**New ADR** lines (below, as Edit List lines) with the `adr-directory` path; and, **only when this run
bumped a `> Version:` header**, the instruction to run the Version Pointer Sweep with the path
`~/.claude/skills/plugin-orchestrator-development-pattern/references/version-pointer-sweep.md` and which
headers moved.

**PMBook status is written once, here.** Step 1.4 writes nothing to the PMBook; this Finalizer sets
each item's Status (`Status → Done`, a Bug row's `Fixed`). The Edit List names every other field that
changes for each item — the phase's own status when its last item lands, and the release or provenance
cells the PMBook keeps (Release label, run id) — so nothing is left to the Finalizer's guess, and no
later step writes Status again.

**New ADRs.** For each Integration drift line `Drift: new ADR — <title> — <decision> — handed to PMBook
Update`, you pick the next free number in the shared `adr-directory` (one higher than the highest `ADR-<NNN>` there
and than any already handed out this run; never reuse or renumber) and hand the PMBook Finalizer one
line: `<adr-directory>/ADR-<NNN>-<slug>.md — new file — <title>; decision: <one line>; context: <why,
from the drift line and the items behind it>; status: <Accepted | Proposed>`. `Accepted` only when the
user ruled that decision in this run — cite where (the item ID and gate); otherwise `Proposed`. A
superseded ADR is named on the same line (`supersedes: ADR-<NNN>`). With `adr-directory` unset, hand
nothing and list the decision on the final summary's `New ADRs:` line as `not written — no
adr-directory`. Every `Proposed` ADR is listed on that line for the user to rule on.

A Tranche boundary (every phase `Done`) comes back under **Notes**. Put the `Tranche:` line in the final
summary telling the user to run `plugin-idea-triage`'s Tranche Closeout. Never archive from this
pipeline.

### Step 3.3 — Handoff Update (Finalizer)

**Task-Specific Inputs:** the Edit List for the handoff doc; features completed with implementation notes, bugs fixed with root-cause notes,
`handoff-doc` path.

### Step 3.4 — Revision + Changelog, Test Runbook (one Finalizer)

One spawn, bundled Task `Revision + Changelog, Test Runbook` — three disjoint files, no reason for two
cold starts.

**Task-Specific Inputs:** the Edit List for each of the three files; features completed with their Test Expectations; bugs fixed with their repro
steps; `revision-file`, `changelog-file` and `test-runbook-location` paths; the `Release label: <label>`;
and, when Integration handed test-cases drift off, the `test-cases-doc` path with one Edit List line per
gap (Integration fixes code, never that doc).

### Step 3.5 — Commit (Orchestrator; push only on a go)

When every Finalizer has returned, **the Orchestrator writes the commit messages and makes the
commits itself**. No extra spawn. Its **file list** is the step's full staging source set, saved in
run-state: in Phase 3, every in-scope item's `files` (every attempt), the `integration` block's
`files`, the Step 1.1b Artboard Edit Outputs' files, every Finalizer's Files Created or Modified,
and run-state's `orchestratorFiles`; in a P0 lane, that Bug's `files` plus its lane Finalizers' files
(and any `orchestratorFiles` entry written for that Bug).

One commit per logical change group, Conventional Commits `type(scope): description` — `feat` for
Features, `fix` for Bugs, plus `chore` / `docs` / `refactor` / `test` as fitting — ending with the
session's attribution lines. **Copy the attribution lines verbatim from your own context** (the
session's attribution instruction); never write them from memory or change a model name. Linked Runs:
one group per component, the depended-on one first.

**Trailers — one rule for every commit, here and in a fast lane:** `Run-Id: <run id>` on every commit;
`Items:` lists only the item IDs whose changes are in that commit; a commit holding only Integration
fixes says `Items: integration`.
`GRAPH_REPORT.md` goes with the group it was rebuilt for.

1. **Check first.** `git status --porcelain` and `git diff --cached --name-only`. Staged paths that are
   all in this step's saved file list are this run's own — carry on and commit them. Stop and ask only
   for a staged path outside that list — it is someone else's work.
2. **Stage by exact path, one group at a time** — the files this run touched, never `git add -A` / `.`
   / a directory. Other sessions may be editing the same tree; a file this run did not touch stays out.
   A commit step (here or a P0 lane's) commits whatever of that file list `git status` still shows
   uncommitted, grouped as usual; a group with nothing left uncommitted is
   skipped. This is also what makes a re-run commit step safe — no git-log check here.
   Gitignored files (run-state, metrics) are never forced in.
3. **Commit on the current branch.** Never create, switch or merge branches; never amend; never pass
   `--no-verify` or skip signing. A hook failure stops the commits: report its output, leave the rest
   unstaged, and ask.
4. **Push only on a go** (`references/push-and-pull.md`). Without one, print the `git push`
   command instead. With one, push exactly as told and report the result.
5. Print each commit's short hash and subject in the final summary.

**Not committed:** a Spike's code (it stays uncommitted — the user's call), and a run that ended
escalated or paused. Follow `decisions.commit`: on `ask` (or unset), ask the user now and save the
answer to `decisions` before committing; on `no`, draft the messages instead. A "commit" the user says
after a commit step chose `no` first sets `decisions.commit: yes` (saved), then runs **one** commit pass
over the union of every commit step's saved file list in this run, grouped as Phase 3 groups are: each
item (Feature, Bug, P0) gets its own code group from its own `files`, its `Items:` naming only that
item; Integration fixes outside any item's files go in their own group with `Items: integration`;
governed docs, any file shared by more than one item, and every other file in no item's code group go in
one docs/chore group whose `Items:` lists every item whose changes it holds (the graph report goes with the item it was rebuilt for; one rebuilt for the whole run goes here,
and `Items:` then lists every item in the run). The Orchestrator drafts the regrouped groups'
messages first, as above, with the trailers. Then it refreshes this
run's RUN row's commit ids from git (**Pipeline Telemetry**). Every message this run commits, here or in a fast lane, ends with the trailers
`Run-Id: <run id>` and `Items: <ids>` — git is the run's commit record (**Run-State Checkpointing**).

### Step 3.6 — Close-out Checklist

Do every line before printing the final summary. Each was being skipped in practice. **It runs for
every run** — a Spike-only or P0-only run, and one that skipped Phases 2–3, included. It runs once, at
the end of the run: a P0 fast lane inside a multi-item run does not run it. An escalation pause does
lines 1 and 2 only: line 1's rows with the RUN row's Verdict `Paused (escalation)`, and `run-state-file`
saved but not complete.

1. Append every `metrics-log-file` row now due, per **Pipeline Telemetry** (row kinds, timing,
   write-once; a resumed escalated item or a resumed Integration adds a row for its new leg).
   Linked Runs: the RUN row goes into each linked component's `metrics-log-file`.
2. Mark `run-state-file` complete — Linked Runs: every run-state file with this run id. Delete the
   `.orchestrator-work/<ID>/` park folder of every item that ended this run; keep one whose item is still
   non-terminal (its `parkedAt` carries it to the next run). The delete applies only to the gitignored `.orchestrator-work/` under the run-state folder — never a tracked folder, even one a run used to park files, and never a folder a governed doc links to. Delete this run's `runs/`, `gate-logs/` and
   `parity/` folders in the work dir too, unless an item of the run is still non-terminal (a Bug
   `awaiting verification` keeps its gate logs for the `verified` reply). Delete with the file tools or a command the session's permissions allow; if the delete is refused, leave the folders, list them in the summary, and the next run's Phase 0 removes any work-dir run folder whose run-state is complete.
3. Surface every Finalizer `Notes` entry in the summary.
4. List any `## Deferred Integration` row still `Pending`, any `heldForNextRun` item, and every item's
   `outsideItem` entries (Steps 1.3 and 1.3b), with what `decisions.outsideItemLog` says of each
   (Phase 3's **Outside items — asked before the Finalizers**), every `decisions.designHolds` item with the
   rows it waits on, and every `decisions.designRowsOwed` entry with its row ID or why it was not written.
5. List every known-red, with its tracking ID or `accepted by the user`, and every `baseline.reds` test
   (Step 0.4b) — still red, or now green.
6. List every overruled issue (`decisions.rulings`, Step 1.4) and, on a Tranche boundary, the `Tranche:`
   line (Step 3.2).
7. Leave the stack in the state it was found in (or say which state it is in).
8. Set every task-bar task `completed`.

---

## Enforcement Rules

**Component**
- NEVER act before Step 0.0a has resolved the component and printed its block (Step 0.0a).
- NEVER default the component, or run without a `components:` table (Step 0.0a).
- NEVER let a diff touch another component's roots or `platform-architecture-file` (Diff Guard, Step 2.1).
- NEVER widen the Drift Check beyond this component's docs plus a read-only pass over the platform file.
- NEVER let a Finalizer write a history row into a live doc, or bump a `> Version:` header without the
  Version Pointer Sweep in the same run (a hub/branch layout may defer the other components' moves to
  the hub, `references/version-pointer-sweep.md`).
- NEVER derive a component's version from another component's changelog or a repo-wide number.
- NEVER perform a Tranche Closeout here — flag it to the user.

**Flow**
- NEVER begin without the hard dependencies (Step 0.0). NEVER write code as the Orchestrator, except in
  a UI Iteration (`references/ui-iteration.md`).
- NEVER let a UI Iteration take in anything but look-and-feel tweaks to one component; NEVER commit an
  iteration before its "done" has run the gates.
- ALWAYS generate a Task Packet before any spawn (Steps 0.3b, 1.1).
- ALWAYS respect dependency order and build waves by Step 1.0's rules; serialize when unsure.
- NEVER skip a phase for a Feature or non-P0 Bug; the only exceptions are Spike, P0 and UI Iteration
  (`references/spike-and-p0.md`, `references/ui-iteration.md`).
- ALWAYS run the Design Gate before a UI packet's Developer; NEVER let a Developer set the design (Step 1.1b, `references/ui-packets.md`).
- NEVER start a UI item whose design rows are not Done in a synced board when an outside designer owns the boards (`references/ui-packets.md` §Design rows hold); NEVER mark a design round sent, renumber a design row, or move an old design layout without the user's yes.

**Gates**
- NEVER advance past a FAIL without a retry, or exceed 3 iterations without escalating (Step 1.4) — the
  only FAILs that cost no iteration are Step 1.4's three rules (review-only first FAIL, an all-overruled
  FAIL, the Reviewer's own miss once per item).
- NEVER overrule a failing test, a failing gate, a Parity mismatch, or an issue that cites a criterion,
  constraint or convention (Step 1.4).
- At loop_count 3, ALWAYS use the Escalated setting (Model Assignment, Steps 1.4, 2.3).
- NEVER let UNVERIFIED touch `loop_count`, or treat it as PASS or FAIL (Handling an UNVERIFIED Verdict).
  A missing Output never touches `loop_count` either: the spawn is re-run, and a second miss escalates
  (`references/escalation.md`).
- NEVER run a repo-wide format — Format is scoped to the item's files, and its gate is the check
  (verify) form (Step 0.2).
- NEVER let a Developer run tests beyond its packet's `Tests you may run` (Step 1.1, Task Packet).
- NEVER skip Step 0.4b's baseline, except for a P0/Spike-only run, a UI Iteration, a mid-run intake or
  a resume (Step 0.4b).
- NEVER write commit attribution lines from memory — copy them verbatim from the session's attribution
  instruction (Step 3.5).
- NEVER accept a Bug's regression test on the Developer's word — the Reviewer runs it (Step 1.3).
- NEVER let a Bug past Step 1.5 without the user's "verified" (Step 1.5).
- NEVER narrow `Test scope: full`; `full` means every command in `Test (full)`, and no agent may narrow
  it on its own judgement (Step 2.0).
- NEVER accept a known-red without its owner and a tracking ID or the user's acceptance (Step 2.2).
- NEVER let a drift finding or a flaky test pass silently (Integration and Reviewer-Integration agents).
- NEVER run Divide-and-Conquer more than once per run, or at any loop_count but 3 (`references/escalation.md`).
- NEVER let a Spike leave its Spike Directory or reach the gates (`references/spike-and-p0.md`).

**Spawning**
- ALWAYS spawn by the role's dedicated `subagent_type` with an explicit `model`, after the spawn
  announcement (Roles, Model Assignment).
- NEVER run graphify unscoped, or before Integration passes (Step 3.1; exceptions in `references/spike-and-p0.md`).
- NEVER resume a stale run without asking (Step 0.0). ALWAYS run the Close-out Checklist (Step 3.6).
- ALWAYS stop and ask if a required tool call is denied.

---

## Git Restrictions

The Orchestrator's only git writes are `git add <exact paths>` and `git commit` at Step 3.5, on the
current branch, after Reviewer-Integration has passed, or was skipped under Step 2.2's rule, or at the
end of a P0 fast lane. Apart from a push or
pull on a go (below), it never runs `git merge`, `git checkout`, `git switch`, `git branch`, `git stash`, `git reset`,
`git commit --amend`, or anything else that changes git state, except `git worktree add`/`remove` of a
temporary detached worktree in the scratchpad (Steps 0.4b, 1.5). Read-only `git status` / `git diff` /
`git log` are fine at any time. Never create or switch branches. Never push or pull on its own
initiative — give the command instead, except on a go.

**Push and pull:** before any push or pull — the user or a hub session asks for one, or this session is
the named hub — read `references/push-and-pull.md` and follow it exactly.

---

## Run-State Checkpointing

`run-state-file` (default `docs/<component>/.orchestrator-run-state.json`) lets a fresh session resume.
It is **local and gitignored — never committed**, like the `.orchestrator-work/` park folders beside it: it holds work-dir paths and mid-run state that mean
nothing in another checkout.
The Orchestrator writes it directly — bookkeeping, not code.

**Content:** run id (`<YYYY-MM-DD>-<component>-<first item id, lowercased>-<HHmm>`, the start time,
fixed at Step 0.4; if that id already appears in `metrics-log-file` or `git log --grep "Run-Id: <id>"`,
add `-2`, `-3`… until it is unique) and
start time, component, Platform Profile (with Test scope once decided), Step 0.3's conventions
summary, the waves
and ordered queue (ID + Type), per-item `status` (`in progress | passed review | awaiting
verification | verified | findings recorded | escalated | dropped`, saved at each change: `in progress`
when the item starts, on any FAIL or rejection that sends it back (Reviewer FAIL, Parity FAIL, a Step
1.5 rejection) and on an escalation resume; a Feature's final PASS (a UI packet: after its Parity PASS)
→ `passed review`; a Bug's PASS → `awaiting verification` (a Bug never sits at `passed review`), and its
Step 1.5 confirmation → `verified`; a Spike Log row → `findings recorded`; an escalation → `escalated`;
the user's explicit "drop" or "defer" of an item → `dropped` (`references/escalation.md`). Terminal for resume: a Feature at
`passed review`, a Bug at `verified`, a Spike at `findings recorded`, and `dropped` (a legacy `done` from an older run-state file counts as terminal too)), `orchestratorFiles` (every governed file the Orchestrator itself writes — a drafted
test-cases doc, a known-red tracking item, a linked item's PMBook row — appended when written; Step
3.5's file list reads it), each unit's current `step` and
`state: started | done` (a unit is a work-item attempt, a P0 lane, Phase 2 or Phase 3; a P0 lane's and
Phase 3's steps are `finalizers → commit → done`, the commit messages drafted inside the commit step; a
`done` Finalizers step keeps the commit step's file list, Step 3.5),
the `decisions` block (below), each item's `loop_count`, `priorLoops`
(loops spent before a resume after escalation), `unverifiedTotal` (UNVERIFIED verdicts since its last
metrics row; reset per **Pipeline Telemetry**) and last verdict, the files of its Step 1.1b Artboard
Edit Output (if any), its **`files`** — the union of the files in all its Developer Outputs, every
attempt, read wherever an item's "files changed" is (Step 2.1, Deferred entries, Step 3.5) — its latest
Developer Output (files changed, summary, deviations, Test Files Written) and both its last Issues list and its last Unable to Verify report, `parkedAt` (the durable folder an escalation pause parked it in, `references/escalation.md`), `loopCountAtEscalation` (saved at
every escalation), `blockedGate` (`reviewer | parity |
reviewer-integration | developer | integration | finalizer`, saved at any Verification Blocked escalation, cleared once the resume has respawned the role it names), the latest
Integration Output, an `integration` block (Step 2.1's tree snapshot, `outputPaths` — every saved
Integration Output file, in order (Step 2.1) — its **`files`** — the union of
changed files across every Integration pass and every Divide-and-Conquer sub-problem spawn — `loop_count`, `unverifiedTotal`, `priorLoops`,
`loopCountAtEscalation`, its own `blockedGate`, and `divideAndConquer: not run |
running | confirmation pass | done` — the confirmation pass is Divide-and-Conquer's aggregate pass and
its one Reviewer-Integration), the Parity Table path of each of its
Step 1.3b runs (FAILs included) with that run's unruled major-mismatch count beside it (counts cleared per
**Pipeline Telemetry**), per-item and per-phase start/finish timestamps (the
RUN row's Phase times come from these), and `linkedRuns` when there are any (Linked Runs: one file per
component, all with the same run id; finding any incomplete one resumes every file with that run id).
A UI Iteration adds `"mode": "ui-iteration"`, `openedAt`, its `tweaks` log (number, the user's ask,
files, time), `doneAt` once the user says "done", and its file set (`references/ui-iteration.md` step 3).
**`decisions`** — written the moment the user (or the Orchestrator) decides, before acting on it:
`commit: yes | no | ask`; the Release label per scope (`lane:<ID>`, `phase3`), each scope reusing only
its own; `acceptedKnownReds` — the accepted known-red list (documented-baseline ones marked with their file), with each tracking ruling and its assigned OI id (saved before
the PMBook write); `heldForNextRun` (Step 0.1b item 7); the `app-url` and `artboard-server` answers; `rulings` (Step 1.2's
design rulings, and Step 1.4's overruled issues: item, issue, reason); `testCasesDoc` (Step 0.0); `outsideItemLog` (Phase 3's offer); `mvWaiver` (Step 1.5); `findingsIntake` (Step 0.1e);
`designHolds` (`references/ui-packets.md` §Design rows hold: item, open rows, round); `dataSourceGaps` (§Data sources check: item, fields, ruling); `designRowsOwed`
(Step 1.2, the Design Gate and the hold: item, surface, change, source, then `written as <row ID>` or
`not written — <why>`).
**Also per item:** `mode` (`review-only` when set, Step 0.1), `outsideItem` (Steps 1.3 and 1.3b), `deferredGaps`
(Step 1.3b), `reviewerMissRetry: used` (Step 1.4), `verification` (a Bug's measurements from Step 1.5's reply, verbatim). **Run-level:** `phase` — where the pipeline is, exactly one of `phase0 | phase1 | phase2 | phase3 | closeout` (a UI Iteration: `ui-iteration`), saved as each begins; resume's "latest phase first" reads it (the PMBook's own phase name goes in `pmbookPhase`, never in `phase`; an older file with free text in `phase` is read from its units' `step` and `state` instead); `baseline` — `reds` (test, how it failed), the command
that ran, or `skipped — <why>` (Step 0.4b); `foreignPaths` (Step 2.0).

**One file per component, replaced by each new run.** Step 0.4 writes a new run over the last one's
file once that run is complete. That is intended: the file exists for resume, and a complete run has
nothing to resume. The finished run's record is its `metrics-log-file` rows and its commits
(`Run-Id:` trailer), not this file.
**Packets:** a PMBook item the Orchestrator used unchanged persists only its ID; every other packet —
ad-hoc Bug and Spike items, and any packet the Orchestrator added to (e.g. a Design Reference) — is
persisted in full.

**Timestamps are ISO date-times with the zone** (`2026-11-03T14:05:00+11:00`), never bare dates —
telemetry's wall-clock columns are computed from them. Read the clock (`Get-Date -Format o`, `date -Iseconds`)
at each transition; never estimate (a metrics event time already saved is reused, **Pipeline Telemetry**). Before appending any metrics row, read the clock: no Timestamp, Started or Finished may be later than now — one that is was guessed, so write `(not recorded)` in its place.

**Written at every step edge:** after Step 0.4 (which a Bug or Spike intake also runs); when each step
starts and when it ends (a Developer, a gate, a Divide-and-Conquer stage, a Finalizer batch, a commit);
after every verdict; at every user decision; when a Bug enters `awaiting verification`; at every
terminal state and escalation; and at close-out, which marks it complete.

**Repeat-safe writes.** A step found `started` re-runs from its start, all of it, so every governed-doc
write first looks for an entry for the same item ID (and, where the doc carries them, the same run id
and scope — `lane:<ID>`, `spike:<ID>` or `phase3`, since a P0 lane and Phase 3 share a run id; Finalizer entries are
tagged `(run <run id>, <scope>)`) and updates it instead of adding a second — the Finalizers' writes, and the Orchestrator's own: a known-red tracking
item reuses an `## Open Items` row already naming that test; metrics rows are write-once (**Pipeline
Telemetry**). **Git is the commit record** (the `Run-Id:` / `Items:` trailers, Step 3.5). A commit step
itself checks only `git status`.

---

## Pipeline Telemetry

`metrics-log-file` (default `docs/<component>/orchestrator-metrics.md`) is the evidence for tuning models,
retries and waves; the Close-out Checklist makes writing it a required step. Appended directly by the
Orchestrator, never overwritten. One header for every row (18 cells):

```
| Timestamp | Run ID | Item ID | Type | Size | Wave | Started | Finished | Final loop_count | Escalated? | UNVERIFIED count | Verdict | Test scope | Divide-and-Conquer triggered? | Known-reds | Phase times | Parity mismatches caught | Mismatches reported after hand-over |
```

**Three row kinds:** one per work item that reached a terminal state; one with `Item ID: Integration`,
only if Phase 2 ran; one with `Item ID: RUN`, always. Every cell is filled — `—` where a column does not
apply (Test scope, Known-reds and Phase times on an item row; the two Parity cells on Integration and RUN).
**Terminal states:** `verified` (a Bug, after the user's "verified"), `passed review` (a Feature, once
the run completes — so an escalation pause writes no row for it; its row comes at close-out), `escalated`, `findings recorded` (a Spike), `dropped`. A `dropped` item gets one
row, Verdict `Dropped`, written when the drop is saved to run-state, with that saved event time as its
Timestamp. An `escalated` row is appended at the
moment of escalation, after the event time and the `escalated` status are saved to run-state
(`references/escalation.md`). A resumed escalated item gets a second row at its next
terminal state, with that event's own Timestamp. **Final loop_count**, on every item and Integration row (an
escalation row included), is `loop_count` minus `loopCountAtEscalation` (0 when
never escalated).

- **Run ID** is the id written to `run-state-file` at Phase 0. **Timestamp, Started, Finished** are ISO
  date-times with the zone (**Run-State Checkpointing**).
- **Timestamp** is the time of the row's event (a terminal state, an escalation, Phase 2's end, the
  pause or the close-out, a mismatch intake), which the Orchestrator saves in run-state **before**
  writing the row; an event time already saved in run-state is reused on a re-run, never read again. **Rows are write-once:** a row with the same Run ID, Item ID and Timestamp
  already in the log is left unchanged, never added again or re-written — a re-run skips it. The one
  exception is the RUN row's commit ids, refreshed after a commit (below). Legs, second escalations,
  second mismatch reports and the `Paused` and `Complete` RUN rows have different event times, so all
  survive.
- **Size** — the item's planned points (Step 0.1, or its intake); `—` on Integration, RUN and Mismatch
  rows. Never re-sized once building starts, so it can be read against Final loop_count and
  Started/Finished to see how well items were sized.
- **Wave** is the wave number, not a model. **Escalated?** is `Yes` only for an escalation under
  `references/escalation.md`; a hub or user ruling goes in Verdict. **UNVERIFIED count** is
  `unverifiedTotal` as the row is written (the verdicts since the item's last row); it resets to 0 once
  the row is in the log (written now, or found there on a re-run).
- **Integration row:** Test scope, Divide-and-Conquer triggered?, Known-reds (each with its tracking ID or `accepted by the user`, or `none`). Its
  Verdict says whether Reviewer-Integration was skipped and how many retries were doc-only (e.g.
  `PASS; R-I skipped`, `PASS on retry 1 (doc-only)`). Linked Runs: the one combined Integration row goes
  into each linked component's file, its Verdict noting `linked with <other component>` (all linked
  files share one run id).
- **RUN row:** Type `Run`; Started and Finished = the run's start and end; Wave, Final loop_count,
  Escalated? and UNVERIFIED count `—`; written at the 🏁 summary with Verdict `Complete` or `Paused (escalation)`, plus ` — commits <ids>` for
  this run's commits so far (`git log --grep "Run-Id: <run id>"`). A commit made later, on the user's
  "commit", refreshes that RUN row's commit ids from git — only a row with this run id, never another run's. An
  escalation pause writes a `Paused (escalation)` RUN row and leaves run-state not complete; the resumed
  run, when it finishes, appends a second RUN row `Complete`;
  Phase times as `P0 <t> · P1 <t> · MV <t> · P2 <t> · P3 <t>` (MV = the Manual Verification wait; `n/a`
  for a phase that did not run).
- **Parity mismatches caught** (item rows): the unruled major mismatches across this leg's Step 1.3b runs,
  summed from the counts run-state keeps beside each Parity Table path, cleared (paths kept) once the
  row is in the log; `n/a` for a non-UI item.
- **Mismatches reported after hand-over** (item rows) starts at `0`. When Bug Fix Intake (Step 0.1b) takes
  a design mismatch on a surface an item built, it notes it then and writes it once Step 0.4 has
  written run-state and saved the intake's event time there (a mid-run intake saves it at once), by
  appending (write-once, so the building item's own row is never edited) a row with
  `Item ID: <ID>`, Type `Mismatch`, Timestamp the intake's saved event time, Run ID of the run doing the intake, Mismatches reported
  after hand-over `1`, Verdict `mismatch reported after hand-over`, every other cell `—`. This
  count should trend to zero; if not, the Parity Check is missing something — raise it with the user.

Create the file with this header on first append. If it exists with a **different header** (e.g. an earlier
14-column table), never rewrite, pad or re-order old rows or force new ones under it; each table is read on its own: add `### From <YYYY-MM-DD>` with the current header and
append there. Before appending, re-read the header you are appending under and check every row has
exactly 18 cells. The final summary's `Retries this run` line uses the item rows' loop_count and
Escalated? counters.

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
   Regression test written: <path>
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
   Tests: <N> passed, <F> failed (each a known-red or flaky, listed)
```

**Final summary:**
```
🏁 Orchestrator Complete — <component>

Component:        <component>   (docs/<component>/, tranche vN)
Graph:            graphify-out/<component>/
Phase:            <phase name>
Features shipped: <IDs>
Bugs fixed:       <IDs> (or "None this run")
P0 hotfixes:      <ID> — <its status as it stands after Step 3.2: Hotfixed — Integration Pending, or Fixed> (one per line; or "None this run")
Spikes run:       <IDs> (or "None this run")
Dropped:          <ID> — dropped/deferred by the user (one per line; or "None")
Outside items:    <ID> — <what, where> — logged as <new ID> | declined | not logged — no Finalization this run (one per line; or "None")
Overruled:        <ID> — <issue> — not an issue: <reason> (one per line; or "None")
Held for design:  <ID> — waits on <row IDs> (round <NNN>, open | sent <date>) (one per line; or "None")
Design rows owed: <ID> — <surface: change> — written as <row ID> in round <NNN> | not written — <why> (one per line; or "None")
Baseline reds:    <test> — still red / now green (one per line; "None"; or "skipped — <why>")
New ADRs:         ADR-<NNN> <title> — Accepted (ruled at <ID>) | Proposed — needs your ruling (one per line; or "None")
Foreign paths:    <path> — foreign (another session or the user) (one per line; or "None")
Quality gate:     ✅  (test scope: <full|component>)
Integration:      ✅ (or "Not run — <why: only P0 fast lanes / Spikes / escalated items>")
Known-reds:       <test> — owner <component> — tracked by <ID> / accepted by the user (one per line; or "None")
Retries this run: <N1>/<N2> items needed a retry, <N3> escalations
Size vs actual:   <ID> — <pts> pts → <loop_count> retries, <minutes> min (one per line, from the item rows)
Time:             P0 <t> · P1 <t> · MV <t> · P2 <t> · P3 <t>   (the RUN row's Phase times)
Finalization:     ✅ (<N> parallel Finalizers + Orchestrator commits)
Tranche:          every phase Done — run /plugin-idea-triage's Tranche Closeout (only on a Tranche boundary; omit otherwise)

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
