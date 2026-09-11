# Reduce background CPU/IO contention on the fleet VM (I0/I1).
# Run as SYSTEM via: az vm run-command invoke ... --scripts @tools/azure/tune-windows.ps1
# Idempotent. Authorised by Jon 2026-09-11: scoped Defender exclusions, appx debloat,
# disable Windows Search. Windows Update is deliberately NOT touched.
$ErrorActionPreference = 'Continue'

# ---- 1. Scoped Defender exclusions (real-time protection stays ON) ----
$paths = @(
    'C:\msys64',
    'C:\src',
    'C:\ccache',
    'C:\Users\azureuser\AppData\Local\ccache'
)
$procs = @(
    'clang.exe','clang++.exe','gcc.exe','g++.exe','ld.exe','ar.exe','as.exe',
    'cc1.exe','cc1plus.exe','cc1obj.exe','make.exe','ninja.exe','ccache.exe',
    'bash.exe','sh.exe','git.exe','pacman.exe','python.exe','python3.exe','node.exe'
)
foreach ($p in $paths) {
    try { Add-MpPreference -ExclusionPath $p -ErrorAction Stop; Write-Output "excl path $p" }
    catch { Write-Output "FAILED path $p : $($_.Exception.Message)" }
}
foreach ($p in $procs) {
    try { Add-MpPreference -ExclusionProcess $p -ErrorAction Stop }
    catch { Write-Output "FAILED proc $p : $($_.Exception.Message)" }
}
try {
    $mp = Get-MpPreference
    Write-Output "exclusion paths now: $($mp.ExclusionPath -join ', ')"
    Write-Output "exclusion procs now: $(($mp.ExclusionProcess | Measure-Object).Count)"
    Write-Output "tamperProtection: $((Get-MpComputerStatus).IsTamperProtected)"
} catch { Write-Output "Get-MpPreference failed: $($_.Exception.Message)" }

# ---- 2. Disable Windows Search indexer ----
try {
    Stop-Service WSearch -Force -ErrorAction SilentlyContinue
    Set-Service WSearch -StartupType Disabled
    Write-Output "WSearch: $((Get-Service WSearch).Status) / $((Get-Service WSearch).StartType)"
} catch { Write-Output "WSearch change failed: $($_.Exception.Message)" }

# ---- 3. Debloat consumer Win11 apps ----
# Deliberately keeps: Store, Terminal, Notepad, Snipping Tool, and all framework
# packages (VCLibs / NET.Native / UI.Xaml), which are dependencies.
$bloat = @(
    'Microsoft.BingNews','Microsoft.BingWeather','Microsoft.BingSearch',
    'Microsoft.GamingApp','Microsoft.XboxGamingOverlay','Microsoft.XboxGameOverlay',
    'Microsoft.XboxSpeechToTextOverlay','Microsoft.XboxIdentityProvider','Microsoft.Xbox.TCUI',
    'Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.WindowsFeedbackHub',
    'Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection','Microsoft.People','Microsoft.PowerAutomateDesktop',
    'Microsoft.Todos','Microsoft.WindowsMaps','Microsoft.YourPhone','Microsoft.WindowsAlarms',
    'Microsoft.WindowsCamera','Microsoft.WindowsSoundRecorder','Microsoft.OutlookForWindows',
    'Microsoft.Windows.DevHome','Microsoft.Copilot','Microsoft.Windows.Ai.Copilot.Provider',
    'MicrosoftTeams','MSTeams','Clipchamp.Clipchamp','MicrosoftWindows.Client.WebExperience'
)
$removed = 0
foreach ($b in $bloat) {
    Get-AppxPackage -AllUsers -Name $b -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop; $removed++ } catch {}
    }
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $b } | ForEach-Object {
            try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null; $removed++ } catch {}
        }
}
Write-Output "appx removals: $removed"

# ---- 4. Report load ----
Write-Output "---"
Get-CimInstance Win32_Process | Sort-Object WorkingSetSize -Descending | Select-Object -First 8 |
    ForEach-Object { Write-Output ("proc {0,-32} rssMB={1}" -f $_.Name, [math]::Round($_.WorkingSetSize/1MB)) }
$os = Get-CimInstance Win32_OperatingSystem
Write-Output "freeRAM_MB: $([math]::Round($os.FreePhysicalMemory/1KB))"
