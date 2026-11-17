# hub.json — the per-project config

One file per project: `<hub checkout>/.claude/hub.json`, **committed**. It holds no secrets: accounts are
names only (the switcher's names), never emails, tokens or folders. Paths to other checkouts are
**relative to the hub checkout** (`../my-repo-advisor`), so the same file works on another machine.
Paths inside a checkout are relative to that checkout's root.

**One place for each fact.** hub.json holds only what no other file holds. A checkout's dev-server port
offset lives in its own gitignored `.portoffset` (the first non-comment line), which the build, the
dev-ports script and the run skill read; the hub reads it from there, never from a copy here.

## Fields

| Field | Meaning |
|---|---|
| `project` | A short name, used in messages and notes |
| `hub.sessionName` | What workers call the hub in SendMessage (e.g. `hub`) |
| `hub.workBranch` | The branch the hub checkout sits on. May equal `mainBranch` |
| `hub.mainBranch` | The integration target (`main`) |
| `hub.fastForwardMain` | The command that moves `mainBranch` up to `workBranch` without a checkout, when they differ (`git fetch -q . <workBranch>:<mainBranch>`). Empty when they are the same branch |
| `components[]` | One entry per component (below) |
| `accounts` | Account names the user switches between, in the order they are usually used (`["muhammed", "john"]`). Names only |
| `launch.mode` | `vscode` or `terminal`: how `launch-workers.ps1` opens each worker |
| `launch.permissionMode` | The permission mode workers start in (terminal workers only): `same-as-hub` (default) or a Claude Code mode (`default`, `acceptEdits`, `plan`, `bypassPermissions`, ...) |
| `launch.model`, `launch.effort` | Optional. The model (`claude --model`, e.g. `opus`) and reasoning effort (`low` … `max`) terminal workers start with; `launch-workers.ps1 -Model` / `-Effort` override them. Absent: each account's `settings.json` decides |
| `launch.hubMode` | `vscode` or `terminal`: how the user opens the hub itself (`./launch-as <account>`, plus `-Terminal` for `terminal`). `launch-workers.ps1` never opens the hub |
| `launch.script` | The per-checkout launcher, relative to each checkout (`launch-as.ps1`) |
| `delegation` | What the hub may approve for the user: `gates` (`"ui-and-non-ui"`, `"non-ui-only"` or `"none"`), `manualVerificationWaiver` (the wording, or empty), `pullPush` (may tell workers to pull the main branch / push their own branch) |
| `push.main` | Always `"user"`: the hub prints the command, the user runs it |
| `push.statusRepo` | `true` lets the hub commit and push the status repo itself |
| `status.repo` | The status page repo, relative to the hub checkout (`../my-repo-status`). Empty → no status page |
| `status.file` | The status JSON inside it (`status.json`) |
| `status.patcher` | `skill` (this skill's `scripts/status_patch.py`) or a path to a project copy |
| `status.excludeComponents` | Components left out of every figure |
| `design.source` | Where the designer works (a URL), or empty |
| `design.changeLogs` | Paths of the designer's change logs inside that source |
| `design.promptFile` | Where a designer prompt waits to be sent, with `<component>` in it |
| `design.syncSkill` | `sync-artboards` |
| `paths.sessionNote` | `docs/sessions/latest.md` |
| `paths.hubOperations` | The hub operations file (`docs/sessions/knowledge/hub-operations.md`). May be gitignored |
| `paths.rulingsLog` | `docs/hub/rulings.md`, committed so workers read it |
| `paths.parityBacklog` | `docs/<component>/parity-backlog.md` |
| `paths.devEnvironment` | The file that holds green test counts and the known-red list, or empty |
| `paths.screenshots` | Where browser screenshots go (gitignored) |
| `merge.ruledExceptions` | Files outside a component's roots that its branch may still change (e.g. its green-count lines). Each with a one-line reason |
| `watch.heartbeatCron` | Cron expression for the heartbeat |
| `triage.tolerancePx` | The strict tolerance (`2`): a look gap this size or smaller is not recorded, and the hub's disparity check fails anything larger |
| `testing.workerScope` | `affected`: a worker's Integration gate runs only the affected tier (tiered testing); `full` or absent: workers keep their own scope rules |
| `testing.affectedCommand` | The affected-tier command(s) a worker runs (e.g. `npx nx affected -t test --base=origin/main`, its `.slnx`, `npm run test:business -- --project=<component>`). Base on `origin/main`, never plain `main` (no local main in a worker checkout); never `--only-changed` (it can select 0 tests and pass); `components[].testAffected` overrides it per component |
| `testing.fullCommand` | The full set the hub runs after a merge (every suite) |
| `testing.fullAfter` | `merge` (each merge) or `batch` (once per batch of merges, at the latest at the next heartbeat) |
| `testing.onDemand` | Suites kept out of every gate and run on demand or nightly (the layout and parity crawls) |
| `triage.workerParityTolerancePx` | The lenient per-item Board Parity tolerance a worker uses under this hub (`20`). A px gap between the two goes to the parity backlog, not a FAIL; functional gaps fail at any size |

### `components[]`

| Field | Meaning |
|---|---|
| `name` | The component name used in `.claude/SKILLS.md` `components:` |
| `short` | The worker's short name in reports (`advisor`) |
| `checkout` | Its checkout, relative to the hub checkout. `.` = the hub checkout itself |
| `branch` | The branch that checkout sits on |
| `inHubCheckout` | `true` when this worker works inside the hub checkout and commits straight onto `hub.workBranch`. The hub never merges it, and never touches its uncommitted files |
| `roots` | The paths the component owns (source, docs, tests, graph). The merge check filters by these |
| `statusName` | Its name on the status page, or empty when it is not on it |
| `pmbook` | Its PMBook path |
| `statusPmbooks` | Optional: every PMBook its status-page figure sums, when it is more than `pmbook` (e.g. `["docs/shell/project-management.md", "docs/landing-page/project-management.md"]`). Closed tranches under each one's `archive/*/` are always included |
| `handoff` | Its handoff doc path |

## Example

```json
{
  "project": "plugin-dashboard",
  "hub": {
    "sessionName": "hub",
    "workBranch": "skills-test",
    "mainBranch": "main",
    "fastForwardMain": "git fetch -q . skills-test:main"
  },
  "components": [
    { "name": "shell", "short": "shell", "checkout": ".", "branch": "skills-test", "inHubCheckout": true,
      "roots": ["apps/shell", "libs", "docs/shell", "business-tests/shell"],
      "statusName": "Shell", "pmbook": "docs/shell/project-management.md", "handoff": "docs/shell/handoff.md" },
    { "name": "advisor-dashboard", "short": "advisor", "checkout": "../plugin-dashboard-advisor",
      "branch": "advisor-dashboard", "inHubCheckout": false,
      "roots": ["apps/advisor-dashboard", "services/AdvisorDashboard.WebAPI", "docs/advisor-dashboard", "business-tests/advisor-dashboard", "graphify-out/advisor-dashboard"],
      "statusName": "Advisor",
      "pmbook": "docs/advisor-dashboard/project-management.md", "handoff": "docs/advisor-dashboard/handoff.md" }
  ],
  "accounts": ["muhammed", "john"],
  "launch": { "mode": "terminal", "hubMode": "vscode", "script": "launch-as.ps1", "permissionMode": "same-as-hub" },
  "delegation": { "gates": "ui-and-non-ui", "manualVerificationWaiver": "", "pullPush": true },
  "push": { "main": "user", "statusRepo": true },
  "status": { "repo": "../plugin-dashboard-status", "file": "status.json", "patcher": "skill", "excludeComponents": [] },
  "design": {
    "source": "https://claude.ai/artifact/<id>",
    "changeLogs": ["project/docs/<component>-changes.md"],
    "promptFile": "docs/design/artboards/<component>/review-<component>.md",
    "syncSkill": "sync-artboards"
  },
  "paths": {
    "sessionNote": "docs/sessions/latest.md",
    "hubOperations": "docs/sessions/knowledge/hub-operations.md",
    "rulingsLog": "docs/hub/rulings.md",
    "parityBacklog": "docs/<component>/parity-backlog.md",
    "devEnvironment": "docs/dev-environment.md",
    "screenshots": "docs/design/screenshots"
  },
  "merge": { "ruledExceptions": [
    { "path": "docs/dev-environment.md", "reason": "green-count lines; the hub re-applies only that component's change" }
  ] },
  "watch": { "heartbeatCron": "45 4,9,14,18,23 * * *" },
  "triage": { "tolerancePx": 2, "workerParityTolerancePx": 20 },
  "testing": { "workerScope": "affected", "affectedCommand": "make test-affected COMPONENT=<component>",
               "fullCommand": "make test-full", "fullAfter": "merge", "onDemand": ["layout crawl", "parity crawl"] }
}
```

## Writing one for a new project

1. List the sibling folders of the hub checkout and `git -C <folder> branch --show-current` each one.
2. Match them to `.claude/SKILLS.md` `components:`; take roots, PMBook and handoff paths from there.
3. Ask the user, with buttons, only for what the repo cannot show: accounts, launch mode, the status
   repo, the design source, and the delegation.
4. Show the file, write it on a yes, and commit it by path when the user says so.
