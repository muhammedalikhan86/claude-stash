# Plugin Orchestrator — Flow Diagrams

Reference only; `SKILL.md` is the source of truth. Matches v1.18.0.

Start with `01`; each of its boxes names the file that draws that stage in detail. Every file ends
with **Open questions**, places where the skill text was ambiguous; all are now closed in the text, so
each reads "None."

| File | Shows |
|---|---|
| [01-birds-eye.md](01-birds-eye.md) | The whole run on one page: component, Phase 0, the entry points, Phases 1–3, close-out on every run, escalation and resume |
| [02-phase0-setup.md](02-phase0-setup.md) | Steps 0.0a–0.4: the resolution ladder, hard dependencies and the resume check, platform and skill, wave rules (Spikes count toward 3), the announcement and the run-state write |
| [03-phase1-work-item-loop.md](03-phase1-work-item-loop.md) | Steps 1.0–1.4: running a wave, packet and Developer Output saved, Developer → Reviewer, retries, model escalation, UNVERIFIED, cross-component FAIL (code or Parity), what PASS means per type; plus a sequence diagram |
| [04-ui-packets.md](04-ui-packets.md) | UI packets: the Design Gate (Step 1.1b, Artboard Edit Prompt) and the Board Parity Check (Step 1.3b, every table kept) |
| [05-manual-verification-and-bugs.md](05-manual-verification-and-bugs.md) | Bug Fix Intake (Step 0.1b) and the batched Manual Verification Gate (Step 1.5) |
| [06-phase2-integration.md](06-phase2-integration.md) | Steps 2.0–2.3: test scope, the Integration agent's order (Diff Guard stop, triage, Known-Reds), the untracked known-red pause, the six skip conditions, doc-only retries |
| [07-phase3-finalization.md](07-phase3-finalization.md) | Steps 3.1–3.6: release label, Edit Lists, the parallel Finalizers, Graphify routes, Version Pointer Sweep, commit, push on a go, close-out on every run |
| [08-spike-and-p0.md](08-spike-and-p0.md) | The Spike Flow and the P0 hotfix fast lane (inside a wave, in a multi-item run) |
| [09-escalation.md](09-escalation.md) | Divide-and-Conquer (sub-problems, aggregate pass), the three templates, what an escalation writes, pausing inside a wave, resume |
| [10-ui-iteration.md](10-ui-iteration.md) | UI Iteration (Step 0.1d): the tweak loop, and the gates run once at "done" (two diagrams) |
| [11-linked-runs.md](11-linked-runs.md) | The cross-component FAIL (code, Parity, Diff Guard), a declined link, a linked run added mid-run, and Linked Runs |
| [12-metrics.md](12-metrics.md) | Which event writes which metrics row (item, escalated, Integration, RUN, paused RUN, Mismatch) |
| [13-run-state-and-resume.md](13-run-state-and-resume.md) | When `run-state-file` is written, and where a resumed run rejoins |
