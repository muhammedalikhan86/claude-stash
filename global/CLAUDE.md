# Skills: which one, and when

The skill listing already describes each skill. These are the routing rules it does not carry.

- **Plain or plugin variant.** In a repo whose `.claude/SKILLS.md` declares a `components:` table, use
  the `plugin-` variant of `idea-triage`, `orchestrator-development-pattern` and `init-adlc-repo`;
  otherwise the plain one.
- **Sticky within a conversation.** Once the orchestrator has run in this conversation, a plain "debug
  X" or "fix X" goes straight back into it as a new Bug Fix Intake item (Step 0.1b). In the plugin
  variant, "let me iterate on the UI", "tweak mode", or a plain look-and-feel ask opens a UI Iteration.
  This resets with each new conversation.
- **`/graphify`**: invoke the `graphify` skill before doing anything else.
- **`dont-lie`** is on demand only: `/dont-lie`, or when the user asks for facts, citations, statistics,
  quotes, or a fact-check.

# Project memory vs governed docs

When working inside `idea-triage` or `orchestrator-development-pattern` on an actual project, don't
route project-specific facts (feature decisions, architecture rationale, current implementation
state, open items) into personal `~/.claude/memory`. Write them into that project's governed docs
instead: PRD/Architecture/PMBook/ADR during triage, `handoff-doc` during orchestration. Those are
version-controlled, team-visible, and reviewed like code; personal memory is private to this CLI and
invisible to teammates or other agents working the same repo. Reserve personal memory for what's
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

# Reply shape

Sort every reply to the user into up to three labelled tiers, in this order. Leave out a tier that has nothing in it.

1. **🔴 Needs you**: a decision, an approval, something to paste, or a command to run. Number these items, and end each one with exactly what the user must do.
2. **🟡 Good to know**: anything that changes the plan or what the user will see.
3. **⚪ FYI**: routine items (merges, routing, acks). Keep this tier to a line or two.

An output style's one-line summary still comes first, above the tiers. Questions under Needs you keep the answer-buttons shape.

Why: an important approval was missed because it was buried in routine reporting.
