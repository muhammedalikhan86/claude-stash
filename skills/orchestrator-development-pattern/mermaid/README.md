# Orchestrator Development Pattern — diagrams

Reference only; SKILL.md is the source of truth. Matches v2.14.0.

| File | What it shows |
|---|---|
| [01-birds-eye.md](01-birds-eye.md) | The whole run on one page, including the Phases 2–3 skip and close-out, with links to the detail files |
| [02-phase0-setup.md](02-phase0-setup.md) | Step 0.0 checks in order (resume, deferred integration, test cases), entry points, platform, conventions, plan |
| [03-phase1-work-item-loop.md](03-phase1-work-item-loop.md) | Developer → Reviewer → retries, the no-board halt, Board Parity Check, Feature terminal state, who sends what |
| [04-manual-verification-and-bugs.md](04-manual-verification-and-bugs.md) | Bug intake, Note on Tests, and the Step 1.5 Manual Verification Gate |
| [05-phase2-integration.md](05-phase2-integration.md) | Integration loop, untracked known-reds pause, flaky-test triage, Divide-and-Conquer with its aggregate pass |
| [06-phase3-finalization.md](06-phase3-finalization.md) | Graphify skip rules and routes, Release label, Finalizers and models, PMBook writes and statuses, close-out, commit |
| [07-spike-and-p0.md](07-spike-and-p0.md) | Spike Flow and the P0 Hotfix Fast Lane |
| [08-escalation.md](08-escalation.md) | The three human pauses, what is recorded, and where "resume" picks up |
| [09-metrics.md](09-metrics.md) | Which event writes which `metrics-log-file` row |

Shapes: rounded = start or end, diamond = decision, rectangle = step, hexagon = sub-agent spawn
(agent and model). No open questions remain: every branch drawn is settled in the text.
