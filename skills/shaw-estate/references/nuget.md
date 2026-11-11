# NuGet: the internal feed and the Shaw.* libraries

## Golden rule: NuGet, never ProjectReference, for Shaw.* libraries

Every consuming project in the estate gets `Shaw.*` code via a NuGet package — **zero examples anywhere
in `WebApis\` or `Websites\` use a `ProjectReference` into `Libraries\ShawLibraries`**. Never add one.
A change to a library is made under `Libraries\ShawLibraries\Shaw.<Name>\` and consumed as a package
version bump — never by pointing at the source folder.

## The feed

- Machine-wide `NuGet.Config` (`%APPDATA%\NuGet\NuGet.Config`) has a source named `Shaw` →
  `\\sic2tfs1\nuget\packages`. Most projects rely on this; a handful carry a project-level
  `NuGet.Config` with a source named `Shaw nuget` → `http://sic2tfs1/Nuget/nuget`, the same feed's HTTP
  endpoint.
- Push endpoint used by the libraries themselves: `http://sic2tfs1/Nuget/nuget`, via
  `\\sic2tfs1\nuget\nuget.exe`. Every `Shaw.*` csproj carries a `PushNuGet` MSBuild target that packs
  and pushes on **Release** build, with `-skipduplicate` — so **pushing without bumping `<Version>`
  silently does nothing**.
- `sic2tfs1` is *also* the legacy TFS server (`SccTeamFoundationServer` bindings in old `.sln` files,
  and the libraries' TFVC at `http://sic2tfs1:8080/tfs/libraries`). Don't confuse a TFS-binding hit
  with a NuGet-feed hit when grepping.

## Which package line

**v1.x and v2.x are two different package lines on the same feed** — different target frameworks
and internals (e.g. the config-loading mechanism). Match the line to the project's generation:

- Classic .NET Framework project (net45/net472/net48) → pin `Shaw.*` **v1.x**.
- Modern SDK-style project (net8.0+/net10.0) → pin `Shaw.*` **v2.x** (`netstandard2.0`, versioned 2.0.x).

Per-library detail, naming traps and observed pins: `shaw-libraries.md`.

## Changing a Shaw.* library (Muhammed's standing rule)

Any change to a library under `Libraries\ShawLibraries` goes on its own branch, is raised for review,
is **reviewed by Muhammed**, and only then merges. Nothing of it reaches the server unreviewed: no
check-in or push to the main line, no Release build (a Release build pushes to the feed), no
`nuget push`. Debug builds stay local and are fine. The libraries are TFVC, not git
(`http://sic2tfs1:8080/tfs/libraries`, `tf.exe` under Visual Studio 18 Professional). Before editing,
make the review unit first; when done, hand Muhammed the review and the publish command, and stop.
Why: these packages are shared across the whole estate, so an unreviewed change reaches every consumer
(Shaw.WebJob 2.1.0 and Shaw.Word 2.1.0 were once edited straight in the working folder).

**Backward compatibility (hard rule; many apps use these libraries):**

1. **Additive only.** No existing public type, member, signature, default, exception or config key
   changes or goes. Existing behaviour stays exactly as it is (e.g. `new Mail()` still reads
   `appSettings` and throws the same message when one is missing).
2. **A consumer-side fix first.** If the app can work round the library unchanged, do that and record it
   in an ADR. Change the library only when no consumer-side route exists, or Muhammed asks.
3. **Same target framework(s), same dependencies.** No dependency removed, upgraded or downgraded in the
   same change: an app may get one transitively. List a removable one as a candidate in the review notes.
4. **A compatible version bump:** minor or patch (2.0.0.1 → 2.0.1), never a major. A breaking change is a
   new package or a new major, and needs Muhammed's explicit say-so.
5. **Proof before review:** the existing tests and an old-style consumer pass against the new version
   unchanged; the new API works; and the review notes list the known consumers (search
   `%USERPROFILE%\source\repos` for the package reference), so Muhammed sees who is affected.
6. **The review notes say "additive only, no behaviour change"**, with that evidence. The review gate
   above stays as it is.

Develop and test locally first; no review is raised until the new version has been built and used by
its consumer on this machine:

1. A Debug build packs `<Id>.<Version>.nupkg` into `ShawLibraries\Nuget\` and does not push.
2. That folder is the machine-level NuGet source `ShawLocal` (`%APPDATA%\NuGet\NuGet.Config`). Never
   add it to a tracked `nuget.config`. Consumer commits that need the local version stay unmerged
   until the version is on the feed.
3. After every change to the library, rebuild in Debug, delete
   `%USERPROFILE%\.nuget\packages\<id lowercase>\<version>` (NuGet keeps serving the first copy it
   restored), then restore the consumer again.
4. After Muhammed publishes: `dotnet nuget remove source ShawLocal` once nothing needs it.

Muhammed's rule, 2026-11-03. The `shaw-library-guard.sh` hook enforces the no-Release-build, no-push part.
