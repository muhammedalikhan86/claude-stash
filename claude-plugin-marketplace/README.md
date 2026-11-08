# Claude Code Plugin Marketplace

Internal marketplace for team-shared Claude Code plugins.

## What's in here

| Plugin | Description |
|---|---|
| `web-dotnet-toolkit` | Angular, React, Next.js, NestJS, TypeScript, API design, CLI tooling, .NET/C# best practices, and Context7 live-docs lookup. |

The `web-dotnet-toolkit` plugin currently bundles these skills:

- `angular-architect` — Angular 17+ standalone components, NgRx, RxJS, routing, performance
- `api-designer` — REST/GraphQL API design, OpenAPI specs, versioning, pagination
- `cli-developer` — CLI tools, argument parsing, shell completions
- `context7-mcp` — pulls current library/framework docs via Context7 instead of relying on training data
- `csharp-developer` — C#, .NET 8+, ASP.NET Core, Blazor
- `dotnet-best-practices` — general .NET/C# best-practices review
- `dotnet-core-expert` — .NET 8 minimal APIs, clean architecture, EF Core, CQRS/MediatR
- `dotnet-design-pattern-review` — design-pattern review for C#/.NET code
- `nestjs-expert` — NestJS modules, controllers, DI, guards, TypeORM/Prisma
- `nextjs-developer` — Next.js 14+ App Router, server components/actions, Vercel deployment
- `react-expert` — React component/state patterns
- `typescript-pro` — modern TypeScript (ES2023+, async patterns, ESM, Node APIs)

## Install (end users)

Run these inside Claude Code (CLI or VS Code extension):

```
/plugin marketplace add <path-to-this-folder>
/plugin install web-dotnet-toolkit@shawpartners-claude-plugins
```

For example, from a clone of the claude-stash repo:

```
/plugin marketplace add "%USERPROFILE%\source\repos\claude-stash\claude-plugin-marketplace"
```

Or from a local copy:

```
/plugin marketplace add "C:\path\to\claude-plugin-marketplace"
```

After installing, reload plugins if Claude Code doesn't pick it up automatically:

```
/reload-plugins
```

Verify it's active:

```
/plugin list
```

## Using the skills

Skills installed via a plugin are namespaced under the plugin name, so invoke them as:

```
/web-dotnet-toolkit:angular-architect
/web-dotnet-toolkit:context7-mcp
/web-dotnet-toolkit:csharp-developer
...
```

(not the bare `/angular-architect` form). Claude will also invoke them automatically when your request matches a skill's description — explicit `/` invocation is optional.

## Updating

When the source skills change, bump the `version` field in both:

- `plugins/web-dotnet-toolkit/.claude-plugin/plugin.json`
- the matching entry in `.claude-plugin/marketplace.json`

Team members already on the marketplace pick up the update with:

```
/plugin marketplace update shawpartners-claude-plugins
```

## Adding more skills later

Copy a skill folder (containing `SKILL.md` and any `references/`) into
`plugins/web-dotnet-toolkit/skills/<skill-name>/`, then bump the version as above.
No code changes are needed — skills work in a plugin exactly as they do standalone.

## Uninstall

```
/plugin uninstall web-dotnet-toolkit@shawpartners-claude-plugins
/plugin marketplace remove shawpartners-claude-plugins
```
