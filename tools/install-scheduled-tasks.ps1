# Register the fleet machine's nightly and weekly scheduled tasks.
#
# Phase 0 exit-gate boxes 30 and 32 (docs/phases/0-safety-net.md): the OXP corpus is
# "per-commit / nightly / weekly" and the GUI tier runs "by Tier C and nightly". Per-commit
# exists (tools/tier-b.sh, the merge queue); this is the nightly and the weekly.
#
# ADR-0016 (no forge, local verification): there is no hosted scheduler and no CI cron, so the
# schedule is two Windows scheduled tasks on this one machine (ADR-0010), and the thing they run
# is tools/nightly.sh.
#
#     powershell -ExecutionPolicy Bypass -File tools\install-scheduled-tasks.ps1
#     powershell -ExecutionPolicy Bypass -File tools\install-scheduled-tasks.ps1 -WhatIf
#     powershell -ExecutionPolicy Bypass -File tools\install-scheduled-tasks.ps1 -Remove
#
#   OoliteMigration Nightly         tools/nightly.sh tier-c         daily,  02:00
#   OoliteMigration Weekly Corpus   tools/nightly.sh corpus-tier3   Sunday, 03:00
#
# ============================================================================================
# FIVE DECISIONS, EACH MEASURED ON THIS BOX RATHER THAN ASSUMED
# ============================================================================================
#
# 1. schtasks.exe, NOT Register-ScheduledTask. Both exist here (PowerShell 5.1.26100 with the
#    ScheduledTasks module), and schtasks was chosen because it is what was verified to work
#    UNELEVATED for a per-user task: /Create rc=0, /Query rc=0, /Delete rc=0, and /Query on a
#    deleted task rc=1. The account the fleet runs as is not an administrator
#    (docs/infra/windows-workstation-setup.md, "Deviations on Jon's desktop"), so a registration
#    path needing elevation would simply not run here.
#
# 2. IDEMPOTENT BY /F, not by a pre-check. `schtasks /Create /F` replaces an existing task of
#    the same name instead of failing with "the task already exists", so re-running this script
#    is a no-op that ends in the same state. A read-then-branch would race itself and would also
#    leave the "already registered by an earlier attempt" case failing, which is exactly the case
#    a replayed acceptance hits.
#
# 3. "RUN ONLY WHEN THE USER IS LOGGED ON" IS REQUIRED, NOT A COMPROMISE. Neither /RU nor /RP is
#    passed, so the task runs interactively as the current user. That is deliberate: Tier C's gui
#    stage drives a real window with synthetic OS input events and its asan stage opens a real GL
#    window, because MSYS2's Mesa ships no EGL and SDL_VIDEODRIVER=offscreen cannot create a
#    context (tools/check-desktop-lock.sh). A task registered with /RU SYSTEM or with stored
#    credentials runs in session 0, where there is no interactive desktop, and every GUI test
#    would fail or, worse, silently skip. The machine is documented to stay logged in and
#    unlocked for exactly this reason (docs/phases/0-gui-tier.md, docs/infra/0-machines.md).
#
# 4. THE BASH INVOCATION IS THE ONE tools/setup-windows.sh DOCUMENTS, and nothing more. MSYS2 on
#    this machine is the scoop package under C:\Users\jon\scoop\apps\msys2\current, not
#    C:\msys64 (windows-workstation-setup.md again), so the path is DISCOVERED, never hardcoded:
#    HERMES_GIT_BASH_PATH, then MSYS2_BASH, then a short list of known roots, and the script dies
#    naming what it looked for rather than registering a task that cannot run. The command is
#    `bash.exe -lc "<repo>/tools/nightly.sh <job>"` -- a LOGIN shell, which is what sources
#    /etc/profile.d/oolite-windows-env.sh (the USERPROFILE/LOCALAPPDATA shim setup-windows.sh
#    installs, without which ccache.exe aborts). MSYSTEM=UCRT64 is deliberately NOT set on the
#    command line: nightly.sh re-execs itself into the UCRT64 shell exactly as tier-c.sh and
#    setup-windows.sh do, so the UCRT64 guarantee lives in ONE place instead of being duplicated
#    into a task definition nobody would think to update.
#
# 5. THE TASK POINTS AT THE MAIN CHECKOUT, NEVER AT A WORKTREE. This script is developed and run
#    from a per-bead worktree under .worktrees/, which accept.sh deletes when the bead lands. A
#    task registered against that path would keep working until the bead was accepted and then
#    silently fail every night afterwards, which is the worst possible failure for a scheduled
#    job. So a repo root inside .worktrees\<id> is resolved back up to the checkout that owns it,
#    and -RepoRoot overrides the whole thing.
#
# schtasks caps /TR at 261 characters; the composed command is ~120 here and the length is
# asserted below rather than left to be discovered as a truncated task.

[CmdletBinding()]
param(
    # The checkout the tasks should run from. Defaults to the main checkout that owns this file.
    [string] $RepoRoot,
    # Path to MSYS2's bash.exe. Defaults to the discovery order documented above.
    [string] $BashPath,
    # Print what would be registered and change nothing.
    [switch] $WhatIf,
    # Unregister both tasks instead of registering them.
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'

# Write-Output inside a function is appended to its return value, so a helper that logs and
# returns a path returns an ARRAY and every later binding fails with "Cannot convert
# System.Object[]" -- the trap recorded in docs/infra/windows-workstation-setup.md. Log with
# Write-Host only.
function Say  { param([string] $m) Write-Host "install-scheduled-tasks: $m" }
function Fail { param([string] $m) Write-Host "install-scheduled-tasks: $m" -ForegroundColor Red; exit 1 }

# --- 1. the repo root -----------------------------------------------------------------------

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
$RepoRoot = $RepoRoot.TrimEnd('\', '/')

# Decision 5: a worktree is transient; the task must outlive it.
$marker = [regex]::Escape([IO.Path]::DirectorySeparatorChar + '.worktrees' + [IO.Path]::DirectorySeparatorChar)
if ($RepoRoot -match $marker) {
    $main = $RepoRoot -replace ($marker + '[^\\/]+.*$'), ''
    # The main checkout is identified by being a git checkout with this repo's tools/ in it --
    # NOT by already containing tools/nightly.sh. When this script is first run from the very
    # worktree that introduces nightly.sh, main does not have it yet and acquires it when the
    # bead lands; pointing the task at main anyway is the whole purpose of this branch, and
    # refusing would force the task onto a path that is about to be deleted.
    if ($main -and (Test-Path (Join-Path $main '.git')) -and (Test-Path (Join-Path $main 'tools\tier-c.sh'))) {
        Say "resolved the worktree $RepoRoot to its main checkout $main (a worktree is deleted when its bead lands)"
        if (-not (Test-Path (Join-Path $main 'tools\nightly.sh'))) {
            Say "NOTE: $main\tools\nightly.sh does not exist YET -- it arrives when this bead lands. The task is registered against the stable path on purpose; it will not run successfully until then."
        }
        $RepoRoot = $main
    } else {
        Fail "this file is in a worktree ($RepoRoot) and no main checkout with tools/tier-c.sh was found above it; pass -RepoRoot explicitly"
    }
}

$runner = Join-Path $RepoRoot 'tools\nightly.sh'
if (-not (Test-Path $runner)) {
    Say "WARNING: no runner at $runner yet (see the note above); registering the task against that path regardless"
}

# --- 2. MSYS2's bash ------------------------------------------------------------------------

if (-not $BashPath) {
    $candidates = @()
    if ($env:HERMES_GIT_BASH_PATH) { $candidates += $env:HERMES_GIT_BASH_PATH }
    if ($env:MSYS2_BASH)           { $candidates += $env:MSYS2_BASH }
    $candidates += @(
        (Join-Path $env:USERPROFILE 'scoop\apps\msys2\current\usr\bin\bash.exe'),
        'C:\msys64\usr\bin\bash.exe',
        'C:\tools\msys64\usr\bin\bash.exe'
    )
    $BashPath = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $BashPath -or -not (Test-Path $BashPath)) {
    Fail ("no MSYS2 bash.exe found. Looked at HERMES_GIT_BASH_PATH, MSYS2_BASH, " +
          "$env:USERPROFILE\scoop\apps\msys2\current\usr\bin\bash.exe, C:\msys64 and C:\tools\msys64. " +
          "Pass -BashPath, and see docs/infra/windows-workstation-setup.md")
}
# Git Bash cannot see ccache, clang or anything else from pacman -- the first trap in the
# workstation runbook. Say so loudly rather than registering a task that fails every night.
if ($BashPath -match 'Program Files\\Git' -or $BashPath -match 'scoop\\apps\\git\\') {
    Fail ("$BashPath is Git Bash, not MSYS2. It cannot see the pacman toolchain, so the tier " +
          "would fail or silently use the wrong compiler (docs/infra/windows-workstation-setup.md). " +
          "Point -BashPath at MSYS2's usr\bin\bash.exe")
}

# The repo path as bash sees it. `cygpath -u` from the very shell that will run the task, so the
# answer comes from that MSYS2 installation rather than from a string substitution here.
$runnerUnix = (& $BashPath -lc "cygpath -u '$($runner -replace '\\', '/')'" 2>$null | Select-Object -First 1)
if (-not $runnerUnix) { Fail "could not translate $runner with cygpath via $BashPath" }
$runnerUnix = $runnerUnix.Trim()

Say "repo   $RepoRoot"
Say "bash   $BashPath"
Say "runner $runnerUnix"

# --- 3. the two tasks -------------------------------------------------------------------------

$tasks = @(
    [pscustomobject]@{
        Name     = 'OoliteMigration Nightly'
        Job      = 'tier-c'
        Schedule = @('/SC', 'DAILY', '/ST', '02:00')
        Why      = 'the full Tier C merge gate, including the GUI tier that runs in Tier C and nightly only (ADR-0017)'
    },
    [pscustomobject]@{
        Name     = 'OoliteMigration Weekly Corpus'
        Job      = 'corpus-tier3'
        Schedule = @('/SC', 'WEEKLY', '/D', 'SUN', '/ST', '03:00')
        Why      = 'the weekly Tier 3 corpus: all 813 expansions, ~3 hours, resumable'
    }
)

if ($Remove) {
    $bad = 0
    foreach ($t in $tasks) {
        if ($WhatIf) { Say "WHATIF would delete '$($t.Name)'"; continue }
        & schtasks /Delete /TN $t.Name /F 2>&1 | Out-Null
        # rc is read from $LASTEXITCODE directly: piping a native tool into Out-Null/head/grep
        # masks its status, and a masked status is how a vacuous green gets mistaken for proof.
        if ($LASTEXITCODE -eq 0) { Say "deleted '$($t.Name)'" }
        else { Say "'$($t.Name)' was not registered (schtasks /Delete rc=$LASTEXITCODE); nothing to do" }
        & schtasks /Query /TN $t.Name 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Say "STILL PRESENT after delete: '$($t.Name)'"; $bad = 1 }
    }
    if ($bad) { Fail 'at least one task survived its delete' }
    Say 'both tasks are absent'
    exit 0
}

$failed = 0
foreach ($t in $tasks) {
    # The quoting that actually survives BOTH layers. The /TR value must reach schtasks as one
    # argument containing literal double quotes: the bash path may contain spaces, and the -lc
    # command must stay a single argument. PowerShell 5's native-command argument marshalling
    # strips bare embedded quotes, so `-lc "…/nightly.sh tier-c"` arrived at schtasks as three
    # tokens and it refused with `ERROR: Invalid argument/option - 'tier-c'` (measured on this
    # box). Escaping each quote as \" is what survives; verified by registering a probe task and
    # reading it back with /Query /V, which returned the command with its quotes intact.
    $tr = '"{0}" -lc "{1} {2}"' -f $BashPath, $runnerUnix, $t.Job
    $trArg = $tr -replace '"', '\"'
    if ($tr.Length -gt 261) {
        Fail "the /TR command for '$($t.Name)' is $($tr.Length) chars; schtasks truncates above 261. Move the checkout to a shorter path."
    }

    Say ""
    Say "'$($t.Name)'  --  $($t.Why)"
    Say "  schedule $($t.Schedule -join ' ')"
    Say "  run      $tr"

    if ($WhatIf) { Say '  WHATIF nothing was registered'; continue }

    # /F makes this IDEMPOTENT: an existing task of this name is replaced rather than refused,
    # so a second run of this script is a no-op ending in the same state (decision 2).
    $out = & schtasks /Create /TN $t.Name /TR $trArg @($t.Schedule) /F 2>&1
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
        Write-Host ($out | Out-String)
        Say "  FAILED: schtasks /Create rc=$rc"
        $failed = 1
        continue
    }

    # VERIFY, because "the create command exited 0" and "the task is registered" are different
    # claims. $LASTEXITCODE is read directly rather than through a pipeline.
    & schtasks /Query /TN $t.Name 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Say "  FAILED: created but /Query rc=$LASTEXITCODE -- the task is not registered"
        $failed = 1
        continue
    }
    Say "  registered and verified (schtasks /Query rc=0)"
}

Say ""
if ($failed) { Fail 'at least one task was not registered' }
Say 'both tasks are registered. Verify with:'
Say '  schtasks /Query /TN "OoliteMigration Nightly"'
Say '  schtasks /Query /TN "OoliteMigration Weekly Corpus"'
Say 'Re-running this script is safe: /F replaces rather than refuses.'
exit 0
