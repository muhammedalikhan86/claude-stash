# Orchestrated Integration — background and worked examples

Companion to `~/.claude/agents/orchestrated-integration.md`. The agent file holds the rules; this file
holds the reasoning and longer examples behind them. Read it only when a rule there is unclear.

## Why the Integration stage exists

Where `orchestrated-developer` stays deliberately narrow (touch only this feature), this role is
deliberately broad: the entire codebase is in scope, and fixing what's broken between the parts — not
just reporting it — is the job. A per-feature "it passed when I built it" is not evidence; work built
against an incomplete codebase produces unreliable results in isolation, which is exactly why this stage
exists.

## Fixing, Not Gaming — the reasoning

A test exists to tell you the system doesn't work. Disabling, loosening, or routing around it to reach a
green build doesn't fix the system — it deletes the alarm and leaves the fire burning.

### Anti-pattern examples in full

**Disabling or skipping:**
- Commenting out a failing assertion, or the test that contains it.
- Adding `@skip` / `xfail` / `.skip()` / `it.skip` / `#[ignore]` (or the platform equivalent) to make a
  suite report green, without explicitly flagging it as an Unresolvable Issue.
- Removing a test from a CI config or test-runner include list.

**Loosening:**
- Changing an assertion's expected value to match whatever the (wrong) actual output currently is,
  instead of fixing the code to produce the right output.
- Widening a numeric tolerance, timeout, or threshold specifically to hide a regression rather than
  because the original bound was genuinely wrong.
- Relaxing a type, schema, or contract check because the real implementation doesn't satisfy the
  stricter one.

**Swallowing:**
- Catching a broad exception type to suppress an error path that should be visible.
- Wrapping a flaky operation in a blanket try/except-and-continue that hides the non-determinism.
- Mocking out the exact component under test so the test can no longer fail.

**Deleting:**
- Removing a "flaky" test instead of diagnosing why it's flaky (shared state, timing dependency,
  unseeded randomness, real race condition).
- Deleting a test that fails after a refactor without checking whether it's still testing something real.

### Why this rule has no exceptions

Every other rule in this skill set balances competing goods — thoroughness against speed, rigor against
pragmatism. This one doesn't, because a gamed gate is worse than no gate: it actively misinforms everyone
downstream (the Reviewer-Integration stage, the human reading the final report, the next developer who
trusts a green build). An honest FAIL with a flagged Unresolvable Issue costs a delay. A gamed PASS costs
trust in every future PASS this pipeline produces.

### The legitimate exception, explained

Sometimes a test asserts old, superseded behavior — a feature intentionally changed what should happen
and the test wasn't updated. Fixing the expectation is not gaming *when the new behavior is the correct,
intended one* — but the call is not yours to make silently mid-pass. Example flag: "Test X asserts
pre-feature-Y behavior; feature Y's acceptance criteria explicitly changed this; recommend updating the
test's expectation." Reviewer-Integration and the human need to see it and agree it was a real spec update.

## Triage and Scope — examples

### In scope (one obvious correct end state)

- **Integration wiring gaps**: a feature wasn't registered with the DI container, router, plugin list.
- **Broken imports/references** after a rename or move in one feature.
- **Merge-order artifacts**: two features built against slightly different snapshots of a shared file.
- **Regressions from feature interaction**: feature B changed shared state, a fixture, or a config default.
- **Environment/config drift**: a config key or env var one feature assumes and another didn't add.
- **Shared test fixtures** broken by another feature's legitimate schema change.
- **Dead code from combining features**: unused exports, orphaned files, branches made unreachable.

### Out of scope (needs a decision nobody has made)

- **Conflicting assumptions about a shared contract** — picking one is a design decision.
- **A failure that would require rewriting a feature's core approach.**
- **An ambiguous or self-contradictory acceptance criterion** surfaced only once features interacted.
- **Silently picking an unspecified product behavior** (e.g. which of two validation rules wins).

## Documentation drift — the reasoning

Treat governed docs as a spec the code must still satisfy, not narrative that's nice to keep current.
Staleness should fail loudly, in the same gate as a broken test, not sit unnoticed until someone trips
over it months later. An incorrect "fix" to documentation is itself new drift.

### Out-of-scope work sharing the working tree — worked example

You may be asked to run the gate against "the entire codebase" while unrelated uncommitted work sits in
the tree. That changes what you may *claim*, not only what you may *touch*. Concrete pattern: scope the
doc fix narrowly to what your feature changed ("`cue_detector.py` now does X — this is the only change to
*its* data flow"), and if you noticed other drift while in the file, add a short explicit note pointing at
it and flag it under Unresolvable Issues. A doc edit that trades one false claim for another isn't a fix;
it's new drift with better prose.

## Re-running a green gate

Earlier versions said "re-run enough to be confident", which led to passing suites being run three times
in a row. That cost real minutes on large suites and added no information: a deterministic green run is
final, and real flakiness is already caught by the one isolated re-run in triage. Hence the bounded rule
in the agent file.
