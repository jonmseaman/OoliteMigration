# Base toolchain for the fleet VM (I0 checklist / I1 provisioning).
# winget cannot search from a non-interactive SSH service context
# (0x8a15000f / "Failed when searching source"), so installers are fetched
# directly from pinned URLs. A pin move is the only reason to re-run.
# Idempotent: each step is skipped if the target is already present.
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

$dl = 'C:\setup'
New-Item -ItemType Directory -Path $dl -Force | Out-Null

function Get-Installer($url, $file) {
    # NOTE: use Write-Host, not Write-Output. Write-Output inside a function adds to
    # the function's return value, so $p becomes @('  downloading x', 'C:\path') and
    # every downstream -FilePath binding fails with "Cannot convert System.Object[]".
    $path = Join-Path $dl $file
    if (Test-Path $path) { Write-Host "  cached $file"; return $path }
    Write-Host "  downloading $file"
    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    return $path
}

# ---- Git for Windows ----
Write-Output "=== Git ==="
if (Test-Path 'C:\Program Files\Git\cmd\git.exe') {
    Write-Output "  already installed"
} else {
    $p = Get-Installer 'https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/Git-2.55.0.5-64-bit.exe' 'Git-2.55.0.5-64-bit.exe'
    Start-Process -FilePath $p -ArgumentList '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/SUPPRESSMSGBOXES','/NOICONS' -Wait
    Write-Output "  installed"
}

# ---- Node.js LTS (for the claude CLI) ----
Write-Output "=== Node.js ==="
if (Test-Path 'C:\Program Files\nodejs\node.exe') {
    Write-Output "  already installed"
} else {
    $p = Get-Installer 'https://nodejs.org/dist/v24.21.0/node-v24.21.0-x64.msi' 'node-v24.21.0-x64.msi'
    Start-Process msiexec.exe -ArgumentList '/i',"`"$p`"",'/qn','/norestart' -Wait
    Write-Output "  installed"
}

# ---- MSYS2 (UCRT64 build environment) ----
Write-Output "=== MSYS2 ==="
if (Test-Path 'C:\msys64\usr\bin\bash.exe') {
    Write-Output "  already installed"
} else {
    $p = Get-Installer 'https://github.com/msys2/msys2-installer/releases/download/2026-06-11/msys2-x86_64-20260611.exe' 'msys2-x86_64-20260611.exe'
    # Qt Installer Framework silent flags
    Start-Process -FilePath $p -ArgumentList 'in','--confirm-command','--accept-messages','--root','C:/msys64' -Wait
    Write-Output "  installed"
}

# ---- Report ----
Write-Output "=== result ==="
foreach ($t in @(
    @('git','C:\Program Files\Git\cmd\git.exe'),
    @('node','C:\Program Files\nodejs\node.exe'),
    @('npm','C:\Program Files\nodejs\npm.cmd'),
    @('bash','C:\msys64\usr\bin\bash.exe'))) {
    Write-Output ("  {0,-6} {1}" -f $t[0], (Test-Path $t[1]))
}
