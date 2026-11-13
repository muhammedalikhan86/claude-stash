# Finalizer Task: Graphify

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

**Follow the route your Task-Specific Inputs name.** Some orchestrators name one of three:

1. **A repo graph script** (e.g. `scripts/graph.ps1 -Component <name>`): run exactly the command given,
   from the repo root. It builds and stamps the report itself; do not run graphify or stamp separately.
   Check it exited 0 and that the report's first lines carry the stamp, then report the files.
2. **The graphify command line, per root:** for each root in order, run `graphify update <root>` with
   `GRAPHIFY_OUT` set to the absolute path of the output directory. Run every root, even when the
   inputs list only some as changed: updating one root drops the edges that run into the other roots
   (references, implements, inherits), so a partial run loses them. Then stamp the report (below),
   listing every root.
3. **The `graphify` skill:** the default when no route is named — see below.

Whatever the route, never scan the project root, which would also pull docs/ADR/PMBook/handoff content
into what must stay a code-structure graph.

**The skill route.** Invoke the `graphify` skill via the `Skill` tool, scoped to the code paths you were
given. Use `graphify-directories` when the Task-Specific Inputs supply it, falling back to
`source-code-directory` when they do not. **When it names more than one root, do not invoke the skill
once per root** — the skill keeps one scan root per output folder, so a later `--update` can drop an
earlier root. Use route 2 for several roots instead, and say so under Notes.

**Where the output goes.** Use the output directory named in your Task-Specific Inputs (`graphify-out`,
where supplied); default to `graphify-out/` at the project root when it is not. Do not hardcode a
location — a repository that keeps one graph per component points this at
`graphify-out/<component>/`, and writing to the root instead silently merges two components' graphs
into one.

Use `--update` if a `graph.json` already exists in that output directory; omit it on a first run.

**Stamp the report.** After the last root finishes, write these three blockquote lines at the very top
of `<output directory>/GRAPH_REPORT.md`, above everything graphify produced. Replace an existing stamp
rather than stacking a second one, and write the file without a byte-order mark (a BOM ahead of the
first `>` breaks the blockquote):

```
> Component: <component, or the project name when there is no component>
> Built at commit: <full SHA from `git rev-parse HEAD`> + uncommitted working tree   Date: <YYYY-MM-DD>
> Code roots: <the roots that were scanned, comma-separated>
```

Read-only git is allowed (agent **Git Restrictions**). Keep the `+ uncommitted working tree` suffix:
the graph is built before the run's commit, so it describes the tree about to be committed, not the
stamped commit. Drop the suffix only when `git status` shows the code roots clean.

Report the graph and report files you actually wrote, by their real paths, under Files Created or
Modified so the commit messages stage them — and list as committable only what the repository's
`.gitignore` does not exclude. Normally that is `GRAPH_REPORT.md` alone; `graph.json`, `graph.html`,
`manifest.json`, `cost.json` and `.graphify_analysis.json` are regenerable and stay uncommitted.
