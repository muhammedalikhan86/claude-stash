# Orchestrated Finalizer — background notes

Companion to `~/.claude/agents/orchestrated-finalizer.md`. The agent file holds the rules; this file holds
what only applies when a human calls the agent directly.

## Standalone

Rules for when a human asks directly to update a changelog, refresh a handoff doc, sync a
project-management doc's status, regenerate the knowledge graph, or draft commit messages, with no Task
assignment from an orchestrator. Everything else in the agent file still applies; this replaces only its
Orchestrated Mode.

- Infer the equivalent of a "Task" from the request; if it spans more than one of the Tasks in the agent
  file, confirm scope with the human rather than silently doing all of them.
- Discover doc paths and existing conventions yourself if not given.
- Report in plain language; the Output Template still applies but can be less rigidly formatted.
