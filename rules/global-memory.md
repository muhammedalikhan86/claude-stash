# Global memory: always on, every project

## Where to look

1. **Shaw & Partners work** → load the `shaw-estate` skill first. It is the one source of Shaw facts
   (code, `Shaw.*` libraries and feed, databases, hosting, identity, sign-in, UI, architecture
   defaults). Never copy them elsewhere; point to the skill.
2. **A library, framework, SDK, API, CLI tool or cloud service** → Context7, even when you think you
   know (training data goes stale). `resolve-library-id` first (unless given an `/org/project` id),
   then `query-docs` with one concept per call. Not for refactoring, your own business logic, code
   review or general concepts.
3. **How the user works** → the notes in `~/.claude/memory/` (list at the end). Read one when its line
   matches the task.

## Shaw hard rules (apply before the skill loads)

1. **Angular is the preferred UI framework.** When Angular is used, Angular Material (or CDK)
   components are mandatory, unless a custom component was requested. Charts: Apache ECharts via
   `ngx-echarts`.
2. **Data access is `Shaw.DataAccess`, never EF Core.**
3. **A `Shaw.*` library change goes branch → Muhammed's review → merge.** No check-in, push, Release
   build or `nuget push` before that.
4. **Query output:** print only what the question needs; never echo the password into chat or a
   tracked file; real pay, book or client figures go to the console only; no staff email addresses
   in governed docs.
5. **No schema copies in a repository.** Query the server, and record the query a finding rests on.

## Shaw live data: the DatabaseReader login

Claude may use the read-only `DatabaseReader` SQL login for analysis, design and development reads. Its connection
strings, `sqlcmd` line and password are in `~/.claude/rules/shaw-db.md`, which lives only on this
machine (the installer creates it once and never overwrites it). If it is missing or still shows
`<DB_PASSWORD>`, ask the team lead.

## Memory notes (`~/.claude/memory/`)

- [local-fixes-vs-repo-fixes](../memory/local-fixes-vs-repo-fixes.md) — when fixing setup or environment problems, report exactly which files changed (tracked or not) and propose the repo-level fix
- [dont-narrate-doc-versions-during-triage](../memory/dont-narrate-doc-versions-during-triage.md) — during idea-triage, don't mention document version numbers in replies; still bump and record them
- [writing-for-shaw-executives](../memory/writing-for-shaw-executives.md) — Shaw executive briefs: progress, genuine improvement, human guardrails; no operational detail
- [temp-files-go-in-the-scratchpad](../memory/temp-files-go-in-the-scratchpad.md) — temp files only in the session scratchpad, by full path; tell every sub-agent the exact path
- [muhammed-owns-the-ofa-initiative](../memory/muhammed-owns-the-ofa-initiative.md) — Muhammed Ali Khan owns the whole OFA initiative (OFA tool, Advisor Dashboard, Compliance tool); never call any part unowned
