---
name: claude-account-switcher
description: Switch between and manage the user's Claude Code accounts (licences, subscriptions, logins) on Windows. Known accounts are Neeraj, Muhammed, John and Lachlan. Switching opens a new VS Code window signed in as that account. Use this skill whenever the user says "switch to NAME", "use NAME's account", "open this as NAME", "change licence/account", names one of those accounts, asks which account Claude Code is using, or wants to add, list, remove or set up accounts in the terminal or the VS Code extension, even if they never mention CLAUDE_CONFIG_DIR or PowerShell.
compatibility: Windows with Claude Code; uses Windows PowerShell 5.1 or PowerShell 7 (powershell.exe ships with Windows).
---

# Claude Code account switcher (Windows)

## How it works

Claude Code keeps its login, settings and history in one config folder, `~/.claude` by default. Setting the environment variable `CLAUDE_CONFIG_DIR` points it at a different folder. Giving each account its own folder keeps every account logged in at once, so "switching" just means launching Claude Code with a different folder.

The bundled script `scripts/claude-accounts.ps1` manages this:

- It stores the account list in `~/.claude-accounts/accounts.json`.
- It writes a managed block of shortcut functions into the user's PowerShell profiles (both `Documents\WindowsPowerShell\profile.ps1` and `Documents\PowerShell\profile.ps1`, so 5.1 and 7 both work). Anything else in those files is left alone.

For each account, for example `work`, the user gets:

| Command       | What it does                                                        |
|---------------|---------------------------------------------------------------------|
| `claude-work` | Starts Claude Code as the work account (passes through any args)    |
| `code-work`   | Opens a separate VS Code window where the Claude Code extension uses the work account |

`claude-default` and `code-default` always use the original `~/.claude` login. The shortcuts restore the previous environment afterward, so a plain `claude` keeps behaving as before.

### How VS Code switching works

A second `code` command normally hands off to the VS Code already running, which keeps its original account. So each named account gets its own VS Code *instance*, using a separate user-data folder at `~/.claude-accounts/vscode/<name>`. It runs alongside the user's normal VS Code, and the account that is the original login simply uses the normal VS Code.

- **Extensions are shared**, so the Claude Code extension is already there.
- **Settings, keybindings and snippets** are copied from the user's normal VS Code the first time an account opens. Later changes don't sync automatically. To re-copy, delete that account's `~/.claude-accounts/vscode/<name>/User/settings.json` (or `keybindings.json`) and open it again.
- **The window title** starts with the account name, e.g. `[Lachlan] app.ts — my-project`, so windows are easy to tell apart.

## Known accounts

| Say | Account name in the script |
|---|---|
| Neeraj | `neeraj` |
| Muhammed | `muhammed` |
| John | `john` |
| Lachlan | `lachlan` |

One of these is the login that was already in Claude Code before setup. It stays in the original `~/.claude` folder, registered with `add <name> -Current`, so it never needs setting up again. The others each get their own folder, `~/.claude-<name>`. `list` shows which is which. `default` always means that original login.

Match names loosely: "Lachy", "switch to john", or a misspelling like "Mohammed" clearly mean one of these, so use it. If a request could mean two accounts, ask. If an account above is missing from `list`, run `add <name>` for it before opening it.

## Two things to tell the user up front

1. **The current session can't switch itself.** The account is fixed when Claude Code starts. "Switching" therefore means opening a new window that runs as the other account (the `open` command). The current session keeps running on its own account until the user closes it with `/exit`. Mention this briefly the first time.
2. **Logging in is done by the user.** Sign-in happens in the browser, so the first time an account opens, the user logs in when Claude Code asks (or types `/login`). This happens once per account.

## Running the script

Run it with Windows PowerShell from whatever shell you have. Use the absolute path to this skill's `scripts` folder:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>/scripts/claude-accounts.ps1" <command> [name] [options]
```

| Command | Purpose |
|---|---|
| `list` | Show accounts, whether each is logged in, its email (when Claude Code has recorded one), and its folder |
| `status` | Show which account this session is using, plus the list |
| `add <name>` | Create an account folder (`~/.claude-<name>`) and its shortcuts. `-Path D:\somewhere` picks a custom folder |
| `add <name> -Current` | Register the login already in `~/.claude` under this name: no new folder, no new login. Only one account can be the current login |
| `remove <name>` | Unregister the account and remove its shortcuts; the folder is kept |
| `remove <name> -DeleteData` | Also delete the folder (its login, settings and history) |
| `install` | Rewrite the profile block, e.g. after the user edited it by hand |
| `open <name>` | **Switch**: open a new VS Code window on the project as that account. `-Project <folder>` sets the folder (default: current folder) |
| `open <name> -Terminal` | Open a terminal window running Claude Code instead. Only when the user explicitly asks for a terminal |
| `open <name> -Terminal -PermissionMode <mode>` | Start that Claude Code in a permission mode (`default`, `acceptEdits`, `plan`, `bypassPermissions`, ...). Only when the user or a hub asks for one |
| `sync` | Copy this skill into every account's `skills` folder, so all accounts use the same version. `add` and `install` do this automatically |
| `open ... -DryRun` | Show what would be launched without launching it |

`open` clears the variables a running Claude Code session sets (`CLAUDECODE`, `CLAUDE_CODE_*`, `CLAUDE_PID`, ...) before it starts the new one, so a window opened from inside a session is a full session of its own: transcript on, listed by `ListAgents`, reachable by peer messages. A value set at User or Machine level is kept.

Names are lowercase letters, digits and hyphens (`work`, `personal`, `client-a`). `default` is reserved.

## Workflows

**First-time setup** (e.g. "set up my accounts"):
1. Run `list`. Before setup it shows one `default` row: the login Claude Code is using now, with its email if available.
2. Work out which known account that login belongs to, so it is reused instead of set up again:
   - If the email clearly matches one name (e.g. `john.smith@...` means John), state your match and ask the user to confirm in one short question.
   - If there's no email or it's ambiguous, ask which of Neeraj, Muhammed, John or Lachlan is currently logged in. (The user can check with `/status` if unsure.)
   - If `default` shows "not logged in", skip this step. Nobody is logged in yet, so every account is added normally.
3. Run `add <that-name> -Current` for the confirmed account, then `add <name>` for each remaining account.
4. Tell the user that only the remaining accounts need logging in, and name them. Each one logs in the first time they switch to it.
5. Offer to run `list` afterward to confirm each account shows "logged in".

The skill copies itself into every account's `skills` folder during setup, so it works whichever account is open.

If an earlier setup created a separate folder for the account that is actually the current login, run `remove <name>` (keeps its folder) and then `add <name> -Current`.

**Switch accounts** (e.g. "switch to Lachlan", "open this as John"): this opens **VS Code**, unless the user says terminal.
1. Map the name to an account from the table above.
2. Run `open <name> -Project "<current project folder>"` (no `-Terminal`), using the folder this session is working in, so the new window opens the same project.
3. Tell the user in one or two sentences: a new VS Code window opened as that account, with its name in the title bar. They can close this window when they're ready. If the script noted the account isn't logged in, say they'll be asked to log in in the new window.
4. The first time an account opens, also mention that its window has its own copy of their settings, and extensions are shared.

Never add `-Terminal` unless the user explicitly asks for a terminal or command line ("open Lachlan in a terminal").

**Which account am I on?** Run `status`. It reads this session's `CLAUDE_CONFIG_DIR`; unset means the default account. Note that "logged in" only means a credentials file exists in that folder. To see the actual email or plan, the user can run `/status` inside Claude Code.

**Switching by hand** (without asking Claude): in PowerShell, `code-<name> .` opens the current folder in VS Code as that account, and `claude-<name>` starts Claude Code in the terminal as it.

**Remove an account:** run `remove <name>`. Only add `-DeleteData` after the user explicitly confirms, because it permanently deletes that account's login, settings and history.

## Troubleshooting

- **"Switch" opened a terminal instead of VS Code:** an old copy of this skill was used. Run `sync` to update every account's copy, then tell the user to restart VS Code, since skills load at startup.
- **"claude-work is not recognized"**: the profile only loads in new windows, so open a new one. If it still fails, the execution policy may be blocking profiles. Suggest `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` and explain that it lets the user's own local scripts (including the profile) run.
- **The new VS Code window still shows the old account:** run `open <name> -DryRun` and check that it uses `--user-data-dir`. The original login opens in the normal VS Code, so if that normal VS Code was itself started by an old `code-<name>` shortcut, close it and reopen VS Code normally.
- **"Could not find VS Code":** in VS Code, run the command palette action *Shell Command: Install 'code' command in PATH*, or reinstall VS Code with "Add to PATH" ticked.
- **Settings out of date in an account's window:** delete that account's `~/.claude-accounts/vscode/<name>/User/settings.json` and open it again to re-copy.
- **Wrong person registered as the current login:** run `remove <name>` (this only unregisters it; the original login is never deleted), then `add <right-name> -Current`, then `add <name>` for the one you removed so it gets its own folder.
- **No new window appears:** run the same command with `-DryRun` to see what it would launch. Some security software blocks launching apps from Claude Code. If it is blocked, give the user the shortcut `code-<name> "<folder>"` to run themselves in PowerShell.
- **Adding another account later:** run `add <name>`, then add a row to the Known accounts table in this file and the name to the description, so Claude recognises it.

## Safety

Never read, print, copy or move `.credentials.json` or any token file. Checking that it exists (as the script does) is fine. The script reads only the signed-in email from Claude Code's `.claude.json`, to help match logins to names; don't read anything else from those files. Moving logins between folders isn't needed: each account logs in once in its own folder.
