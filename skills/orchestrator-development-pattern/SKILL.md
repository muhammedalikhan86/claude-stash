---
name: orchestrator-development-pattern
description: Multi-agent development orchestrator for PMBook-driven features, orchestrated bug fixes (including P0/hotfix fast lanes) and exploratory spikes. Invoke only when the user explicitly wants the full Developer→Reviewer→Integration→Finalization pipeline run end-to-end (e.g. "orchestrate a fix for X", "run the orchestrator on this bug", "build this from the PMBook", "spike this", "this is a P0", "hotfix this") — not for a plain "debug X" / "fix this" question, which is a normal debugging conversation or a job for debugging-wizard. Reads the PMBook (or an ad-hoc bug report), detects the platform, and runs developer + reviewer sub-agent pairs in a loop (max 3 retries before human escalation); an integration agent then runs the full test suite and fixes build health, and parallel Finalizers update docs, changelog, graph and commit messages. A Spike skips the Reviewer/Integration gates; a P0 Bug fast-lanes to its own Finalization. Language and platform agnostic.
license: MIT
metadata:
  author: https://github.com/mak100186
  version: "2.16.1"
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
    design-directory,
    design-rows-directory,
    design-rounds-directory,
    app-url,
    artboard-server,
    parity-viewports,
    parity-command,
    known-red-baseline
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
An end-to-end check that waits on another item is carried in that other item's Acceptance Criteria
(the item that lands last proves the whole path), never parked as Deferred Integration, which is for P0
fast lanes only.

## Key design principles

- **Developers write tests and may run only their packet's `Tests you may run`, never the suite.**
  Several Developers may run in parallel against an incomplete codebase, so suite results would be
  unreliable; the Integration Agent owns test execution, test fixing and build health.
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
[INIT] Read PMBook → Detect Platform → Identify features for current phase → Baseline test run (Step 0.3b)
  │    (or: Bug Fix Intake → assign B-XXX → skip straight here — see Step 0.1b)
  │    (or: Spike Intake → assign S-XXX → skip straight here — see Step 0.1c)
  │    Step 0.0 also surfaces any Pending "## Deferred Integration" rows here (soft warning, never blocks)
  ▼
[FEATURE LOOP] For each work item — Feature, Bug, or Spike — (in dependency order):
  │
  ├──► [DEVELOPER AGENT] Implement + write tests + Format + Lint
  │         │   (Mode: review-only → no Developer; the Orchestrator's Build Record goes to the Reviewer)
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
  │    Feature → run-state: passed review → next item (PMBook Done is written at Step 3.2)
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
**Finished, close-out missed:** if every item in that file is terminal (a Feature `passed review`, a Bug `verified`, a Spike `findings recorded`, or `dropped`; a legacy item status `done` from an older run-state file counts as terminal), and no phase or P0 lane is `started`, it is not a run to resume. Ask instead: "Run `<run id>` finished but its close-out never ran — run its close-out now, or mark it complete?" Do that (Step 3.6's close-out lines, or just mark it complete) before this run goes on. **Start fresh never loses an item:** before Step 0.4 replaces the file, name every item in it that is not terminal (`in progress`, `awaiting verification`, `escalated`) with its `parkedAt` folder, and put each into the new run's queue — its packet from `parkedAt`, or re-derived from its PMBook row — unless the user drops it. **Rejoining from a park folder:** the item's packet, latest output, last verdict and `loop_count` come from its `parkedAt` folder (`park.json`), and it rejoins at the gate it was parked at, as `references/resume.md` §Resuming after an escalation says. Also list any `.orchestrator-work/<ID>/` folder that no run-state entry names (a file replaced by an older version of this skill) and offer it the same way.
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
  packet carries a `## Design Reference` and Step 1.3b never runs. Boards are read from here, as synced.
- `design-directory`, `design-rows-directory`, `design-rounds-directory` — optional; the design folder's
  row ledgers and round files (`~/.claude/skills/sync-artboards/references/design-files.md`). Read and written by Step 0.3c and Phase 3's **Design rows owed**.
- **For UI packets (Step 1.3b), when `artboards-directory` is set:** `app-url` — the app's address as a
  pattern with the port offset in it, e.g. `http://localhost:{4200+offset}`, filled with **this checkout's**
  offset (from its stack config; never assume 0); `artboard-server` — how the boards are served;
  `parity-viewports` — layout widths to compare at (default `1440`); `parity-command` — optional, the repo's checked-in parity harness, e.g.
  `npx playwright test business-tests/layout/parity.spec.ts`; set, the Parity Check runs or extends it
  instead of writing a script; unset, it looks for an existing parity or layout spec first.
  If `app-url` or `artboard-server` is
  missing when a UI packet is planned, **look in the repo before asking**: the root `CLAUDE.md`, the
  project's run skill (`.claude/skills/run/`), the stack config, and the README of whatever serves or
  tests against the boards. Read the same sources for a parity harness when `parity-command` is unset
  (a parity or layout spec they name), and use one found the same way. If both are found, use them, say where each came from in the Step 0.4
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
- **Thin, but a work item in this run exists to write or extend those test cases:** do not ask — that
  item fills the gap. Save it in run-state's `decisions` (`testCasesDoc: thin — filled by <ID>`), say so
  in the Step 0.4 announcement, and go on.

### Step 0.1 — Read the PMBook

Read `project-management-doc`. Identify:
- The current active phase
- All features with status `Planned` or `In Progress` in that phase, in dependency order
- Any item the user names as **review-only** — built outside this loop, its code already in the tree —
  whatever its PMBook status. Its packet gets `## Mode: review-only` (see **Review-only items** under
  Step 1.2).
- Acceptance criteria and dependencies for each feature

Features must be processed in dependency order — never start a feature before all its dependencies are `Done` in the PMBook or passed review earlier in this run.

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
   run-state's queue and `decisions.heldForNextRun` (IDs already assigned), and assign the next free number. If none exists, start at `S-001`. IDs are stable once assigned, same rule as `F-XXX` / `B-XXX`. **A planned spike** — a PMBook row typed `Spike` (in the Feature Backlog or elsewhere) — keeps that row's ID; never mint a new one for it. Its question and done-when come from the row.
3. **Assign a Spike Directory.** Default to repo-root `spikes/S-XXX/` — outside every source root and test
   discovery path, with no test config of its own — unless the user specifies otherwise. The full gate and
   Graphify exclude it. This is not optional — see the Task Packet's `## Spike Directory` field and
   `orchestrated-developer`'s **Scoped Confinement for Spike-Type Packets** for why. If `spikes/` is not in `.gitignore`, say so once and suggest the line (init adds it); until then stage every commit by path so the spike code never rides along.
4. Proceed straight to Step 0.2 (Detect Platform) and Phase 1, generating a Spike-type Task Packet — read
   `references/spike-and-p0.md` now for its shape. Skip Step 0.4's feature-list announcement in favor of a one-line equivalent:
   `Spike Mode — S-XXX: <one-line question>`. As for a Bug, still print the `⚠ Deferred Integration
   outstanding` line when one is Pending, and still write `run-state-file` (mid-run, see **Mid-run intake**).

### Step 0.2 — Detect Platform

Probe `source-code-directory` for platform markers. Set the **Platform Profile** — injected into every task packet.

| Marker | Platform | Format (fix · verify) | Lint | Test | Security audit |
|--------|----------|--------|------|------|----------------|
| `package.json` | Node / TypeScript | `npx prettier --write <files>` · `npx prettier --check <files>` | `npm run lint` | `npm test` | `npm audit` |
| `pyproject.toml` / `requirements.txt` | Python | `ruff format <files>` · `ruff format --check <files>` (or `black` / `black --check`) | `ruff check .` or `pylint` | `pytest` | `snyk-command` |
| `go.mod` | Go | `gofmt -w <files>` · `gofmt -l <files>` (any output fails) | `golangci-lint run` | `go test ./...` | `govulncheck ./...` |
| `Cargo.toml` | Rust | `rustfmt <files>` · `rustfmt --check <files>` | `cargo clippy` | `cargo test` | `cargo audit` |
| `*.csproj` / `*.sln` | .NET | `dotnet format <sln\|proj> --include <files>` · `dotnet format <sln\|proj> --verify-no-changes --include <files>` | `dotnet build` | `dotnet test` | `dotnet list package --vulnerable` |

**Format is scoped to the item's changed files, never the whole repo.** `<files>` is the files the
Developer created or changed. A repo-wide format rewrites files nobody touched (line endings, old style)
and drags them into the diff. The Developer runs the fix form, then the verify form; the verify form is
the gate — it must exit non-zero on a difference. A fix form alone is not a gate: `dotnet format`
without `--verify-no-changes` never fails.

**A scoped test command must actually scope.** Before putting one in a packet, check it once with a list-only run (Jest `--listTests`, `dotnet test --list-tests`). Through Nx, the runner's flags go after `--`: `npx nx test <project> -- --testPathPattern=<pattern>`; without the `--`, Nx runs the whole project. Quote a pattern that holds `|`, `(` or `\` (`--testPathPattern="(a|b)\.spec\.ts"`), or pass plain file paths; unquoted, the shell mangles it and the whole suite runs.

If no marker is found or multiple platforms are detected, **stop and ask the user to confirm the primary platform** before proceeding.

The `snyk-command` variable acts as an override for the security audit step when set.

### Step 0.3 — Detect Coding Conventions

Scan for convention files in `source-code-directory`: `.editorconfig`, `.prettierrc`, `pyproject.toml [tool.ruff]`, `.eslintrc`, `golangci.yml`, etc. Summarise the active conventions — included in every task packet, and saved in `run-state-file` (a resume uses the saved summary).

### Step 0.3b — Baseline Test Run

Before any spawn, run the Platform Profile's Test command once on the tree as this run found it, so a
test that was already red is never mistaken for this run's regression. Bring the app up first if the
tests need it (the repo's run skill or `CLAUDE.md`). **The first `up` may be slow** (a cold build cache, e.g. a federated front end's first build): wait longer on the first start, and if it times out, retry it once before calling the stack failed.

1. Run it. For each test that fails, re-run that one test alone once: it passes → `flaky`; it fails
   again → `fails`.
2. Save the result in run-state as `baseline`: the time it ran and `reds` — one entry per test, with
   how it failed (`fails`, `flaky`, or `timeout`, plus the message's first line).
3. Print it in the Step 0.4 announcement: `Baseline: <N> red at start — <test (how)>, …` or
   `Baseline: green`.
4. **Skip it** for a run that holds only P0 Bugs and Spikes (say `Baseline: skipped — P0/Spike-only
   run`), for a mid-run intake (the run already has one), and on a resume (the saved one is reused).
5. **An item whose code is already in the tree** (a carried-over or rejoined item, e.g. from `parkedAt`):
reuse its old run's saved baseline when there is one. Otherwise, if that code is committed, take the
baseline in a temporary `git worktree` of the last commit before it (removed afterwards); if it is not
committed, run on the tree as it is and print `Baseline: includes <ID>'s uncommitted change`. Never
stash, reset or check out over the user's tree to get a baseline.
6. **A suite that needs the running stack** (business or e2e tests) and can't be brought up for the
baseline may take the repo's documented baseline (root `CLAUDE.md`'s figure) instead: print
`Baseline: <suite> — documented figure from <file>, not run`. Every other suite runs fresh.

The baseline is evidence, not a ruling. Step 2.1 passes `baseline.reds` to Integration as
`## Known Reds at Baseline`; what happens to each is in **Known-reds**.

### Step 0.3c — Design Rows Hold (UI items only)

Runs before the plan is announced, when `artboards-directory` is set and a planned item changes what
a user sees. The design folder, its rows and rounds, and their rules are in `~/.claude/skills/sync-artboards/references/design-files.md` — read it first.
Shaw work: rows and round prompts carry the board rules in `~/.claude/skills/shaw-estate/references/ui.md` §Design boards
(real Material components on the boards, never plain controls).
Only for boards an outside designer owns (the design README says so, or `design-source` is
bound); when the repo draws its own boards, skip this step — Step 1.1 settles them.

1. **Old layout.** If the artboards folder holds `review-<page>.md` ledgers and `design-rows-directory`
   is unset or empty, say so once, point to `~/.claude/skills/sync-artboards/references/migrate-design-layout.md`, and suggest the move — never make it. For this run,
   read the rows from those ledgers (same IDs; `Done, checked <date>` counts as Done) and write any new
   row into them, with the prompt at the end, as that repo already does.
2. **Find each UI item's rows:** the IDs its Acceptance Criteria name (`Design rows: …`), plus any row
   whose Source names the item.
3. **Any of them not `Done` → hold the item.** It leaves this run's queue, with every item that depends
   on it; the other items go on. Save it in run-state's `decisions.designHolds` (item, its open rows,
   their round and that round's status), and list it in the announcement under `Held for design:`. A held
   item is not escalated or dropped, and its PMBook row is not touched. The next run (or a resume after
   the user says the round is synced) checks it again.
4. **No rows, and the item needs a new or changed layout no board draws → write them.** Add the rows to
   the open round per `~/.claude/skills/sync-artboards/references/design-files.md` (next IDs for the screen's letter, Source the item and its criterion, Round
   `open`; a new round file if the last one was sent), rewrite the round's Summary and Detailed prompt,
   and hold the item as in 3. Show both texts, Summary first, and tell the user: send the round to the
   designer, then run `sync-artboards` when the designer is done. Do not mark the round sent.
5. **A change the Acceptance Criteria fully describe** (a label, a tooltip, a state of an existing
   control) does not hold: it goes on with the criteria as its spec (Step 1.1), and the drawing is owed —
   add it to `decisions.designRowsOwed` (Phase 3 **Design rows owed**).

### Step 0.3d — Data Sources Check (UI items only)

Runs before the plan is announced, for every planned item that changes what a user sees, whoever
draws the boards. A `Depends on:` item being done is not proof the data exists: check the read it delivered.

1. **List what the board shows.** For each UI item still in the queue, list every data field its board
   (or, with no board, its Acceptance Criteria) displays on the surfaces it touches: each column, value,
   count, badge, filter option and default. Also the base it stands on: the app's theme and shell
   must already match the boards' design layer; a missing base is a gap, ruled as in 4.
2. **Name where each comes from:** the API endpoint and response field the screen reads, and behind it
   the database read (view, procedure or column). Read the code, and for a database query the server
   itself — never a schema copy; record the query in the packet (Shaw work:
   `~/.claude/skills/shaw-estate/references/databases-and-querying.md`).
3. **Every field has a source, or this item's own scope adds it** → write the list into the packet's
   `## Design Reference` as `Data sources:` (field → source, or `added by this item`). The Developer
   builds to it and the Reviewer checks it.
4. **A field with no source, outside this item's scope → ask before the plan is announced:**
   (a) widen this item to add the read; (b) add a `Depends on:` item that adds it; or
   (c) hold the item. Save the answer in run-state's `decisions.dataSourceGaps` (item, fields, ruling).
   A held item works like a design hold (Step 0.3c, item 3): it leaves this run's queue with every item that depends
   on it, its PMBook row is not touched, and the next run checks it again. Never let a Developer find
   the gap mid-build.

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
  Format:  <fix command> · verify: <verify command>   (scoped to the item's changed files)
  Lint:    <command>

Baseline: <N> red at start — <test (how)>, … | green | skipped — <why>   (Step 0.3b)
Review-only: <IDs> — built outside the loop; reviewed first, no Developer unless it fails (or omit)
Held for design: <ID> — waits on <row IDs> (round <NNN>, open | sent <date>) (Step 0.3c; or omit)

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
| Best | N × 2 (Developer + Reviewer, no retries; a review-only item counts 1 — its Reviewer) + 2 (Integration, Reviewer-Integration) + 6 Finalizers |
| Typical | Best × 1.3 (assumes ~30% of items need one retry; optionally use the observed rate from `metrics-log-file`) |
| Worst | N × 8 (Developer + Reviewer on the first try and each of 3 retries; a review-only item adds 1 for its first review) + 4 Parity Check spawns per UI item + Integration 2 × 4 + 6 Finalizers + Divide-and-Conquer's spawns if it triggers |

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

Save it to `<work dir>/runs/<run id>/packet-<ID>.md` (the path the Parity Prompt is given). If the
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
deviations` with its date and the item proceeds. With designer-owned boards, Step 0.3c normally holds such
an item before it gets here; and a "build to the Acceptance Criteria" ruling leaves the drawing owed —
add it to `decisions.designRowsOwed`.

### Step 1.2 — Invoke Developer Agent

Spawn a Developer sub-agent via the Agent tool with `subagent_type: "orchestrated-developer"` and `model: "sonnet"` (see **Model Assignment**), using the **Developer Agent Prompt Template** below, with the Task Packet substituted in full.

It returns a **Developer Output** in its agent's Output Template (Format and Lint must be PASS).

**Its own tests.** This skill runs one item at a time, so no other Developer shares the build: fill the
packet's `Tests you may run` with the test classes this item creates or changes (a Bug: its regression
test). The Developer may run those, and only those. The Reviewer still runs them independently.

**A design ruling.** If the Developer's Assumptions raise a difference from the board (it cannot be
built as drawn, e.g. no Material slot for it), rule on it — the user rules when it changes what the user
sees beyond the board's intent. A ruling that accepts the difference becomes a `Ruled deviations` line
in the packet's `## Design Reference`, with its source (`orchestrator ruling, <date>` or
`user ruling, <date>`). Before the Reviewer spawn: **re-save the packet file** with that line, store the
full packet in `run-state-file`, and save the ruling in run-state's `decisions.rulings` (item, the
difference, the ruling, its source). The Reviewer and the Parity Check then read it from the packet.
Send the Developer back only when the ruling needs a code change; otherwise go straight to Step 1.3.
When an outside designer owns the boards and the ruling leaves the board wrong (it now draws something
the product will not have), the board change is owed: add it to `decisions.designRowsOwed` (item, surface,
the change, the ruling's source) — Phase 3's **Design rows owed** writes it.

**Review-only items** (`## Mode: review-only`, Step 0.1). The code was built outside this loop, so skip
the Developer spawn. Instead the Orchestrator writes a **Build Record** in the Developer Output's shape:
`Source: built outside the loop`; Files Created or Modified, from `git diff --name-only` (and `git
status --porcelain` for new files) or the list the user gives; a one-paragraph summary of what the code
does; Test Files Written, from that list; Format and Lint `not run by a Developer`. Save it as the item's
latest Developer Output in run-state (its files become the item's `files`) and go to Step 1.3. The
Reviewer reviews it like any Developer Output.
- **PASS** → the item goes on as any PASS does (Step 1.4).
- **FAIL** → the first Developer spawn. It uses the normal Developer Agent Prompt — not a retry: the
  Reviewer's issues go in its `## Review Findings to Fix` section, and there is no `## Previous Attempt`
  (the Build Record is not a previous Developer Output). **This FAIL does not increment `loop_count`**: no Developer has tried yet, so the
  Developer gets the full 3 attempts. From that Developer's return on, Step 1.4's loop runs as normal.

**`Type: Spike` carve-out:** skip Step 1.3 and Step 1.4 entirely — go straight to **Spike Flow** (below
Step 1.5) instead. There is no Reviewer spawn, no retry loop, and no Manual Verification Gate for a Spike;
its Developer Output is Findings, not a reviewable implementation.

### Step 1.3 — Invoke Reviewer Agent

Spawn a Reviewer sub-agent via the Agent tool with `subagent_type: "orchestrated-reviewer"` and `model: "haiku"` (see **Model Assignment**), using the **Reviewer Agent Prompt Template**, passing the original Task Packet and the Developer Output.

It returns its Output Template with Verdict `PASS`, `FAIL` (with Issues) or `UNVERIFIED` (with Unable to
Verify — see **Handling an UNVERIFIED Verdict** below).

**Outside this item.** Its Output's `Outside this item` section lists real defects it saw outside the
packet's scope (e.g. a config value too long for its field, in a file this item does not touch). They are
not part of the verdict and no Developer retry fixes them. Save each in the item's run-state
`outsideItem` list (one entry per file + defect, merged across retries), as Step 1.3b point 6 does for
board differences; Phase 3 offers to log them before its Finalizers run (**Outside items — asked before
the Finalizers**), and the final summary lists what was logged or declined.

### Step 1.3b — Board Parity Check (UI packets only)

**Runs after the code Reviewer's PASS, before the Manual Verification Gate and Integration.** Skip only
for a packet with no `## Design Reference`. Read `references/parity.md` now: it holds the Parity Prompt
and why the check is measured on the rendered screen.

1. **Bring up** the app (the way the repo's run skill or `CLAUDE.md` says) and the boards
   (`artboard-server`), and check both answer. Fill `app-url` with this checkout's port offset.
2. **Spawn** `subagent_type: "orchestrated-reviewer"`, `model: "sonnet"` (see **Model Assignment**), with
   the **Parity Prompt** (`references/parity.md`): the packet's saved path (Step 1.1), the app URL, the board URL, `parity-viewports`, `parity-command` (or `None`), and the folder
   `<work dir>/parity/<run id>/<ID>[-legN][-retryN]/` (`-legN` when run-state's `leg` > 1). A separate
   spawn: the code Reviewer stays narrow.
3. **It measures** the elements this item changes, in every state in `States to compare` at every width,
   running or extending the repo's parity harness when there is one, plus a quick pass that lists
   differences outside the item — as the prompt says — and returns a Parity Table; screenshots and measurements stay in the parity folder.
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
   state + element). Phase 3 offers once, before its Finalizers run, to log them as new Bugs
   (**Outside items — asked before the Finalizers**); nothing is logged without the user's yes.

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

**A spawn that returns no Output.** Any spawn — Developer, Reviewer, Parity, Integration,
Reviewer-Integration, Finalizer — that ends without an Output in its role's template (it stops early,
or says it could not hand its report back):
1. Send it one `SendMessage` asking for its Output in its template, and nothing else.
2. Still none → respawn the same role with the same inputs.
3. It counts like an UNVERIFIED: it adds to `unverified_count` and `unverifiedTotal`, never to
   `loop_count`. Two missing Outputs in a row from the same step → **Escalation** (Verification Blocked,
   with what the spawn last said).

### Step 1.4 — Review Loop

```
WHILE verdict == FAIL:
  Apply this step's rulings first (below: review-only first FAIL, Overruling a weak issue,
  A Reviewer's own miss). A free FAIL skips the escalation check and the increment; a FAIL with
  every issue overruled leaves the loop as PASS by ruling.

  IF loop_count == 3:   # the FAIL that takes loop_count past 3; loop_count stays 3 (recorded and reported as 3)
    → ESCALATE (see **Escalation** — `references/escalation.md`)
    → STOP all activity until user types "resume"

  loop_count += 1
  model = (loop_count == 3) ? Escalated Model : Base Model   # see Model Assignment

  Spawn Developer Agent with model = model, and:
    - Original Task Packet
    - Reviewer's issues list (fills the Developer Agent Prompt Template's "Reviewer Issues" section)
    - Previous Developer Output's file list (fills the "Previous Attempt" section; none after a
      review-only item's first FAIL — the Build Record is not a previous Developer Output)
    - Note: "Fix only the listed issues. Do not change anything else."

  Spawn Reviewer Agent with model = model, and:
    - Original Task Packet
    - New Developer Output
    - loop_count and the previous issues list (fills the Reviewer Agent Prompt Template's "Retry Context" section)
```

**Retry escalation:** loop_count 3 uses each role's Escalated Model — see **Model Assignment**.

**Overruling a weak issue.** Before a Reviewer FAIL enters the loop, the Orchestrator may rule one of its
issues `not an issue`, with a written reason anyone can check (e.g. "the same settlement account is
already used in 8 existing test files"). Only when the issue cites **no** acceptance criterion,
constraint, coding convention, failing test or failing gate. Never a failing test, a failing gate, a
Bug's regression test, or a Parity mismatch (a board difference is accepted only as a `Ruled
deviations` line). Save each ruling in run-state's `decisions.rulings` (item, the issue, `not an issue`,
the reason) before acting on it. The remaining issues go into the loop as usual. If every issue in the
FAIL is overruled, the item goes on as a PASS — log `PASS by ruling` — with no `loop_count` change. Each
ruling is listed on the final summary's `Overruled:` line. This applies to Phase 1 Reviewer issues only,
never to a Reviewer-Integration FAIL.

**A Reviewer's own miss.** A new issue in a re-review that points at code the last Developer attempt did
not change (not in its Files Created or Modified, and present when the previous review ran) is a miss
by the earlier review, not a Developer failure. It must still be fixed, but the retry it causes does
**not** increment `loop_count` — at most once per item. Save `reviewerMissRetry: used` on the item in
run-state; a second such issue counts as a normal FAIL. If the FAIL also has issues on changed code, it
counts as usual.

When verdict == `PASS`: **a UI packet's code PASS is not the item's PASS** — run Step 1.3b first. A
Parity FAIL re-enters this loop with its mismatches as the issues list (`loop_count` goes up as for any
FAIL); the retry goes to the code Reviewer, then Step 1.3b again. Only a Parity PASS, or a packet with no
`## Design Reference`, goes on below. Every FAIL that sends the item back (a Reviewer FAIL, a Parity
FAIL, a Step 1.5 rejection) saves its run-state status `in progress`.

- Feature packet: status `passed review` (run-state only — Step 1.4 writes nothing to the PMBook; the
  Step 3.2 Finalizer sets the row's Status to `Done`, once, after Integration has passed); log `✅ F-XXX <name> — PASS after <N> iteration(s)`;
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

Entered only when every Feature and non-P0 Bug in this run is at a terminal state (a Feature `passed review` in
run-state, a non-P0 Bug `verified` (its Reviewer PASS leaves it `awaiting verification`) — PMBook writes for both happen later, at Step 3.2; a `dropped` item is
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
  `- <test> — accepted by the user`, `- <test> — accepted by the user (baseline: <file>)` or
  `- <test> — tracked by <ID>`, or `None`. Passed on every
  Integration spawn: the first, every retry (normal or fresh-spawn), and every Divide-and-Conquer
  `## Sub-problem` and `## Aggregate pass` spawn.
- **`## Known Reds at Baseline`** — run-state's `baseline.reds` from Step 0.3b, one line per test with
  how it failed, or `None — baseline green`, or `Not run — <why>`. Passed on every Integration spawn,
  like Accepted Known-Reds.
- **`## Foreign Paths`** — the run's own file set is every item's run-state `files` (every attempt),
  the Deferred IDs' files and, on a later pass, the `integration` block's `files`. Run
  `git status --porcelain` as a cross-check only: a changed path in none of those sets belongs to another
  session or the user. List each as `- <path> — foreign (another session or the user)`, or `None`, save
  them in run-state's `foreignPaths`, and show them in the final summary. The agent neither fixes,
  reverts nor formats a foreign path, and never counts it as this run's change. Passed on every
  Integration spawn and to Reviewer-Integration.

**Pass paths, never inlined file contents** — the agent reads the documents itself.

**Save each Integration Output to a file, verbatim.** As soon as an Integration spawn returns, write
its final reply — exactly as returned, never a summary or an excerpt — to
`<work dir>/runs/<run id>/integration-output-pass<N>.md`. N counts Integration passes from 1: the
first pass, each retry, a crash re-run, a resume, Divide-and-Conquer's aggregate pass. A
Divide-and-Conquer sub-problem spawn K writes `integration-output-pass<N>-sub<K>.md`, N being the
aggregate pass it feeds. Append the path to run-state's `integration.outputPaths` (in order; the latest
Output is the last entry without `-sub`) and save run-state. Reviewer-Integration and an Integration
retry's Retry Context get that path, never a summary. The only edit ever made to the file is the
**Known-reds** rewrite of an `— untracked` line, made in the file as well as in the Output you hold. A
background spawn's task output file is a transcript of the whole spawn, not its Output: write the
agent's final reply, and never pass or cite the transcript. If the task output file reads empty, save the final reply from the completion notification verbatim instead; never re-spawn the agent to get it again.

### Documentation Drift Check

A **FAIL-worthy check**: drift is a defect like a broken test. What is checked is the Integration
template's "Documentation Drift Check — Specific Mapping for This Pipeline" section; findings come back
under the Integration Output's `Documentation Drift` section. **Integration fixes code, not the
test-cases doc:** a gap in `test-cases-doc` comes back as `Drift: test cases doc — <what> — handed to
Test Runbook`, and Step 3.5 writes it. **Nor a new ADR:** a decision that needs one comes back as
`Drift: new ADR — <title> — <decision in one line> — handed to PMBook Update`; at Step 3.2 you pick the next free number in `adr-directory` and hand it to the PMBook
Finalizer (**New ADRs** below).

### Step 2.2 — Invoke Reviewer-Integration Agent

**First, settle untracked known-reds** (see **Known-reds** below).

Spawn a Reviewer-Integration sub-agent via the Agent tool with `subagent_type: "orchestrated-reviewer-integration"` and `model: "haiku"` (see **Model Assignment**), using the **Reviewer-Integration Agent Prompt Template**, passing the Integration Output's file path (Step 2.1), the condensed Task Packets of only the items under Features Completed /
Bugs Fixed (never a fast-laned P0 — that is a Deferred ID), the Platform Profile with its Test scope, the same doc paths Step 2.1 passed, the Deferred Integration IDs Step 2.1 passed (its `## Deferred Integration` section, or None), the same `## Accepted Known-Reds` lines, the same `## Known Reds at Baseline` lines, and the same `## Foreign Paths` lines.

It returns Verdict `PASS`, `FAIL` (with Issues) or `UNVERIFIED` → **Handling an UNVERIFIED Verdict**.

### Step 2.3 — Integration Loop

Same logic as Phase 1, including the Escalated Model at loop_count 3 (see **Model Assignment**). Max 3
iterations before escalation to a human — except that loop_count 3's FAIL doesn't escalate immediately;
see **Divide-and-Conquer — Last Attempt Before Escalation** below, which runs first.

On re-invocation, the Integration Agent receives loop_count, the Reviewer-Integration's issues list, its `## Accepted Known-Reds`, and its own prior Integration Output's file path (Step 2.1; fills the Integration Agent Prompt Template's "Retry Context" section) and addresses only those issues. The prior Integration Output tells the fresh spawn what was already fixed and what the Documentation Drift Check already found, so it re-runs the quality gate (code changed, so this must be re-verified for real) without repeating the full drift analysis for sections the previous pass already cleared. The Reviewer-Integration Agent likewise receives loop_count and its own previous issues list on each re-review (fills its Prompt Template's "Retry Context" section).

### Divide-and-Conquer — Last Attempt Before Escalation

On the Reviewer-Integration `FAIL` that takes Integration's loop_count past 3, do not escalate yet:
read `references/escalation.md` and run its **Divide-and-Conquer** first. It runs at most once per batch.

### Known-reds

A line under the Integration Output's `### Known-Reds` is a failure this run did not cause. It does not
make Overall Status FAIL, so it can pass silently unless the Orchestrator acts on it. This skill has no
component map: a known-red's owner is the top-level folder or module under `source-code-directory` that
holds the test.

**Baseline reds** (Step 0.3b) are the evidence for "this run did not cause it". A test red at baseline
and still red belongs under `### Known-Reds`, with how it failed at baseline — the Integration Agent
does not triage it as new — but it still needs a ruling below like any other known-red, and it is
listed in the final summary. A test green at baseline and red now is this run's, never a known-red. A
baseline red that is now green is noted on the final summary's `Baseline reds:` line.

**Documented baseline.** A repo may document failures it already lives with: the file the
`known-red-baseline` binding names, or else a known-red or baseline section in the root `CLAUDE.md`.
Read it before the first Integration spawn. Each test or audit finding it names is already ruled — the
user accepted it by writing it down — so it goes straight into the run's accepted known-red list as
`- <test or finding> — accepted by the user (baseline: <file>)`, and into run-state's
`decisions.acceptedKnownReds`, and the first `## Accepted Known-Reds` section already carries it. Such a
line never pauses the run. A failure the baseline does not name is ruled as below.

**A `— untracked` line pauses the run** before any Reviewer-Integration spawn. Ask the user, per test:
raise a tracking item (the line becomes `— tracked by <new ID>`) or accept it (`— accepted by the user`).
Save each answer in run-state's `decisions` as given — for "raise a tracking item", with the `OI-NNN` the
Orchestrator assigns (the next free number in that PMBook) — before any PMBook write. Then it writes that item into `project-management-doc`'s `## Open Items` (creating the section if absent),
the ID at the start of the row's Item cell (`Item: OI-NNN — <test> …`), **before** any
Reviewer-Integration spawn, which looks the ID up there (an Open Items row already naming that test is
reused, not duplicated); then it rewrites that line in the Integration Output it holds and in its saved file (Step 2.1). The ruled tests form the
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

**Outside items — asked before the Finalizers.** When any item's run-state `outsideItem` list
(Steps 1.3 and 1.3b) is not empty, ask the user once, now, before spawning a Finalizer, so a yes lands
in this run's PMBook. List every entry, and offer to log them as new Bugs: **one Bug per surface** (a
screen, or a file) **or one Bug grouping them all** — say which you propose and why. A board
difference where the board itself may be wrong is still a Bug, with `board may be wrong — needs a design
ruling` in its description. Save the answer in run-state's `decisions` as `outsideItemLog` (the grouping,
then each entry: `logged as <new ID>` or `declined`) before any Finalizer runs; a resume reuses it and
never asks again. On a yes, give each new Bug the next free ID and hand it to Step 3.2 as a new `## Bug
Log` row: Status `Open`, `Fixed In` blank. Nothing is logged without the user's yes. A P0 fast lane does
not ask; a run that never reaches Phase 3 lists the entries at close-out as `not logged — no
Finalization this run`.

**Design rows owed — written before the Finalizers.** When `decisions.designRowsOwed` has an entry not
yet written (a drawing a design ruling, a "build to the Acceptance Criteria" ruling or a not-drawn surface
left owing — Steps 1.1–1.2 and the Design rows hold), the Orchestrator writes each as an `Open` row in the
open round per `~/.claude/skills/sync-artboards/references/design-files.md`: next ID for the screen's letter, Source the item and the ruling (who, date), Round
`open`; a new round file if the last one was sent. Then it rewrites the round's Summary and Detailed
prompt, marks each entry `written as <row ID>` in run-state, and adds the rows and round files to
the files Step 3.6 stages. Old layout → the old ledger, as the Design rows hold says. No design folder at all → the
entry stays `not written — no design folder`. A P0 fast lane writes its own entries the same way. The
final summary shows the round's two texts when any row was written. Never mark the round sent.

For each parallel spawn, use the **Finalizer Agent Prompt** template below with the stated Task and
Task-Specific Inputs. Every Finalizer — Phase 3, a P0 lane's, the Commit Messages one — also gets
`## Final Status per Item`: one line per item in its scope with its final run-state status (e.g.
`F-013 — Done`, `B-007 — verified`, `B-009 — Hotfixed — Integration Pending`, `F-020 — dropped`), so no
Finalizer guesses an item's state from the docs. Before spawning, `Grep` each item ID across the governed
docs; every line that states the item's status or calls it open goes, with its file and line, to the
Finalizer that owns that file (`Stale mentions:`), so none is left saying "open". The Revision + Changelog
Finalizer is told every section `changelog-file` keeps per entry (`Grep` its headings: e.g.
`### Smoke tests`, `Files touched`), and fills each. None of them write code or run tests — that boundary stays with
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
   stamps the report. That keeps the pipeline and the team building the graph the same way. For the
   standard `scripts/graph.ps1`, pass the changed paths:
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graph.ps1 -Root <changed paths, comma-separated>`
   (it rebuilds only those when `graph.json` exists, every path when it does not, and rejects a path
   that is not one of its roots); drop `-Root` when every path changed.
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

**Runs only when this run changed code in the graphed paths.** Before Phase 3, decide from **the run's
own file set** (the one `## Foreign Paths` uses: every item's run-state `files`, every attempt, plus the
`integration` block's `files`), never from raw `git status`: another session's or the user's
uncommitted file under a path does not make it changed. A path in `graphify-directories` (or
`source-code-directory`) counts as changed when a file in that set lies under it — committed earlier in
this run or not. If no path counts as changed, spawn no
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
  section is non-empty — that list of test names; the new Bugs from `decisions.outsideItemLog` (each
  ID, one-line description, surface, Status `Open`), when the user said yes; the **New ADR** lines
  (below), each with the `adr-directory` path; `project-management-doc` path

**New ADRs.** For each Integration drift line `Drift: new ADR — <title> — <decision> — handed to PMBook
Update`, you pick the next free number in `adr-directory` (one higher than the highest `ADR-<NNN>` there
and than any already handed out this run; never reuse or renumber) and hand the PMBook Finalizer one
line: `<adr-directory>/ADR-<NNN>-<slug>.md — new file — <title>; decision: <one line>; context: <why,
from the drift line and the items behind it>; status: <Accepted | Proposed>`. `Accepted` only when the
user ruled that decision in this run — cite where (the item ID and gate); otherwise `Proposed`. A
superseded ADR is named on the same line (`supersedes: ADR-<NNN>`). With `adr-directory` unset, hand
nothing and list the decision on the final summary's `New ADRs:` line as `not written — no
adr-directory`. Every `Proposed` ADR is listed on that line for the user to rule on.

The Finalizer sets each completed feature's Status to `Done` — the only place a feature becomes `Done`,
once Integration has passed — then marks the phase complete if warranted, fills the row's other fields, resolves addressed open items, and runs the Tranche-boundary
check — but it cannot talk to the user directly, so a
detected Tranche boundary comes back under its Output's **Notes**, not as a live message. If Notes reports
one, **the Orchestrator** puts the final summary's `Tranche:` line in, telling the user every phase is
`Done` and to run `idea-triage`'s Tranche Closeout before the next round of feature work begins.
Archiving itself is never performed here — `project-management-doc`'s format and lifecycle (the `Tranche`
header, the `## Closed Tranches` table) are owned by `idea-triage`, not this pipeline.

**Bug logging:** for each item in the Bugs Fixed list, the Finalizer writes a row to a `## Bug Log` table
in `project-management-doc` — `ID | Description | Reported | Status | Fixed In`, Status `Fixed`, the
regression test path in the Description so a later Integration can run it — creating that section
(after `## Feature Backlog`) if it doesn't exist yet. This applies whether the bug started as a PMBook
entry or arrived through ad-hoc **Bug Fix Intake** (Step 0.1b): either way, once fixed it must exist in the
governed PMBook, since that's the durable record this pipeline relies on, not the Orchestrator's own
context. The Bug Log is a section this pipeline owns and appends to; it does not interact with
`idea-triage`'s Tranche mechanics the way the Feature Backlog does. The new Bugs from
`decisions.outsideItemLog` get rows here too, Status `Open` and `Fixed In` blank. `## Spike Log` rows are never written
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
  confirming the bug no longer occurs); `test-runbook-location` path (create if absent); every
  Integration Output drift line ending `— handed to Test Runbook`, with the `test-cases-doc` path (when
  there are none, say `Test cases doc: no handoff`)

### Step 3.6 — Commit step: draft the messages (the Finalizer never executes git), then commit

Only after every Finalizer spawned in 3.1–3.5 has returned (in a P0 fast lane, its own lane's), spawn one more Finalizer sub-agent via the Agent tool with `subagent_type: "orchestrated-finalizer"` and `model: "sonnet"` (see **Model Assignment**), using the **Finalizer Agent Prompt** template, with:

- **Task:** `Commit Messages`
- **Task-Specific Inputs:** the commit step's file list (below), verbatim; the trailer rule (below); and
  `Attribution:` — the exact attribution lines from the Orchestrator's own context (e.g. a
  `Co-Authored-By:` line), copied character for character, or `None`. The Finalizer copies them as
  given and never writes, recalls or corrects attribution itself.

**Trailer rule — one rule, every commit.** Every message ends with `Run-Id: <run id>`. `Items:` lists
only the item IDs whose changes are in that commit. A commit holding only Integration fixes says
`Items: integration`.

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
own code group from its own `files`, with `Items:` naming only that item; Integration fixes outside any
item's files go in their own group with `Items: integration`; governed docs, any file shared by more
than one item, and every other file in no item's code group go in one docs/chore group whose `Items:`
lists every item whose changes it holds (the graph report goes with the item it was rebuilt for; one rebuilt for the whole run goes here,
and `Items:` then lists every item in the run). One Commit Messages
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

## Mode
<omit entirely for a normal item; `review-only` only when the user named the item as built outside this
loop — Step 0.1, and **Review-only items** under Step 1.2>

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
- Format: <fix command> then <verify command> — both scoped to the files you create or change, never the
  whole repo (Step 0.2)
- Lint:   <command>

## Note on Tests
Write the test files. You may run only the tests under `Tests you may run`, to catch your own wrong
expectations before you return; do NOT run the wider suite — test execution is the Integration Agent's
responsibility, and the Reviewer runs your tests again independently.
Tests you may run: <the platform Test command narrowed to the test classes this item creates or changes,
  e.g. `dotnet test --filter "FullyQualifiedName~<Namespace>.<ClassName>"`, `pytest <path>`,
  `npx jest <path>` — or "None" when the item writes no tests>

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
Data sources: <each field the board shows → its API field and database read, or "added by this item"
  (Step 0.3d)>
Standing acceptance criterion (every UI packet): The built screen matches the board in every listed
  state; the Parity Table (Step 1.3b) shows no unruled mismatch.

## Constraints
- Edge decisions: <each choice the criteria rest on — which exceptions are caught, ordering and
  collation, null and empty handling, time zones — or "Developer decides; state each under Assumptions">
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
- Format: <fix command> then <verify command> — both scoped to the files you create or change, never the
  whole repo (Step 0.2)
- Lint:   <command>

## Note on Tests
Write a regression test that reproduces the bug — it must fail against the pre-fix code and pass once the
fix is applied. You may run only the tests under `Tests you may run` (the regression test, and any test
class you change); do NOT run the full test suite — test execution is the Integration Agent's
responsibility, and the Reviewer runs the regression test again independently.
Tests you may run: <the regression test below, plus any test class this fix changes — or "None">.
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
- Edge decisions: <each choice the criteria rest on — which exceptions are caught, ordering and
  collation, null and empty handling, time zones — or "Developer decides; state each under Assumptions">
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

Run exactly the Format and Lint commands in the Task Packet's Developer Quality Gate, scoped to the files
you create or change. Both must pass before you return; fix any failures. Run no tests beyond the
packet's `Tests you may run`.

## Return Format

Use exactly your own Output Template (with its Spike substitution for a `Type: Spike` packet).

## Review Findings to Fix (present only on the first Developer spawn of a review-only item whose review failed; omit otherwise)
<INSERT THE REVIEWER'S ISSUES LIST>
The code was built outside this pipeline and reviewed as it stands. Fix only the findings above and
nothing else. This is your first attempt, not a retry.

## Reviewer Issues (present whenever Previous Issues exist — a retry, or a resume after escalation; omit otherwise)
<INSERT REVIEWER'S ISSUES LIST, or the escalation's issues on a resume>
Fix only the issues listed above and nothing else.

## Previous Attempt (present whenever a previous Developer Output exists — a retry, or a resume after escalation; omit otherwise — a review-only item's Build Record does not count)
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
`States to compare` is built, nothing the board draws is missing, and each `Data sources:` field is read
from the source named there. Report any divergence you can see
in the code as an issue. "The board looks out of date" is not a defence. **A static read does not
satisfy the design check.** You may PASS the code, but the item is not done until the Board Parity Check
(Step 1.3b) measures the rendered screen and passes. Do not claim the screen matches the board.

If `Mode` is `review-only`, the Developer Output below is the Orchestrator's Build Record of code built
outside this pipeline: review the code as it stands, against the packet, exactly as you would a
Developer's. Format/Lint were not run by a Developer, so run the packet's check-mode commands yourself —
the Format gate (verify) form and Lint without any fix flag — and nothing that rewrites files (your
agent's What You May Run).

Cite an ID, file, test or tracking item only after opening it and seeing it there. If you cannot find
one, write `not tracked` — never name an ID from memory.

## Return Format

Use exactly your own Output Template.

## Developer Output
<INSERT DEVELOPER OUTPUT — or, for a review-only item's first review, the Build Record>

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
<INSERT one line per test the user ruled on, documented-baseline ones included:
`- <test> — accepted by the user`, `- <test> — accepted by the user (baseline: <file>)` or
`- <test> — tracked by <ID>`, or "None">

## Known Reds at Baseline
<INSERT run-state's baseline.reds, one line per test: `- <test> — <fails | flaky | timeout>: <first
line>`, or "None — baseline green", or "Not run — <why>">
These were red before this run changed anything. A test listed here and still red goes under
`### Known-Reds` with how it failed at baseline, not into your flaky triage as a new failure. A test not
listed here that is red now is this run's to fix. Note any listed test that is now green.

## Foreign Paths
<INSERT Step 2.1's foreign paths, one line each — "- <path> — foreign (another session or the user)" — or "None">
These changed in the tree but are not this run's. Don't fix, revert or format them, and never count them
as this run's changes; a failure that traces to one is classified like any known-red (owner: whoever
changed it, or `unknown`).

## Documentation Drift Check — Specific Mapping for This Pipeline
- Does the Architecture Doc still describe every component that now exists in the source tree, including
  its inline `mermaid` diagrams?
- Does the PMBook's Acceptance Criteria for each `Done` feature in this batch match what the code
  actually does?
- For a bug in this batch that already had a `## Bug Log` row before this run: does that row accurately
  describe the fix — does the code no longer reproduce the logged symptom? This batch's new Bug Log rows
  are written at Step 3.2, after you; their absence is not drift.
- Does the Test Runbook cover the flows introduced by these features (if a runbook path was given)?
- Does the Test Cases Doc have a case for each flow this batch added or changed, still matching the code
  (if a test cases path was given)?
- If an ADRs path was given: does every ADR ID cited in the Architecture Doc's Technology Decisions table
  exist in adr-directory, and is it still the active (non-superseded) one?

**Place every drift finding.** Fix it yourself, or flag it under Unresolvable Issues — never leave one
unplaced. Write each as `Drift: <doc> — <what> — fixed` or `Drift: <doc> — <what> — flagged`. The two
hand-offs: the test cases doc is never yours to edit — write each gap as
`Drift: test cases doc — <what> — handed to Test Runbook` (Step 3.5 writes it); and a new ADR is never
yours to write — write it as `Drift: new ADR — <title> — <decision in one line> — handed to PMBook Update`, never choosing its number (Step 3.2 writes it). No other document is handed to a Finalizer in
this pipeline.

## Retry Context (present whenever Previous Issues exist — a retry, or a resume after escalation; omit otherwise)
loop_count: <INSERT N>
Previous Issues: <INSERT REVIEWER-INTEGRATION'S ISSUES LIST, or the escalation's issues on a resume>
Previous Integration Output: <INSERT the prior pass's saved file path, `<work dir>/runs/<run id>/integration-output-pass<N>.md` — read it yourself>
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

## Known Reds at Baseline
<INSERT the same lines the Integration prompt carried>
Check each still-red one is under the Integration Output's `### Known-Reds`, not dropped.

## Foreign Paths
<INSERT the same lines the Integration prompt carried>
Not this run's changes: a FAIL never asks to fix, revert or format one.

Cite an ID, file, test or tracking item only after opening it and seeing it there; if you cannot find
one, write `not tracked`.

## Return Format

Use exactly your own Output Template.

## Integration Output
<INSERT the saved file path, `<work dir>/runs/<run id>/integration-output-pass<N>.md` (Step 2.1) — never a
summary. Read that file: it is the Output verbatim.>

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
<INSERT LIST: B-ID, one-line description, files changed, `Regression test: <path>`, and `Verified with:
<measurements>` when the user gave any — or "None this
phase", or "N/A, this is a Spike Log Task" if Task is Spike Log>

## Spike Completed (only present when Task is Spike Log)
<INSERT: S-ID, Question, Spike Directory, Files Created, and the Developer's Findings/recommendation
verbatim; `project-management-doc` path>

## Final Status per Item
<INSERT one line per item in this scope, from run-state: `<ID> — <final status>` (e.g. `F-013 — Done`,
`B-007 — verified`, `B-009 — Hotfixed — Integration Pending`, `F-020 — dropped`)>
This is each item's state. Do not infer it from the docs you are about to update.

## Task-Specific Inputs
<INSERT — see the matching Phase 3 step (3.1–3.6) above, or Spike Flow's Finalizer step in
references/spike-and-p0.md, for exactly what this Task receives; for Commit Messages specifically, this
is the commit step's file list (Step 3.6), verbatim, the trailer rule, and the `Attribution:` lines>
```

---

## Escalation

Three situations pause for a human: `loop_count` passes 3 on a real FAIL (any work item, or
Integration; Integration: only after Divide-and-Conquer, or when its failures can't be split); a Reviewer or Reviewer-Integration returns `UNVERIFIED` a third time in a row, or any spawn returns no Output twice in a row; or
Divide-and-Conquer's confirmation pass still fails. When one is reached, read `references/escalation.md`:
it says what to save and record before posting its matching report, and how "resume" proceeds. An explicit user "drop" or "defer" of an escalated (or any) item sets its status
`dropped`, saved at once with the event time: terminal, excluded from Phase 2's entry rule and the resume rules, and listed
in the 🏁 summary; its one metrics row (Verdict `Dropped`, Timestamp that saved event time) is written then. Every pause ends with `⏸ Orchestrator is PAUSED. Waiting for
instruction.`, and nothing resumes until the user types "resume" or gives an explicit instruction. Spike
work items never reach this.

---

## Enforcement Rules

- NEVER begin Phase 0 without verifying the hard dependencies (Step 0.0)
- NEVER start a UI item whose design rows are not Done in a synced board when an outside designer owns the boards (Step 0.3c); NEVER mark a design round sent, renumber a design row, or move an old design layout without the user's yes
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
- NEVER let UNVERIFIED, a missing Output, a review-only item's first FAIL, or a Reviewer's own miss (once per item) increment `loop_count` (Handling an UNVERIFIED Verdict, Step 1.2, Step 1.4)
- NEVER overrule an issue that cites an acceptance criterion, constraint, convention, failing test or gate, or a Parity mismatch (Step 1.4)
- NEVER run a repo-wide format — Format is scoped to the item's files, and its gate is the verify form (Step 0.2)
- NEVER let a Developer run tests beyond its packet's `Tests you may run` (Task Packet Format)
- NEVER skip Step 0.3b's baseline, except for a P0/Spike-only run, a mid-run intake or a resume (Step 0.3b)
- NEVER let a Finalizer write attribution lines it was not given verbatim (Step 3.6)
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
directly** (`Write`/`Edit`, no sub-agent); this is bookkeeping, not code. **It is local and gitignored,
never committed** — `init-adlc-repo` puts it, and the `.orchestrator-work/` park folders beside it, in `.gitignore`; if it shows up untracked, it is missing
from there, and no commit step ever stages it.

**The work dir** is `<folder of run-state-file>/.orchestrator-work/` — gitignored beside run-state, and it survives a session restart, which the scratchpad does not. Every file the run must keep goes under it: `runs/<run id>/` (packets, Developer Outputs, Integration Outputs), `gate-logs/<run id>/` (gate and Integration logs, raw before/after outputs) and `parity/<run id>/` (Parity Check folders, Step 1.3b), beside the `<ID>/` park folders. The scratchpad is only for throwaway files, such as a before-side worktree. Fix it with the run id at Phase 0.

**Units and steps.** A unit is a work-item attempt, a P0 lane, Phase 2, or Phase 3. Each unit records
only its current `step` and `state: started | done`. A P0 lane's and Phase 3's steps are Finalizers →
commit (Step 3.6: messages drafted, then the commit) → done; Divide-and-Conquer's stages are Phase 2 steps.

**Content:** run id (`<YYYY-MM-DD>-<first item id, lowercased>-<HHmm>` from the start time, set at
Phase 0; if that id is already in `metrics-log-file` or `git log --grep "Run-Id: <id>"`, add `-2`, `-3`…)
and start time, the
Platform Profile, the Step 0.3 coding-conventions summary, the ordered queue (ID + Type), the current
item index, `phase` (where the pipeline is, exactly one of `phase0 | phase1 | phase2 | phase3 | closeout`, saved as
each begins; resume's "latest phase first" reads it; the PMBook's own phase name goes in `pmbookPhase`,
never in `phase`; an older file with free text in `phase` is read from its units' `step` and `state`
instead), each unit's `step` and `state`, and each item's and phase's start/finish times (ISO 8601 with
offset — **Pipeline Telemetry** is computed from them), and the event time of each metrics row, saved
before the row is written. Plus the outputs of `done` steps that later steps
read. Per item: `status` (`in progress | passed review | awaiting verification | verified | findings
recorded | escalated | dropped`, saved at each change: `in progress` when the item starts, on any FAIL
or rejection that sends it back (Reviewer FAIL, Parity FAIL, Step 1.5 rejection) and on escalation
resume; a Feature's final PASS (a UI packet: after Parity PASS) → `passed review`; a Bug's PASS →
`awaiting verification` (never `passed review`), then Step 1.5's "verified" → `verified`; Spike Log →
`findings recorded`; escalation → `escalated`; an explicit user "drop" or "defer" → `dropped`; the
resume rules in `references/resume.md` read it; a legacy `done` from an older run-state file counts as terminal),
`loop_count`, last verdict, `unverifiedTotal` (UNVERIFIED verdicts since its last metrics
row), `priorLoops` (loop counts from legs before an escalation), `leg` (1, plus 1 per escalation resume),
`files` (the union of Files Created or Modified across all its Developer Outputs, every attempt and leg;
every "files changed" this skill passes reads it),
a verified Bug's regression test path, each Parity table path with its unruled-mismatch count (cleared
with `unverifiedTotal` once the metrics row is written), the latest Developer Output (for a review-only
item, the Build Record until a Developer returns), and the last Issues list and Unable to Verify report;
`mode: review-only` when set; `outsideItem` (Steps 1.3 and 1.3b — defects and board differences outside
the item, merged across retries); `reviewerMissRetry: used` once Step 1.4 has spent it; `verification` (a Bug's measurements from Step 1.5's reply, verbatim); `parkedAt` (the durable folder an escalation pause parked the item in — `references/escalation.md`). The run's
`baseline` (Step 0.3b: when it ran, or why it was skipped, and its `reds`); `foreignPaths` (Step 2.1). An `integration` block: `loop_count`, `unverifiedTotal`, `priorLoops`,
the latest Integration Output, `outputPaths` (every saved Integration Output file, in order — Step 2.1), `files` (the union of changed files across every Integration pass and
every Divide-and-Conquer sub-problem spawn), and `divideAndConquer: not run | running | confirmation pass | done`. At
every escalation, the `escalated` status (the `integration` block's `escalated: true`), that metrics
row's Final loop_count (`escalationFinalLoopCount`, so a re-run writes the same value), `loopCountAtEscalation`, and on Report 2 `blockedGate: reviewer | parity |
reviewer-integration | developer | integration | finalizer` (per item and in the `integration` block). A `done` Finalizers step keeps its
Finalizers' Files Created or Modified lists; the commit step saves its full file list (Step 3.6).
`orchestratorFiles`: every governed file the Orchestrator itself writes (the test-cases doc draft, a
known-red tracking item's PMBook row, …), appended when written. Only IDs persist for PMBook-sourced Features,
unless the Orchestrator added to the packet (a Design Reference, a ruling); then the full packet is kept,
as it always is for Bug and Spike intake items (no PMBook row to regenerate from).

**One `decisions` block**, written the moment the user (or the Orchestrator) decides, before acting on it:
`commit: yes | no | ask`; the Release label per scope (`lane:<ID>`, `phase3` — each scope reuses only its
own); `acceptedKnownReds` — the accepted known-reds (documented-baseline ones marked with their file), with any tracking ruling's assigned `OI-NNN`; `heldForNextRun` (full
packets of mid-run intakes held because Phase 2 had started — counted in the next-free-ID scan, announced
at resume and at close-out, and seeding the next run's queue); the `app-url` / `artboard-server`
answers; `rulings` (Step 1.2's design rulings and Step 1.4's `not an issue` rulings, each with its
reason); `outsideItemLog` (Phase 3's offer); `designHolds` (Step 0.3c: item, open rows, round); `dataSourceGaps` (Step 0.3d: item, fields, ruling);
`designRowsOwed` (Steps 1.1–1.2 and 0.3c: item, surface, change, source, then `written as <row ID>` or
`not written — <why>`); and `testCasesDoc` when Step 0.0 let a thin doc stand because an item fills it.

**One file, replaced by each new run.** A new run writes over the last one's file once that run is
complete. That is intended: the file exists for resume, and a complete run has nothing to resume. The
finished run's record is its `metrics-log-file` rows and its commits (`Run-Id:` trailer), not this file.

**When it is saved:** when each step starts and when it ends; at every Developer return and every
verdict (so every `loop_count` change); at every user decision; when a Bug enters `awaiting
verification`; at every terminal state and escalation; and at close-out, marked complete with the
"🏁 Orchestrator Complete" summary. A file marked complete never triggers the Step 0.0 resume check.
At that close-out, delete the `.orchestrator-work/<ID>/` park folder of every item that ended this run;
keep one whose item is still non-terminal (its `parkedAt` carries it to the next run). The delete applies only to the gitignored `.orchestrator-work/` under the run-state folder — never a tracked folder, even one a run used to park files, and never a folder a governed doc links to. Delete this run's
`runs/`, `gate-logs/` and `parity/` folders in the work dir too, unless an item of the run is still
non-terminal (a Bug `awaiting verification` keeps its gate logs for the `verified` reply). Delete with the file tools or a command the session's permissions allow; if the delete is refused, leave the folders, list them in the summary, and the next run's Phase 0 removes any work-dir run folder whose run-state is complete.

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

**An older header.** If the log's last table has a different header (an earlier version of this skill, e.g. 14 columns), never rewrite, pad or re-order its rows. Append a heading `### From <YYYY-MM-DD>` and a new table with this header, then the row. Each table is read on its own.

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
`outsideItem` entries (Steps 1.3 and 1.3b) with what `decisions.outsideItemLog` says of each, every
`decisions.designHolds` item with the rows it waits on, and every `decisions.designRowsOwed` entry with
its row ID or why it was not written, and mark run-state complete. An escalation pause is not close-out: it
writes the rows so far plus a `RUN` row with Verdict `Paused (escalation)`, and saves run-state **without**
marking it complete, so Step 0.0's resume check still fires. When the resumed run finishes, its close-out
appends a second `RUN` row, `Complete`.

**Cells:**
- `Run ID` — run-state's run id (format in **Run-State Checkpointing**).
  `Timestamp`, `Started`, `Finished` — ISO 8601 with offset (`2026-11-10T14:05:00+11:00`), read from the
  clock, never estimated; `Timestamp` is the saved event time. Before appending any metrics row, read the clock: no Timestamp, Started or Finished may be later than now — one that is was guessed, so write `(not recorded)` in its place.
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
Outside items:    <ID> — <what, where: a defect, or a board difference (state, element: board vs built)> — logged as <new ID> | declined | not logged — no Finalization this run (one per line; or "None")
Overruled:        <ID> — <issue> — not an issue: <reason> (one per line; or "None")
Held for design:  <ID> — waits on <row IDs> (round <NNN>, open | sent <date>) (one per line; or "None")
Design rows owed: <ID> — <surface: change> — written as <row ID> in round <NNN> | not written — <why> (one per line; or "None")
Quality gate:     ✅
Integration:      ✅ (or "Not run — the run has no Feature and no non-P0 Bug")
Baseline reds:    <N> red at start — <test: still red / now green> (one per line; or "green", or "skipped — <why>")
New ADRs:         ADR-<NNN> <title> — Accepted (ruled at <ID>) | Proposed — needs your ruling (one per line; or "None")
Foreign paths:    <path> — foreign (another session or the user) (one per line; or "None")
Known-reds:       <test> — owner <module> — tracked by <ID> / accepted by the user (one per line; or "None")
Tranche:          every phase is Done — run idea-triage's Tranche Closeout before new feature work (only when Step 3.2's Notes reported it; else omit)
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
