# App-owned data: a new app's own database

How a new Shaw app stores its own data, from Shaw Portal's precedent.

Sources: `shaw-plugin-dashboard\docs\deployment\README.md`, SHELL-ADR-022 (decision 4, amended
2026-10-12), SHELL-ADR-025, and Shaw Portal's ADR-010 (DbUp).

1. **One database per store, named `<Product>-<Name>`** (Shaw Portal uses `ShawPortal-<Name>`).
2. **The developer creates it empty**, with an admin account. Nothing else is set up by hand.
3. **The app adds its own tables on first start, with DbUp.** Scripts are versioned
   (`v2_….sql`) and DbUp keeps a journal of what has run. Example:
   `shaw-plugin-dashboard\services\Shell.WebAPI\Shell.WebAPI\Preferences\ShellPlatformMigrator.cs`.
4. **No grants needed:** the pool's gMSA already has access to every database on the server
   (`app-identity-and-sql.md`).
5. **Data access is `Shaw.DataAccess`**, never EF Core; the connection-string key is the store's
   `DatabaseName` (`code-and-libraries.md`, `shaw-libraries.md`).
6. **Development uses LocalDB:** `Server=(localdb)\MSSQLLocalDB;...;Integrated Security=true` in
   `appsettings.Development.json`.
7. **Sharing within an initiative (SHELL-ADR-025):** plugins that serve one initiative may share one
   subject database, each through its own API, each connecting as the gMSA. The firm keeps one
   database per subject.
