# App identity: what account the app uses to reach SQL

This is a different question from how *users* sign in (`sign-in-and-ad.md`). Ask them separately:

1. **How do users sign in?** Windows (Negotiate) sign-in, with AD groups for roles.
2. **What account does the app itself use to reach SQL?** The IIS pool's gMSA, through Windows
   Integrated Security.

## Production: the gMSA, Integrated Security, no credentials

Sources: `shaw-plugin-dashboard\docs\adr\SHELL-ADR-022-intranet-iis-deployment.md` (decision 4,
amended 2026-10-12) and `shaw-plugin-dashboard\docs\deployment\README.md`.

1. Every API's IIS pool runs as the firm's existing **gMSA** (group managed service account), never
   ApplicationPoolIdentity (DEP-8).
2. Each API ships `appsettings.Production.json`. Every connection string in it uses **Windows
   Integrated Security** as that gMSA — no user name, no password.
3. A test fails the build if a credential appears in it: `ProductionSettingsTests`, e.g.
   `services/AdvisorDashboard.WebAPI/AdvisorDashboard.WebAPI.Tests/ProductionSettingsTests.cs`
   (ComplianceDashboard has the same). Copy it into a new API.
4. The connection-string key is the store's `DatabaseName` — the name `Shaw.DataAccess` looks up
   (`ConnectionStrings:<DatabaseName>`).
5. The gMSA already has access to every database on the server, so a new database needs no grants.
6. No `Shaw.Configuration` / `SP_GETCONFIGURATION` (legacy, per the server administrator).

So **an application never connects with a SQL login.**

## Development

1. **The app's own databases:** LocalDB, in `appsettings.Development.json`:
   `Server=(localdb)\MSSQLLocalDB;...;Integrated Security=true` (`app-owned-data.md`).
2. **Estate databases read in development** (Shaw Portal, SHELL-ADR-021): shared development
   connection strings live in `services/appsettings.Shared.{Environment}.json`, inserted at
   configuration index 0. They use the read-only `DatabaseReader` SQL login, and that file is
   committed with the password, on the product owner's instruction (internal remote). There is
   deliberately **no Production counterpart**.

`DatabaseReader` is for analysis, design and development reads only — never a deployed app's
identity and never a design default. Its connection details are in `~/.claude/rules/shaw-estate.md`
(`databases-and-querying.md`).
