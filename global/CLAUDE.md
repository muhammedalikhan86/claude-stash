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
The answer-buttons plugin turns a question to the user into buttons. It reads only lines tagged `[Question]:`; any other "?" is ordinary text, so a question you ask and answer yourself never gets buttons. Whenever you need the user to answer or decide something, write it in this shape:

```
[Question]: Which order should I run them in?
Options: 1. «Sync first (Recommended)» 2. «Backfill first» 3. «Other»
```

- **`[Question]:`** starts its own line (bold or after a list number is fine). The "?" is optional: "[Question]: Tell me the port to use" works.
- **`Options:`** goes on the next line. Number every option and put each one between `«` and `»` (guillemets), never bullets. For Yes/No write `Options: 1. «Yes» 2. «No» 3. «Other»`.
- **`«Other»` is always the last option.** The plugin draws it as a button that opens a text box.
- Add `(Recommended)` inside the quotes of the option you would pick, and `(pick any)` at the end of the question line when several options may be picked.
- One question gets buttons too; up to 8 per reply. Tagged lines in code blocks and `>` quotes are ignored.
- Answers come back as `My answers to your questions:` with `→` lines. `Not answered` means ask, do not assume.
- **Open questions stay open.** A reply's buttons stay in the chat, answerable, across later replies, until the user presses Submit or Dismiss. Nothing else closes them: not a later reply, not a typed message, not another session's message. So never reprint a question that is still open, and never assume a typed message answers it.

# task-bar
When you start any job of three or more steps, call `mcp__task-bar__set_tasks` (the task-bar mod's tool, if you have it) with the whole task list. Call it again whenever a task starts, finishes or is added, or the plan changes, and send an empty list once the user has seen everything done. The user reads progress from the bar above the prompt instead of scrolling. If you do not have the tool, carry on without it.

Give each task an `estimateMinutes` guess when you can. Parallel work (several workers or agents) gets a `group` per task, the worker's or agent's name, so each draws under its own heading. A helper (subagent) has its own list, drawn indented under its task name: send only your own steps, never your caller's.

# Reply shape

Sort every reply to the user into up to three labelled tiers, in this order. Leave out a tier that has nothing in it.

1. **🔴 Needs you**: a decision, an approval, something to paste, or a command to run. Number these items, and end each one with exactly what the user must do.
2. **🟡 Good to know**: anything that changes the plan or what the user will see.
3. **⚪ FYI**: routine items (merges, routing, acks). Keep this tier to a line or two.

An output style's one-line summary still comes first, above the tiers. A question to the user never goes inside a numbered item. Each one sits on its own lines, after the numbered items, in the answer-buttons `[Question]:` shape.

Why: an important approval was missed because it was buried in routine reporting.
