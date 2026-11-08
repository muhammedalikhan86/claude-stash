# Personal memory that applies to every project

These notes live in `~/.claude/memory/`, one fact per file. They are about
how the user works and what they want, across every repository, not about any one project. When a
line below matches the task in hand, read that file before acting.

- [local-fixes-vs-repo-fixes](../memory/local-fixes-vs-repo-fixes.md) — when fixing setup or environment problems, report exactly which files changed (tracked or not) and propose the repo-level fix
- [dont-narrate-doc-versions-during-triage](../memory/dont-narrate-doc-versions-during-triage.md) — during idea-triage, don't mention document version numbers in replies; still bump and record them
- [writing-for-shaw-executives](../memory/writing-for-shaw-executives.md) — Shaw executive briefs: progress, genuine improvement, human guardrails; no operational detail
- [muhammed-owns-the-ofa-initiative](../memory/muhammed-owns-the-ofa-initiative.md) — Muhammed Ali Khan owns the whole OFA initiative (OFA tool, Advisor Dashboard, Compliance tool); never call any part unowned
- [shaw-data-access-not-efcore](../memory/shaw-data-access-not-efcore.md) — Shaw .NET work uses the in-house `Shaw.DataAccess` package, never EF Core
- [shaw-library-changes-need-review](../memory/shaw-library-changes-need-review.md) — any Shaw.* library change goes branch → review by Muhammed → merge; never check in, push or Release-build it unreviewed
