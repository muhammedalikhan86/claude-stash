# Sign-in and Active Directory: how users sign in

Users sign in with their Windows account. No login page, no tokens to manage. (What account the
*app* uses to reach SQL is a separate question: `app-identity-and-sql.md`.)

## The Gen-3 pattern (copy from Phoenix.WebAPI)

Reference: `WebApis\PhoenixV3WebAPI\Phoenix.WebAPI\Program.cs` and its `ConfigurationController`.

1. **Negotiate authentication:**
   `builder.Services.AddAuthentication(NegotiateDefaults.AuthenticationScheme).AddNegotiate();`
2. **Every endpoint needs a signed-in user:** set the authorization `FallbackPolicy` to the
   `DefaultPolicy`.
3. **Let `Shaw.ActiveDirectory` see the request:**
   `NetworkCredentials.Initialize(app.Services.GetRequiredService<IHttpContextAccessor>());`
4. **Who is calling:** `Shaw.ActiveDirectory.NetworkCredentials` — `GetCurrentUser()`,
   `GetCurrentUserAD()`, `GetDetailedCurrentUserAD()`.
5. **Role checks against AD groups:** `NetworkCredentials.GetUsersInRoleAD(roleName)`, or
   `HttpContext.User.IsInRole(roleName)` (Shaw Portal's Shell does this, in
   `ClaimsPrincipalWindowsIdentityResolver`). Shaw Portal's ADR-004 records `GetCurrentUser()` plus
   `GetUsersInRoleAD` for group checks.
6. **CORS with `.AllowCredentials()` only when the front end is on another origin.** Under the IIS
   standard (DEP-2) the SPA and API share one host, so there is no CORS.
7. On IIS, Windows auth is switched on for the API's IIS application (DEP-5/DEP-8).
8. **Kerberos only, never NTLM, for all new work** (Muhammed's rule, 2026-11-11). In the API's IIS
   Windows Authentication providers, keep **Negotiate** and remove **NTLM**, so the host enforces
   Kerberos instead of the code only intending it; record it in the app's deploy notes. An existing
   app that already relies on NTLM keeps it until it is changed on purpose; never add NTLM to a new
   app or switch one back to it. AI Form Filler is the worked example.
9. **A cross-origin API under Windows auth** (outside DEP-2's one host): the browser's preflight
   `OPTIONS` carries no credentials, so Windows auth rejects it before CORS answers. Enable the
   **IIS CORS module**, which answers preflight before auth runs; in code, register `UseCors` before
   `UseAuthentication`/`UseAuthorization` (the same ordering, in-process). Source: AI Form Filler's
   API `CLAUDE.md`, *IIS deployment notes*.

**Don't copy one thing from Phoenix.WebAPI:** its `Program.cs` still calls
`Shaw.Configuration ... GetConfiguration("PhoenixWebAPI")`. That central config is legacy for new
work (`code-and-libraries.md`). Copy the auth wiring, not that call.

## Who is who: data that mirrors AD

1. `ShawCentral.dbo.Users` mirrors Active Directory (`DisplayName`, `EmailAddress`, `Branch`,
   `JobTitle`, `Status`, `NetworkUsername`).
2. `DataWarehouse.dbo.AdvisorAccess` maps a person's email to their advisor codes; the advisor
   dashboard reads it. `AdvisorAccessProper` is its nightly rebuild with branch managers cut down to
   their own branch.

See `databases-and-querying.md` for reading them.
