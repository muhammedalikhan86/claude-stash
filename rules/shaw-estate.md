# Shaw & Partners estate

Applies to any Shaw & Partners work, in any repository or session.

**Load the `shaw-estate` skill first.** It is the single source of Shaw facts: where the code is,
the `Shaw.*` libraries and NuGet feed, the databases, hosting and deployment, app identity, sign-in
and AD, app-owned data, the UI standard, and the standard architecture defaults for a new app.
Don't copy those facts into other files; point to the skill.

## Hard rules (always on)

1. **UI is Angular Material.** If Material or the CDK has a component, use it; any other plain-HTML
   control needs Muhammed Ali Khan's written sign-off first. Charts are Apache ECharts via
   `ngx-echarts`. Detail: the skill's `references/ui.md`.
2. **Data access is `Shaw.DataAccess`, never EF Core.**
3. **A change to any `Shaw.*` library goes branch → review by Muhammed → merge.** No check-in, push,
   Release build or `nuget push` before that. Detail: the skill's `references/nuget.md`.
4. **Query output:** print only what the question needs; never echo the password into chat or a
   tracked file; real pay, book or client figures go to the console only; no staff email addresses
   in governed docs.
5. **No schema copies in a repository.** Query the server, and record the query a finding rests on.

## Reading the live data: credentials

The read-only **DatabaseReader** SQL login is approved for analysis and design. What it can read and
how to use it: the skill's `references/databases-and-querying.md`. The credentials stay here, because
this file is copied per user and the skill is shared.

1. **Server:** `idb_ag.shawstock.com.au,4433`. **Login:** `DatabaseReader`, SQL authentication,
   read-only.
2. **Password:** not stored in this repo. Ask the team lead, then put it in your own copy at `~/.claude/rules/shaw-estate.md`, in place of the placeholder in each connection string and the `sqlcmd` line below. The installer carries it over from your old copy on each re-install.
   **Connection strings, one per readable database** (all five checked to connect on 2026-10-09):

   ```
   DataWarehouse: Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=DataWarehouse;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   PowerBI:       Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=PowerBI;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   ShawCentral:   Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=ShawCentral;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   FeeDisclosure: Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=FeeDisclosure;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   IS:            Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=IS;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
   ```

   From a shell: `sqlcmd -S "idb_ag.shawstock.com.au,4433" -U DatabaseReader -P "<DB_PASSWORD>" -d <Database> -C`
   (`-C` trusts the server certificate).
3. This login is never a deployed app's identity. Apps connect as their pool's gMSA with Integrated
   Security: the skill's `references/app-identity-and-sql.md`.
