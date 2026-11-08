---
name: dont-narrate-doc-versions-during-triage
description: During idea-triage conversations the user does not want document version numbers reported back to them; versioning is bookkeeping that belongs to the PMBook stage.
metadata: 
  node_type: memory
  pinned: false
  originSessionId: 98ab3dcf-4797-41b0-a07d-8dbda5ce83ba
  modified: 2026-09-11T10:49:20.130Z
---

# Don't narrate document version numbers during triage

When working through `idea-triage` or `plugin-idea-triage`, the governed documents (PRD,
Architecture, PMBook) each carry a version counter that increments on every edit, and the skill
requires a matching row in the corresponding history file. That bookkeeping still has to happen —
it is what makes ripple effects traceable — but the user does not want to read about it.

The user's instruction was blunt: "dont talk about versions. we do that at pmbook stage." So keep
version numbers out of the conversational reply entirely. Do not open a response with "the PRD is
now v7", do not announce a bump after each triage edit, and do not refer to earlier states by their
version number when explaining what changed. Describe *what* changed and *why* in plain terms
instead, and let the version numbers live in the document header and the history file where they
belong.

The reasoning is about signal: during triage the user is making product decisions, and a version
number is pure ceremony that competes for attention with the actual question in front of them.
Versions become conversationally relevant later, at the PMBook stage, where they are used to
reason about whether a downstream document has fallen behind an upstream one.

Keep writing the history rows and bumping the headers as the skill requires — this is about what
gets said, not about what gets recorded.
