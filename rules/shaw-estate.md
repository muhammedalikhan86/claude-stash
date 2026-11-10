# Shaw & Partners estate: code and data

Applies to any Shaw & Partners work, in any repository or session.

## Reading the estate's code

The whole internal estate is checked out at `%USERPROFILE%\source\repos`: `WebApis\`,
`Websites\`, `ShawApplications\`, `Database\` and `Libraries\ShawLibraries\`, about 180 solutions.

1. Each area has a `README.md` at its root that indexes every project in it. Read that index before
   opening a project in the area.
2. Before deciding how to use a Shaw library, database or service, find where the estate already
   uses it and read that. Working sample code carries constraints the library's own surface does not.
3. To build or extend a .NET project there, load the `shaw-dotnet-estate` skill.
4. **Database source is in two places, and `Database\` is only the first.** It holds the SQL
   projects `DataWarehouse`, `PowerBI` and `ShawCentral` (nested inside the `DataWarehouse`
   solution), plus SSIS projects `CRMSSIS`, `ISSSIS`, `SOLSSIS`, `XrmSSIS`. **A database owned by a
   service lives beside that service instead**, as a `.sqlproj` under `WebApis\`:
   `FeeDisclosureWebAPI\FeeDisclosureDatabase`, `GridPayWebAPI\GridPayDB`,
   `InformationSystemWebAPI\InformationSystemDatabase`, `PhoenixWebAPI\PhoenixDB`. So
   `find . -iname *.sqlproj` across `repos\` is the way to locate one, not a look in `Database\`.
   **This is the only source for `GridPay`**, which the read-only login cannot reach.
   Read these projects for intent and change history; **they lag production in places**, so for what
   an object actually is right now, read the server (see below).
5. Before saying some data, mapping or capability does not exist, search every project and schema
   in the estate. If the search was not exhaustive, say what was searched instead of claiming absence.

## Building a user interface

**Shaw & Partners builds its user interfaces with Angular Material.** This holds for any Shaw work,
in any repository, whether or not the request says so — it is the house standard, not a per-project
preference, and it does not need restating in a brief to be in force.

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

## Querying the data

Querying the live databases with the read-only **DatabaseReader** SQL login is approved for analysis
and design. When the question is "what does the data actually contain", look rather than guess.

1. **Server:** `idb_ag.shawstock.com.au,4433` (`@@SERVERNAME` is `SIC1DB1.shawstock.com.au\IDB`).
   **Login:** `DatabaseReader`, SQL authentication, read-only, not sysadmin.
2. **Password:** not stored in this repo. Ask the team lead, then put it in your own copy at `~/.claude/rules/shaw-estate.md`, in place of the placeholder in each connection string and the `sqlcmd` line below. The installer carries it over from your old copy on each re-install.
   **Connection strings, one per readable database** (all five checked to connect on 2026-10-09):

   ```
   DataWarehouse: Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=DataWarehouse;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   PowerBI:       Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=PowerBI;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   ShawCentral:   Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=ShawCentral;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   FeeDisclosure: Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=FeeDisclosure;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   IS:            Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=IS;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   ```

   From a shell: `sqlcmd -S "idb_ag.shawstock.com.au,4433" -U DatabaseReader -P "<DB_PASSWORD>" -d <Database> -C`
   (`-C` trusts the server certificate). The server name is an availability-group listener, not a
   single node.
3. **Databases it can read:** `DataWarehouse`, `PowerBI`, `ShawCentral`, `FeeDisclosure`, `IS`, plus
   `master`, `msdb`, `tempdb`. Nothing else on that server (not GridPay, Phoenix,
   Personnel_Information_System and the rest). **`GridPay` being shut is deliberate, not an
   oversight**: the architect's instruction is to go through the warehouse rather than to GridPay
   directly. Where a warehouse table aggregates away detail that GridPay holds, the ask is for the
   warehouse to keep it — not for access. And `PowerBI` is a reporting mart, not a substitute: its
   revenue tables are advisor-grain and carry no account number.
4. Use 3-part names across databases, e.g. `ShawCentral.dbo.Users` from a `DataWarehouse` connection.
5. **`VIEW DEFINITION` was granted on 2026-10-09**, so view, procedure and function bodies are
   readable: `select definition from sys.sql_modules`. Every module in all five databases comes
   back — 316 in `DataWarehouse`, 152 in `IS`, 90 in `ShawCentral`, 38 in `PowerBI`, 8 in
   `FeeDisclosure`. Before that date the definitions came back null, so any note saying to read
   procedure source in `Database\` instead is out of date.
   To print a whole definition with `sqlcmd`, pass `-y 0`; it cannot be combined with `-h`.
6. Handy starting points: `ShawCentral.dbo.Users` mirrors Active Directory (`DisplayName`,
   `EmailAddress`, `Branch`, `JobTitle`, `Status`, `NetworkUsername`); `DataWarehouse.dbo.AdvisorAccess`
   maps a person's email to their advisor codes (`AdvisorCode`, `Email`, `Name`), and is what the
   advisor dashboard reads. `AdvisorAccessProper` is its nightly rebuild with branch managers cut down
   to their own branch.

**Rules for what comes out of a query:**

1. Print only what the question needs: counts, shapes, names of staff and teams.
2. Don't echo the password into chat output or a tracked file.
3. Real pay, book or client figures go to the console only, never into a tracked file, a doc or a
   stash folder.
4. No staff email addresses in governed docs.
5. **Do not keep a copy of a schema in a repository.** Scripting the DDL into a project folder
   feels like a safeguard and is the opposite: other teams change these databases while you work,
   so the copy starts decaying the moment it is taken, and a stale snapshot that reads as
   authoritative is worse than no snapshot. A set scripted on 2026-09-15 was already wrong on
   every database three weeks later — 199 tables against 187 live in `DataWarehouse`, and similar
   in the other four — and was deleted. Query the server instead, and where a finding rests on
   what the schema says, record the query that produced it rather than the schema.
