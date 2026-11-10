# Identifying which generation a repo belongs to

Four style clusters were found across `WebApis\`, `Websites\`, and `ShawApplications\`. Check the `.csproj` shape and reference style first — that alone almost always tells you which cluster you're in.

**If you just want to know which generation a *named* project is, don't re-derive it** — the area index has it in a table already: `WebApis\README.md`, `Websites\README.md`, `ShawApplications\README.md`. Each lists every project with its generation, target frameworks, and `Shaw.*` package pins. Current distribution:

| Area | Gen 1 | Gen 1.5 | Gen 2 | Gen 3 | Mixed |
|---|---|---|---|---|---|
| `WebApis\` (43 buildable) | 6 | 4 | 30 | 2 | 1 (`PhoenixV3WebAPI`, Gen 2 + Gen 3 in one solution) |
| `ShawApplications\` (75 buildable) | 9 | 13 | 52 | 1 | — |
| `Websites\` (44 buildable) | see below — the generation model fits this area poorly | | | | |

For `Websites\`, generation is largely the wrong axis: only 1 of 46 references a `Shaw.*` package at all, because these are thin frontend shells over the paired API. Classify a website by its **frontend** stack instead (Angular CLI / AngularJS+bower / Web Forms / plain JS) — `Websites\README.md` does that.

Use this file for the *signatures* — what to look for when the project isn't in an index, or when you need to know why a classification is what it is.

## Gen 1 — hand-copied DLLs, no NuGet at all

**Signature**: non-SDK csproj (`ToolsVersion="12.0"` or similar), `TargetFrameworkVersion` v4.5–v4.6.1, `<Reference>` with a `<HintPath>` pointing at a manually-committed `DLL\` folder inside the project (not `packages\`):

```xml
<Reference Include="Shaw.ConfigurationManager">
  <HintPath>..\ComplianceCommon\DLL\Shaw.ConfigurationManager.dll</HintPath>
</Reference>
```

Sometimes paired with a `PreBuildEvent` that runs an import script to refresh those DLLs, e.g. `IntranetWebAPI`:

```xml
<Content Include="DLL\Import New DLLS.bat" />
...
<PropertyGroup><PreBuildEvent>"..\DLL\Import New DLLS.bat"</PreBuildEvent></PropertyGroup>
```

**Examples**: `WebApis\ComplianceWebAPI\`, `WebApis\IntranetWebAPI\`.
**Stack**: ASP.NET Web API 2, OWIN self-hosted in IIS, `Web.config` + `Web.Debug.config`/`Web.Release.config` transforms, plaintext connection strings.
**Don't imitate**: the manual-DLL-folder + import-script mechanism entirely — this is what NuGet (Gen 2/3) replaced.

## Gen 1.5 — no shared library at all, locally forked

**Signature**: zero references to any `Shaw.*` assembly; instead the solution ships its own sibling class libraries that duplicate `Shaw.Common`/`Shaw.Exception` functionality under an app-specific name, referenced via plain `ProjectReference`.

**Examples**:
- `WebApis\ShawDashboardAPI\` → forks `ShawCommon`, `ShawException` (TFM v4.5.2).
- `WebApis\APESWebAPI\` → forks `APESCommon`, `APESException`, `APESDTO`, `APESProvider` (TFM v4.7.2).

**Stack notes**: ASP.NET SignalR 2.x + OWIN; APESWebAPI also uses Application Insights and WebActivatorEx; ShawDashboardAPI embeds Crystal Reports (`CrystalDecisions.*`, `.rpt` files). No IoC container in either — raw ADO.NET throughout. The only unit-test framework found anywhere in the WebApis sample was MSTest (`RBS.UnitTests`).
**Don't imitate**: forking common code per-app. If you find yourself about to duplicate something `Shaw.Common`/`Shaw.Exception` already does, take the shared package instead.

## Gen 2 — packages.config + Shaw.* v1.x (current majority pattern)

**Signature**: non-SDK csproj (`ToolsVersion="15.0"`), `TargetFrameworkVersion` v4.8, a `packages.config` with `Shaw.*` v1.x entries, and generated `<Reference>`/`HintPath` into a local `packages\` folder:

```xml
<!-- packages.config -->
<package id="Shaw.ActiveDirectory" version="1.5.1.3" targetFramework="net48" />
<package id="Shaw.Configuration" version="1.3.2.1" targetFramework="net48" />
<package id="Shaw.DataAccess" version="1.6.7.1" targetFramework="net48" />
```
```xml
<!-- .csproj -->
<Reference Include="Shaw.ActiveDirectory, Version=1.5.1.3, Culture=neutral, processorArchitecture=MSIL">
  <HintPath>packages\Shaw.ActiveDirectory.1.5.1.3\lib\net48\Shaw.ActiveDirectory.dll</HintPath>
</Reference>
```

This is genuine NuGet consumption (old-style, non-SDK project format) — not hand-copied DLLs. It is by far the dominant pattern today: found across ~66 `packages.config` files in `WebApis\` alone (only 1 in `Websites\`), and ~80 `.csproj` files with raw `HintPath` references into a `packages\Shaw.*` folder.

**Examples**: `WebApis\PhoenixV3WebAPI\PhoenixV3WebAPI.csproj` (the original, top-level project — see `reference-projects.md` for the newer sibling rewrite in the same solution), `WebApis\StraightThroughPaymentsWebAPI\`, `ShawApplications\AETInterface\`, `ShawApplications\BloombergTradeMatch\`.

**Stack**: ASP.NET Web API 2, OWIN self-host, auth via `Microsoft.AspNet.Identity.Core/Owin` + `Microsoft.Owin.Security.OAuth/Cookies`, CORS via `Microsoft.Owin.Cors`. Common third-party libs: `AutoMapper` 10.x, `EPPlus` 6.x, `HtmlAgilityPack`, `Newtonsoft.Json` 13.x. Structure: `App_Start\WebApiConfig.cs`, `Controllers\`, `Models\`, `DataAccess\`, `Business\`, `Startup.cs` (OWIN), `Properties\PublishProfiles\*.pubxml`. `Web.config` + Debug/Release transforms, with `Shaw.Configuration.ConfigurationManager` also overlaying values from the central `ShawCentral` DB at runtime (see the config-bootstrap gotcha in `code-and-libraries.md`).

Console-job variant of this same generation (`ShawApplications\AETInterface\`, `\BloombergTradeMatch\`): `App.config` with plain `<appSettings>`, `Shaw.Diagnostics.Trace` logging, and the canonical email-on-completion pattern:

```csharp
ConfigurationManager.GetConfiguration("BloombergTradeMatch");
...
try { TraceMail.Title = "..."; TraceMail.Information("..."); ... matchMail.Send(); }
catch (Exception e) { TraceMail.Exception(e.Message); }

receiptMail.Subject = TraceMail.ErrorCount > 0 ? "[FAILURE] ..." : "[SUCCESS] ...";
receiptMail.Message = TraceMail.Log;   // HTML log body
receiptMail.Send();
```
(repeated near-verbatim in `IressFXUpload`, `Colonial`).

Windows-Service variant of this generation: `System.ServiceProcess.ServiceBase` subclass + `ProjectInstaller.cs`/`.Designer.cs` + a checked-in `Install.bat` running `InstallUtil /i <exe>.exe`. Example: `ShawApplications\IRESSInterfaceV2\` self-hosts an OWIN Web API *inside* a Windows Service:
```csharp
using (WebApp.Start<Startup>(url: baseAddress))
{
#if DEBUG
    var service = new IRESSInterfaceAPI(); service.StartService(args); ...
#else
    ServiceBase.Run(new ServiceBase[] { new IRESSInterfaceAPI() });
#endif
}
```
No project anywhere in the estate uses TopShelf.

## Gen 3 — SDK-style + Shaw.* v2.x (newest, target for new work)

**Signature**: SDK-style csproj (`<Project Sdk="Microsoft.NET.Sdk.Web">` or plain `Microsoft.NET.Sdk`), `<TargetFramework>net10.0</TargetFramework>` (or `net8.0`), `<Nullable>enable</Nullable>`, `<ImplicitUsings>enable</ImplicitUsings>`, and true `<PackageReference Include="Shaw.X" Version="2.x.x" />` entries (no `packages.config`). `appsettings.json`/`appsettings.Development.json` instead of `Web.config`/`App.config` transforms.

Four live examples exist: `WebApis\PhoenixV3WebAPI\Phoenix.WebAPI\` (multi-project layered API), `WebApis\PersonalContactUpdatePIS\` and `WebApis\BpayLoaderInstructionsGeneratorWebAPI\` (single-project, folder-per-layer API), and `ShawApplications\LowBrokerageReportV2\` (console job). Full structural detail and csproj snippets are in `reference-projects.md` — use those as the template for new work.

A further Gen-3 signature to look for: a **`.slnx`** solution file instead of `.sln`. Three of the four use it (`PersonalContactUpdatePIS`, `BpayLoaderInstructionsGenerator`, `LowBrokerageReportV2`); `PhoenixV3WebAPI` still has a `.sln` because its Gen-2 sibling shares it.

Note: `WebApis\PhoenixV3WebAPI\Phoenix.WebAPI\` still calls the legacy `Shaw.Configuration.ConfigurationManager.GetConfiguration(...)` static bootstrap at startup even though everything else about the project is modern — that config-loading mechanism hasn't been replaced yet, so keep calling it in new Gen-3 projects too.

## A parallel note on Websites specifically

- Older `Websites\*` projects (e.g. `ShawOnline`, `StatementOfAdvice\SOA`) are AngularJS 1.x SPAs hosted inside a legacy non-SDK Web Application project with almost no C# — they call out to the matching legacy WebApi rather than referencing any `Shaw.*` library client-side.
- `Websites\PhoenixV3\` is the closest thing to a Gen-3 website: a `Microsoft.NET.Sdk.Web`, `net8.0` project whose real content is an embedded Angular app (`angular.json`, `package.json`), with ASP.NET Core used purely as a static-file host/build wrapper — not a C#-heavy rewrite the way `Phoenix.WebAPI` is on the API side.

## Other one-off outliers seen (context only, not patterns to follow)

- `ShawApplications\PhoenixDataSync\` still has a VSS-style `_main`/`development` branch-folder layout — a pre-Git artifact.
- `ShawApplications\RemoteExec\` dates to Visual Studio 2008 and uses `.NET Remoting` (`ChannelManager.cs`) — obsolete, unrelated to the `Shaw.*` stack.
- `ShawApplications\UBSTradeFile\` is an empty folder (0 files) — not a real project to reference.
