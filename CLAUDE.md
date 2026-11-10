# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# idea-triage
- **idea-triage** (`~/.claude/skills/idea-triage/SKILL.md`) - pre-development workflow: idea → PRD → Architecture (with ADRs for non-trivial decisions, in `adr-directory`) → PMBook. Invoke via `/idea-triage` or automatically when the user presents a new idea, product concept, or says "I want to build X". In a plugin-based repo — one whose `.claude/SKILLS.md` declares a `components:` table — use the `plugin-` variant instead.

# llm-council
- **llm-council** (`~/.claude/skills/llm-council/SKILL.md`) - runs a question, idea, or decision through a council of 5 AI advisors that independently analyze it, peer-review each other anonymously, and synthesize a final verdict. Invoke via `/llm-council`, or automatically when the user asks for a debated/pressure-tested outcome (e.g. "council this", "war room this", "pressure-test this", "should I X or Y", "I can't decide").

# orchestrator-development-pattern
- **orchestrator-development-pattern** (`~/.claude/skills/orchestrator-development-pattern/SKILL.md`) - multi-agent development orchestrator: reads the PMBook (or an ad-hoc bug report), detects the runtime platform, and coordinates developer + reviewer sub-agent pairs in a controlled loop (max 3 retries before human escalation), then runs an integration agent for the full test suite, build health, and a documentation-drift check against Architecture/PMBook/test-runbook, followed by graphify. Language and platform agnostic. Invoke only when the user explicitly wants the full orchestrated pipeline run end-to-end — e.g. "orchestrate a fix for X", "run the orchestrator on this bug", "build this from the PMBook". Do NOT invoke on a plain "debug X" / "fix this" / "why is this failing" — those are a normal debugging conversation (or `debugging-wizard`), not a request to spin up the Developer/Reviewer/Integration/Finalizer loop. **Exception — sticky within a conversation:** once the orchestrator has been invoked in the current conversation, that high bar applies only to the *first* invocation. For the rest of that same conversation, a plain "debug X" or "fix X" is routed straight back into it as a new Bug Fix Intake item (Step 0.1b), no re-justification needed — the user already opted into orchestrated mode once. This resets with each new conversation; it does not carry over. In a plugin-based repo — one whose `.claude/SKILLS.md` declares a `components:` table — use the `plugin-` variant instead.

# dont-lie
- **dont-lie** (`~/.claude/skills/dont-lie/SKILL.md`) - truth/accuracy rules: flags uncertainty, refuses invented sources/quotes/APIs/stats, verifies its own results. On-demand only (not always-on) — invoke via `/dont-lie`, or automatically when the user asks for facts, citations, statistics, quotes, or to verify/fact-check a claim.

# plugin-idea-triage
- **plugin-idea-triage** (`~/.claude/skills/plugin-idea-triage/SKILL.md`) - the plugin-repo fork of `idea-triage`. Same three gated phases (PRD → Architecture → PMBook), but it first resolves which **component** the idea belongs to and writes into that component's own `docs/<component>/` folder, with per-component tranches. Use it in any repo whose `.claude/SKILLS.md` declares a `components:` table; use plain `idea-triage` in a single-component repo. Invoke via `/plugin-idea-triage` or on the same triggers as `idea-triage`.

# plugin-orchestrator-development-pattern
- **plugin-orchestrator-development-pattern** (`~/.claude/skills/plugin-orchestrator-development-pattern/SKILL.md`) - the plugin-repo fork of `orchestrator-development-pattern`. Resolves the component first, then runs the same Developer→Reviewer→Integration→Finalization pipeline scoped to that component's docs, source roots and knowledge graph, plus a Design Gate that settles the artboard before a Developer is spawned. Use it in any repo whose `.claude/SKILLS.md` declares a `components:` table. Invoke only when the user explicitly wants the full pipeline run end-to-end — e.g. "orchestrate a fix for X", "run the orchestrator on this bug", "build this from the PMBook". Do NOT invoke on a plain "debug X" / "fix this" / "why is this failing" — those are a normal debugging conversation, not a request to spin up the Developer/Reviewer/Integration/Finalizer loop. **Exception — sticky within a conversation:** once the orchestrator has been invoked in the current conversation, that high bar applies only to the *first* invocation. For the rest of that same conversation, a plain "debug X" or "fix X" is routed straight back into it as a new Bug Fix Intake item (Step 0.1b), no re-justification needed — the user already opted into orchestrated mode once. This resets with each new conversation; it does not carry over. **UI Iteration (v1.3.0):** "let me iterate on the UI" / "tweak mode", or a plain look-and-feel ask once the skill is sticky, opens a UI Iteration — Claude makes each small tweak directly with no gates, and the gates (Design Gate, one Reviewer, Integration, Finalizers, commit) run once when the user says "done".

# plugin-init-adlc-repo
- **plugin-init-adlc-repo** (`~/.claude/skills/plugin-init-adlc-repo/SKILL.md`) - the plugin-repo fork of `init-adlc-repo`. Scaffolds `.claude/` settings, `.mcp.json`, the knowledge-graph `.gitignore` block, `CLAUDE.md`, a shared `docs/adr/` and one governed-doc folder per component, and writes the `components:` table the two skills above read. Also runs in **add mode** to scaffold one new component into a repo that already has the rest. Invoke via `/plugin-init-adlc-repo`. Use plain `init-adlc-repo` for a single-component repo.

# project-memory-vs-governed-docs
When working inside `idea-triage` or `orchestrator-development-pattern` on an actual project, don't
route project-specific facts (feature decisions, architecture rationale, current implementation
state, open items) into personal `~/.claude/memory` — write them into that project's governed docs
instead: PRD/Architecture/PMBook/ADR during triage, `handoff-doc` during orchestration. Those are
version-controlled, team-visible, and reviewed like code; personal memory is private to this CLI and
invisible to teammates or other agents working the same repo — using it for project facts recreates
the single-point-of-failure problem those skills exist to avoid. Reserve personal memory for what's
genuinely about *you* across projects: your role, your preferences for how Claude should collaborate,
feedback on approach, and pointers to external systems (Linear, Slack, dashboards).

# answer-buttons
The answer-buttons plugin draws buttons under questions to the user (needs 2+ in one reply). Write them in a shape it can read:
- **Yes/No:** one question per line, ending in `?`. No options needed.
- **A question that asks for a name or a value** ("which group?", "what port?") is not Yes/No. Give it options (a Choice), or end its line with `(no buttons)`. Bare, it renders as Yes/No and the answer comes back as "Yes".
- **Choice:** the question line, then 2+ options on the next lines, indented, no blank line between: `a) text` or `- text`. Add `(Recommended)` at the end of the option you would pick.
- **Pick any:** end the question line with `(pick any)` and list options as above. Without options it is just Yes/No.
- **Other:** every question gets an "Other" button for free text. Do not add an "Other" option yourself.
- **No buttons:** a line ending in `(no buttons)` switches buttons off for its block: under a heading, until the next heading; on a plain lead-in line, until the next blank line; on a list item, for its nested lines. Use it for any list of `?` lines that are not questions to the user (checklists, "things to look for", examples).
- Maximum 8 questions per reply; code blocks and `>` quotes are never read as questions.
- Answers come back as `My answers to your questions:` with `→` lines. `Not answered` means ask, do not assume.
- **Open questions stay open.** A reply's buttons stay in the chat, answerable, across later replies, until answered, dismissed or replaced. So never reprint a question that is still open. To withdraw earlier questions because new ones supersede them, put the line `(replaces earlier questions)` in the reply that asks the new ones.

# task-bar
When you start any job of three or more steps, call `mcp__task-bar__set_tasks` (the task-bar mod's tool, if you have it) with the whole task list. Call it again whenever a task starts, finishes or is added, or the plan changes, and send an empty list once the user has seen everything done. The user reads progress from the bar above the prompt instead of scrolling. If you do not have the tool, carry on without it.
