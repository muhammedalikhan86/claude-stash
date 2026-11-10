---
name: shaw-estate
description: The single knowledge base for Shaw & Partners work — where the internal code lives (%USERPROFILE%\source\repos WebApis\, Websites\, ShawApplications\, Database\, Libraries\ShawLibraries\), the Shaw.* libraries and the sic2tfs1 NuGet feed, the databases (DataWarehouse, ShawCentral, PowerBI, FeeDisclosure, IS) and how to query them, IIS hosting and deployment on sic2iws1, the gMSA app identity and Integrated Security, Windows/AD sign-in, app-owned databases with DbUp, Angular Material UI, and the standard architecture defaults for a new Angular + .NET app. Load it before any Shaw & Partners work — designing, building, deploying or answering questions — whenever the user mentions Shaw, Shaw & Partners, a Shaw.* package, sic2tfs1, sic2iws1, ShawApplications, WebApis, ShawCentral, DataWarehouse, IIS deploy, gMSA, AD sign-in, or Angular Material for a Shaw app.
---

# Shaw & Partners estate

The one place for Shaw facts. Other skills, rules and repos point here instead of copying them.
Read the reference a task needs; don't load them all.

**Credentials are not here.** The `DatabaseReader` connection strings and password live in
`~/.claude/rules/shaw-estate.md`, which is copied per user. This skill is shared, so it holds none.

## References

| File | Read it when |
|---|---|
| `references/code-and-libraries.md` | Finding or reading estate code; picking which code generation to follow; cross-cutting conventions (Shaw.DataAccess, logging, errors, Windows services). |
| `references/nuget.md` | Consuming or changing a `Shaw.*` library; the sic2tfs1 feed; v1.x vs v2.x; the library-change review flow. |
| `references/shaw-libraries.md` | Per-library detail: version lines, API surface, naming traps. |
| `references/generations-and-signatures.md` | Telling which generation an existing project is. |
| `references/reference-projects.md` | Starting a new Gen-3 API or job from a template. |
| `references/databases-and-querying.md` | Where database source lives; reading live data; what a query may output. |
| `references/hosting-and-deployment.md` | Hosting or deploying on the intranet IIS server (DEP-1 … DEP-10). |
| `references/app-identity-and-sql.md` | What account a deployed app uses to reach SQL; production vs development connection strings. |
| `references/sign-in-and-ad.md` | How users sign in; AD groups and roles; who-is-who tables. |
| `references/app-owned-data.md` | A new app's own database: naming, DbUp, LocalDB, sharing within an initiative. |
| `references/ui.md` | Any Shaw user interface (Angular Material house standard). |

## Standard architecture defaults — start from these, ask only about real deviations

For a new Angular + .NET app on the intranet, these are settled. Don't ask the user to choose them
again; ask only where the product genuinely needs something different, and record a departure in an
ADR. The precedent is `shaw-plugin-dashboard` (Shaw Portal).

1. **Front end:** Angular with Angular Material, served at `/<AppFolder>/` on `sic2iws1`;
   `apiBaseUrl` set in `environment.prod.ts` (`ui.md`, `hosting-and-deployment.md`).
2. **API:** .NET (Gen 3, SDK-style), its own IIS application at `/api/<api-slug>` with its own
   "No Managed Code" pool. Same origin as the front end, so no CORS (`hosting-and-deployment.md`).
3. **App identity:** the pool runs as the firm's gMSA; SQL is reached with Windows Integrated
   Security. `appsettings.Production.json` holds no credentials, and `ProductionSettingsTests` fails
   the build if one appears (`app-identity-and-sql.md`).
4. **User sign-in:** Windows (Negotiate) with a fallback policy that requires sign-in;
   `Shaw.ActiveDirectory` for the current user and AD-group roles — the Phoenix.WebAPI pattern
   (`sign-in-and-ad.md`).
5. **App data:** its own database(s), created empty, tables added by DbUp on first start; LocalDB in
   development (`app-owned-data.md`).
6. **Data access:** `Shaw.DataAccess`, never EF Core (`code-and-libraries.md`).
7. **Libraries:** `Shaw.*` v2.x as NuGet packages from the sic2tfs1 feed, never a project reference
   (`nuget.md`).
8. **Configuration:** `appsettings.{Environment}.json`. No `Shaw.Configuration` /
   `SP_GETCONFIGURATION` — legacy for new work.
9. **Deployment:** `deploy/deploy.ps1` per DEP-3/4/7, copied from the standard's reference scripts;
   `GET /configuration` as the smoke endpoint, returning no connection strings; release labels in
   `docs/releases.md`.

## Two questions people mix up

Keep these apart when asking or designing:

1. **How do users sign in?** → Windows sign-in plus AD groups (`sign-in-and-ad.md`).
2. **What account does the app itself use to reach SQL?** → the pool's gMSA plus Integrated
   Security (`app-identity-and-sql.md`).

## Always-on rules

These are also in `~/.claude/rules/shaw-estate.md`, so they apply even before this skill loads:
Angular Material house standard; `Shaw.DataAccess`, not EF Core; `Shaw.*` library changes need
Muhammed's review; query output rules; no schema copies in a repository.
