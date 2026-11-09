# Orchestrator fix notes — 2026-11-03

Found by a live test run on `shaw-plugin-dashboard`: PLUGIN0-B-006 with the linked SHELL-B-004.
`plugin-orchestrator-development-pattern` moved from 1.1.0 to 1.2.0. The agent edits are kept generic,
because the non-plugin `orchestrator-development-pattern` uses the same agents.

| # | Finding | Fix | File |
|---|---|---|---|
| 1 | Bug intake assumed every bug was new; an `Open` Bug Log row had no rule | Reuse the existing row's ID; else a "next ID" line wins; read the table, not a grep | SKILL.md Step 0.1b |
| 2 | Orchestrator gave SHELL-B-004 while the PMBook said "next is B-003" | Same rule as 1 | SKILL.md Step 0.1b |
| 3 | Metrics file had the old header, with no rule for that | A new `### From <date>` section with the current header; old rows untouched | SKILL.md Pipeline Telemetry |
| 4 | Run-state held dates only, so wall-clock could not be computed | ISO date-times with the zone, read from the clock | SKILL.md Run-State |
| 5 | Design Gate said "author/edit the artboard", but the designer owns synced artboards | Designer-owned branch: never edit; small change → AC is the spec + flag a designer ask; new layout → halt | SKILL.md Step 1.1b |
| 6 | A FAIL caused by a file in another component would burn three retries | "FAIL — cross-component dependency": no retry, no loop_count change, a linked item, the Reviewer respawned after | SKILL.md Step 1.4; templates.md Reviewer prompt |
| 7 | Two linked runs had no rule for Integration or Finalization | New "Linked Runs" section: one combined full Integration, a per-owner Diff Guard, 4 Finalizers per component, depended-on commit first | SKILL.md; templates.md Integration prompt; Enforcement |
| 8 | No stack lifecycle (e2e needs it up; build and .NET need it down) | `Stack: up · down · check` in the Platform Profile; the stack is up before an e2e Bug Reviewer; a Stack Order block in the Integration prompt | SKILL.md Step 0.2, 1.3; templates.md |
| 9 | No known-red concept; a pre-existing tracked red blocked Integration | Known-red = tracking ID + owner by path + git evidence; recorded, not silenced; checked by R-I | SKILL.md Step 2.3; templates.md; orchestrated-integration.md; orchestrated-reviewer-integration.md §5 |
| 10 | Integration misattributed a failing spec by its name, not its path | Owner by path; search every PMBook first | orchestrated-integration.md |
| 11 | Integration self-narrowed "full" and skipped .NET | Full = every Test (full) command, no self-narrowing; R-I FAILs a skip | orchestrated-integration.md; R-I §5; SKILL.md Enforcement |
| 12 | Parallel Finalizers raced on the version (PMBook "Fixed In" vs changelog heading) | The Orchestrator decides the Release label before Phase 3 and passes it to both | SKILL.md Phase 3; orchestrated-finalizer.md |
| 13 | Released vs `[Unreleased]` handled differently per component | Same as 12: an `[Unreleased]` section → label `Unreleased` | SKILL.md Phase 3 |
| 14 | `revision.md` has no integer | A revision entry in the file's own form | SKILL.md Step 3.4; orchestrated-finalizer.md |
| 15 | The Finalizer could duplicate an existing Bug Log row | Update in place; move the "next ID" line on | SKILL.md Step 3.2; orchestrated-finalizer.md |
| 16 | The graph stamp lagged HEAD, so a fresh graph looked stale after the commit | Stamp gets `+ uncommitted working tree`; the staleness rule exempts the commit it was built for | SKILL.md Step 3.1; orchestrated-finalizer.md |
| 17 | `nx test -t` did not narrow to one test | The Bug packet's Note on Tests says to check narrowing and name the file if not | templates.md |
| 18 | The Developer claimed an e2e "unaffected" without reading it | MUST NOT claim "unaffected" without reading the dependants | orchestrated-developer.md |
| 19 | Close-out did not list known-reds or the stack state | Two new checklist lines | SKILL.md Step 3.6 |
| 20 | The user expected the run to end committed; the skill only drafted messages | Step 3.5 now commits by itself, staging exact paths, one commit per group, on the current branch; never pushes, amends, skips hooks or branches; stops if something is already staged (user's decision, 2026-11-03) | SKILL.md Step 3.5, Git Restrictions, Roles, Output; spike-and-p0.md |
| 21 | A UI tweak loop of many small prompts re-ran the whole pipeline each time | **Done (v1.3.0).** UI Iteration, Step 0.1d: the Orchestrator makes each look-and-feel tweak directly (the user's choice, option a), with scoped Format and Lint only, and logs it in run-state. Not-a-tweak asks are turned away; undo edits back, never git. On "done": file set = the tweak log, next F-ID taken, Design Gate run once after (designer ask, or one agent updates a repo-owned artboard), stale assertions updated, one Reviewer over the whole change, then Integration, Finalizers, commit and close-out; no Manual Verification Gate | references/ui-iteration.md (new), SKILL.md (intro, side files, invocation boundary, overview, Step 0.1d, Design Gate, Enforcement, run-state, version 1.3.0, description), global CLAUDE.md entry, mermaid (third diagram) |
| — | Flow diagram out of date | Redrawn for 1.2.0, plus a new Linked Runs diagram | mermaid/orchestrator-development-workflow.md |

Worked well and needs no change: the Reviewer and Reviewer-Integration verified independently; the
Integration Diff Guard; the cp1252 caution; the batched Manual Verification.

## Feature run findings, 2026-11-03 (fixed the same day)

| # | Finding | Suggested fix | File |
|---|---|---|---|
| 22 | A run whose code lies wholly outside the component's graph roots (libs/table-tools, business-tests) has nothing for Graphify to scan; the skill has no rule for it | **Done.** Step 3.1 skips Graphify when nothing changed inside the roots, prints the reason and passes it to the Handoff Finalizer | SKILL.md |
| 23 | Integration still recorded drift findings without saying which Finalizer places them | **Done.** Integration prompt: place every drift finding, with the owner list per Finalizer | references/templates.md |
| 24 | Known-red search found an archived, Done item | **Done.** Live PMBooks only, never archive/history; the tracking item must still be open (templates.md and the agent) | agents/orchestrated-integration.md |
| 25 | The sweep moved only header pointers and reported the other `built against` lines; the reference does not say which it moves | **Done.** The sweep moves header lines only; other `built against` lines are reported under Notes | references/version-pointer-sweep.md |
| 26 | Artboard business tests need a server on the artboards folder; a foreign one on :8765 served the wrong folder | **Done.** Step 0.2 Stack line includes a static server a test target needs; check the port serves the right folder | SKILL.md Step 0.2, repo SKILLS.md |
| 27 | A Feature Reviewer running three business-test projects took 18 minutes | **Done.** Feature review: no suite run; one quick check under about five minutes at most (templates.md and the agent) | agents/orchestrated-reviewer.md |

## Agent frontmatter, 2026-11-03 (fixed the same day)

| # | Finding | Fix | File | Status |
|---|---|---|---|---|
| 28 | `orchestrated-integration` and `orchestrated-reviewer` dropped out of the session's agent list. Their `description:` is an unquoted YAML scalar holding `: ` ("rule: never", "audit: this"), which a strict YAML parser rejects; `orchestrated-finalizer` had the same ("release: updating"). | Each `: ` in the three descriptions became ` — `. All seven agent files now parse with js-yaml. | agents/orchestrated-integration.md, orchestrated-reviewer.md, orchestrated-finalizer.md | Done |

## Integration speed-up, 2026-11-09 (plugin orchestrator 1.4.0 → 1.5.0)

Evidence from the metrics logs: Phase 2 often ran as long as Phase 1 (1h06m vs 1h13m; 34m vs 29m), and
most first-pass Reviewer-Integration FAILs were report or doc bookkeeping, not code — each one re-ran the
whole gate.

| # | Change | File |
|---|---|---|
| 29 | Doc-only retry: when every R-I issue is about docs or the report, the Integration retry fixes only those, carries the gate results forward and re-runs nothing; resume the same spawn where possible. The Orchestrator snapshots the tree before and after and hands R-I the list of changed files | SKILL.md Step 2.3; templates.md; orchestrated-integration.md; orchestrated-reviewer-integration.md |
| 30 | Integration Self-Check before returning: numbers, scope, a drift line per doc path, every drift finding placed, skips recorded twice, known-red facts, every fix listed | orchestrated-integration.md; templates.md; SKILL.md Step 2.1 |
| 31 | Reviewer-Integration skipped on a clean first pass (no fixes, tree unchanged against a snapshot, gate ran at the set scope, logs agree, self-check all ticked, nothing flaky or unresolvable, known-reds look right). Never skipped on a retry | SKILL.md Step 2.2, Enforcement, Telemetry, Output; mermaid |
| 32 | Gate output goes to log files; agents read only summaries and failure blocks; R-I checks numbers against the logs | orchestrated-integration.md; orchestrated-reviewer-integration.md; templates.md; SKILL.md Step 2.1 |
