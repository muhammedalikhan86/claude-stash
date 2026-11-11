---
name: disparity-checker
description: Compare what was built with what should have been, and list the gaps. Drives the running app and the design artboards with Playwright at the repo's parity viewports, in every state a board draws or a test case names, checks each test case's expected outcome against both, and writes one findings file of open issues (screen, state, board vs built, severity, owning component, suggested type). Read, analyse and report only: it never edits the PMBook, the artboards, the code or the tests; the orchestrator folds the file in through its Findings Intake. Use when asked to "check disparity", "run the disparity checker", "compare the build with the boards", "what's different from the design", or "find the gaps between the boards and the app". Works in plain and plugin (components:) repos.
metadata:
  version: "1.0.0"
  related-skills: orchestrator-development-pattern, plugin-orchestrator-development-pattern, sync-artboards
---

# Disparity checker

Finds where the built app differs from its specification, the artboards and the test cases, and writes
the gaps as **one findings file**. It is run on its own, outside the orchestrators. It never fixes
anything and never assigns IDs: the orchestrator's **Findings Intake** turns the file into Bug Log rows
(`references/findings-intake.md`).

An artboard is a **specification**: where it and the build disagree, the build is the defect, unless the
board itself looks wrong (then the finding is a design-row question, not a Bug).

## Read-only, always

- **Never edit** the PMBook, the artboards, the design rows or rounds, the code, the tests, the specs
  or helpers, `.claude/SKILLS.md` or any governed doc. Never commit.
- **It writes only:** the findings file, and its evidence folder (below).
- Starting the app or the board server to measure them is allowed. Stop what you started when done.

## Bindings

Read `.claude/SKILLS.md` (the **Disparity Checker** block, then the orchestrator block for anything it
lacks):

| Binding | Use | Default when unset |
|---|---|---|
| `findings-directory` | Where the findings file goes | plugin: `./docs/{component}/findings`; plain: `./docs/findings` |
| `artboards-directory`, `artboard-server` | The boards and how they are served | look in the repo, else ask |
| `app-url` | The app, with **this checkout's** port offset (`~/.claude/ports.md`, never assume 0) | look in the repo, else ask |
| `parity-viewports` | Widths to measure at | `1440` |
| `parity-command` | The repo's checked-in parity harness | look for a `parity` or `layout` spec |
| `test-cases-doc`, `test-runbook-location` | The test cases and runbook | look in the repo |
| `design-rows-directory`, `adr-directory`, `project-management-doc`, `run-state-file` | For sifting (step 5) | skip that source |

For a missing binding, **look in the repo first**, as `sync-artboards` does: the root `CLAUDE.md`, the
run skill (`.claude/skills/run-app/`), the design README, and the README of whatever tests against the
boards (e.g. `business-tests/README.md`). Say where each value came from, and offer once, at the end of
the report, to write it into `.claude/SKILLS.md`. Only ask for what the repo does not say.

**Plugin repo** (`components:` table): resolve the component as the plugin orchestrator's Step 0.0a
ladder does (the user named it, else ask; never a default), and fill every `{component}` template from
it, the component's row overriding. "All components" is one run per component, one file each.

**Evidence folder:** `<folder of run-state-file>/.orchestrator-work/disparity/<file stem>/` (gitignored
beside run-state). Screenshots, raw measurements and any script you write go there, never in the repo.

## Steps

Use the task bar if you have one: one task per step, and one per screen in step 4.

### 1. Scope

Which screens: the ones the user named, else every board in `artboards-directory` (plugin: the
component's). List them, with the board file and the app route for each. A board with no route found is
`Unable to check`, with the reason.

### 2. Bring up both sides

Check that `app-url` and the board server answer. If one is down, start it the way the repo says (its
`make` targets or run skill; `artboard-server`). If it still will not load, stop and report what failed:
never report a screen you could not measure as matching.

### 3. Build the state list (boards + test cases)

For each screen, list every state to drive, from two sources:

1. **The board:** its state labels, frames and toggles (populated, empty, loading, error, each dialog
   and menu, each role or seat, each status).
2. **The test cases:** `test-cases-doc`, the test runbook, and the repo's business-test feature files
   (e.g. `business-tests/**/*.feature`) where present. Take each scenario that touches the screen: its
   state, role or seat, status, the path to reach it, and its expected outcome.

Then match them. **A state the test cases name that no board draws** is a finding (`Design-row
question`: the board is missing it). **A state a board draws that no test case covers** is a finding
(`Test-case gap`). Both are Low unless the state is an error or a permission boundary (Medium).
Earlier findings files with `Status: open` in `findings-directory` (e.g. a Board Parity Check's
deferred minor gaps) are read too: a difference one already holds is not written again.

### 4. Drive and measure

Per screen, for every state in step 3, at every width in `parity-viewports`, on both sides. Follow the
Parity Prompt's measuring rules, which are the one source for **how** to measure:
`~/.claude/skills/orchestrator-development-pattern/references/parity.md` §Parity Prompt, "How to measure"
steps 1 to 5. Read them now. Two differences from that prompt:

1. **The whole screen is in scope**, not one item's elements. Measure every element the board draws.
2. **Harness:** run or reuse `parity-command`, or the repo's existing `parity`/`layout` spec (e.g.
   `business-tests/layout`), importing its helpers by path. Never edit them; any spec or script you
   write lives in the evidence folder and runs with the repo's Playwright. No Playwright in the repo →
   say so and stop; never install packages.

Reach states with `page.route` stubs as the prompt says, and roles or seats the way the test cases do
(their sign-in or fixture). Also, for each test-case scenario: walk its path in the app and check its
**expected outcome** against the build and against the board. An outcome the build breaks is a finding;
one the board contradicts is a `Design-row question`.

### 5. Sort and sift

Per difference:

1. **Board wrong, or a target?** Apply the Parity Prompt's Verdict rules on design defects and "before
   calling the board wrong" (same file): a board value that is not a design-system token, and that the
   design kit and built siblings do not use, is a `Design-row question`. Otherwise the board is the
   target and the difference is a `Bug`.
2. **Sift out what is already settled.** Not a finding, listed under `Sifted` with its source: a
   difference a ruling covers (a `Done` design row, an ADR, run-state `decisions.rulings`, a packet's
   Ruled deviations); one a `Planned` or `In Progress` PMBook item will build, or an open Bug Log row
   already covers (`planned: <ID>`); one the harness's own known-differences list holds.
3. **Owner.** The component whose `code` roots hold the file that renders or styles the element
   (plugin repos; read the `components:` table). Chrome the shell renders (the top bar, nav, page
   frame, theme) belongs to the shell even on a plugin's screen. When the measured value is set in
   another component's stylesheet, that component owns it. Plain repos: the repo's name. Also note
   **Built by**: the work item that built the surface (the PMBook, or `git log` on its files), else `—`.
4. **Severity**, from the one major/minor definition:
   `~/.claude/skills/plugin-orchestrator-development-pattern/references/ui-packets.md` §Major and minor
   gaps (read it now; it serves plain repos too).
   - **High**: a major gap, or a test case's expected outcome the build breaks.
   - **Medium**: a minor gap in a font-weight step or a colour shade.
   - **Low**: any other minor gap (a few px of spacing, size, radius or line height).
5. **One finding per element per difference**; the same difference at several widths or states is one
   finding listing them.

### 6. Write the findings file

`<findings-directory>/<yyyy-mm-dd>-<scope>.md` (scope: the screen, or `all`), in the format in
`references/findings-format.md` (read it now). `Status: open`. Never overwrite an earlier file; a second
run the same day adds `-2`.

### 7. Report

One line, then numbered: the file path; counts by severity and by suggested type; the owners (plugin);
what was `Unable to check`; bindings found in the repo (and the offer to write them). Then the next step:
`orchestrate the findings in <path>` runs the orchestrator's Findings Intake, which logs them.
