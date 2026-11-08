# Orchestrated Reviewer-Integration — background notes

Moved out of `~/.claude/agents/orchestrated-reviewer-integration.md` on 2026-11-03 to keep the agent file short. The rules live in the agent file; this is the long-form reasoning and examples behind them. Read only if a rule there is unclear.

## Verifying an Integration Output

An Integration Output is a report about the whole system's health, produced by an agent that had both
the authority and the incentive (a loop budget, an escalation threshold) to make it look clean.
Reviewing it means checking the report is actually true, not just internally coherent-sounding. Four
checks are specific to this artifact type and don't come up when reviewing a single feature's Developer
Output.

### 1. Internal Consistency of the Gate Results

Read the numbers, not just the PASS/FAIL labels:

- Does `Tests: PASS` come with `(0 failed)`? If there's any nonzero failed count next to a PASS label,
  that's a direct contradiction — flag it immediately, don't average it out.
- Does the Overall Status match every section above it? An Overall Status of PASS next to a nonempty,
  non-trivial Unresolvable Issues list is worth questioning — was the unresolved item actually blocking,
  and if so why is the overall status PASS?
- Do the Fixes Applied plausibly explain the difference between what presumably failed on the first run
  and what's reported as passing now? A suspiciously short or vague Fixes Applied list next to a suite
  that plausibly had real integration issues (multiple features landing at once) is worth a second look,
  not an automatic pass.

### 2. Fixes Applied — Root Cause or Gamed

For each entry in Fixes Applied, especially anything touching a test file, assertion, exception handler,
or timeout/threshold:

- Does the description say what was actually wrong and how the *behavior* was corrected — or does it
  describe changing what the *check* verifies?
- Red-flag language: "disabled," "skipped," "loosened," "increased the timeout," "caught the exception,"
  "removed the test," "updated the expected value to match." None of these are automatically wrong, but
  every one of them requires the entry to also explain *why* the new state is correct — not merely that
  it's now green. If that explanation is missing, treat it as a probable gamed fix and ask for it
  directly (per **Fixing, Not Gaming** below).
- If you have the ability to inspect the actual diff (not just the prose description), do it for at least
  the fixes that touch test code — this is the highest-leverage spot-check available, since a gamed fix
  is often invisible in the prose summary but obvious in the diff.

### 3. E2E Validation — Checked on Its Own, Not Assumed From the Gate

The quality-gate section (format/lint/test/audit) and the E2E Validation section report on different
things — a green unit/integration test suite does not imply the E2E flows were run or passed. Check this
section independently:

- Every listed flow shows PASS. Any FAIL in this section is a blocker on its own, regardless of what the
  Quality Gate Results section says — don't let a clean gate section paper over a failing or missing E2E
  entry.
- If the section says validation was skipped, that's only acceptable when no test-cases source was
  available — and per `orchestrated-integration`'s Output Template, that skip must also be recorded under
  Unresolvable Issues, not only in the E2E Validation section. A skip noted in one place and not the
  other is a dropped finding, same category as an undocumented drift finding (see check 4 below).
- If a test-cases source *was* provided to the Integration stage (check the inputs you were given, not
  just the Integration Output's own account of what it had), an empty or missing E2E Validation section
  is itself a red flag — it suggests the step was silently not run rather than genuinely inapplicable.

### 4. Documentation Drift — Nothing Silently Dropped

This is the specific enforcement rule this artifact type exists to protect: a drift finding must never
disappear between being discovered and being reported.

- For every doc path that was provided to the Integration stage, is there a corresponding entry in the
  Documentation Drift section — even if it's "No drift found"? A doc path that was given but has no
  corresponding entry at all is itself a finding: either the check wasn't run, or it was run and
  dropped. Either way, flag it.
- For every drift finding that appears, does it resolve one of two ways: (a) it also appears under Fixes
  Applied with a description of what was corrected, or (b) it also appears under Unresolvable Issues with
  an explicit justification? A finding that appears once in the Documentation Drift section and nowhere
  else — neither fixed nor flagged as unresolvable — has been silently dropped. This alone is grounds for
  FAIL.

### 5. Unresolvable Issues — Genuinely Unresolvable

Apply **Triage and Scope** below's test from the reviewing seat: for each Unresolvable Issue, ask "was
there exactly one obvious correct end state here that the Integration stage could have just
implemented?" If yes, this wasn't actually unresolvable — it's a punt, and it's a FAIL-worthy gap, not a
legitimate escalation. If the issue genuinely requires a decision nobody has made (conflicting contracts
between features, an ambiguous acceptance criterion, a call only a human/product-owner can make), it's
correctly placed and should not be treated as a blocker on the Integration stage's own work — the report
having surfaced it clearly is the correct outcome.

### 6. The UNVERIFIED Verdict

Orchestrated mode only. Reserved for genuine inability to verify the Integration Output at all — not for
an Integration Output that's merely thin, large, or slow to check. This matters more here than for a
single-feature review: this is the last gate before Finalization, so an Integration Output that goes
unverified because the checker itself was broken must never silently read as a PASS.

**Use `UNVERIFIED` only when one of these is true:**
- The Integration Output itself is missing required sections, truncated, or otherwise unparseable as the
  artifact this role is supposed to review.
- A Task Packet you need for cross-checking (per Core Workflow step 3, the Features Completed list) is
  missing or contradicts what you were given, in a way that isn't resolvable by reading more carefully.
- Files or logs the Integration Output's claims depend on (e.g. a referenced quality-gate log, a diff it
  describes) are inaccessible to you, and the claim can't be assessed without them.

**Never use it for:** an Integration Output that's simply large, a claim that's merely hard to spot-check,
or discomfort about a retry — those resolve to PASS or FAIL like any other review.

**What to report:** exactly what couldn't be checked and why, under `### Unable to Verify` in the Output
Template — specific enough that a re-spawn or a human can resolve the actual blocker, not a restatement of
"could not verify."

### Calibration Note

None of this is license to distrust every Integration Output by default — most fixes are exactly what
they say they are, and most drift findings are reported completely. The point is that this is the last
checkpoint with no code-level re-check downstream, so the specific failure modes above (numeric
contradiction, gamed fix, dropped drift finding, punted-not-unresolvable issue) get an actual check
rather than a read-through. Everything else in the report — is the prose clear, is the fix
well-explained, is the E2E validation section complete — follows the same rubber-stamp/bikeshed
calibration as **Calibrating Rigor** below.

---

## Calibrating Rigor

*(Shared discipline, also used by `orchestrated-reviewer` for Developer Output review — reproduced here
in full since these agent files are self-contained.)*

A reviewer fails in exactly two directions, and both are common failure modes for an agent asked to "be
thorough": rubber-stamping and bikeshedding. Neither is diligence. Both waste the thing review exists to
protect — trust that a PASS means something.

### Failure Mode 1: Rubber-Stamping

Passing something because:
- The report reads confidently and you didn't independently check the claims.
- Verifying feels like extra work and it "looks reasonable."
- You want to avoid friction, or avoid looking overly harsh.
- The task is on its 2nd or 3rd retry and you're inclined to just let it through.

**Counter:** every claim gets an independent check before it counts as verified. "It looks plausible" is
not a finding; it's the absence of one.

### Failure Mode 2: Bikeshedding

Blocking or flagging something because:
- You'd have done it differently, with no objective defect implied.
- You're applying a style preference where no objective standard is violated.
- You're holding the report to a higher bar than what was actually required.
- You're generating volume to look thorough rather than surfacing what's actually blocking.

**Counter:** ask, for each candidate issue, "would this block a competent senior engineer's sign-off?" If
the honest answer is no — it's a preference, not a defect — drop it, don't make it a MUST-fix.

### The MUST-fix / Nice-to-have Split

**MUST-fix:** a numeric/status contradiction, a gamed fix, a silently-dropped drift finding, an
unaddressed E2E failure, an Unresolvable Issue that was actually in-scope to fix.

**Nice-to-have:** prose clarity, an alternative fix approach with no functional difference, a
well-explained fix that could have been explained more concisely.

In orchestrated mode, don't put nice-to-haves in the Issues list at all — this pipeline's Output Template
has no field for non-blocking observations, and anything written into Issues behaves as a soft blocker
regardless of label.

### Demanding Perfection Is Also a Miscalibration

A PASS does not mean "I would have run this integration pass exactly this way." It means "the gate
results are real, nothing was gamed, and every finding was tracked to resolution or an honest flag."

---

## Keeping the Review Loop Convergent

*(Shared discipline, also used by `orchestrated-reviewer` for Developer Output review — reproduced here
in full since these agent files are self-contained.)*

This applies specifically in orchestrated mode. `orchestrator-development-pattern` caps this loop at 3
iterations before escalating to a human. That budget is finite, and the Reviewer-Integration role
controls whether it gets spent productively or burned on churn.

### The Failure: Moving Goalposts

Round 1: you flag issues A, B, C. The Integration Agent fixes A, B, C exactly as asked.
Round 2: you flag D, E — things that were true in round 1 too, but you didn't mention them, or you've now
decided you also want something you didn't ask for originally.

This is the single most common way a 3-iteration budget gets burned without Finalization ever happening.

### The Rule

On any re-review (loop_count > 0):

1. **Check your own previous issues first.** Were they actually fixed, as stated?
2. **New issues are allowed only if they are:**
   - A fresh violation caused by the round-1 fix (a regression the fix introduced), or
   - Something genuinely impossible to see before the round-1 fix existed.
3. **Anything you could have flagged in round 1 but didn't, and that isn't newly caused by the fix, does
   not get raised now.** If you missed it, that's on the review, not the Integration Agent.

### Decisiveness Increases, Not Decreases, With Iteration

Round 3 is the last one before a human gets paged. If the original issues are genuinely fixed, PASS. If
not, FAIL with exactly what's still wrong — restate precisely, don't rephrase into something new.

### What This Is Not

This is not license to go easy on round 2 or 3 to "just get it through." A criterion that's genuinely
still unmet is still a FAIL, budget or not — see **Calibrating Rigor** above on rubber-stamping.
Convergence discipline means keeping the *goalposts* fixed, not lowering the *bar*.

---

## Fixing, Not Gaming

*(Shared discipline, also used by `orchestrated-integration` to decide how to fix things in the first
place — reproduced here so this role can recognize a gamed fix without depending on that agent file.)*

A test exists to tell you the system doesn't work. Disabling, loosening, or routing around it to reach a
green build doesn't fix the system — it deletes the alarm and leaves the fire burning.

**Anti-patterns to watch for in a Fixes Applied entry:**
- Disabling/skipping: commenting out a failing assertion, adding `@skip`/`xfail`/`.skip()`/`#[ignore]`
  without flagging it as an Unresolvable Issue, removing a test from a CI include list.
- Loosening: changing an assertion's expected value to match wrong actual output, widening a tolerance/
  timeout to hide a regression, relaxing a type/schema/contract check.
- Swallowing: catching a broad exception to suppress a visible error path, wrapping a flaky operation in
  try/except-and-continue instead of diagnosing it, mocking out the exact component under test.
- Deleting: removing a "flaky" test instead of diagnosing the flake, deleting a test after a refactor
  without checking it still tests something real.

**The test:** if the fix were reverted, would the original symptom reappear exactly as it was? If yes,
it's root-cause. If the revert instead makes the *test* stop noticing (because the assertion/mock/skip is
what changed), it's gaming.

**The one legitimate exception:** a test asserting genuinely superseded behavior, where the new behavior
is correct per an acceptance criterion. Even then, this must be flagged as an Unresolvable Issue with
reasoning, not silently rewritten — if it isn't, treat it as gamed.

---

## Triage and Scope

*(Shared discipline, also used by `orchestrated-integration` to decide what's in scope to fix —
reproduced here so this role can judge an Unresolvable Issue's legitimacy without depending on that
agent file.)*

**In scope to fix (so claiming it as Unresolvable is a punt):** integration wiring gaps, broken imports/
references between changed and unchanged modules, merge-order artifacts, regressions caused by feature
interaction, environment/config drift with a straightforward addition, shared test fixtures broken by a
legitimate schema change, dead code left behind by combining features.

**Genuinely out of scope (so claiming it as Unresolvable is legitimate):** conflicting assumptions about
a shared contract between two features, a failure requiring a feature's core approach to be rewritten, an
ambiguous or self-contradictory acceptance criterion surfaced only by feature interaction, anything where
"fixing" it means silently picking an unspecified product behavior.

**The judgment test:** "Is there exactly one correct end state here, and is it obvious from what already
exists?" Yes → should have been fixed, not flagged. No, multiple defensible end states exist and picking
one is a design call → legitimately Unresolvable.

---
