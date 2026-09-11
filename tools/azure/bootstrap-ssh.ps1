# Bootstrap agent-drivable SSH on the Azure Windows VM (I0).
# Run as SYSTEM via: az vm run-command invoke ... --scripts @tools/azure/bootstrap-ssh.ps1
# Idempotent: running it twice changes nothing.
$ErrorActionPreference = 'Stop'

# 1. OpenSSH Server feature
$cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
if ($cap.State -ne 'Installed') {
    Write-Output "installing $($cap.Name)"
    Add-WindowsCapability -Online -Name $cap.Name | Out-Null
} else {
    Write-Output "OpenSSH.Server already installed"
}

# 2. Service: automatic + running
Set-Service -Name sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne 'Running') { Start-Service sshd }
Set-Service -Name ssh-agent -StartupType Automatic -ErrorAction SilentlyContinue

# 3. Windows firewall
# NOTE: the OpenSSH.Server capability creates this rule scoped to the *Private* profile only,
# while an Azure VM's NIC is classified *Public* - so the stock rule never applies and 22 is
# silently dropped. Always enforce Profile=Any rather than trusting an existing rule.
$fw = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $fw) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Any | Out-Null
    Write-Output "firewall rule created (Profile=Any)"
} else {
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True -Profile Any
    Write-Output "firewall rule present; forced Enabled=True Profile=Any (was Profile=$($fw.Profile))"
}

# 4. Authorized key for administrator accounts
$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICwwXgFPYc2MX+fGTcItjyslxnf2FJlTlvsRApzb21sH jonms@Jons-MacBook-Pro.local'
$akf = 'C:\ProgramData\ssh\administrators_authorized_keys'
if (-not (Test-Path 'C:\ProgramData\ssh')) { New-Item -ItemType Directory -Path 'C:\ProgramData\ssh' | Out-Null }
$existing = if (Test-Path $akf) { Get-Content $akf -Raw } else { '' }
if ($existing -notmatch [regex]::Escape($key)) {
    Add-Content -Path $akf -Value $key -Encoding ascii
    Write-Output "key added"
} else {
    Write-Output "key already authorised"
}
# Required ACL: only Administrators and SYSTEM, no inheritance, or sshd ignores the file.
icacls.exe $akf /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null

# 5. Report
Write-Output "---"
Write-Output "sshd: $((Get-Service sshd).Status)"
Write-Output "listening: $((Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count)"
Write-Output "os: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)"
Write-Output "ramGB: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1))"
Write-Output "cores: $((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors)"
Get-Volume | Where-Object DriveLetter | ForEach-Object { Write-Output "vol $($_.DriveLetter): size=$([math]::Round($_.Size/1GB,1))GB free=$([math]::Round($_.SizeRemaining/1GB,1))GB" }
