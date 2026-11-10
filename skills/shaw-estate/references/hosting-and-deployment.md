# Hosting and deployment: the intranet IIS server

Read this before designing how a Shaw product is hosted or deployed — an architecture draft, an ADR,
a `deploy/` script. These documents are the firm's precedent; a design that departs from them needs
an ADR saying why.

## Sources (read the originals; this is a summary)

All under `%USERPROFILE%\source\repos\shaw-plugin-dashboard\docs\` (read `main`, not a feature branch):

1. `deployment\iis-deployment-standard.md` — **the Shaw IIS Deployment Standard**, rules DEP-1 to
   DEP-10. A verbatim firm copy from the server administrator (v3, 2026-10-12). Its two reference
   deploy scripts are in `deployment\reference\`. New products copy the scripts and fill the
   placeholders — only the folders change.
2. `deployment\README.md` — how Shaw Portal applies the standard, and where it departs.
3. `deployment\release-runbook.md`, `deployment\iis-setup.md`,
   `deployment\change-request-template.md` (the IT Change Request raised for a release).
4. `adr\SHELL-ADR-022-intranet-iis-deployment.md` — the decision record: one host, a folder per front
   end, one IIS application and pool per API, every pool as the firm's gMSA.

## The standard in one screen (DEP-1 … DEP-10)

| Rule | What it says |
|---|---|
| DEP-1 | Never take IIS, a site or the server offline. Scripts never stop or start pools; the deployer stops the API's own pool by hand and types `stopped` to continue. |
| DEP-2 | One host, two IIS applications per product: SPA at `/<AppFolder>/`, API at `/api/<api-slug>`. Same origin, so no CORS. API routes sit at the app root. |
| DEP-3 | `deploy/deploy.ps1`, Windows PowerShell 5.1, `$ErrorActionPreference='Stop'`, params `-Target` / `-SiteUrl` / `-AppPool` / `-SkipTests`. Copies with `robocopy /MIR /R:3 /W:5 /NP /NJH`; exit code 8 or more is a failure. Agents don't run the copy step. |
| DEP-4 | API: `dotnet test -c Release`, then `dotnet publish -c Release --no-self-contained`, in-process hosting. The mirror excludes `<ApiProject>.dll.config`, `logs` and folders the app writes at runtime. Smoke test: `GET /configuration` with `-UseDefaultCredentials`. |
| DEP-5 | `web.config` holds only `maxAllowedContentLength`. Windows auth is set on the IIS application. Connection strings from central config — **Shaw Portal departs here** (below). |
| DEP-6 | Angular `environment.prod.ts` sets `apiBaseUrl: '/api/<api-slug>'` through `fileReplacements`. No runtime `config.json`. |
| DEP-7 | Front end: lint, test, then `ng build --configuration production --base-href /<AppFolder>/`; copy the standard rewrite `Web.config`. |
| DEP-8 | Each API has its own "No Managed Code" pool with one worker. Identity is the firm service account (gMSA), never ApplicationPoolIdentity. Windows auth on. Registered in `SP_GETCONFIGURATION` — **not for new work** (below). |
| DEP-9 | Secrets come out of the deployed appsettings once the repo is pushed. |
| DEP-10 | Release labels Alpha / Beta / Version x.x, recorded in `docs/releases.md`. |

**Hosts and paths:**

1. Server `sic2iws1`.
2. Front-end folder `\\sic2iws1\inetpub\wwwroot\<AppFolder>`; API folder `\\sic2iws1\WebAPI\<AppFolder>`.
3. URLs `https://intranet.shawandpartners.com.au/<AppFolder>/` and
   `https://intranet.shawandpartners.com.au/api/<api-slug>`.
4. A pool needs only Read & execute on its folder.

## Where Shaw Portal departs (and new work follows it)

Source: `deployment\README.md` and SHELL-ADR-022 decision 4, amended 2026-10-12.

1. The server administrator advised that `ShawCentral.dbo.Configuration` / `SP_GETCONFIGURATION` /
   `Shaw.Configuration` is legacy. Shaw Portal removed it, so DEP-5's central config and DEP-8's
   registration don't apply.
2. Instead each API ships `appsettings.Production.json`, with no credentials in it — see
   `app-identity-and-sql.md`.
3. `GET /configuration` returns only `webAPIVersion` and `loginUser.networkUsername`, never a
   connection string (SHELL-ADR-022 decision 7).
4. Changing a production connection string is therefore a code change and a release.
