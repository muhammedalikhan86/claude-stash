# Building a user interface: Angular Material

**Shaw & Partners builds its user interfaces with Angular Material.** This holds for any Shaw work,
in any repository, whether or not the request says so — it is the house standard, not a per-project
preference, and it does not need restating in a brief to be in force. (The one-line version is also
an always-on rule in `~/.claude/rules/shaw-estate.md`.)

1. **If Angular Material or the Angular CDK has a component for it, use that component.** Not a
   native element styled to look like it, and not a hand-built equivalent. That covers buttons,
   cards, tables, form fields, selects, checkboxes, radios, toggles, menus, tabs, dialogs,
   snackbars, tooltips, lists, expansion panels, steppers, chips, paginators, progress indicators,
   toolbars, sidenavs and datepickers, plus the CDK's drag-and-drop, overlay, virtual scrolling and
   a11y utilities.
2. **Plain HTML is for text, layout and landmarks** — `p`, headings, `span`, `strong`, `div`,
   `section`, `article`, `header`, `footer`, `nav`, `main`, `aside`, `img`, a real `a` link, and the
   `<canvas>` or `<svg>` a chart draws into. These carry no behaviour and Material has no component
   for them.
3. **Anything else in plain HTML needs Muhammed Ali Khan's sign-off, before it is built, recorded in
   writing.** A hand-built control re-implements focus management, keyboard behaviour, ARIA, density
   and the theme's token wiring, and it does so invisibly — it looks right on the day it ships and
   costs for the life of the product. An exception that is not written down is a defect.
4. **Two things this does not apply to.** An existing non-Material user interface that the work
   merely touches — match what is there and say so, rather than converting it mid-task. And a
   project where a different library was asked for by name. Everything else is Material.
5. **Styling follows the same order of resort.** A component's own appearance is corrected in the
   shared theme, not locally; then by the shared class vocabulary the design system already
   emits; then by adding a class to that shared vocabulary; and only then by local CSS, which
   should be short and particular to that one screen. The test is not *does this look right* —
   local CSS always looks right — but *would a second screen want this*. If yes, it belongs in
   the shared layer.
6. Where a repository has its own UI contract, read it: it is the same rule with that project's
   carve-outs attached. In `shaw-plugin-dashboard` it is the UI component contract in
   `docs/shell/architecture.md` §3, with `ADR-008` behind it.

Hosting an Angular front end on the intranet (base href, `environment.prod.ts`, rewrite
`Web.config`): `hosting-and-deployment.md` (DEP-6, DEP-7).
