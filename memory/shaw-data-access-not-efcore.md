---
name: shaw-data-access-not-efcore
description: For Shaw & Partners .NET work, use the in-house Shaw.DataAccess NuGet package for database connectivity; do not propose Entity Framework Core.
metadata:
    pinned: false
---

# Data access on Shaw & Partners .NET work

Muhammed has stated a standing preference that database connectivity in Shaw & Partners .NET
projects goes through the in-house `Shaw.DataAccess` NuGet package, and explicitly **not** through
Entity Framework Core. This came up when a freshly triaged design had proposed EF Core in
database-first mode, and he corrected it to Shaw.DataAccess.

The reason is estate consistency rather than any technical shortcoming of EF Core. The Shaw estate at
`%USERPROFILE%\source\repos` contains roughly 180 solutions, and every one of them that
touches a database does so through `Shaw.DataAccess`, consumed as a package from the internal
`sic2tfs1` feed. Introducing EF Core into a single new project would mean the estate carries two
data-access stacks, two sets of idioms, and two things a maintainer has to know — a cost that
outweighs any per-project convenience EF Core offers.

The practical consequence worth remembering is that `Shaw.DataAccess` is a thin raw-ADO.NET wrapper,
not an ORM. It has no change tracking, no LINQ provider and no migrations. So whenever a design leans
on an EF Core feature — change tracking for "update only what changed" being the usual one — that
part of the design has to be re-argued and hand-written rather than assumed. Raise this early in
design rather than discovering it during implementation.

Applies to any Shaw & Partners .NET project unless he says otherwise for a specific case. It is a
preference about which stack to build on, so it holds even when EF Core would be the more
conventional choice outside this organisation. The companion `shaw-dotnet-estate` skill carries the
estate-wide detail (package versions, the feed, the Gen-1/2/3 code generations).
