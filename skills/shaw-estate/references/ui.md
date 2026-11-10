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

## Design boards and designer prompts

The house standard binds the **boards** too, not only the built code. A board is the specification
the build is checked against, so a control drawn as plain HTML either gets copied into the build or
starts an argument at parity. Any brief, round prompt or board edit for Shaw work carries these rules,
in the brief's `## Build rules`:

1. **Draw the real component, not a look-alike.** Every control on a board is the Angular Material 3
   or CDK element itself: `matButton` / `matIconButton` / `mat-menu-item`, `mat-form-field` +
   `matInput` with a `mat-label`, `mat-select`, `mat-checkbox`, `mat-slide-toggle`,
   `mat-button-toggle-group`, `mat-chip-row`, `mat-table`, `mat-list`, `mat-dialog`, `mat-menu`.
2. **A plain `<button>`, `<input>`, `<label>` or `<select>` is not allowed on a board.** Plain HTML is
   for text, layout and landmarks only, as in point 2 above.
3. **Name the controls designers most often hand-draw**, because a brief that lists components
   generally still gets these as plain markup (the Log Viewer's first round, 2026-11-10, drew all of
   them as `<button>` / `<label>`):
   - a removable chip → `mat-chip-row` with a `matChipRemove` button;
   - a sortable column header → `mat-sort-header`;
   - a calendar or day grid → `mat-calendar` / `mat-date-range-picker`;
   - a clickable list or results row → `mat-list-item` in a `mat-action-list`;
   - a trigger that looks like a field → `matButton="outlined"`, or a read-only `matInput` in a
     `mat-form-field`;
   - a "show more" link-button → `matButton="text"`;
   - a field label → `mat-label` inside the `mat-form-field`;
   - a set of toggle buttons → `mat-button-toggle-group`;
   - section tabs → `mat-tab-nav-bar` + `mat-tab-link`.
4. **A control Material does not have is a question, not a drawing.** The designer asks in the change
   log; the exception needs Muhammed Ali Khan's written sign-off (point 3 above) before it is drawn.
5. **The hand-back says which component each control is.** The sync checks the boards for plain
   controls (`<button>`, `<input>`, `<label>`, `<select>` with no Material attribute or `mat-` parent)
   and raises each as a finding with its Material replacement; the build always uses the Material
   component, never the drawn markup.

Hosting an Angular front end on the intranet (base href, `environment.prod.ts`, rewrite
`Web.config`): `hosting-and-deployment.md` (DEP-6, DEP-7).
