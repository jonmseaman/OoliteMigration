# Second-stage tooling for the fleet VM: gh (GitHub auth for the private repo) and bd (beads).
# Pinned URLs; winget cannot search from a non-interactive SSH session.
# Idempotent.
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

$dl = 'C:\setup'
New-Item -ItemType Directory -Path $dl -Force | Out-Null

function Get-Installer($url, $file) {
    # Write-Host, not Write-Output: Write-Output would become part of the return value.
    $path = Join-Path $dl $file
    if (Test-Path $path) { Write-Host "  cached $file"; return $path }
    Write-Host "  downloading $file"
    Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
    return $path
}

# ---- GitHub CLI ----
Write-Output "=== gh ==="
if (Test-Path 'C:\Program Files\GitHub CLI\gh.exe') {
    Write-Output "  already installed"
} else {
    $p = Get-Installer 'https://github.com/cli/cli/releases/download/v2.100.0/gh_2.100.0_windows_amd64.msi' 'gh_2.100.0_windows_amd64.msi'
    Start-Process msiexec.exe -ArgumentList '/i',"`"$p`"",'/qn','/norestart' -Wait
    Write-Output "  installed"
}

# ---- beads (bd) - same version as the Mac (1.2.2) so the Dolt DB matches ----
Write-Output "=== bd ==="
$bdDir = 'C:\tools\bd'
if (Test-Path (Join-Path $bdDir 'bd.exe')) {
    Write-Output "  already installed"
} else {
    New-Item -ItemType Directory -Path $bdDir -Force | Out-Null
    $p = Get-Installer 'https://github.com/gastownhall/beads/releases/download/v1.2.2/beads_1.2.2_windows_amd64.zip' 'beads_1.2.2_windows_amd64.zip'
    Expand-Archive -Path $p -DestinationPath $bdDir -Force
    Write-Output "  extracted to $bdDir"
}

# ---- dolt (beads' backing store; bd runs a dolt sql-server) ----
# Pinned to the same version as the Mac so the database format matches.
Write-Output "=== dolt ==="
$doltDir = 'C:\tools\dolt'
if (Test-Path (Join-Path $doltDir 'dolt.exe')) {
    Write-Output "  already installed"
} else {
    New-Item -ItemType Directory -Path $doltDir -Force | Out-Null
    $p = Get-Installer 'https://github.com/dolthub/dolt/releases/download/v2.3.3/dolt-windows-amd64.zip' 'dolt-windows-amd64.zip'
    $tmp = Join-Path $dl 'dolt-extract'
    Remove-Item $tmp -Recurse -Force -EA SilentlyContinue
    Expand-Archive -Path $p -DestinationPath $tmp -Force
    $exe = Get-ChildItem $tmp -Recurse -Filter 'dolt.exe' | Select-Object -First 1
    Copy-Item $exe.FullName (Join-Path $doltDir 'dolt.exe') -Force
    Write-Output "  installed to $doltDir"
}

# ---- Machine PATH: git, node, gh, bd ----
Write-Output "=== PATH ==="
$want = @(
    'C:\Program Files\Git\cmd',
    'C:\Program Files\nodejs',
    'C:\Program Files\GitHub CLI',
    'C:\tools\bd',
    'C:\tools\dolt'
)
$cur = [Environment]::GetEnvironmentVariable('Path','Machine')
$parts = $cur -split ';' | Where-Object { $_ -ne '' }
$added = @()
foreach ($w in $want) {
    if ($parts -notcontains $w) { $parts += $w; $added += $w }
}
if ($added.Count -gt 0) {
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'Machine')
    Write-Output "  added: $($added -join ', ')"
} else {
    Write-Output "  already complete"
}

Write-Output "=== result ==="
foreach ($t in @(
    @('git','C:\Program Files\Git\cmd\git.exe'),
    @('node','C:\Program Files\nodejs\node.exe'),
    @('npm','C:\Program Files\nodejs\npm.cmd'),
    @('bash','C:\msys64\usr\bin\bash.exe'),
    @('gh','C:\Program Files\GitHub CLI\gh.exe'),
    @('bd','C:\tools\bd\bd.exe'),
    @('dolt','C:\tools\dolt\dolt.exe'))) {
    Write-Output ("  {0,-6} {1}" -f $t[0], (Test-Path $t[1]))
}
