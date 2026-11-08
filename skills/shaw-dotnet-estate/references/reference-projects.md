# Gen-3 reference projects — templates for new work

These are the live examples of the modern target pattern found in the estate. When starting a brand-new standalone project (see the decision rule in `SKILL.md`), scaffold from whichever of these is the closer analog and adjust names.

There are **two distinct Gen-3 API shapes**, and picking the right one first saves rework:

| Shape | Examples | Choose it when |
|---|---|---|
| **Multi-project layered** — host csproj plus sibling `.Business` / `.DataAccess` / `.Models` csprojs | `WebApis\PhoenixV3WebAPI\Phoenix.WebAPI\` | The API has genuinely separable layers you expect to test or reuse independently, or it needs Windows-auth role splits and a substantial business layer. |
| **Single-project, folder-per-layer** — one csproj with `Domain\`, `Application\`, `Infrastructure\`, `Controllers\` folders, plus a `.slnx` | `WebApis\PersonalContactUpdatePIS\`, `WebApis\BpayLoaderInstructionsGeneratorWebAPI\` | One bounded service. Same clean-architecture discipline, far less project plumbing. **Default to this** unless you can name why you need separate assemblies. |

Both are `net10.0`, SDK-style, `appsettings.json` + `appsettings.Development.json`, and consume `Shaw.*` v2.x via `PackageReference`. Both ship a `.http` file for manual endpoint exercise and a `Properties\launchSettings.json`.

## API template (multi-project): `WebApis\PhoenixV3WebAPI\Phoenix.WebAPI\`

A from-scratch ASP.NET Core rewrite living *side-by-side* inside the same `PhoenixV3WebAPI` solution folder as the older Gen-2 OWIN project (`PhoenixV3WebAPI.csproj`) — both projects are in the same `.sln`. This "rewrite-in-place next to the original" layout is itself worth copying when modernizing an existing API: don't delete the old project, add the new one alongside it in the same solution.

Layered into sibling projects: `Phoenix.WebAPI` (host), `Phoenix.Business`, `Phoenix.DataAccess`, `Phoenix.Models`.

`Phoenix.WebAPI.csproj`:
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <StartupObject>Phoenix.WebAPI.Program</StartupObject>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="handlebars.net" Version="2.1.6" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.Negotiate" Version="10.0.9" />
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.0.8" />
    <PackageReference Include="scalar.aspnetcore" Version="2.16.3" />
    <PackageReference Include="Shaw.ActiveDirectory" Version="2.0.2.4" />
    <PackageReference Include="Shaw.Configuration" Version="2.0.0" />
    <PackageReference Include="Shaw.DataAccess" Version="2.0.1" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Phoenix.Business\Phoenix.Business.csproj" />
    <!-- ...and the other sibling layer projects -->
  </ItemGroup>
</Project>
```

Notable choices to copy:
- **Minimal-hosting `Program.cs`** (no `Startup.cs`).
- **`appsettings.json` / `appsettings.Development.json` / `appsettings.Production.json`** — standard ASP.NET Core config, not `Web.config` transforms.
- **Auth via Windows/Negotiate**: `Microsoft.AspNetCore.Authentication.Negotiate` rather than the OWIN `Microsoft.Owin.Security.OAuth`/cookie stack Gen 2 uses.
- **API docs via `scalar.aspnetcore`** (OpenAPI-based) rather than Swashbuckle.
- **Still bootstraps the legacy config mechanism** even though everything else is modern — this hasn't been replaced yet, so keep doing it in new Gen-3 work too:
```csharp
using ConfigurationManager = Shaw.Configuration.ConfigurationManager;
...
ConfigurationManager.GetConfiguration("PhoenixWebAPI", false);
```

## API template (single-project): `WebApis\PersonalContactUpdatePIS\`

The lighter Gen-3 API shape — clean-architecture *folders* rather than clean-architecture *projects*:

```
PersonalContactUpdatePIS.slnx
PersonalContactUpdatePIS.csproj
Program.cs
appsettings.json / appsettings.Development.json
Domain\                        (ContactDetails.cs — entities, no dependencies)
Application\                   (PersonnelService.cs, UrlTemplateExtensions.cs — use-case logic)
Infrastructure\DataAccess\     (PersonnelDA.cs — derives from Shaw.DataAccess)
Infrastructure\DTO\            (AddressDTO.cs — wire shapes, kept out of Domain)
Controllers\                   (PersonnelController.cs)
Properties\launchSettings.json, Properties\PublishProfiles\FolderProfile.pubxml
PersonalContactUpdatePIS.http
```

Packages: `Shaw.ActiveDirectory` 2.0.2.4, `Shaw.Configuration` 2.0.0, `Shaw.DataAccess` 2.0.1, `Shaw.Diagnostics` 2.0.0, `Shaw.Models` 2.0.0.

`WebApis\BpayLoaderInstructionsGeneratorWebAPI\BpayLoaderInstructionsGenerator\` is the same shape, smaller still: `Domain\`, `Application\Workflow.cs`, `Controllers\WorkflowController.cs`, and only `Shaw.Configuration` + `Shaw.Mail` — no data access at all. It also keeps a template asset under `App_Data\` (an `.xlsx`), which is a reasonable place for one.

Notable choices to copy from both:
- **A `.slnx` solution file** rather than `.sln` — the newer, terser solution format, also used by `LowBrokerageReportV2`.
- **`Infrastructure\DTO\` separate from `Domain\`** — external wire shapes do not leak into domain types.
- **A checked-in `.http` file** so endpoints can be exercised without Postman or a client app.
- **`Properties\PublishProfiles\*.pubxml`** (present in `PersonalContactUpdatePIS`) — deployment still goes through a publish profile, exactly as Gen-2 projects do. Gen 3 changed the project format, not the deployment mechanism.

## Console/service template: `ShawApplications\LowBrokerageReportV2\`

A clean-architecture rewrite split across four projects, with a new-style `.slnx` solution file:

```
LowBrokerageReportV2.slnx
LowBrokerageReport.Domain\        (entities/value types, no dependencies)
LowBrokerageReport.Application\   (use-case/orchestration logic)
LowBrokerageReport.Infrastructure\(Shaw.* packages live here)
LowBrokerageReport.Console\       (composition root / entry point)
```

Infrastructure layer references the shared libraries as NuGet packages, plus a `ProjectReference` up to `Domain`:
```xml
<PackageReference Include="shaw.dataaccess" Version="2.0.1" />
<PackageReference Include="shaw.diagnostics" Version="2.0.0" />
<PackageReference Include="shaw.mail" Version="2.0.0" />
<PackageReference Include="shaw.models" Version="2.0.0" />
<ProjectReference Include="..\LowBrokerageReport.Domain\LowBrokerageReport.Domain.csproj" />
```

Console project (`LowBrokerageReport.Console\Program.cs`):
- **Top-level statements**, composed via `Microsoft.Extensions.DependencyInjection` (`Microsoft.Extensions.Configuration*`/`DependencyInjection` `PackageReference`s), with `ProjectReference`s to all three inner layers — this is genuinely DI-composed, unlike the `Main()`-only style of every older console job in `ShawApplications`.
- **`appsettings.json`** loaded via `new ConfigurationBuilder().AddJsonFile("appsettings.json")` — not `App.config`.
- **Exit-code convention**: the composed `Workflow.ExecuteAsync()` call is wrapped in try/catch and the result sets `Environment.ExitCode` (0 success / 1 failure) — more scheduler/CI-friendly than the legacy pattern of only emailing a `[SUCCESS]`/`[FAILURE]` receipt. Still fine to *also* send the `TraceMail` receipt (see `Shaw.Diagnostics` in `shaw-libraries.md`) if the job needs the same human-facing notification other jobs have — the two aren't mutually exclusive.
- Still uses the `shaw.diagnostics`/`shaw.mail` packages for logging/notification — same Shaw stack as legacy jobs, just consumed as NuGet v2.x instead of GAC/HintPath v1.x.

## When neither template fits exactly

If the new project doesn't cleanly map to "API" or "console/service job" (e.g. a new website), there is no clean Gen-3 website example in the estate yet — the closest is `Websites\PhoenixV3\` (an ASP.NET Core `net8.0` host wrapping an Angular SPA, see `generations-and-signatures.md`). In that case, default to a plain modern ASP.NET Core (`net10.0`, SDK-style, `PackageReference` to `Shaw.*` v2.x, `appsettings.json`) host and pick a frontend approach with the user rather than assuming Angular — Angular was this one team's choice, not an estate-wide convention.
