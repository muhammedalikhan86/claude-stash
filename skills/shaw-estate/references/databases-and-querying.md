# Databases and querying

## Where database source lives (two places)

1. **`Database\`** holds the SQL projects `DataWarehouse`, `PowerBI` and `ShawCentral` (nested inside
   the `DataWarehouse` solution), plus SSIS projects `CRMSSIS`, `ISSSIS`, `SOLSSIS`, `XrmSSIS`.
2. **A database owned by a service lives beside that service**, as a `.sqlproj` under `WebApis\`:
   `FeeDisclosureWebAPI\FeeDisclosureDatabase`, `GridPayWebAPI\GridPayDB`,
   `InformationSystemWebAPI\InformationSystemDatabase`, `PhoenixWebAPI\PhoenixDB`. So
   `find . -iname *.sqlproj` across `repos\` is the way to locate one, not a look in `Database\`.
   **This is the only source for `GridPay`**, which the read-only login cannot reach.
3. Read these projects for intent and change history; **they lag production in places**, so for what
   an object actually is right now, read the server.
4. Databases a new app owns are created and migrated by the app itself: `app-owned-data.md`.

## Reading the live data (analysis and design)

Querying the live databases with the read-only **`DatabaseReader`** SQL login is approved for
analysis and design. When the question is "what does the data actually contain", look rather than
guess. It is never an app's production identity (`app-identity-and-sql.md`).

1. **Server:** `idb_ag.shawstock.com.au,4433` (`@@SERVERNAME` is `SIC1DB1.shawstock.com.au\IDB`), an
   availability-group listener, not a single node. **Login:** `DatabaseReader`, SQL authentication,
   read-only, not sysadmin.
2. **Connection strings, the `sqlcmd` line and the password** are in `~/.claude/rules/shaw-db.md`,
   not here: that file lives only on each user's machine; this skill is shared.
3. **Databases it can read:** `DataWarehouse`, `PowerBI`, `ShawCentral`, `FeeDisclosure`, `IS`, plus
   `master`, `msdb`, `tempdb`. Nothing else on that server (not GridPay, Phoenix,
   Personnel_Information_System and the rest). **`GridPay` being shut is deliberate**: the architect's
   instruction is to go through the warehouse rather than to GridPay directly. Where a warehouse table
   aggregates away detail GridPay holds, the ask is for the warehouse to keep it — not for access.
   `PowerBI` is a reporting mart, not a substitute: its revenue tables are advisor-grain and carry no
   account number.
4. Use 3-part names across databases, e.g. `ShawCentral.dbo.Users` from a `DataWarehouse` connection.
5. **`VIEW DEFINITION` was granted on 2026-10-09**: `select definition from sys.sql_modules` returns
   every view, procedure and function body in all five databases (316 in `DataWarehouse`, 152 in
   `IS`, 90 in `ShawCentral`, 38 in `PowerBI`, 8 in `FeeDisclosure`). Any older note saying to read
   procedure source in `Database\` instead is out of date. To print a whole definition with `sqlcmd`,
   pass `-y 0`; it cannot be combined with `-h`.
6. **Handy starting points:**
   - `ShawCentral.dbo.Users` mirrors Active Directory (`DisplayName`, `EmailAddress`, `Branch`,
     `JobTitle`, `Status`, `NetworkUsername`).
   - `DataWarehouse.dbo.AdvisorAccess` maps a person's email to their advisor codes (`AdvisorCode`,
     `Email`, `Name`); the advisor dashboard reads it. `AdvisorAccessProper` is its nightly rebuild
     with branch managers cut down to their own branch. `DepartmentAccess` is the same kind of
     who-sees-which-code map (`Email` to `DepartmentCode`).
   - **`DepartmentCode` (DataWarehouse, IS) is not a department.** It is a repurposed column holding a
     personal code for one individual (e.g. an Adviser's own account). Never group or label by it as
     if it were a team.
   - **Dealer's Assistants** are mapped in `AdvisorAccess` / `DepartmentAccess` too, to the State
     Managers, Advisers or National staff they assist. They are identified by the `Dealers Assistants`
     AD security group, not by a column. (Source: Muhammed, 2026-11-12.)
   - `ShawCentral` also holds `Trace.Information` / `Trace.Exception` / `Trace.AuditTrail` and
     `audit.SyncJobs` (written by `Shaw.Diagnostics`) and `webJob.Jobs` / `webJob.JobResult`
     (`Shaw.WebJob`) — see `shaw-libraries.md`.

## Rules for what comes out of a query

1. Print only what the question needs: counts, shapes, names of staff and teams.
2. Don't echo the password into chat output or a tracked file.
3. Real pay, book or client figures go to the console only, never into a tracked file, a doc or a
   stash folder.
4. No staff email addresses in governed docs.
5. **Do not keep a copy of a schema in a repository.** Other teams change these databases while you
   work, so a scripted copy starts decaying the moment it is taken, and a stale snapshot that reads as
   authoritative is worse than none. A set scripted on 2026-09-15 was already wrong on every database
   three weeks later (199 tables against 187 live in `DataWarehouse`) and was deleted. Query the
   server instead, and where a finding rests on the schema, record the query that produced it.
