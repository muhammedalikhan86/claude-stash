# Claude Code team setup: create-symlinks.bat

This links your Claude Code folder to the team's shared skills, agents, hooks, rules, memory and
`CLAUDE.md` on this share, so you get the same setup as everyone else and pick up updates as soon
as they are published here.

The source lives in the `claude-stash` repo. Don't edit files on this share; change the repo and
publish (see the repo's README).

## Before you run it

1. Close Claude Code completely: the desktop app and the VS Code (or other IDE) extension.
2. Be on the office network or VPN.

## How to run it

1. Open **Command Prompt as administrator** (right-click Command Prompt, then *Run as
   administrator*). Windows only lets an administrator make links.
2. Preview first. Nothing is changed:

   ```
   \\sic2tfs1\Claude\create-symlinks.bat <your-windows-username> /whatif
   ```

3. Then run it:

   ```
   \\sic2tfs1\Claude\create-symlinks.bat <your-windows-username>
   ```

   Your username is the folder name under `C:\Users\`, for example `muhammedali.khan`.

4. Start Claude Code again.

Several Claude Code accounts on one machine (set up with the account switcher)? Link them all at once:

```
\\sic2tfs1\Claude\create-symlinks.bat <your-windows-username> all
```

Or name the folders: `create-symlinks.bat <username> .claude .claude-lachlan`.

## What it does

1. **Backs up first.** Everything it replaces goes to
   `C:\Users\<you>\.claude-backups\link-<account>-<date-time>\`, with a list of every change.
2. Links `agents`, `agent-notes`, `agent-tasks`, `hooks`, `output-styles` and `commands` as whole
   folders. If one of yours holds files of your own, it links the shared items one by one instead
   and keeps yours.
3. Links each shared skill, memory file and rule one by one, so your own skills and memories stay.
4. Links `CLAUDE.md`.
5. Copies (does not link) `rules\shaw-estate.md`, because your copy holds the database password,
   and the mods, because they write into their own folder. Your password is carried over.
6. Never touches `settings.json`. If you have one, it writes `settings.stash.json` beside it for
   you to merge by hand.

Safe to run again any time: anything already linked is left as it is. Run it again after a new
skill is published, so the new skill gets linked too.

## Undo

The end of each run prints the exact undo command. It looks like this (run it as administrator):

```
powershell -ExecutionPolicy Bypass -File \\sic2tfs1\Claude\Prod\install.ps1 -Rollback "C:\Users\<you>\.claude-backups\link-claude-<date-time>"
```

## When the share is down

The links point here, so with no network, Claude Code can't load the shared skills or run the hooks.
Connect to the VPN. To work offline for a while, the `claude-stash` repo's `install.ps1` puts real
copies in place instead.

## Trouble

1. **"Run this from Command Prompt opened as administrator"**: close the window and reopen it with
   *Run as administrator*.
2. **"Can't read \\sic2tfs1\Claude\Prod"**: check you are on the office network or VPN.
