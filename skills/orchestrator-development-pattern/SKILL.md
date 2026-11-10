---
name: orchestrator-development-pattern
description: Multi-agent development orchestrator for PMBook-driven features, orchestrated bug fixes (including P0/hotfix fast lanes), and exploratory spikes. Invoke only when the user explicitly wants the full Developer→Reviewer→Integration→Finalization pipeline run end-to-end (e.g. "orchestrate a fix for X", "run the orchestrator on this bug", "build this from the PMBook", "spike this", "run a spike on X", "this is a P0", "hotfix this") — not for a plain "debug X" / "fix this" question, which is a normal debugging conversation or a job for debugging-wizard, not this pipeline. Reads the PMBook (or takes an ad-hoc bug report directly for the Bug Fix path), detects the runtime platform, and coordinates developer + reviewer sub-agent pairs in a controlled loop (max 3 retries before human escalation). After all work items complete, an integration agent runs the full test suite, fixes failures, and ensures build health. Finalization (docs, changelog, graphify, commit messages) runs as parallel Finalizer sub-agents. A Spike work item skips the Reviewer/Integration gates entirely (exploratory, no fixed acceptance criteria); a P0 Bug fast-lanes straight to its own Finalization and defers full-suite Integration. Language and platform agnostic.
license: MIT
metadata:
  author: https://github.com/mak100186
  version: "2.13.0"
  domain: development-workflow
  triggers: implement, build, develop, orchestrate, start development, run orchestrator, orchestrate a fix, run the orchestrator on this bug, run a spike, spike this, P0, hotfix
  role: orchestrator
  scope: multi-agent-development
  related-skills: idea-triage, graphify
  variables: [
    project-management-doc,
    handoff-doc,
    source-code-directory,
    graphify-directories,
    revision-file,
    changelog-file,
    snyk-command,
    test-runbook-location,
    architecture-doc,
    test-cases-doc,
    adr-directory,
    run-state-file,
    metrics-log-file,
    artboards-directory,
    app-url,
    artboard-server,
    parity-viewports
  ]
---

# Orchestrator Development Pattern

## Task bar

If you have a task-list tool (`mcp__task-bar__set_tasks`, or `TodoWrite`), keep it current so the user
can watch progress above the prompt: send the whole list when work starts (one task per phase or work
item), again whenever a task starts or finishes or the plan changes, all `completed` at the end, then an
empty list once the user has seen it. If you have neither tool, carry on without; do not mention it.

The Orchestrator reads the Project Management Book (PMBook), detects the platform, turns work into Task
Packets, and runs a Developer and a Reviewer sub-agent per work item. After every item passes, an
Integration Agent runs the full test suite, fixes build and test failures and validates end to end, and a
Reviewer-Integration gate checks it. Finalization then runs the Step 3.1–3.5 Finalizers in parallel,
then one that drafts commit messages (Phase 3).

**Three work-item types share this one pipeline:** planned **Features** from the PMBook's Feature Backlog
(per `idea-triage`'s gates); reactive **Bugs**, taken ad hoc without needing a PMBook row first (Step
0.1b); and exploratory **Spikes**, with no fixed acceptance criteria (Step 0.1c). Features and Bugs share
the Developer → Reviewer loop, Integration and Finalization, and differ only in the Task Packet, the
Reviewer's run of the Bug's regression test, the Step 1.5 Manual Verification Gate (Bugs only), and a few
Finalizer outputs (changelog category, PMBook logging). Two documented exceptions to specific steps, not
parallel pipelines: a **Spike** leaves the loop after one Developer spawn, with no Reviewer, retry loop or
Integration (**Spike Flow**); a **`Priority: P0`** Bug defers only Integration (**P0 Hotfix Fast-Lane
Finalization**).

## Side files

Read each only when its trigger occurs. They are part of this skill.

| File | Read when |
|---|---|
| `references/spike-and-p0.md` | A Spike intake (Step 0.1c) builds its packet, a `Type: Spike` packet reaches Spike Flow, or a `Priority: P0` Bug is `verified` at Step 1.5 |
| `references/parity.md` | A packet with a `## Design Reference` reaches Step 1.3b (Board Parity Check) |
| `references/escalation.md` | A work item or Integration is about to escalate to a human, or Divide-and-Conquer triggers |
| `references/resume.md` | The user confirms a resume at Step 0.0, or types "resume" at an escalation pause |

## Invocation boundary

The pipeline needs an explicit ask — "orchestrate a fix for X", "run the orchestrator on this bug",
"build this from the PMBook", "spike this", "this is a P0". A plain "debug X" / "why is this failing" is a
normal debugging conversation (`debugging-wizard` or direct investigation), not this pipeline. Spike and
P0 likewise need the user to actually ask for them ("spike", "P0", "hotfix" or equivalent); never infer
them from tone or severity.
<!-- Maintainers: this gate also lives in the frontmatter description and the global CLAUDE.md entry; keep all three in sync. -->

**Sticky per conversation:** once this skill has entered Phase 0 in a conversation, a later plain "debug
X" / "fix X" in the same conversation becomes a new Bug Fix Intake item (Step 0.1b), and a plain "let's
try X" / "explore Y" a new Spike Intake item (Step 0.1c), without re-clearing the bar. A new conversation
starts back at the high bar.

**Mid-run intake** (a new bug or spike while a run is open, run-state not complete): keep the same run id
and run-state file, skip Step 0.4's run-id/run-state write, and append the item to the queue (save
run-state). If Phase 2 has already started, save its full packet in run-state's `decisions.heldForNextRun`
instead; it seeds the next run's queue (see **Run-State Checkpointing**). At Step 1.5's gate, a report of a *different* bug is an intake, not a rejection of the current one.

## Key design principles

- **Developers write tests but do not run the suite.** Several Developers may run in parallel against an
  incomplete codebase, so their test results would be unreliable; the Integration Agent owns test
  execution, test fixing and build health.
- **Cold spawns keep context small.** Compaction is the harness's job; this skill keeps there being
  little to compact. Every sub-agent is a fresh single-purpose spawn (Task Packet in, Output out). A retry
  never continues the old conversation: it spawns fresh with the Task Packet, the issues list and the
  previous attempt's file list (Step 1.4). After each item the Orchestrator keeps only its one-line
  `✅ F-XXX — PASS after N iteration(s)` result; the durable record is the PMBook on disk.

---

## Roles

Each role is a dedicated agent (`~/.claude/agents/<name>.md`) holding its discipline, tools and
standalone default model. The Orchestrator feeds it structured input (Task Packet, Developer Output,
Integration Output). Spawn every sub-agent via its dedicated `subagent_type`, never a generic agent type,
so that definition's discipline and tool restrictions apply.

| Agent | Spawned By | Responsibility | Sub-Agent / Model |
|-------|-----------|----------------|-----------------------------|
| **Orchestrator** | User (this skill) | Reads PMBook or intakes an ad-hoc bug report, detects platform, generates task packets, dispatches sub-agents, tracks state, escalates | — (this skill) |
| **Developer** | Orchestrator | Implements one feature or bug fix, writes tests, runs Format + Lint only | `orchestrated-developer` / see **Model Assignment** |
| **Reviewer** | Orchestrator | Reviews Developer Output against the task packet; on Bug packets, also executes the single named regression test; returns PASS or FAIL with actionable issues | `orchestrated-reviewer` / see **Model Assignment** |
| **Integration** | Orchestrator | Runs full test suite, fixes test/build failures, runs security audit, validates E2E — after all work items complete | `orchestrated-integration` / see **Model Assignment** |
| **Reviewer-Integration** | Orchestrator | Reviews Integration Output; returns PASS or FAIL | `orchestrated-reviewer-integration` / see **Model Assignment** |
| **Finalizer** | Orchestrator | Performs exactly one Phase 3 task (Graphify / PMBook / Handoff / Revision+Changelog / Test Runbook / Commit Messages), or a Spike's solo **Spike Log** — see **Phase 3**, **Spike Flow** and **P0 Hotfix Fast-Lane Finalization** | `orchestrated-finalizer` / see **Model Assignment** |

**Model announcement:** immediately before every sub-agent spawn, in every phase, the Orchestrator prints
a one-line announcement naming the role and the model being used:

```
→ Spawning <Role> agent — model: <model>
```

Every spawn — Developer, Reviewer, Integration, Reviewer-Integration, and each Finalizer Task — passes
`model` explicitly as an `Agent` tool parameter, from **Model Assignment** below, including roles whose
value matches the agent's default. That overrides the agent's own frontmatter `model:`, which is only its
standalone default; model selection lives in this one table, with one plug-in point per role.

### Model Assignment

Edit this table to change a model; nothing else needs to change. Values are tier aliases (`sonnet` /
`haiku` / `opus` / `fable`), which is all the `Agent` tool's `model` parameter accepts — never versioned
API strings. An alias resolves to that tier's current release, so a point release needs no edit here.

| Role / Task | Model (loop_count 1–2) | Escalated Model (loop_count 3) |
|------|-------|-------|
| Developer | `sonnet` | `opus` |
| Reviewer | `haiku` | `sonnet` |
| Board Parity Check (Step 1.3b) — `orchestrated-reviewer`, Parity Prompt | `sonnet` | `sonnet` |
| Integration | `sonnet` | `opus` |
| Reviewer-Integration | `haiku` | `sonnet` |
| Finalizer — Graphify | `haiku` | — (no retry loop) |
| Finalizer — PMBook Update | `sonnet` | — (no retry loop) |
| Finalizer — Handoff Update | `sonnet` | — (no retry loop) |
| Finalizer — Revision + Changelog | `haiku` | — (no retry loop) |
| Finalizer — Test Runbook | `sonnet` | — (no retry loop) |
| Finalizer — Commit Messages | `sonnet` | — (no retry loop) |
| Finalizer — Spike Log | `sonnet` | — (no retry loop) |

**Escalated Model applies only at loop_count == 3**, the last retry before a FAIL past 3 escalates to a
human (Steps 1.4 and 2.3); loop_count 1 and 2 use the base model. Finalizers and Spike spawns have no
retry loop, so never an Escalated Model.

---

## Workflow Overview

```
[START]
  │
  ▼
[INIT] Read PMBook → Detect Platform → Identify features for current phase
  │    (or: Bug Fix Intake → assign B-XXX → skip straight here — see Step 0.1b)
  │    (or: Spike Intake → assign S-XXX → skip straight here — see Step 0.1c)
  │    Step 0.0 also surfaces any Pending "## Deferred Integration" rows here (soft warning, never blocks)
  ▼
[FEATURE LOOP] For each work item — Feature, Bug, or Spike — (in dependency order):
  │
  ├──► [DEVELOPER AGENT] Implement + write tests + Format + Lint
  │         │
  │         ├── Type: Spike → Findings (no fixed target to review against)
  │         │         ▼
  │         │    [SPIKE LOG FINALIZER] writes one row to PMBook "## Spike Log" → next item
  │         │    (no Reviewer, no retry loop, no Integration, no escalation path — see Spike Flow)
  │         │
  │         ▼ (Type: Feature or Bug)
  │    [REVIEWER AGENT] Review against task packet
  │         │
  │    ┌────┴──────────┐
  │    │  Verdict?      │
  │    └────┬──────────┘
  │    PASS │  FAIL (loop_count += 1; ≤ 3) → Developer re-invoked with issues
  │         │  FAIL taking loop_count past 3 → ESCALATE TO HUMAN → PAUSE (type "resume" to continue)
  │         │  UNVERIFIED (≤2x, doesn't touch loop_count) → fix what's fixable → respawn Reviewer unchanged
  │         │  UNVERIFIED (3rd time) → ESCALATE TO HUMAN (Verification Blocked) → PAUSE (type "resume")
  │         │  PASS + Design Reference → [BOARD PARITY CHECK] (Step 1.3b) — FAIL re-enters the retry loop
  │         ▼
  │    Feature → PMBook: status → Done → next item
  │    Bug → [MANUAL VERIFICATION GATE] (Step 1.5) Orchestrator posts repro steps → PAUSE
  │              │
  │         ┌────┴─────────────────────┐
  │         │ user types "verified"    │ user reports still broken
  │         ▼                          ▼
  │    Priority: P0?                back into retry loop (loop_count += 1,
  │    │            │               same escalation past 3 as above)
  │    No           Yes
  │    ▼             ▼
  │  kept for   [P0 FAST-LANE FINALIZATION] the Phase 3 Finalizer batch, scoped to
  │  Step 3.2's  this bug only, runs NOW — Bug Log row: "Hotfixed — Integration
  │  Bug Log     Pending" + new "## Deferred Integration" row. Integration is
  │  write →     deferred, not skipped. → next item (does not end the run)
  │  next item
  │
  ▼
[INTEGRATION] All work items Done / manually verified and every P0 fast lane finished
              (fast-laned P0s are re-validated as Deferred IDs, not as work items):
  │
  ├──► [INTEGRATION AGENT] Full test suite + fix failures + audit + E2E + docs drift check
  │         │
  │         ▼
  │    [REVIEWER-INTEGRATION] Review integration output
  │         │
  │    ┌────┴──────────┐
  │    │  Verdict?      │
  │    └────┬──────────┘
  │    PASS │  FAIL (loop_count += 1; ≤ 3) → Integration re-invoked with issues
  │         │  FAIL taking loop_count past 3 → [DIVIDE-AND-CONQUER] split remaining failures into
  │         │      independent sub-problems → parallel scoped Integration sub-agents
  │         │      (Escalated Model, never commit) → one aggregate full-gate Integration
  │         │      pass → single Reviewer-Integration confirmation (doesn't increment loop_count)
  │         │        │
  │         │   ┌────┴────┐
  │         │   │  PASS?  │
  │         │   └────┬────┘
  │         │   YES  │  NO → ESCALATE TO HUMAN, scoped to still-failing sub-problems only
  │         │        │       → PAUSE (type "resume")
  │         │  UNVERIFIED (≤2x, doesn't touch loop_count) → fix what's fixable → respawn unchanged
  │         │  UNVERIFIED (3rd time) → ESCALATE TO HUMAN (Verification Blocked) → PAUSE (type "resume")
  │         ▼ (PASS, from either the direct path or Divide-and-Conquer)
[FINALIZE] The Step 3.1–3.5 Finalizers that apply, spawned in parallel (disjoint files, no ordering):
  │           Graphify | PMBook | Handoff | Revision+Changelog | Test Runbook
  │
  ▼ (all spawned Finalizers return — four if Graphify was skipped)
  [FINALIZER AGENT] Commit Messages — sequential, synthesizes the outputs above
  │
[CLOSE-OUT] metrics rows + run-state marked complete — always, even for a Spike-only or P0-only run
  │
[DONE]
```

Note: `[FINALIZE]` can fire more than once in a single run — once per P0 item that fast-lanes through
its own Finalization mid-loop, plus this final batch-end pass if any non-P0 items remain (see Output
Format for how the summary reports multiple Finalization blocks).

---

## Phase 0 — Initialization

### Step 0.0 — Verify Hard Dependencies

Before reading anything else, confirm these required inputs exist. Do not fabricate content or proceed on assumptions if one is missing.

**Hard dependencies (must exist before Phase 0 can proceed):**
- `project-management-doc` (PMBook) — source of features, acceptance criteria, and dependency order
- `source-code-directory` — needed for platform detection in Step 0.2
- `architecture-doc` — referenced in every Task Packet's Architecture Reference section

If any of these is missing or unresolvable, **stop and ask the user** for the correct path, or whether to create it, before continuing.

**Bug Fix Mode carve-out:** the three hard dependencies above must still exist as documents — a bug fix still needs a PMBook to log into, a codebase to detect platform from, and an architecture doc for context. What's carved out is narrower: the *bug itself* does not need to already be a row in the PMBook's Feature Backlog. An ad-hoc bug report handed to the Orchestrator directly (see **Bug Fix Intake**, Step 0.1b) skips straight to Phase 1 for that item; the Finalizer logs it into the PMBook retroactively in Phase 3 (see Step 3.2) so the governed docs remain the authoritative record even though the item didn't start there. The same carve-out applies to Spikes (see **Spike Intake**, Step 0.1c) — a spike question doesn't need a pre-existing PMBook row either.

**Order of the Step 0.0 checks:** hard dependencies, then the Resume check, then the Deferred Integration
check, then the Test Cases Doc checks. A resumed run skips the rest of Phase 0 and picks up at its saved
position, since its Phase 0 already ran. The Test Cases Doc checks run only on a PMBook entry (Step 0.1,
Features); on a Bug or Spike entry they are skipped, and Step 2.1 passes the doc's path if it exists, or
"None provided".

**Resume check:** immediately after the hard-dependency verification above, check whether `run-state-file`
exists and its run is not marked complete. If so, stop and ask explicitly before doing anything else:
"Found an incomplete run from `<timestamp>`, last at `<item>` — resume it, or start fresh?" Never resume
silently. On a confirmed resume, read `references/resume.md` first; it says where the run rejoins. If the file doesn't exist, or exists but
its run is already marked complete, proceed normally — this check never blocks a fresh invocation.
**Held intakes survive a new run:** before Step 0.4 writes the new file, the old file's
`decisions.heldForNextRun` packets — whether its run is complete or the user chose "start fresh" — are
announced and put into the new run's queue, where the next-free-ID scan sees them.

**Deferred Integration check:** after the Resume check above, scan `project-management-doc`
for a `## Deferred Integration` section (written by a prior run's P0 fast-lane Finalization — see **P0 Hotfix
Fast-Lane Finalization**; this run's own P0s are picked up when Step 2.1 re-reads it). If it has any row with `Status: Pending`, hold that finding — do not act on it
and do not block — for Step 0.4 to surface in the plan announcement.

**Soft dependencies (not required upfront — created/updated or drafted later):**
- `handoff-doc`, `changelog-file`, `revision-file`, `test-runbook-location` — created if absent when Phase 3 reaches them
- `test-cases-doc` — required by Phase 2; if missing at Step 0.0, the Orchestrator drafts it upfront (see below) rather than asking each run
- `snyk-command` — optional; if unset, fall back to the platform-default security audit command from Step 0.2
- `adr-directory` — only needed at Phase 2's Documentation Drift Check; if unset, skip the ADR-reference check and note the gap explicitly rather than guessing a default path
- `graphify-directories` — optional array of one or more code-root paths, used only by Step 3.1
  (Graphify) instead of `source-code-directory`, which stays the single path for platform detection and
  the Integration Agent's Source Directory. Unset → Step 3.1 uses `source-code-directory` as a one-entry
  list.
- `run-state-file` — convention `docs-directory/.orchestrator-run-state.json`; auto-created on first write, never asked about upfront. See **Run-State Checkpointing**.
- `metrics-log-file` — convention `docs-directory/orchestrator-metrics.md`; auto-created on first append, never asked about upfront. See **Pipeline Telemetry**.
- `artboards-directory` — optional; the folder of design boards the user interface is built to. Unset → no
  packet carries a `## Design Reference` and Step 1.3b never runs.
- **For UI packets (Step 1.3b), when `artboards-directory` is set:** `app-url` — the app's address as a
  pattern with the port offset in it, e.g. `http://localhost:{4200+offset}`, filled with **this checkout's**
  offset (from its stack config; never assume 0); `artboard-server` — how the boards are served;
  `parity-viewports` — layout widths to compare at (default `1440`). If `app-url` or `artboard-server` is
  missing when a UI packet is planned, **look in the repo before asking**: the root `CLAUDE.md`, the
  project's run skill (`.claude/skills/run/`), the stack config, and the README of whatever serves or
  tests against the boards. If both are found, use them, say where each came from in the Step 0.4
  announcement, and offer once (in the end-of-run summary, not mid-run) to write them into
  `.claude/SKILLS.md`. Only what the repo does not say is asked of the user — once, right after the
  Step 0.4 announcement and before Phase 1. The Parity Check is never skipped for want of a URL. Save
  the values in run-state's `decisions`; a resumed run that lacks them looks again, then asks, before
  Step 1.3b.

**Test Cases Doc checks.** A good doc has, for the current phase's features: at least one E2E or smoke
scenario per feature in scope; concrete, executable scenarios, not placeholders; edge cases and
regression-sensitive flows, not just happy paths.
- **Absent:** the Orchestrator drafts it now to that standard from the PMBook's Feature Backlog — the
  standing default, not a per-run question — saves it to the project's docs location, and registers the
  path as `test-cases-doc` for this run. Ask the user only if drafting is genuinely blocked (e.g. the
  PMBook has no features yet).
- **Present:** review it against that standard. If it looks thin or stale, tell the user what's missing
  and ask whether to proceed as-is, have the Orchestrator draft the missing scenarios, or pause so the
  user can fill the gaps. Never silently proceed with a doc judged inadequate.

### Step 0.1 — Read the PMBook

Read `project-management-doc`. Identify:
- The current active phase
- All features with status `Planned` or `In Progress` in that phase, in dependency order
- Acceptance criteria and dependencies for each feature

Features must be processed in dependency order — never start a feature before all its dependencies are `Done`.

### Step 0.1b — Bug Fix Intake (alternate entry point)

Triggered instead of Step 0.1 when the user has explicitly asked for the orchestrated pipeline on a bug —
e.g. "orchestrate a fix for X", "run the orchestrator on this bug" (see this skill's frontmatter
`description` for the exact bar; a plain "debug X" does not reach this skill at all — see
**Invocation boundary** above). Both entry points converge on the same Phase 1 Feature Loop —
this step only replaces *where the work item's content comes from*, not any downstream phase.

1. **Do not require a PMBook row.** Take the bug directly from the user: what's broken, how to reproduce
   it, expected vs. actual behavior, and (if known) the suspected files or component. If any of these is
   missing, ask — a Task Packet built from a vague report produces a vague fix.
2. **Assign a Bug ID.** Scan `project-management-doc` for the highest existing `B-XXX` (in its `## Bug Log`
   table, if one exists yet — see Step 3.2) **and** run-state's queue and `decisions.heldForNextRun` (IDs
   already assigned, not yet logged), and assign the next free number. If none exists, start at `B-001`.
   IDs are stable once assigned, same rule as `F-XXX`.
3. **Multiple bugs reported at once** are processed in the order given. Bugs don't carry PMBook dependency
   edges the way features do, so no dependency-order analysis is needed — but if two reported bugs are
   likely to touch the same files, say so and serialize them rather than risking colliding Developer
   spawns.
4. **Detect an explicit P0/hotfix signal** in the user's own words — "P0", "hotfix", "prod is down",
   "urgent, fast-track this" — and only then set `## Priority: P0` in the resulting Task Packet. Same bar
   as everywhere else in this skill: never inferred from how bad the bug sounds, only from the user
   actually saying so (see **Invocation boundary**). A P0 flag changes phase-sequencing after
   Step 1.5 only — see **P0 Hotfix Fast-Lane Finalization** — everything through the Review Loop and
   Manual Verification Gate stays identical to a normal Bug.
5. Proceed straight to Step 0.2 (Detect Platform) and Phase 1, generating a Bug-type Task Packet (see
   **Task Packet Format**) for each item. Skip Step 0.4's feature-list announcement in favor of a one-line
   equivalent: `Bug Fix Mode — B-XXX: <one-line description>` (or, for a P0, `Bug Fix Mode [P0] — B-XXX:
   <one-line description>`). Still print Step 0.4's `⚠ Deferred Integration outstanding` line under it
   when Step 0.0 found a Pending row, and still write `run-state-file` as Step 0.4 would (mid-run, see
   **Mid-run intake** instead).

**A design mismatch on a built screen** (the screen differs from its board): find the work item that built
that surface (the PMBook, or the Orchestrator's read-only `git log` on its files) and note it at intake;
**Pipeline Telemetry**'s `Mismatches reported after hand-over` cell says when its row is written.

### Step 0.1c — Spike Intake (alternate entry point)

Triggered instead of Step 0.1 when the user has explicitly asked for a spike — e.g. "spike this", "run a
spike on X", "let's explore Y" said as an explicit ask, not inferred from exploratory-sounding language
(see **Invocation boundary**). Converges into the same Phase 1 Feature Loop as every other entry
point, but the work item it produces exits that loop almost immediately — see **Spike Flow**, reached right
after the Developer Agent step instead of going to the Reviewer.

1. **Do not require a PMBook row.** Take the spike directly from the user: what question it's meant to
   answer, and any specific approaches to try (optional — "explore freely" is a valid answer). If the
   question itself is unclear, ask; a Spike Task Packet built from a vague question produces vague findings.
2. **Assign a Spike ID.** Scan `project-management-doc` for the highest existing `S-XXX` (in its `## Spike
   Log` table, if one exists yet — see Spike Flow's Finalizer step in `references/spike-and-p0.md`) **and**
   run-state's queue and `decisions.heldForNextRun` (IDs already assigned), and assign the next free number. If none exists, start at `S-001`. IDs are stable once assigned, same rule as `F-XXX` / `B-XXX`.
3. **Assign a Spike Directory.** Default to repo-root `spikes/S-XXX/` — outside every source root and test
   discovery path, with no test config of its own — unless the user specifies otherwise. The full gate and
   Graphify exclude it. This is not optional — see the Task Packet's `## Spike Directory` field and
   `orchestrated-developer`'s **Scoped Confinement for Spike-Type Packets** for why.
4. Proceed straight to Step 0.2 (Detect Platform) and Phase 1, generating a Spike-type Task Packet — read
   `references/spike-and-p0.md` now for its shape. Skip Step 0.4's feature-list announcement in favor of a one-line equivalent:
   `Spike Mode — S-XXX: <one-line question>`. As for a Bug, still print the `⚠ Deferred Integration
   outstanding` line when one is Pending, and still write `run-state-file` (mid-run, see **Mid-run intake**).

### Step 0.2 — Detect Platform

Probe `source-code-directory` for platform markers. Set the **Platform Profile** — injected into every task packet.

| Marker | Platform | Format | Lint | Test | Security audit |
|--------|----------|--------|------|------|----------------|
| `package.json` | Node / TypeScript | `npx prettier --write .` | `npm run lint` | `npm test` | `npm audit` |
| `pyproject.toml` / `requirements.txt` | Python | `ruff format .` or `black .` | `ruff check .` or `pylint` | `pytest` | `snyk-command` |
| `go.mod` | Go | `gofmt -w .` | `golangci-lint run` | `go test ./...` | `govulncheck ./...` |
| `Cargo.toml` | Rust | `cargo fmt` | `cargo clippy` | `cargo test` | `cargo audit` |
| `*.csproj` / `*.sln` | .NET | `dotnet format` | `dotnet build` | `dotnet test` | `dotnet list package --vulnerable` |

If no marker is found or multiple platforms are detected, **stop and ask the user to confirm the primary platform** before proceeding.

The `snyk-command` variable acts as an override for the security audit step when set.

### Step 0.3 — Detect Coding Conventions

Scan for convention files in `source-code-directory`: `.editorconfig`, `.prettierrc`, `pyproject.toml [tool.ruff]`, `.eslintrc`, `golangci.yml`, etc. Summarise the active conventions — included in every task packet, and saved in `run-state-file` (a resume uses the saved summary).

### Step 0.4 — Announce Plan

```
🎯 Orchestrator Initialized

Platform:  <detected platform>
Phase:     <current phase name from PMBook>
Features   (<N> total, in dependency order):
  1. F-XXX — <name>
  2. F-XXX — <name>
  ...

Developer Quality Gate (per feature):
  Format:  <command>
  Lint:    <command>

Integration Quality Gate (after all features):
  Test:    <command>   ← Integration Agent owns this + fixes failures
  Audit:   <command>

Estimated Spawns (N = <item count> items, plus fixed Integration/Finalization overhead):
  Best case:   <N_best> spawns   — no retries
  Typical:     ~<N_typ> spawns   — assumes ~30% of items need one retry
  Worst case:  <N_worst> spawns  — every item exhausts all 3 retries
  By tier:     Sonnet ~<X> · Haiku ~<Y> · Opus ~<Z> (Opus only if escalation occurs)
  (Static formula — see **Estimated Spawns** below. Not a dollar cost; tier counts only, consistent with
  Model Assignment's own tier-alias-over-versioned-pricing reasoning.)

⚠ Deferred Integration outstanding (<N> item(s)): B-XXX, B-YYY — hotfixed without a full-suite Integration
  run. Recommend running Integration on these soon. (Only shown if Step 0.0 found a Pending row; never
  blocks — see **Deferred Integration check**.)

Type STOP at any time to pause the orchestrator.
Proceeding with Feature Loop.
```

**Estimated Spawns** — a static formula; N = work items in this run's batch:

| Case | Spawns |
|---|---|
| Best | N × 2 (Developer + Reviewer, no retries) + 2 (Integration, Reviewer-Integration) + 6 Finalizers |
| Typical | Best × 1.3 (assumes ~30% of items need one retry; optionally use the observed rate from `metrics-log-file`) |
| Worst | N × 8 (Developer + Reviewer on the first try and each of 3 retries) + 4 Parity Check spawns per UI item + Integration 2 × 4 + 6 Finalizers + Divide-and-Conquer's spawns if it triggers |

Break the total down by tier from **Model Assignment**'s base models; Opus is shown only as a possibility
(loop_count 3), not counted into Best case.

---

## Phase 1 — Feature Loop

Repeat for each work item — Feature, Bug, or Spike — in dependency order (bugs from ad-hoc intake and
spikes typically have none). Track `loop_count` per item (starts at 0). The loop mechanics below are
identical for Feature and Bug; only the Task Packet's content differs (see **Task Packet Format**). A Spike
work item exits this loop immediately after Step 1.2 — see **Spike Flow**, reached instead of Step 1.3.

### Step 1.1 — Generate Task Packet

Produce a Task Packet for the feature (see **Task Packet Format** below). This is the single source of truth for both the Developer and Reviewer.

Save it to `<scratchpad>/runs/<run id>/packet-<ID>.md` (the path the Parity Prompt is given). If the
Orchestrator added anything to a PMBook-sourced packet (a Design Reference, a ruling), also store the full
packet in `run-state-file` — see **Run-State Checkpointing**.

**UI packets, when `artboards-directory` is set:** resolve the board that draws each surface the item
touches and fill the packet's `## Design Reference` — the board, the states to compare, and any ruled
deviations. The board is the specification: the Developer builds to it and never decides the design while
coding. If no board draws a surface, say so in the packet (`Compared against: Acceptance Criteria —
<surface> not drawn`): the Acceptance Criteria are the spec, and Step 1.3b compares against them. A new
layout with no board and no criteria that describe it fully goes to the user before the Developer is
spawned: the item halts (run-state saved) until the user either has the board drawn — the item then
resumes at this step — or rules "build to the Acceptance Criteria", which is recorded in `Ruled
deviations` with its date and the item proceeds.

### Step 1.2 — Invoke Developer Agent

Spawn a Developer sub-agent via the Agent tool with `subagent_type: "orchestrated-developer"` and `model: "sonnet"` (see **Model Assignment**), using the **Developer Agent Prompt Template** below, with the Task Packet substituted in full.

It returns a **Developer Output** in its agent's Output Template (Format and Lint must be PASS).

**A design ruling.** If the Developer's Assumptions raise a difference from the board (it cannot be
built as drawn, e.g. no Material slot for it), rule on it — the user rules when it changes what the user
sees beyond the board's intent. A ruling that accepts the difference becomes a `Ruled deviations` line
in the packet's `## Design Reference`, with its source (`orchestrator ruling, <date>` or
`user ruling, <date>`). Before the Reviewer spawn: **re-save the packet file** with that line, store the
full packet in `run-state-file`, and save the ruling in run-state's `decisions.rulings` (item, the
difference, the ruling, its source). The Reviewer and the Parity Check then read it from the packet.
Send the Developer back only when the ruling needs a code change; otherwise go straight to Step 1.3.

**`Type: Spike` carve-out:** skip Step 1.3 and Step 1.4 entirely — go straight to **Spike Flow** (below
Step 1.5) instead. There is no Reviewer spawn, no retry loop, and no Manual Verification Gate for a Spike;
its Developer Output is Findings, not a reviewable implementation.

### Step 1.3 — Invoke Reviewer Agent

Spawn a Reviewer sub-agent via the Agent tool with `subagent_type: "orchestrated-reviewer"` and `model: "haiku"` (see **Model Assignment**), using the **Reviewer Agent Prompt Template**, passing the original Task Packet and the Developer Output.

It returns its Output Template with Verdict `PASS`, `FAIL` (with Issues) or `UNVERIFIED` (with Unable to
Verify — see **Handling an UNVERIFIED Verdict** below).

### Step 1.3b — Board Parity Check (UI packets only)

**Runs after the code Reviewer's PASS, before the Manual Verification Gate and Integration.** Skip only
for a packet with no `## Design Reference`. Read `references/parity.md` now: it holds the Parity Prompt
and why the check is measured on the rendered screen.

1. **Bring up** the app (the way the repo's run skill or `CLAUDE.md` says) and the boards
   (`artboard-server`), and check both answer. Fill `app-url` with this checkout's port offset.
2. **Spawn** `subagent_type: "orchestrated-reviewer"`, `model: "sonnet"` (see **Model Assignment**), with
   the **Parity Prompt** (`references/parity.md`): the packet's saved path (Step 1.1), the app URL, the board URL, `parity-viewports`, and the folder
   `<scratchpad>/parity/<run id>/<ID>[-legN][-retryN]/` (`-legN` when run-state's `leg` > 1). A separate
   spawn: the code Reviewer stays narrow.
3. **It measures** every state in `States to compare` at every width, as the prompt says, and returns a
   Parity Table; screenshots and measurements stay in the parity folder.
4. **Verdict.** Any mismatch not covered by a `Ruled deviations` line is a **FAIL**. The mismatches go
   back into Step 1.4's loop as the issues list, under the same 3-strike rule: a Developer retry, then
   the code Reviewer, then this check again. In that retry's Reviewer Retry Context, mark each parity
   issue `verified by Step 1.3b, not by you`: the code Reviewer checks only its own issues, and this
   check re-runs the parity ones. UNVERIFIED (the app or board would not load) follows
   **Handling an UNVERIFIED Verdict**: it counts toward the item's same `unverified_count` and
   `unverifiedTotal` as the code Reviewer's, and the spawn repeated is this Parity Check. PASS → the item goes on as Step 1.4's "When verdict == `PASS`" says.
5. **Keep the Parity Table's path, with its unruled-mismatch count beside it,** in `run-state-file`.
   Step 1.5 attaches the table, and the metrics row sums the counts; the counts are cleared once that
   row is written, so a later leg counts only its own. Save run-state after every Parity verdict.
6. **Outside this item.** Differences the check returns under `Outside this item` are not mismatches:
   they do not touch the verdict, the issues list or the unruled-mismatch count, and no Developer
   retry fixes them. Check its sorting — a row whose element is rendered or styled by a file in the
   packet's `Files to Create or Modify` is this item's, and counts as an unruled mismatch. Save the rest
   in `run-state-file` under the item's `outsideItem` list, merged across retries (one entry per
   state + element). The final summary lists them, and offers once to log each as a new Bug in the
   PMBook, or as a design row when the board itself may be what is wrong. Nothing is logged without
   the user's yes.

### Handling an UNVERIFIED Verdict

Applies to every Reviewer spawn in this pipeline — the first review of a work item and every retry inside
Step 1.4's loop below alike, plus the Board Parity Check (Step 1.3b), which shares the item's counters,
and every Reviewer-Integration spawn in Phase 2. It never consumes the `loop_count` budget a real FAIL
does.

```
unverified_count = 0
WHILE verdict == UNVERIFIED:
  unverified_count += 1
  unverifiedTotal += 1   # per item, in run-state; zeroed when the item's metrics row is written — so it is this leg's metrics UNVERIFIED count

  IF unverified_count > 2:
    → ESCALATE (see **Escalation** — `references/escalation.md`) — flagged explicitly as
      "Reviewer could not complete verification," not as an implementation failure; include the
      Reviewer's last Unable to Verify report verbatim so the human knows what to unblock
    → STOP all activity until user types "resume"

  If the Reviewer's Unable to Verify report points at something the Orchestrator can fix directly (e.g. a
  wrong path in the Task Packet), fix it before respawning. Otherwise respawn unchanged.

  Spawn a fresh Reviewer Agent — same Task Packet, same Developer Output as the spawn that returned
  UNVERIFIED, model unchanged (an UNVERIFIED result doesn't trigger the Escalated Model — that's reserved
  for loop_count 3 on a real FAIL). This does NOT increment loop_count.
```

Once a Reviewer spawn actually returns `PASS` or `FAIL`, control passes to the ordinary loop below — the
UNVERIFIED handling above is a wrapper around each spawn, not a replacement for the retry loop.

### Step 1.4 — Review Loop

```
WHILE verdict == FAIL:
  IF loop_count == 3:   # the FAIL that takes loop_count past 3; loop_count stays 3 (recorded and reported as 3)
    → ESCALATE (see **Escalation** — `references/escalation.md`)
    → STOP all activity until user types "resume"

  loop_count += 1
  model = (loop_count == 3) ? Escalated Model : Base Model   # see Model Assignment

  Spawn Developer Agent with model = model, and:
    - Original Task Packet
    - Reviewer's issues list (fills the Developer Agent Prompt Template's "Reviewer Issues" section)
    - Previous Developer Output's file list (fills the "Previous Attempt" section)
    - Note: "Fix only the listed issues. Do not change anything else."

  Spawn Reviewer Agent with model = model, and:
    - Original Task Packet
    - New Developer Output
    - loop_count and the previous issues list (fills the Reviewer Agent Prompt Template's "Retry Context" section)
```

**Retry escalation:** loop_count 3 uses each role's Escalated Model — see **Model Assignment**.

When verdict == `PASS`: **a UI packet's code PASS is not the item's PASS** — run Step 1.3b first. A
Parity FAIL re-enters this loop with its mismatches as the issues list (`loop_count` goes up as for any
FAIL); the retry goes to the code Reviewer, then Step 1.3b again. Only a Parity PASS, or a packet with no
`## Design Reference`, goes on below. Every FAIL that sends the item back (a Reviewer FAIL, a Parity
FAIL, a Step 1.5 rejection) saves its run-state status `in progress`.

- Feature packet: status `passed review`; update PMBook feature status → `Done`; log `✅ F-XXX <name> — PASS after <N> iteration(s)`;
  this is the Feature's terminal `PASS` (metrics row, run-state); move to next work item
- Bug packet: status `awaiting verification` (a Bug never sits at `passed review`); **do not move to the next work item yet** — proceed to Step 1.5 (Manual Verification Gate).
  The Reviewer's PASS here only means the single regression test executes and passes (see the Reviewer
  Agent Prompt's bug-specific note and `orchestrated-reviewer`'s **Scoped Execution for Bug-Type Packets**);
  it is not yet confirmation that the reported symptom is actually gone for the user who hit it.

### Step 1.5 — Manual Verification Gate (Bug packets only)

Only reached when a Bug packet's Reviewer verdict is `PASS`. Features never pass through this step — they
go straight from Reviewer PASS to the next work item.

1. Post the gate to the user, including the Bug Report's reproduction steps verbatim so they don't have to
   go dig them back out of the Task Packet:

   ```
   🔍 Manual Verification Required — B-XXX <title>

   The regression test now passes (confirmed by the Reviewer by actually running it — see its Regression
   Test Execution output). Before this is treated as fixed, please verify it yourself:

   Reproduction steps:
   1. <from the Task Packet's Bug Report>
   2. ...

   Expected behavior: <from Bug Report>

   Parity (UI bugs only): what was compared, before you look —
   <the Step 1.3b Parity Table: State | Width | Element | Board | Built | Match | Ruling>
   Screenshots: <parity folder path>

   Reply "verified" once you've confirmed the fix, or describe what's still wrong to send it back to the
   Developer.
   ```

2. **PAUSE.** Run-state holds the item `awaiting verification` (saved at its PASS). Do not proceed to Integration, do not
   spawn anything else, until the user responds.

3. **On `verified`:** save status `verified`, then fork on the Task Packet's `## Priority` field.
   - **Not P0 (the default):** treat it the same as a Feature's Reviewer PASS from here — hold the fix in
     run-state as pending until Finalization, with its regression test path from the Developer Output's
     Test Files Written (Step 3.2 writes the `## Bug Log` row; no PMBook write happens here, since a bug
     may not have had a pre-existing row); this is the Bug's terminal `PASS`; log
     `🐛 B-XXX <title> — PASS after <N> iteration(s), manually verified`; move to the next work item.
   - **`Priority: P0`:** do NOT hold this fix for the batch's eventual Finalization — trigger **P0 Hotfix
     Fast-Lane Finalization** (below) immediately for this one item, then move to the next work item; when
     none remain and the run has no Feature and no non-P0 Bug, go to close-out (otherwise Phase 2).

4. **On a question:** answer it, then ask again for "verified" or what is still wrong. A question is not
   a rejection and changes no counter.

5. **On a report of a different, new bug:** that is a **Mid-run intake** (see **Invocation boundary**),
   not a rejection; ask again for "verified" on this one.

6. **On a reply that reports a failure** of this fix (or says it is not fixed): that is a rejection. If it carries no
   detail of what is wrong, ask once for it before re-spawning. The status goes back to `in progress`. This
   re-enters Step 1.4's retry loop exactly as a Reviewer FAIL would — the user's description becomes the issues list handed to a re-invoked Developer, `loop_count`
   increments, and the same escalation-to-human rule applies (the FAIL that takes `loop_count` past 3). There is no separate escalation
   path for this case; it consumes the same three-strike budget as an automated FAIL, because from the
   loop's perspective it is one — the only difference is who found the problem. A P0 is no different here.

### Spike Flow

Reached for any `Type: Spike` packet, immediately after Step 1.2's Developer spawn, instead of Step 1.3.
Read `references/spike-and-p0.md` and follow its **Spike Flow**. In short: no Reviewer, no retry loop, no
Manual Verification Gate, no Integration, no escalation; one solo Spike Log Finalizer, and the spike code
stays uncommitted in its Spike Directory.

### P0 Hotfix Fast-Lane Finalization

Triggered only from Step 1.5's `verified` branch, on a packet with `## Priority: P0`. Read
`references/spike-and-p0.md` and follow its **P0 Hotfix Fast-Lane Finalization**. In short: the Phase 3
Finalizer batch runs at once, scoped to that one Bug, writing its `## Bug Log` row as `Hotfixed —
Integration Pending` plus a `## Deferred Integration` row (Graphify skipped when the run's own Phase 3 will build it); then
the Feature Loop carries on.

---

## Phase 2 — Integration

Entered only when every Feature and non-P0 Bug in this run is at a terminal state (a Feature `Done` in
the PMBook, a non-P0 Bug `PASS` — its PMBook logging happens later, at Step 3.2; a `dropped` item is
excluded and does not count) **and** every P0 Bug is
verified with its fast lane (Finalizers, and the commit if the user asked for one) finished. A fast-laned
P0 is not one of this batch's work items: Step 2.1 re-reads its `## Deferred Integration` row, so it is
re-validated here as a Deferred ID. Spike items never reach Phase 2 at all (see Spike Flow). **When the run
has no Feature and no non-P0 Bug (`dropped` ones not counted), it skips Phases 2 and 3** and goes straight to close-out (the metrics rows
and run-state marked complete, at the 🏁 summary), which always runs.

### Step 2.1 — Invoke Integration Agent

Spawn an Integration sub-agent via the Agent tool with `subagent_type: "orchestrated-integration"` and `model: "sonnet"` (see **Model Assignment**), using the **Integration Agent Prompt Template**, passing:
- Platform Profile (all quality gate commands)
- List of all completed features (F-IDs, names, files changed) and verified non-P0 bugs (B-IDs, one-line description, files changed; a fast-laned P0 comes in only as a Deferred ID, below). "Files changed" is the item's run-state `files` (see **Run-State Checkpointing**)
- `source-code-directory`
- Path of `test-cases-doc`, if present (see Step 0.0 — this is a soft dependency; if absent, pass "None provided")
- Path of `architecture-doc` and `project-management-doc` — needed for the Documentation Drift Check
- Path of `test-runbook-location`, if present, or "None provided"
- Path of `adr-directory`, if present, or "None provided" — needed for the ADR-reference half of the Documentation Drift Check
- **`## Deferred Integration` — Pending Bug IDs, each with its regression test path** (from its Deferred
  row or Bug Log row), **its files changed and its commit ids** — for this run's P0s, the files from
  run-state (the item's `files` plus its lane Finalizers' files) and commit ids from
  `git log --grep "Run-Id: <run id>"` only when any exist; for an earlier run's, `git log --grep "<ID>"
  --name-only` — re-read from `project-management-doc` now (so it includes this run's fast-laned
  P0s, not only Step 0.0's finding), or "None provided." The Integration Agent must state in its
  Output which of these IDs it actually re-validated against the current working tree — never assume all
  of them were covered just because a full-suite run happened (see **Step 3.2**'s explicit-list resolution
  rule below).
- **`## Accepted Known-Reds`** — one line per test the user has ruled on (see **Known-reds**):
  `- <test> — accepted by the user` or `- <test> — tracked by <ID>`, or `None`. Passed on every
  Integration spawn: the first, every retry (normal or fresh-spawn), and every Divide-and-Conquer
  `## Sub-problem` and `## Aggregate pass` spawn.

**Pass paths, never inlined file contents** — the agent reads the documents itself.

### Documentation Drift Check

A **FAIL-worthy check**: drift is a defect like a broken test. What is checked is the Integration
template's "Documentation Drift Check — Specific Mapping for This Pipeline" section; findings come back
under the Integration Output's `Documentation Drift` section.

### Step 2.2 — Invoke Reviewer-Integration Agent

**First, settle untracked known-reds** (see **Known-reds** below).

Spawn a Reviewer-Integration sub-agent via the Agent tool with `subagent_type: "orchestrated-reviewer-integration"` and `model: "haiku"` (see **Model Assignment**), using the **Reviewer-Integration Agent Prompt Template**, passing the Integration Output, the condensed Task Packets of only the items under Features Completed /
Bugs Fixed (never a fast-laned P0 — that is a Deferred ID), the Platform Profile with its Test scope, the same doc paths Step 2.1 passed, the Deferred Integration IDs Step 2.1 passed (its `## Deferred Integration` section, or None), and the same `## Accepted Known-Reds` lines.

It returns Verdict `PASS`, `FAIL` (with Issues) or `UNVERIFIED` → **Handling an UNVERIFIED Verdict**.

### Step 2.3 — Integration Loop

Same logic as Phase 1, including the Escalated Model at loop_count 3 (see **Model Assignment**). Max 3
iterations before escalation to a human — except that loop_count 3's FAIL doesn't escalate immediately;
see **Divide-and-Conquer — Last Attempt Before Escalation** below, which runs first.

On re-invocation, the Integration Agent receives loop_count, the Reviewer-Integration's issues list, its `## Accepted Known-Reds`, and its own prior Integration Output (fills the Integration Agent Prompt Template's "Retry Context" section) and addresses only those issues. The prior Integration Output tells the fresh spawn what was already fixed and what the Documentation Drift Check already found, so it re-runs the quality gate (code changed, so this must be re-verified for real) without repeating the full drift analysis for sections the previous pass already cleared. The Reviewer-Integration Agent likewise receives loop_count and its own previous issues list on each re-review (fills its Prompt Template's "Retry Context" section).

### Divide-and-Conquer — Last Attempt Before Escalation

On the Reviewer-Integration `FAIL` that takes Integration's loop_count past 3, do not escalate yet:
read `references/escalation.md` and run its **Divide-and-Conquer** first. It runs at most once per batch.

### Known-reds

A line under the Integration Output's `### Known-Reds` is a failure this run did not cause. It does not
make Overall Status FAIL, so it can pass silently unless the Orchestrator acts on it. This skill has no
component map: a known-red's owner is the top-level folder or module under `source-code-directory` that
holds the test.

**A `— untracked` line pauses the run** before any Reviewer-Integration spawn. Ask the user, per test:
raise a tracking item (the line becomes `— tracked by <new ID>`) or accept it (`— accepted by the user`).
Save each answer in run-state's `decisions` as given — for "raise a tracking item", with the `OI-NNN` the
Orchestrator assigns (the next free number in that PMBook) — before any PMBook write. Then it writes that item into `project-management-doc`'s `## Open Items` (creating the section if absent),
the ID at the start of the row's Item cell (`Item: OI-NNN — <test> …`), **before** any
Reviewer-Integration spawn, which looks the ID up there (an Open Items row already naming that test is
reused, not duplicated); then it rewrites that line in the Integration Output it holds. The ruled tests form the
`## Accepted Known-Reds` lines (`- <test> — accepted by the user` / `- <test> — tracked by <ID>`) that
every later Integration and Reviewer-Integration prompt carries. List every known-red, as its line
reads, in the 🏁 final summary and in the Integration row of `metrics-log-file`.

---

## Phase 3 — Finalization

Only entered when Reviewer-Integration returns `PASS` — **except** a P0 Bug's own fast-lane Finalization
(see **P0 Hotfix Fast-Lane Finalization**, under Step 1.5), which runs this exact same Steps 3.1–3.6
sequence early, scoped to that single Bug, before Phase 2 has run for it at all. And except Spike, which
never reaches this phase — it gets the single **Spike Log** Task instead (see **Spike Flow**). Steps 3.1–3.5 write to disjoint files/paths
and none of them reads another's output, so **the Step 3.1–3.5 Finalizers that apply (four when Graphify
is skipped) are spawned in parallel** — `Agent` tool calls in a single message, each an
`orchestrated-finalizer` with its `model` from **Model Assignment**. Step 3.6 has a real dependency on them (it needs
their combined file lists to draft accurate commit messages, and must know to stage the Graphify outputs),
so it is spawned once more, alone, only after every Finalizer spawned in 3.1–3.5 returns.

For each parallel spawn, use the **Finalizer Agent Prompt** template below with the stated Task and
Task-Specific Inputs. None of them write code or run tests — that boundary stays with
Developer/Integration — they only touch governed docs, the knowledge graph, and (for 3.6) drafted text.

**Release label — decided once, before the spawn.** The PMBook Finalizer writes `Fixed In <label>` while
the Changelog Finalizer writes the entry under that label, at the same time — so neither may pick it.
Before spawning, read `changelog-file`: if it keeps an `[Unreleased]` section, the label is `Unreleased`;
otherwise take the newest released version and bump it (minor for any Feature, patch for Bugs only).
Save it in run-state's `decisions` under its scope (`phase3`, or `lane:<ID>` for a P0 fast lane); a resume
reuses that scope's label and never re-decides it. Pass the same label to Steps
3.2 and 3.4 as `Release label: <label>`, and print it. The Changelog
Finalizer uses that heading and creates it if `changelog-file` lacks it; it never chooses a version itself.

### Step 3.1 — Graphify

**Mandatory and automatic — do not wait for the user to invoke it, and do not skip it** (the one skip
is no code change in the graphed paths, below).

Spawn a Finalizer sub-agent via the Agent tool with `subagent_type: "orchestrated-finalizer"` and `model: "haiku"` (see **Model Assignment**), using the **Finalizer Agent Prompt** template, with:
- **Task:** `Graphify`
- **Task-Specific Inputs:** which route builds the graph (below), with the exact command for route 1;
  `graphify-directories` (or `source-code-directory`, wrapped as a one-entry list, if
  `graphify-directories` is unset) — the array of path(s) to scope the graph to; for route 3, whether
  `graphify-out/graph.json` already exists (first run vs. `--update`)

**Scope: the Finalizer must pass `graphify-directories` (falling back to `source-code-directory`) as
graphify's path(s), never the project root, and never a Spike Directory (`spikes/`).** Left unscoped, graphify defaults to the current
directory, which also holds `docs-directory`, `adr-directory`, and the PRD/Architecture/PMBook/handoff/
changelog files this pipeline maintains. This automatic, per-feature invocation is a code-structure
graph, not a corpus-wide one — pulling planning docs into it on every feature adds noise (product
rationale mixed into architecture nodes) and cost (re-extracting prose that didn't change) to a step
that runs after every single feature. If the user wants a combined code+docs graph, that's a deliberate
manual `/graphify` run over the project root, not this automatic one.

**How the graph is built — pick the first that applies:**

1. **The repo's own graph script.** If the repo has one (e.g. `scripts/graph.ps1`, or a `make graph`
   target), name its exact command and the Finalizer runs that and nothing else — the script builds and
   stamps the report. That keeps the pipeline and the team building the graph the same way.
2. **No script, more than one path → the graphify command line, per path.** For each changed path in
   order (every path when `graphify-out/graph.json` does not exist yet; an unchanged path's nodes stay in
   the graph): `graphify update <path>` with the environment variable `GRAPHIFY_OUT` set to the
   **absolute** path of
   `graphify-out/` (a relative value resolves against the scanned folder and scatters stray output
   folders). It re-extracts code with no LLM and merges each path into the same graph: a later update of one path keeps the other's nodes. **Never the `/graphify` skill once per
   path:** the skill keeps one scan root per output folder, so a later `--update` can drop an earlier
   path.
3. **No script, one path → the `/graphify` skill**, scoped to that path, with `--update` when
   `graphify-out/graph.json` already exists from a prior Finalization.

**Runs only when code in the graphed paths changed.** Before Phase 3, for each path in
`graphify-directories` (or `source-code-directory`) run `git status --porcelain -- <path>`. A path
counts as changed if it prints anything **or** holds a file that `git log --grep "Run-Id: <run id>"
--name-only` lists (a commit made earlier in this run). If no path counts as changed, spawn no
Finalizer for this Task and print `Graphify: skipped — no change in <paths>`. Otherwise pass the
changed paths in the Task-Specific Inputs: route 2 runs only those when `graphify-out/graph.json`
already exists. **Never spawned at all for a Spike** — see **Spike Flow**'s single
Spike Log Task. **For a P0 fast lane**, when it runs or skips is in `references/spike-and-p0.md` (step 3).

### Step 3.2 — Update PMBook

Spawn a Finalizer sub-agent via the Agent tool with `subagent_type: "orchestrated-finalizer"` and `model: "sonnet"` (see **Model Assignment**), using the **Finalizer Agent Prompt** template, with:
- **Task:** `PMBook Update`
- **Task-Specific Inputs:** Features Completed list (F-IDs, names), Bugs Fixed list — the verified non-P0
  bugs (a fast-laned P0 is handled only as a Deferred ID; in its own fast lane, that P0) — (B-IDs, one-line
  description, files changed, and `Regression test: <path>` per bug, from its Developer Output's Test
  Files Written), `Release label: <label>`, `P0 fast lane: <B-ID>,
  Hotfixed On <date>` when this is a P0 fast lane, the Integration Output's `Deferred Integration
  Re-Validated` list (when Phase 2 ran), and — if the Integration Output's **Flaky Tests Detected**
  section is non-empty — that list of test names; `project-management-doc` path

The Finalizer confirms completed features are `Done`, marks the phase complete if warranted, resolves
addressed open items, and runs the Tranche-boundary check — but it cannot talk to the user directly, so a
detected Tranche boundary comes back under its Output's **Notes**, not as a live message. If Notes reports
one, **the Orchestrator** tells the user the PMBook has reached a Tranche boundary and that
`idea-triage`'s Tranche Closeout procedure is available before the next round of feature work begins.
Archiving itself is never performed here — `project-management-doc`'s format and lifecycle (the `Tranche`
header, the `## Closed Tranches` table) are owned by `idea-triage`, not this pipeline.

**Bug logging:** for each item in the Bugs Fixed list, the Finalizer writes a row to a `## Bug Log` table
in `project-management-doc` — `ID | Description | Reported | Status | Fixed In`, Status `Fixed`, the
regression test path in the Description so a later Integration can run it — creating that section
(after `## Feature Backlog`) if it doesn't exist yet. This applies whether the bug started as a PMBook
entry or arrived through ad-hoc **Bug Fix Intake** (Step 0.1b): either way, once fixed it must exist in the
governed PMBook, since that's the durable record this pipeline relies on, not the Orchestrator's own
context. The Bug Log is a section this pipeline owns and appends to; it does not interact with
`idea-triage`'s Tranche mechanics the way the Feature Backlog does. `## Spike Log` rows are never written
here — that's the separate solo **Spike Log** Finalizer Task (see Spike Flow), since Spike bypasses this
step's normal batch invocation entirely.

**Deferred Integration logging:** this same PMBook Update Task also owns `## Deferred Integration` —
folded in here rather than given its own parallel Finalizer Task, since both write to
`project-management-doc` and running them as separate concurrent spawns would violate the disjoint-file
guarantee every other Phase 3 step relies on (see `orchestrated-finalizer.md`'s Parallel-Safety
Discipline). Two cases:
- **New hotfix** (this invocation is a **P0 Hotfix Fast-Lane Finalization**): append a row — `Bug ID |
  Hotfixed On | Status: Pending`, with the regression test path — alongside that Bug Log row's
  `Hotfixed — Integration Pending` status.
- **Later batch's Integration passed**: if the Integration Output's `Deferred Integration Re-Validated`
  list names IDs, flip exactly those rows' `Status` to `Resolved` and their matching Bug Log rows'
  `Status` to `Fixed`. Never blanket-flip every
  `Pending` row just because an Integration run happened — only the ones the Integration Agent explicitly
  confirmed it re-checked against the current working tree.

**Flaky-test logging:** if the Integration Agent's Output (see Step 2.1) listed any entries under **Flaky
Tests Detected**, this same PMBook Update Task writes one `## Open Items` row per test — `Owner:
unassigned | Item: Investigate flaky test <name>`, carrying the entry's wording verbatim (`<test>: failed
in full run, passed in isolated re-run of <command>; locators/waits read, no cause found`) — reusing the Open Items table the PMBook format already
defines, creating the section if it doesn't exist yet. (A known-red's tracking item is written by the
Orchestrator in Phase 2, not here — same row shape, its Item cell starting with its `OI-NNN`; see
**Known-reds**.) A flaky test is never logged anywhere else and
never left unlogged; this is the one place it reaches the durable record.

### Step 3.3 — Update Handoff Doc

Spawn a Finalizer sub-agent via the Agent tool with `subagent_type: "orchestrated-finalizer"` and `model: "sonnet"` (see **Model Assignment**), using the **Finalizer Agent Prompt** template, with:
- **Task:** `Handoff Update`
- **Task-Specific Inputs:** Features Completed list + implementation notes, and Bugs Fixed list + root cause notes; `handoff-doc` path

### Step 3.4 — Update Revision + Changelog

Spawn a Finalizer sub-agent via the Agent tool with `subagent_type: "orchestrated-finalizer"` and `model: "haiku"` (see **Model Assignment**), using the **Finalizer Agent Prompt** template, with:
- **Task:** `Revision + Changelog`
- **Task-Specific Inputs:** Features Completed list and Bugs Fixed list; `Release label: <label>`; `revision-file` and `changelog-file` paths

### Step 3.5 — Update Test Runbook

Spawn a Finalizer sub-agent via the Agent tool with `subagent_type: "orchestrated-finalizer"` and `model: "sonnet"` (see **Model Assignment**), using the **Finalizer Agent Prompt** template, with:
- **Task:** `Test Runbook`
- **Task-Specific Inputs:** Features Completed list + their Test Expectations, and Bugs Fixed list + their
  reproduction steps (the manual verification for a bug fix is walking the original repro steps and
  confirming the bug no longer occurs); `test-runbook-location` path (create if absent)

### Step 3.6 — Commit step: draft the messages (the Finalizer never executes git), then commit

Only after every Finalizer spawned in 3.1–3.5 has returned (in a P0 fast lane, its own lane's), spawn one more Finalizer sub-agent via the Agent tool with `subagent_type: "orchestrated-finalizer"` and `model: "sonnet"` (see **Model Assignment**), using the **Finalizer Agent Prompt** template, with:

- **Task:** `Commit Messages`
- **Task-Specific Inputs:** the commit step's file list (below), verbatim, and the trailers every
  message must end with: `Run-Id: <run id>` and `Items: <ids in that group>`

**The commit step** is this Task plus the commit. The Orchestrator commits only as run-state's
`decisions.commit` says: `yes` → commit, `no` → don't, `ask` (or unset) → ask the user and save the answer
first. **Its file list** is the step's full staging set, saved in run-state: in Phase 3, every in-scope
item's `files`, the `integration` block's `files`, every Finalizer's Files Created or Modified,
and run-state's `orchestratorFiles`; in a P0
lane, that Bug's `files` plus its lane Finalizers' files. It commits whatever of that list `git status`
still shows uncommitted, grouped as usual; a group with nothing left uncommitted is skipped. Before
committing it runs `git diff --cached --name-only`: staged paths all in this step's file list are
committed with it; any staged path outside that list stops the step and asks the user. A "commit" said
after a commit step chose `no` first sets `decisions.commit: yes` (saved), then runs **one** commit pass
over the union of every commit step's saved file list in this run: each item (Feature, Bug, P0) gets its
own code group from its own `files`, with `Items:` naming only that item; governed docs, any file shared
by more than one item, and every file in no item's code group (e.g. an Integration fix outside any item,
the graph report) go in one docs/chore group whose `Items:` lists every item. One Commit Messages
Finalizer drafts the messages for these regrouped groups first, with the trailers. Then it refreshes the
RUN row's commit ids. Run-state keeps no commit ids; git
log stays the record for the RUN row's commit ids, Step 3.1's roots and Deferred evidence.

---

## Task Packet Format

`Type` selects the shape. A **Bug** swaps `## Acceptance Criteria` for `## Bug Report`, strengthens
`## Note on Tests` and may carry `## Priority: P0`. A **Spike** has no Acceptance Criteria and adds a
mandatory `## Spike Directory`; its shape is in `references/spike-and-p0.md`.

```markdown
# Task Packet: F-XXX — <Feature Name>

## Type
Feature

## Feature ID
F-XXX

## Description
<one paragraph: what this feature does and why it exists>

## Acceptance Criteria
<numbered list, taken directly from PMBook — these are the pass/fail conditions>

## Files to Create or Modify
<Orchestrator's best estimate based on architecture-doc; Developer may deviate with justification>

## Dependencies
<features or modules already implemented that this feature builds on>

## Platform
<platform name>

## Developer Quality Gate
- Format: <command>
- Lint:   <command>

## Note on Tests
Write the test files. Do NOT run the test suite — test execution is the Integration Agent's responsibility.

## Coding Conventions
<summary from Step 0.3>

## Architecture Reference
See: architecture-doc — <relevant section IDs or component names>

## Design Reference
<Omit this whole section when the work item touches no user interface, or `artboards-directory` is unset.>
Board (the visual contract for this work): artboards-directory/<Surface>.<ext> — or
  "Compared against: Acceptance Criteria — <surface> not drawn". Build to it; do not change it.
States to compare: <the board states this item must match — populated, empty, loading, error, full
  view, and each dialog and menu it touches>
Ruled deviations: <each accepted difference from the board, with its source: a design row ID, or a
  user ruling with its date — or "None". Only these may differ; anything else fails>
Standing acceptance criterion (every UI packet): The built screen matches the board in every listed
  state; the Parity Table (Step 1.3b) shows no unruled mismatch.

## Constraints
<constraints from PRD or Architecture that apply>

## Test Expectations
- Unit tests must cover: <list>
- Edge cases to test: <list>
- Test file location convention: <e.g. tests/, __tests__/, *_test.go>

## Expected Output (for Reviewer)
<what must exist after the Developer is done — Reviewer checks this>
```

```markdown
# Task Packet: B-XXX — <Bug Title>

## Type
Bug

## Bug ID
B-XXX

## Priority
<omit entirely for a normal bug; set to exactly `P0` only when the user explicitly said so — see Step
0.1b's P0-detection bullet. Never inferred from how severe the description sounds.>

## Description
<one paragraph: user-visible symptom and impact>

## Bug Report
- Reproduction steps: <numbered, concrete>
- Expected behavior: <what should happen>
- Actual behavior: <what happens instead>
- Suspected files/component (if known): <from the user report, else "Unknown — Developer to locate">
- Root cause (if already known): <else "Unknown — Developer to diagnose">

## Files to Create or Modify
<Orchestrator's best guess from the suspected component, if any; Developer may deviate with justification>

## Dependencies
<none, unless the bug is blocked on another in-flight fix>

## Platform
<platform name>

## Developer Quality Gate
- Format: <command>
- Lint:   <command>

## Note on Tests
Write a regression test that reproduces the bug — it must fail against the pre-fix code and pass once the
fix is applied. Do NOT run the full test suite — test execution is the Integration Agent's responsibility.
State explicitly which assertion is the one that would have caught this bug.
Regression test: <path, if the Orchestrator can name it — else "Developer names it under Test Files
  Written; the Reviewer takes the path from there">
Test command (that one test only): <the platform Test command narrowed to one test, e.g.
  `pytest <path>::<name>`, `npx jest <path> -t "<name>"`, `dotnet test --filter <name>`>

## Coding Conventions
<summary from Step 0.3>

## Architecture Reference
See: architecture-doc — <relevant section IDs or component names, if applicable>

## Design Reference
<Omit this whole section when the bug touches no user interface. Same shape as the Feature packet's.>

## Constraints
<constraints from PRD or Architecture that apply>

## Expected Output (for Reviewer)
Bug no longer reproduces per the steps above, root cause is identified (not just the symptom patched),
and a regression test exists that fails without the fix.
```

---

## Sub-Agent Prompt Templates

**Ordering convention:** content that is byte-identical between a first attempt and its retry comes
first; anything that only exists on a retry (Reviewer Issues, Previous Attempt, Retry Context) is
appended at the very end, so a first-attempt prompt is a strict prefix of its retry's prompt and prompt
caching can reuse it.

**Rules live in the agent files.** Each spawned agent already has its `agents/orchestrated-*.md` as its
system prompt, including its orchestrated-mode rules and Output Template. A template below carries only
inputs and the pipeline rules its agent file does not state; do not add a rule here that the agent file
already holds.

### Developer Agent Prompt

```
You are operating in **orchestrated mode**.

## Task Packet
<INSERT FULL TASK PACKET>

## Pipeline-Specific Boundaries (in addition to your operating discipline)

Run exactly the Format and Lint commands in the Task Packet's Developer Quality Gate. Both must pass
before you return; fix any failures.

## Return Format

Use exactly your own Output Template (with its Spike substitution for a `Type: Spike` packet).

## Reviewer Issues (present whenever Previous Issues exist — a retry, or a resume after escalation; omit otherwise)
<INSERT REVIEWER'S ISSUES LIST, or the escalation's issues on a resume>
Fix only the issues listed above and nothing else.

## Previous Attempt (present whenever a previous Developer Output exists — a retry, or a resume after escalation; omit otherwise)
<INSERT PREVIOUS DEVELOPER OUTPUT'S "Files Created or Modified" LIST>
You are a fresh spawn with no memory of building this — the list above is exactly what the prior attempt
touched. Start there instead of re-exploring the codebase.
```

---

### Reviewer Agent Prompt

```
You are operating in **orchestrated mode**.

## Task Packet
<INSERT FULL TASK PACKET>

## Pipeline-Specific Note

If `Type` is `Bug`: besides running the named regression test (your own **Scoped Execution for Bug-Type
Packets**), check the fix addresses the stated root cause rather than papering over the symptom (e.g.
suppressing an exception instead of preventing it) — flag a symptom-only patch as an issue even if the
test passes. A Manual Verification Gate with the user follows your PASS (the Orchestrator's Step 1.5);
your job is the regression test, not the user's view of the symptom.

If the Task Packet carries a `## Design Reference`, check the code against it: that every state in
`States to compare` is built, and nothing the board draws is missing. Report any divergence you can see
in the code as an issue. "The board looks out of date" is not a defence. **A static read does not
satisfy the design check.** You may PASS the code, but the item is not done until the Board Parity Check
(Step 1.3b) measures the rendered screen and passes. Do not claim the screen matches the board.

## Return Format

Use exactly your own Output Template.

## Developer Output
<INSERT DEVELOPER OUTPUT>

## Retry Context
loop_count: <INSERT N — 0 if this is the first review of this feature>
Previous Issues (whenever they exist — a retry, or a resume after escalation): <INSERT PREVIOUS ISSUES
LIST, keeping any `verified by Step 1.3b, not by you` marks, or "None — first review">
```

---

### Parity Prompt (Step 1.3b)

In `references/parity.md`.

---

### Integration Agent Prompt

```
You are operating in **orchestrated mode**.

## Platform Profile
<INSERT PLATFORM PROFILE>

## Features Completed
<INSERT LIST: F-ID, name, files changed>

## Bugs Fixed
<INSERT LIST: B-ID, one-line description, files changed — or "None this phase">

## Source Directory
<INSERT source-code-directory>
Spike Directories (`spikes/`) are out of scope: the full gate excludes them.

## Module Map
None — a known-red's owner is the top-level folder or module under the Source Directory that holds the
test.

## Test Cases Doc
<INSERT test-cases-doc path, or "None provided">

## Architecture Doc
<INSERT architecture-doc path>

## PMBook
<INSERT project-management-doc path>

## Test Runbook
<INSERT test-runbook-location path, or "None provided">

## ADRs
<INSERT adr-directory path, or "None provided">

Read the documents above yourself — you were given paths, not contents.

## Deferred Integration
<INSERT Pending Bug IDs from PMBook's "## Deferred Integration" section, each with its regression test
path, files changed and commit ids, or "None provided">
If any IDs are listed, re-validate each against the current working tree in this run.

## Accepted Known-Reds
<INSERT one line per test the user ruled on: `- <test> — accepted by the user` or
`- <test> — tracked by <ID>`, or "None">

## Documentation Drift Check — Specific Mapping for This Pipeline
- Does the Architecture Doc still describe every component that now exists in the source tree, including
  its inline `mermaid` diagrams?
- Does the PMBook's Acceptance Criteria for each `Done` feature in this batch match what the code
  actually does?
- For a bug in this batch that already had a `## Bug Log` row before this run: does that row accurately
  describe the fix — does the code no longer reproduce the logged symptom? This batch's new Bug Log rows
  are written at Step 3.2, after you; their absence is not drift.
- Does the Test Runbook cover the flows introduced by these features (if a runbook path was given)?
- If an ADRs path was given: does every ADR ID cited in the Architecture Doc's Technology Decisions table
  exist in adr-directory, and is it still the active (non-superseded) one?

## Retry Context (present whenever Previous Issues exist — a retry, or a resume after escalation; omit otherwise)
loop_count: <INSERT N>
Previous Issues: <INSERT REVIEWER-INTEGRATION'S ISSUES LIST, or the escalation's issues on a resume>
Previous Integration Output: <INSERT PRIOR INTEGRATION OUTPUT — Quality Gate Results / Fixes Applied / Documentation Drift / Unresolvable Issues>
Re-run the quality gate for real (code may have changed), but treat drift sections your prior pass
already cleared as still clear unless a Previous Issue reopens one.

## Sub-problem (only present on a Divide-and-Conquer spawn — omit otherwise)
Failing tests in scope: <INSERT>
Files you may touch: <INSERT>

## Aggregate pass (only present on Divide-and-Conquer's aggregate spawn — omit otherwise)
```

---

### Reviewer-Integration Agent Prompt

```
You are operating in **orchestrated mode**.

## Task Packets (all completed features and fixed bugs, condensed)
<INSERT, PER ITEM: ID (F-XXX or B-XXX), Name/Title, Platform, and — Feature: Acceptance Criteria only;
Bug: Bug Report's Expected/Actual behavior only. Drop every other packet field; this role does not use
them.>

## Platform Profile
<INSERT PLATFORM PROFILE, including Test scope: full>

## Doc Paths
Test cases: <path or "None provided"> · Architecture: <path> · PMBook: <path> ·
Test runbook: <path or "None provided"> · ADRs: <path or "None provided">

## Deferred Integration
<INSERT the IDs given at Step 2.1 (the Integration prompt's `## Deferred Integration`), or "None">

## Accepted Known-Reds
<INSERT the same lines the Integration prompt carried, or "None">
A `tracked by <ID>` item lives in `## Open Items` of the PMBook path under Doc Paths.

## Return Format

Use exactly your own Output Template.

## Integration Output
<INSERT INTEGRATION OUTPUT>

## Retry Context
loop_count: <INSERT N — 0 if this is the first review>
Previous Issues (whenever they exist — a retry, or a resume after escalation): <INSERT PREVIOUS ISSUES
LIST, or "None — first review">
```

---

### Finalizer Agent Prompt

Used for every Phase 3, Spike Log and P0 fast-lane Finalizer spawn: one template, with only the Task and
Task-Specific Inputs changing.

```
You are operating in **orchestrated mode**.

## Task
<INSERT EXACTLY ONE OF: Graphify | PMBook Update | Handoff Update | Revision + Changelog | Test Runbook | Commit Messages | Spike Log>

Run ID: <INSERT run id>
Scope: <INSERT lane:<ID> | phase3 | spike:<ID>>

## Features Completed
<INSERT LIST: F-ID, name, files changed — or "N/A, this is a Spike Log Task" if Task is Spike Log>

## Bugs Fixed
<INSERT LIST: B-ID, one-line description, files changed, `Regression test: <path>` — or "None this
phase", or "N/A, this is a Spike Log Task" if Task is Spike Log>

## Spike Completed (only present when Task is Spike Log)
<INSERT: S-ID, Question, Spike Directory, Files Created, and the Developer's Findings/recommendation
verbatim; `project-management-doc` path>

## Task-Specific Inputs
<INSERT — see the matching Phase 3 step (3.1–3.6) above, or Spike Flow's Finalizer step in
references/spike-and-p0.md, for exactly what this Task receives; for Commit Messages specifically, this
is the commit step's file list (Step 3.6), verbatim>
```

---

## Escalation

Three situations pause for a human: `loop_count` passes 3 on a real FAIL (any work item, or
Integration; Integration: only after Divide-and-Conquer, or when its failures can't be split); a Reviewer or Reviewer-Integration returns `UNVERIFIED` a third time in a row; or
Divide-and-Conquer's confirmation pass still fails. When one is reached, read `references/escalation.md`:
it says what to save and record before posting its matching report, and how "resume" proceeds. An explicit user "drop" or "defer" of an escalated (or any) item sets its status
`dropped`, saved at once with the event time: terminal, excluded from Phase 2's entry rule and the resume rules, and listed
in the 🏁 summary; its one metrics row (Verdict `Dropped`, Timestamp that saved event time) is written then. Every pause ends with `⏸ Orchestrator is PAUSED. Waiting for
instruction.`, and nothing resumes until the user types "resume" or gives an explicit instruction. Spike
work items never reach this.

---

## Enforcement Rules

- NEVER begin Phase 0 without verifying the hard dependencies (Step 0.0)
- NEVER write code as the Orchestrator — all code is written by sub-agents
- NEVER skip a phase for a Feature or non-P0 Bug; the named exceptions are Spike (Spike Flow), a run with no Feature and no non-P0 Bug (Phase 2 entry), and a P0's fast lane (P0 Hotfix Fast-Lane Finalization)
- NEVER advance past a FAIL verdict without a re-run or escalation
- NEVER exceed 3 loop iterations without escalating (Step 1.4, Escalation)
- NEVER retry at loop_count 3 on the base model (Model Assignment)
- NEVER run graphify before Integration passes, except in a P0 fast lane (`references/spike-and-p0.md`)
- NEVER skip the Step 3.1 Graphify Finalizer, except its no-change skip (Step 3.1)
- NEVER leave Step 3.1 unscoped — always pass `graphify-directories` or `source-code-directory` (Step 3.1)
- NEVER run git beyond **Git Restrictions**
- NEVER let a Documentation Drift finding pass silently — resolved or justified under Unresolvable Issues (Documentation Drift Check)
- NEVER treat `architecture-doc`, `project-management-doc`, `handoff-doc`, or ADR files as side artifacts exempt from review — they live in the project's git repository and go through the same PR review as code
- NEVER spawn the Step 3.6 Commit Messages Finalizer before every 3.1–3.5 Finalizer has returned (Step 3.6)
- NEVER let a Finalizer's `Notes` go unread — surface them in the summary (Step 3.2, Output Format)
- NEVER accept a Bug's regression test on the Developer's word — the Reviewer runs it (Step 1.4, `orchestrated-reviewer`)
- NEVER ask a Reviewer to run beyond `orchestrated-reviewer`'s **What You May Run**
- NEVER let a Bug skip Step 1.5's Manual Verification Gate (Step 1.5)
- NEVER treat a "still broken" at Step 1.5 as anything but a FAIL into Step 1.4's loop (Step 1.5)
- NEVER let a Bug skip its `## Bug Log` row at Step 3.2, ad-hoc intake included (Step 3.2)
- NEVER let UNVERIFIED increment `loop_count` (Handling an UNVERIFIED Verdict)
- NEVER treat UNVERIFIED as PASS or FAIL — respawn per Handling an UNVERIFIED Verdict
- NEVER run Divide-and-Conquer more than once per batch, or other than on the FAIL past 3 (`references/escalation.md`)
- NEVER let a Divide-and-Conquer sub-agent commit or leave its sub-problem (`references/escalation.md`)
- NEVER let a Spike write outside its `## Spike Directory` (`orchestrated-developer`'s Scoped Confinement)
- NEVER spawn a Reviewer, Integration or Phase 3 batch for a Spike — only its Spike Log (Spike Flow)
- NEVER treat a Spike's Developer Output as reviewed or shippable (`references/spike-and-p0.md`)
- NEVER let a P0 skip Step 1.4's loop or Step 1.5's gate — it defers only Integration (Step 0.1b)
- NEVER leave a Pending `## Deferred Integration` row unsurfaced (Steps 0.0, 0.4)
- ALWAYS write a P0's Bug Log row as `Hotfixed — Integration Pending` with its Deferred Integration row (`references/spike-and-p0.md`)
- ALWAYS process work items in dependency order (Steps 0.1, 0.1b, 0.1c)
- ALWAYS generate a Task Packet with the right `Type` before any spawn (Step 1.1, Task Packet Format)
- ALWAYS log features, bugs and spikes to the PMBook (Steps 1.4, 3.2, Spike Flow)
- ALWAYS stop and ask if a required tool call is denied
- ALWAYS spawn the applicable 3.1–3.5 Finalizers in parallel in one message (Phase 3)
- ALWAYS pass an explicit `model` from **Model Assignment** on every spawn (Roles)
- ALWAYS print the model announcement before every spawn (Roles)
- ALWAYS spawn each role via its dedicated `subagent_type` (Roles)
- ALWAYS save `run-state-file` at every step start and end, verdict and user decision (Run-State Checkpointing)
- NEVER resume a stale `run-state-file` without explicit user confirmation (Step 0.0)
- ALWAYS append a `metrics-log-file` row at each terminal state and the `RUN` row at the summary (Pipeline Telemetry)
- NEVER classify a failing test as a defect without the isolated re-run triage (`orchestrated-integration`'s triage protocol; Step 3.2 logs flaky tests)
- NEVER let a known-red pass silently (Known-reds)
- NEVER let a detected flaky test go unlogged (Step 3.2)

---

## Git Restrictions

The Orchestrator never runs: `git push`, `git merge`, `git checkout main`, or any destructive git operation, and never `git commit` unprompted. The git commands it runs are read-only — `git log` (Phase 0's run-id check, Steps 0.1b, 2.1, 3.1, 3.6, and `git log --grep "Run-Id: <run id>"` for the RUN row's commit ids at close-out and at an escalation pause) and `git status --porcelain` (Steps 3.1, 3.6) and `git diff --cached --name-only` (Step 3.6's staged check) — plus `git add` and `git commit` with the drafted messages in Step 3.6's commit step once the user has said "commit". Every commit message ends with the `Run-Id:` and `Items:` trailers, so `git log --grep "Run-Id: <run id>"` is the run's commit record.

Never create or switch branches — ask the user, provide the command.

---

## Run-State Checkpointing

`run-state-file` lets a fresh session pick an interrupted run back up. **The Orchestrator writes it
directly** (`Write`/`Edit`, no sub-agent); this is bookkeeping, not code.

**Units and steps.** A unit is a work-item attempt, a P0 lane, Phase 2, or Phase 3. Each unit records
only its current `step` and `state: started | done`. A P0 lane's and Phase 3's steps are Finalizers →
commit (Step 3.6: messages drafted, then the commit) → done; Divide-and-Conquer's stages are Phase 2 steps.

**Content:** run id (`<YYYY-MM-DD>-<first item id, lowercased>-<HHmm>` from the start time, set at
Phase 0; if that id is already in `metrics-log-file` or `git log --grep "Run-Id: <id>"`, add `-2`, `-3`…)
and start time, the
Platform Profile, the Step 0.3 coding-conventions summary, the ordered queue (ID + Type), the current
item index, each unit's `step` and `state`, and each item's and phase's start/finish times (ISO 8601 with
offset — **Pipeline Telemetry** is computed from them), and the event time of each metrics row, saved
before the row is written. Plus the outputs of `done` steps that later steps
read. Per item: `status` (`in progress | passed review | awaiting verification | verified | findings
recorded | escalated | dropped`, saved at each change: `in progress` when the item starts, on any FAIL
or rejection that sends it back (Reviewer FAIL, Parity FAIL, Step 1.5 rejection) and on escalation
resume; a Feature's final PASS (a UI packet: after Parity PASS) → `passed review`; a Bug's PASS →
`awaiting verification` (never `passed review`), then Step 1.5's "verified" → `verified`; Spike Log →
`findings recorded`; escalation → `escalated`; an explicit user "drop" or "defer" → `dropped`; the
resume rules in `references/resume.md` read it),
`loop_count`, last verdict, `unverifiedTotal` (UNVERIFIED verdicts since its last metrics
row), `priorLoops` (loop counts from legs before an escalation), `leg` (1, plus 1 per escalation resume),
`files` (the union of Files Created or Modified across all its Developer Outputs, every attempt and leg;
every "files changed" this skill passes reads it),
a verified Bug's regression test path, each Parity table path with its unruled-mismatch count (cleared
with `unverifiedTotal` once the metrics row is written), the latest Developer Output, and the last Issues
list and Unable to Verify report. An `integration` block: `loop_count`, `unverifiedTotal`, `priorLoops`,
the latest Integration Output, `files` (the union of changed files across every Integration pass and
every Divide-and-Conquer sub-problem spawn), and `divideAndConquer: not run | running | confirmation pass | done`. At
every escalation, the `escalated` status (the `integration` block's `escalated: true`), that metrics
row's Final loop_count (`escalationFinalLoopCount`, so a re-run writes the same value), `loopCountAtEscalation`, and on Report 2 `blockedGate: reviewer | parity |
reviewer-integration` (per item and in the `integration` block). A `done` Finalizers step keeps its
Finalizers' Files Created or Modified lists; the commit step saves its full file list (Step 3.6).
`orchestratorFiles`: every governed file the Orchestrator itself writes (the test-cases doc draft, a
known-red tracking item's PMBook row, …), appended when written. Only IDs persist for PMBook-sourced Features,
unless the Orchestrator added to the packet (a Design Reference, a ruling); then the full packet is kept,
as it always is for Bug and Spike intake items (no PMBook row to regenerate from).

**One `decisions` block**, written the moment the user (or the Orchestrator) decides, before acting on it:
`commit: yes | no | ask`; the Release label per scope (`lane:<ID>`, `phase3` — each scope reuses only its
own); the accepted known-reds, with any tracking ruling's assigned `OI-NNN`; `heldForNextRun` (full
packets of mid-run intakes held because Phase 2 had started — counted in the next-free-ID scan, announced
at resume and at close-out, and seeding the next run's queue); the `app-url` / `artboard-server`
answers; and `rulings` (Step 1.2's design rulings).

**One file, replaced by each new run.** A new run writes over the last one's file once that run is
complete. That is intended: the file exists for resume, and a complete run has nothing to resume. The
finished run's record is its `metrics-log-file` rows and its commits (`Run-Id:` trailer), not this file.

**When it is saved:** when each step starts and when it ends; at every Developer return and every
verdict (so every `loop_count` change); at every user decision; when a Bug enters `awaiting
verification`; at every terminal state and escalation; and at close-out, marked complete with the
"🏁 Orchestrator Complete" summary. A file marked complete never triggers the Step 0.0 resume check.

**Repeat-safe writes.** A step re-run after a crash may repeat a write, so every governed-doc write
checks for an entry for the same item ID (and run id and scope, where the doc carries them) and updates it instead
of adding a second — the Finalizers' writes and the Orchestrator's own: a known-red tracking item reuses
an Open Items row already naming that test; metrics rows are write-once (see **Pipeline Telemetry**).

**Resuming:** on a confirmed resume, read `references/resume.md` first; it says where the run rejoins.

---

## Pipeline Telemetry

`metrics-log-file` (convention `docs-directory/orchestrator-metrics.md`, soft dependency — see Step 0.0)
is the evidence for tuning the Model Assignment table — models per role, when to escalate. This skill
does not analyze the log; it only writes it. **Written directly by the Orchestrator**, no sub-agent
spawn, appended and never overwritten. Every row kind uses this one header:

`| Timestamp | Run ID | Item ID | Type | Wave | Started | Finished | Final loop_count | Escalated? | UNVERIFIED count | Verdict | Test scope | Divide-and-Conquer triggered? | Known-reds | Phase times | Parity mismatches caught | Mismatches reported after hand-over |`

**Row kinds.** One per work item that reached a terminal state; one with `Item ID: Integration`, only if
Phase 2 ran; one with `Item ID: RUN`, always, written at the 🏁 final summary. Every cell is filled — `—`
where it does not apply. **Every row** (item, Integration, RUN, Mismatch, Paused or Complete) takes its
Timestamp from the event time the Orchestrator saves in run-state before writing it (an event time
already saved is reused on a re-run, never read again). **Rows are write-once:** a row with the same
Run ID, Item ID and Timestamp already in the log is left unchanged (a re-run skips it). The only later
edit is the RUN row's commit ids (below).

**Terminal states** (also used by **Run-State Checkpointing**): `PASS` (a Feature: on its Reviewer PASS,
after Step 1.3b's PASS for a UI packet; a Bug: after the user's "verified"), `Escalated` (paused for a
human — the row is appended at that moment, right after run-state saves the event time and the
`escalated` status), `Findings recorded` (a Spike), `Dropped` (an explicit user "drop" or "defer" — the
row is written when the drop is saved, with its saved event time). A resumed escalated item
gets a second row when it reaches its next terminal state.

**Close-out always runs** — Spike-only and P0-only runs included: append a row for each item (and
Integration) that has no row for its current leg (a `Dropped` row counts; a resumed escalated item or a resumed Integration adds one), the
`RUN` row (Verdict `Complete`), announce any `decisions.heldForNextRun` items and every item's
`outsideItem` entries (Step 1.3b point 6, with the offer to log them), and mark run-state complete. An escalation pause is not close-out: it
writes the rows so far plus a `RUN` row with Verdict `Paused (escalation)`, and saves run-state **without**
marking it complete, so Step 0.0's resume check still fires. When the resumed run finishes, its close-out
appends a second `RUN` row, `Complete`.

**Cells:**
- `Run ID` — run-state's run id (format in **Run-State Checkpointing**).
  `Timestamp`, `Started`, `Finished` — ISO 8601 with offset (`2026-11-10T14:05:00+11:00`), read from the
  clock, never estimated; `Timestamp` is the saved event time.
- `Wave` — `—`: this skill runs one item at a time.
- `Final loop_count` — this leg's count, on every row (an Escalated row included): `loop_count` minus
  run-state's `loopCountAtEscalation` (0 when never escalated), read before an escalation overwrites it;
  an Escalated row uses the saved `escalationFinalLoopCount`, so a re-run writes the same value.
- `Escalated?` — `Yes` only for an escalation per `references/escalation.md`; a user ruling goes in
  `Verdict`, not here.
- `UNVERIFIED count` — this leg's count: the item's (or the `integration` block's) `unverifiedTotal`,
  UNVERIFIED verdicts since its last row. Zero it once the row is written.
- `Test scope` — Integration row only: `full` (this skill always runs the full suite).
  `Divide-and-Conquer triggered?` and `Known-reds` (each `### Known-Reds` line's test and its tracked-by
  ID or `accepted by the user`, or `none`) — Integration row only.
- **`RUN` row:** written at the 🏁 summary (Verdict `Complete`) or at an escalation pause (Verdict
  `Paused (escalation)`). Type `Run`; Wave, Final loop_count, Escalated? and UNVERIFIED count `—`;
  Started / Finished = the run's start and end (or the pause). Commit ids come from git, `git log --grep
  "Run-Id: <run id>"`: when the RUN row is written, and again after each later commit, set
  ` — commits <ids>` on this run's latest RUN row's Verdict cell (never another run's row).
- `Phase times` — RUN row only: `P0 <t> · P1 <t> · MV <t> · P2 <t> · P3 <t>` (MV = the Manual
  Verification wait), `n/a` for a phase that did not run.
- `Parity mismatches caught` — the sum of the unruled-mismatch counts run-state keeps for this leg's
  Step 1.3b runs (`n/a` for a non-UI item). Clear them once the row is written, as for `unverifiedTotal`.
- `Mismatches reported after hand-over` — starts at `0`. When Bug Fix Intake (Step 0.1b) takes a design
  mismatch on a surface an item built, it notes the mismatch at intake and writes nothing until Step 0.4
  has created run-state and saved the event time (so Run ID and Timestamp exist); then it appends (rows
  are write-once, so the building item's own row is never edited) a row: `Item ID: <ID>`, Type
  `Mismatch`, Timestamp the saved event time, Run ID of the run doing the intake, Mismatches reported after hand-over `1`,
  Verdict `mismatch reported after hand-over`, other cells `—`. It should trend to zero; if
  it does not, the Parity Check is missing something — raise it with the user.

**Header rule.** Create the file with the header on first append. If it exists with a different header,
never rewrite old rows (beyond the RUN row's commit ids above): add `### From <YYYY-MM-DD>` with the current header and append there. Before
appending, re-read that header and check each row you write has exactly 17 cells.

**Immediate payoff independent of the log file itself:** reuse the same in-memory counters this section
tracks to add one line to the final "🏁 Orchestrator Complete" summary (Output Format), e.g. `Retries this
run: 2/5 items needed a retry, 0 escalations` — useful on the very first run, before any cross-run history
exists in `metrics-log-file`.

---

## Output Format

**After each feature:**
```
✅ F-XXX — <name> | PASS after <N> iteration(s)
   Files:  <list>
   Tests written: <N files>
```

**After each bug fix:**
```
🐛 B-XXX — <title> | PASS after <N> iteration(s)
   Files:  <list>
   Regression test written: <path>
```

**After each P0 hotfix's fast-lane Finalization** (in addition to the 🐛 line above, immediately after it):
```
🚑 B-XXX — P0 Fast-Lane Finalization complete
   Status: Hotfixed — Integration Pending
   Deferred Integration row added — full-suite validation still owed
```

**After each spike:**
```
🔎 S-XXX — <question> | Findings recorded
   Spike Directory: <path>
   Recommendation: <promote to backlog / abandon / needs more investigation>
```

**After all work items (before integration):**
```
📦 Feature Loop Complete

Features:  F-XXX, F-XXX, F-XXX
Bugs:      B-XXX, B-XXX (or "None this phase")
Starting integration validation...
```

**After integration:**
```
✅ Integration — PASS after <N> iteration(s)
   Fixes applied: <N>
   Tests: <N passed>
```

**Final summary:**
```
🏁 Orchestrator Complete

Phase:            <phase name>
Features shipped: F-XXX, F-XXX, F-XXX
Bugs fixed:       B-XXX, B-XXX (or "None this phase")
P0 hotfixes:      B-XXX — status as it stands after Step 3.2 (Integration Pending, or Fixed if this
                  run's Integration re-validated it) (or "None this run")
Spikes run:       S-XXX (or "None this run")
Dropped:          F-XXX / B-XXX — dropped or deferred by the user (or "None")
Outside items:    <ID> — <state, element: board vs built> — log as Bug / design row? (one per line; or "None")
Quality gate:     ✅
Integration:      ✅ (or "Not run — the run has no Feature and no non-P0 Bug")
Known-reds:       <test> — owner <module> — tracked by <ID> / accepted by the user (one per line; or "None")
Retries this run: <N1>/<N2> items needed a retry, <N3> escalations
Finalization:     ✅ (<N> parallel + 1 sequential Finalizer)
                  (+ 1 additional Finalization block per P0 hotfix above, run mid-loop — see its own
                  🚑 line; + 1 solo Spike Log Task per spike above — see its own 🔎 line)

📝 Commit Messages
<one per logical group — includes each P0 fast lane's own Commit Messages output, not just the batch-end
one>

📍 Impacted Areas
<modules, files, APIs>

🔎 Smoke Tests
1. <happy path>
2. <edge case>
3. <regression-sensitive flow>
```

If any Deferred Integration items remain `Pending` after this run (a P0 hotfixed this run, or one carried
over from a prior run that this batch's Integration didn't happen to cover), list them explicitly here
too — see Step 0.0's Deferred Integration check for where that finding originates.

If any Finalizer's `Notes` field reported something (a Tranche boundary, a skipped soft dependency, a
deviation), add it here explicitly rather than letting it disappear once the summary is assembled:

```
📋 Finalization Notes
- <Task>: <what was flagged>
```
(omit this section only if every Finalizer's Notes was genuinely "None")
