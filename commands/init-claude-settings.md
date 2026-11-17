# /init-claude-settings

> Global slash command. Invoke with: `/init-claude-settings` in any git repo.
> Scaffolds a stack-agnostic `.claude/` setup (permissions, a session
> orientation pointer file, generic commands, skill wiring, diagram
> pipeline) for the `idea-triage` → `orchestrator-development-pattern` →
> `graphify` workflow. Detects the current repo's language/platform from
> whatever's actually present — never assumes a specific stack.

## Steps

1. **Confirm scope.** Verify the current directory is a git repository
   (`git rev-parse --is-inside-work-tree`). If not, stop and tell the user to
   run this inside a git repo (offer `git init` if they want one).

2. **Check for existing `.claude/` state.** If `.claude/settings.json`,
   `.claude/memory.md`, `.claude/SKILLS.md`, or `.claude/commands/*.md`
   already exist, show the user what's there and ask before overwriting
   anything — merge/append instead of clobbering unless they explicitly say
   to replace.

3. **Detect the stack.** Look for signal files to identify language/platform
   (do not hardcode — check what's actually present):
   - `package.json` → Node/JS/TS (read `scripts` for run/test/lint/build)
   - `requirements.txt` / `pyproject.toml` → Python (look for `pytest`,
     `ruff`, `black`, entry point like `app.py`/`main.py`)
   - `Cargo.toml` → Rust (`cargo run` / `cargo test`)
   - `go.mod` → Go (`go run .` / `go test ./...`)
   - `*.csproj` / `*.sln` → .NET
   - `Gemfile` → Ruby
   - `pom.xml` / `build.gradle*` → Java/Kotlin
   - No match → ask the user how to run/test the project, don't guess.

4. **Create `.claude/settings.json`.** If it doesn't exist, write:

   ```json
   {
     "permissions": {
       "allow": [
         "Read",
         "Bash(ls *)",
         "Bash(cat *)",
         "Bash(cd *)",
         "Bash(mkdir *)",
         "Bash(mv *)",
         "Bash(cp *)",
         "Bash(echo *)",
         "Bash(curl * http://127.0.0.1*)",
         "Bash(curl * http://localhost*)",
         "Bash(git log *)",
         "Bash(git status *)",
         "Bash(git diff *)",
         "Bash(git add *)",
         "Bash(git commit *)",
         "Bash(git branch *)"
       ],
       "deny": [
         "Bash(*git push --force*)",
         "Bash(*git push -f *)",
         "Bash(*git reset --hard *)",
         "Bash(*git stash*)",
         "Bash(*git checkout*)",
         "Bash(*git switch -c*)",
         "Bash(*git switch -C*)",
         "Bash(*git switch --create*)",
         "Bash(*git switch --force-create*)",
         "Bash(*rm -rf *)"
       ],
       "defaultMode": "auto",
       "additionalDirectories": []
     },
     "hooks": {
       "PreToolUse": [],
       "PostToolUse": [],
       "Stop": [],
       "Notification": []
     },
     "effortLevel": "high"
   }
   ```

   Then, based on the stack detected in step 3, append a handful of
   stack-specific allow patterns for the package manager / test runner /
   build tool actually present (e.g. `Bash(npm *)` + `Bash(node *)` for
   Node, `Bash(cargo *)` for Rust, `Bash(dotnet *)` for .NET). Do not add
   permissions for tools that aren't present in the repo.

   **Allow patterns are prefix rules: `Bash(<command> *)`, with the space.**
   The space makes a word boundary, so `Bash(ls *)` matches `ls -la` but not
   `lsof`. Never write an allow rule with a leading `*` or without the space
   (`Bash(*cd*)`, `Bash(cd*)`): `*cd*` matches any command that merely contains
   "cd". Claude Code splits `&&`, `;` and `|` chains and checks each part on its
   own, so a leading `*` buys nothing. The `deny` list keeps its leading `*`
   on purpose: there, matching more is the safe direction.

   **`git stash`, `git checkout` and branch-creating `git switch` (`-c`, `-C`,
   `--create`, `--force-create`) stay in `deny` — do not move any of them back
   to `allow`.** The first two discard uncommitted work silently, leaving no
   trace but a `git status` that comes back cleaner than it should; `git switch
   -c` relocates the working tree onto a branch the human never asked for, so
   their next commit or PR lands somewhere they did not choose. Creating or
   changing a branch is the user's decision. Read-only git (`git status`,
   `git diff`, `git log`, `git rev-parse`) stays allowed, and verification
   should lean on those plus scratchpad copies of files.

5. **Create `.claude/memory.md`** from this skeleton (leave placeholders —
   do not invent product details). This file is deliberately a pointer, not
   a store: once `idea-triage` and `orchestrator-development-pattern` are
   wired in (step 8), the PRD, Architecture doc, ADRs, PMBook, and
   handoff-doc are each the one governed home for that kind of information.
   Duplicating decisions/architecture/status into `memory.md` as well would
   give the repo two versions of the same fact with no way to tell which one
   is current — exactly the problem those docs exist to avoid. So this file
   only holds static identity (which never goes stale) and a routing table
   to the real sources — nothing that could drift out of sync with them:

   ```markdown
   # Project — Session Orientation

   > Read this first in a new session, then follow the pointers below to
   > the actual source of truth. This file intentionally holds no
   > decisions, architecture, or status of its own — update the linked doc,
   > never this file, when any of that changes.

   ---

   ## Identity

   - Name: <TODO>
   - Owner: <TODO>
   - Type: <TODO>

   ---

   ## Where to Look

   | Topic | Source of truth |
   |---|---|
   | Problem, goals, scope | `docs/prd.md` |
   | System design, components, tech decisions | `docs/architecture.md` |
   | Why a specific technical decision was made | `docs/adr/` |
   | Feature backlog, phases, status | `docs/project-management.md` |
   | Current implementation state, what's next | `docs/handoff.md` |
   | Diagrams | `docs/diagrams/mmd/` (source) → `docs/diagrams/img/` (rendered) |
   ```

6. **Scaffold the diagram pipeline.** `idea-triage`'s Diagram Policy requires
   mermaid diagrams to live as standalone `.mmd` source, never embedded in
   the docs themselves, rendered to PNG and referenced by image link. Set
   this up now so the convention exists before any diagram is drafted:

   - Create `docs/diagrams/mmd/` and `docs/diagrams/img/` (each with a
     `.gitkeep` so git tracks the empty directories).
   - Create `.claude/scripts/render-diagrams.ps1` with the following content
     — it installs `mmdc` (`@mermaid-js/mermaid-cli`) on first use if it
     isn't already on PATH, then renders every `.mmd` file in
     `docs/diagrams/mmd/` to a same-named PNG in `docs/diagrams/img/` using
     the dark theme with a matching dark background (not transparent — the
     dark theme's light-colored text/lines need a dark backdrop to stay
     readable) and 2x scale for a crisp, non-blurry PNG:

     ```powershell
     # .claude/scripts/render-diagrams.ps1
     #
     # Renders every Mermaid .mmd file in docs/diagrams/mmd to a PNG in
     # docs/diagrams/img, via mermaid-cli (mmdc), dark theme. Installs mmdc
     # if missing. Re-run after any .mmd edit - always re-renders, no
     # incremental diffing, so there's no stale-cache risk.
     #
     # NOTE: comments/strings in this script must stay plain ASCII (no em
     # dashes, smart quotes, etc). Windows PowerShell 5.1 (the default
     # `powershell.exe`) misparses non-ASCII characters in a BOM-less UTF-8
     # file, which corrupts brace/string matching later in the script.

     param(
         [string]$MmdDir = "docs/diagrams/mmd",
         [string]$ImgDir = "docs/diagrams/img",
         [string]$Background = "#1e1e1e",
         [int]$Width = 1600,
         [int]$Height = 1200,
         [int]$Scale = 2
     )

     $ErrorActionPreference = "Stop"

     function Find-Mmdc {
         $cmd = Get-Command mmdc -ErrorAction SilentlyContinue
         if ($cmd) { return $cmd.Source }
         return $null
     }

     $mmdc = Find-Mmdc
     if (-not $mmdc) {
         Write-Host "mmdc not found - installing @mermaid-js/mermaid-cli globally..."
         npm install -g @mermaid-js/mermaid-cli
         $mmdc = Find-Mmdc
         if (-not $mmdc) {
             Write-Error "mmdc install failed - install Node/npm first, then re-run this script."
             exit 1
         }
     }

     if (-not (Test-Path $MmdDir)) {
         Write-Host "No diagrams directory at $MmdDir - nothing to render."
         exit 0
     }

     New-Item -ItemType Directory -Force -Path $ImgDir | Out-Null

     # Puppeteer needs --no-sandbox in some locked-down/CI environments.
     # Written via .NET File.WriteAllText with an explicit no-BOM UTF8
     # encoding, not `Out-File -Encoding utf8` - on Windows PowerShell 5.1,
     # `-Encoding utf8` always prepends a BOM, and Node's JSON.parse (used by
     # mmdc/puppeteer to read this file) rejects a BOM-prefixed JSON file.
     $puppeteerConfigPath = Join-Path $PSScriptRoot "puppeteer-config.json"
     if (-not (Test-Path $puppeteerConfigPath)) {
         [System.IO.File]::WriteAllText($puppeteerConfigPath, '{"args": ["--no-sandbox"]}', (New-Object System.Text.UTF8Encoding $false))
     }

     $mmdFiles = Get-ChildItem -Path $MmdDir -Filter "*.mmd" -File -ErrorAction SilentlyContinue
     if (-not $mmdFiles) {
         Write-Host "No .mmd files found in $MmdDir"
         exit 0
     }

     $rendered = 0
     foreach ($file in $mmdFiles) {
         $outPng = Join-Path $ImgDir ($file.BaseName + ".png")
         Write-Host "Rendering $($file.Name) -> $outPng"
         & mmdc -i $file.FullName -o $outPng -t dark -b $Background -w $Width -H $Height -s $Scale -p $puppeteerConfigPath
         if ($LASTEXITCODE -ne 0) {
             Write-Error "Failed to render $($file.Name)"
             continue
         }
         $rendered++
     }

     Write-Host "Done. $rendered / $($mmdFiles.Count) diagram(s) rendered to $ImgDir"
     ```

   - Do not run the script now — it only needs to exist. It gets invoked by
     `idea-triage` after a `.mmd` file is written or edited.

7. **Create `.claude/commands/run.md`** — a stack-detecting version (do NOT
   hardcode Streamlit/Python; use the detection from step 3). This is not
   redundant with the `orchestrator-development-pattern` skill: the `orchestrator-development-pattern`'s Integration Agent
   runs format/lint/test/audit as automated quality gates, but never starts
   an interactive dev server for a human to look at. It's also not redundant
   with the global `run` skill — that skill explicitly looks for a
   project-local command covering app launch before falling back to its own
   generic per-platform patterns, so this file is the intended customization
   point, not a duplicate:

   ```markdown
   # /run

   > Custom slash command. Invoke with: `/run`
   > Starts the project locally using whatever run command fits this repo's
   > stack, and verifies it comes up.

   ## Steps

   1. Detect how this project runs by checking, in order: `package.json`
      scripts (`dev`/`start`), a `Makefile` `run` or `up` target, `requirements.txt`
      + an entry point (`app.py`/`main.py`), `Cargo.toml` (`cargo run`),
      `go.mod` (`go run .`), a `.csproj`/`.sln` (`dotnet run`), a
      `Gemfile` (`bin/rails server` or similar). If nothing matches, ask
      the user how they run this project instead of guessing.
   2. Check for any required local services this project depends on (e.g.
      a local API, database, or model server mentioned in README/CLAUDE.md)
      before starting, and warn if one isn't reachable.
   3. Start the app in the background using the detected command.
   4. Wait a moment, then confirm it's accessible at whatever port/URL the
      tool reports.
   5. Report the URL to the user and note any startup warnings from the
      process output.

   ## Guardrails

   - If no entry point / run target exists yet, stop and tell the user to
     scaffold the app first.
   - If dependencies are missing, suggest the stack's install command
     (`npm install`, `pip install -r requirements.txt`, `cargo build`,
     `dotnet restore`, etc.) rather than assuming one.
   ```

8. **Create `.claude/SKILLS.md`**. Wire up all four skills below — they're
   all language/platform agnostic (the `orchestrator-development-pattern` detects the runtime
   itself; idea-triage, graphify, and find-skills don't touch stack-specific
   tooling at all). Only check first that each referenced skill actually
   exists at `~/.claude/skills/<name>/SKILL.md` before wiring it in — skip
   any that aren't installed and note that to the user.

   ```markdown
   # Available Skills

   This file binds project-specific variable values to skills that accept
   parameters. Claude reads this file to know which skills are active and
   what paths/values to inject.

   ---

   ## Orchestrator Development Pattern

   Skill: `orchestrator-development-pattern` (located at `~/.claude/skills/orchestrator-development-pattern/SKILL.md`)
   Trigger: `/orchestrator-development-pattern` or when the user says "start development", "implement", "build".

   The `orchestrator-development-pattern` detects the platform at runtime.

   values:
     project-management-doc: "./docs/project-management.md"
     handoff-doc: "./docs/handoff.md"
     source-code-directory: "./"
     revision-file: "./REVISION.md"
     changelog-file: "./CHANGELOG.md"
     snyk-command: "<TODO — dependency audit command, e.g. npm audit / pip-audit / cargo audit>"
     test-runbook-location: "./docs/testing/<FEATURE-ID>-<short-name>.md"
     architecture-doc: "./docs/architecture.md"
     test-cases-doc: "./docs/test-cases.md"
     adr-directory: "./docs/adr"
     diagrams-mmd-dir: "./docs/diagrams/mmd"
     diagrams-img-dir: "./docs/diagrams/img"

   ---

   ## Idea Triage

   Skill: `idea-triage` (located at `~/.claude/skills/idea-triage/SKILL.md`)
   Trigger: `/idea-triage` or when the user presents a new idea or feature concept before any code exists.

   values:
     docs-directory: "./docs"
     prd-file: "./docs/prd.md"
     architecture-file: "./docs/architecture.md"
     project-management-doc: "./docs/project-management.md"
     adr-directory: "./docs/adr"
     diagrams-mmd-dir: "./docs/diagrams/mmd"
     diagrams-img-dir: "./docs/diagrams/img"
     diagram-render-script: "./.claude/scripts/render-diagrams.ps1"

   ---

   ## Graph-Assisted Context

   Skill: `graphify` (located at `~/.claude/skills/graphify/SKILL.md`)
   Trigger: `/graphify` or `/graphify query "<topic>"` or `/graphify --update`

   Use graphify before starting any feature that touches multiple modules.
   The graph report lives at `graphify-out/GRAPH_REPORT.md` after the first run.

   ---

   ## Find Skills

   Skill: `find-skills` (located at `~/.claude/skills/find-skills/SKILL.md`)
   Trigger: `/find-skills` or `/find-skills <query>`

   Use this skill to discover available skills by name or capability.

   ---

   ## How Skills Are Loaded

   1. Skills are installed globally at `~/.claude/skills/<skill-name>/SKILL.md`
   2. This file (`SKILLS.md`) provides the variable values Claude substitutes at runtime
   3. Skills can also be installed from marketplaces via `/install-skill`
   4. Custom skills: create `~/.claude/skills/<name>/SKILL.md` with your own instructions
   ```

   Fill in the `orchestrator-development-pattern`'s `<TODO>` placeholders using the stack detected
   in step 3 (e.g. for Node: lint = `eslint .`, test = `npm test`, audit =
   `npm audit`). The other three skills need no stack-specific values —
   their `docs-directory`/`prd-file` paths are already generic conventions,
   not tied to any language.

   **Keep `architecture-file` (idea-triage) and `architecture-doc`
   (`orchestrator-development-pattern`) pointed at the same path.** They're the same physical
   file — idea-triage writes it, `orchestrator-development-pattern` reads it — but each skill
   names its own variable independently (by design, so either skill stays
   usable on its own without the other installed). This scaffold sets both
   to `./docs/architecture.md` in one pass; if either ever changes, update
   the other to match, or the two skills will silently diverge on which
   file is "the" architecture doc. Same applies to `adr-directory`,
   `diagrams-mmd-dir`, and `diagrams-img-dir`, which both skills already
   name identically — keep those three identical too if the convention
   paths ever change.

9. **Do not** create a `CLAUDE.md` unless the user asks — that's a separate
    concern (use the existing `/init` command for codebase documentation) and
    mixing the two would overwrite project-specific instructions.

10. **Summarize** what was created/skipped and remind the user these files
    (including `docs/diagrams/`, `.claude/scripts/render-diagrams.ps1`, and
    the diagram folders) are meant to be committed to the repo — they're
    project conventions, not local secrets.

## Guardrails

- Never overwrite existing `.claude/` files without explicit confirmation.
- Never invent identity details in `memory.md` — leave `<TODO>` placeholders
  for the user to fill in.
- Never add a decision, architecture, status, or open-question entry to
  `memory.md` itself — it's a pointer file only. That content belongs in
  `prd-file`/`architecture-file`/`adr-directory`/`project-management-doc`/
  `handoff-doc`; putting it in both places creates two versions of the same
  fact with no way to tell which is current.
- Never add permission allow-patterns for tools that aren't actually used in
  the target repo.
- This command touches `.claude/` and the `docs/` scaffolding it creates
  (`docs/diagrams/mmd/`, `docs/diagrams/img/`, and whatever doc paths
  `idea-triage`/`orchestrator-development-pattern` are wired to). It does not
  modify application code.
