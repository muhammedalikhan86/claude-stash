@echo off
setlocal EnableExtensions
rem ---------------------------------------------------------------------------------------------
rem  Links a Windows user's Claude Code folders to the team's shared copies on the PROD share, so
rem  everyone (and every Claude Code account on the machine) uses the same skills, agents, hooks,
rem  rules, memory and CLAUDE.md, and picks up updates as soon as they are published.
rem
rem  Maintained in the claude-stash repo. publish-to-prod.ps1 copies it to \\sic2tfs1\Claude.
rem  The work is done by install.ps1 -Link, which backs up everything it replaces and can undo it.
rem
rem  Usage (from Command Prompt opened as administrator):
rem    create-symlinks.bat <windows-username>                     links  C:\Users\<user>\.claude
rem    create-symlinks.bat <windows-username> all                 links  every account in .claude-accounts
rem    create-symlinks.bat <windows-username> .claude-lachlan ... links  the folders named
rem    add /whatif anywhere to preview without changing anything
rem ---------------------------------------------------------------------------------------------

set "PROD=\\sic2tfs1\Claude\Prod"
set "USERS=C:\Users"
rem Tests only: point at a sandbox share and users folder.
if defined CLAUDE_STASH_TEST_PROD set "PROD=%CLAUDE_STASH_TEST_PROD%"
if defined CLAUDE_STASH_TEST_USERS set "USERS=%CLAUDE_STASH_TEST_USERS%"
set "SCRIPT=%~dp0install.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%PROD%\install.ps1"

if "%~1"=="" goto :usage
set "TARGET_USER=%~1"
set "USERDIR=%USERS%\%~1"
shift

set "WHATIF="
set "DIRS="
set "ALL="
:args
if "%~1"=="" goto :argsdone
if /i "%~1"=="/whatif" (
    set "WHATIF=-WhatIf"
) else if /i "%~1"=="all" (
    set "ALL=1"
) else (
    set "DIRS=%DIRS% "%~1""
)
shift
goto :args
:argsdone
if not defined DIRS if not defined ALL set "DIRS=".claude""

if not exist "%USERDIR%" (
    echo [ERROR] %USERDIR% does not exist. Check the username: it is the folder name under C:\Users\.
    exit /b 1
)
if not exist "%SCRIPT%" (
    echo [ERROR] Can't find install.ps1 next to this file or in %PROD%.
    echo         Check you are on the office network or VPN.
    exit /b 1
)
if not defined WHATIF (
    rem fltmc only works in an elevated window ("net session" can succeed without it).
    fltmc >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Run this from Command Prompt opened as administrator.
        echo         Right-click Command Prompt, choose "Run as administrator", then run it again.
        exit /b 1
    )
)

echo.
echo Linking Claude Code for %TARGET_USER% to %PROD%
echo Close Claude Code first: the desktop app and the VS Code extension.
echo.

set "FAILED="
if defined ALL (
    for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$f = '%USERDIR%\.claude-accounts\accounts.json'; if (Test-Path -LiteralPath $f) { (Get-Content -Raw -LiteralPath $f | ConvertFrom-Json).accounts | ForEach-Object { $_.dir } } else { '%USERDIR%\.claude' }"`) do call :one "%%D"
)
for %%F in (%DIRS%) do call :one "%USERDIR%\%%~F"

echo.
if defined FAILED (
    echo Finished with errors; see above. Anything already changed is listed with its undo command.
    exit /b 1
)
if defined WHATIF (
    echo Preview done. Nothing was changed.
) else (
    echo Complete. Start Claude Code again.
)
exit /b 0

:one
echo ==== %~1
if not exist "%~1\" if /i not "%~nx1"==".claude" (
    echo [SKIP] %~1 does not exist.
    echo.
    goto :eof
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Link -ProdDir "%PROD%" -ClaudeDir "%~1" -BackupRoot "%USERDIR%\.claude-backups" %WHATIF%
if errorlevel 1 (
    echo [ERROR] Linking %~1 did not finish.
    set "FAILED=1"
)
echo.
goto :eof

:usage
echo Usage: %~nx0 ^<windows-username^> [all ^| ^<config-folder^> ...] [/whatif]
echo.
echo   %~nx0 muhammedali.khan                   link C:\Users\muhammedali.khan\.claude
echo   %~nx0 muhammedali.khan all               link every Claude Code account on this machine
echo   %~nx0 muhammedali.khan .claude-lachlan   link one other account's folder
echo   %~nx0 muhammedali.khan all /whatif       preview only
echo.
echo Run it from Command Prompt opened as administrator.
exit /b 1
