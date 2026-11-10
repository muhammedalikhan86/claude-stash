---
name: shaw-library-changes-need-review
description: Any change to a Shaw.* library goes on its own branch, through a review by Muhammed, before it merges or is published; never push or publish it unreviewed
metadata:
  type: feedback
---

Any change to a library under `%USERPROFILE%\source\repos\Libraries\ShawLibraries`
lives on its own branch, is raised for review, is reviewed by Muhammed, and only then is merged.
Nothing of it reaches the server unreviewed: no check-in or push to the main line, no Release build
(a Release build pushes the package to the internal NuGet feed), no `nuget push`.

**Why:** said 2026-11-03, after Shaw.WebJob 2.1.0 and Shaw.Word 2.1.0 were edited straight in the
working folder. These packages are shared across the whole estate, so an unreviewed change reaches
every consumer.

**How to apply:** the libraries are TFVC (`http://sic2tfs1:8080/tfs/libraries`, `tf.exe` under
Visual Studio 18 Professional), not git. Before editing, make the review unit first; when done,
hand Muhammed the review and the publish command, and stop. Debug builds stay local and are fine.

**Develop and test locally first** (said 2026-11-03): no review is raised until the new version has
been built and used by its consumer on this machine.
1. A Debug build packs `<Id>.<Version>.nupkg` into `ShawLibraries\Nuget\` and does not push
   (the `PushNuGet` target runs on Release only).
2. That folder is the machine-level NuGet source `ShawLocal` (`%APPDATA%\NuGet\NuGet.Config`).
   Never add it to a tracked `nuget.config`. Consumer commits that need the local version stay
   unmerged until the version is on the feed.
3. **After every change to the library, refresh the package:** rebuild in Debug, then delete
   `%USERPROFILE%\.nuget\packages\<id lowercase>\<version>` (NuGet caches the first copy it
   restored and keeps serving it), then tell the consumer to restore again.
4. After Muhammed publishes: `dotnet nuget remove source ShawLocal` once nothing needs it.
See [[shaw-estate]] (the skill's `references/nuget.md`).
