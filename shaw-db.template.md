# Shaw live data: the DatabaseReader login (this machine only)

This file lives only in `~/.claude/rules/` on this machine. It is never in git, and the installer
creates it once and never overwrites it.

Claude may use this read-only SQL login to query the Shaw databases for analysis, design and
development reads (how: the `shaw-estate` skill's `references/databases-and-querying.md`). It is never
a deployed app's identity (apps use their pool's gMSA). Never echo the password into chat or into a
tracked file. If the lines below still show the `DB_PASSWORD` placeholder, ask the team lead and
replace it.

```
DataWarehouse: Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=DataWarehouse;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
PowerBI:       Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=PowerBI;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
ShawCentral:   Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=ShawCentral;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
FeeDisclosure: Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=FeeDisclosure;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
IS:            Data Source=idb_ag.shawstock.com.au,4433;Initial Catalog=IS;User ID=DatabaseReader;Password=<DB_PASSWORD>;TrustServerCertificate=true
```

Shell: `sqlcmd -S "idb_ag.shawstock.com.au,4433" -U DatabaseReader -P "<DB_PASSWORD>" -d <Database> -C`
