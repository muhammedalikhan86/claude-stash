# Finalizer Task: Revision + Changelog

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

Add a revision entry in the revision file's own form, or update this run's existing one; tag the revision and changelog entries `(run <run id>, <scope>)`. If the file
keeps an integer, increment it only for a new entry; if it does not, add an entry shaped like its existing ones (e.g. a dated narrative line). Never invent a numbering
scheme the file doesn't use. Put the changelog entry under exactly the `Release label:` the prompt gives
(e.g. `[Unreleased]`, or a version heading); create it if it is absent. Add, or update the existing, changelog entry covering: features shipped (F-IDs and
names) under a `feat` category, bugs fixed (B-IDs and one-line descriptions) under a `fix` category,
modules/files affected, breaking changes (if any), and smoke tests (happy path, edge case,
regression-sensitive flow — for a bug, the regression-sensitive flow is the reported repro scenario).
