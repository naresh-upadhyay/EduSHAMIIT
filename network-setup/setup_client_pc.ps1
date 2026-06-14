# ============================================================
# SHAMIIT / SHAMIITDSK Client Setup Script
# Run this on EACH remote PC in an ELEVATED (Admin) PowerShell
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Client PC Setup - Connect to DurgamYogi" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check for admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n[ERROR] Run as Administrator!" -ForegroundColor Red
    exit 1
}

# --- Step 1: Set Network to Private ---
Write-Host "`n--- Step 1: Set Network to Private ---" -ForegroundColor Yellow
try {
    $iface = Get-NetConnectionProfile | Where-Object { $_.InterfaceAlias -like "Wi-Fi*" -or $_.InterfaceAlias -like "Ethernet*" }
    foreach ($i in $iface) {
        Set-NetConnectionProfile -InterfaceIndex $i.InterfaceIndex -NetworkCategory Private
        Write-Host "  [OK] $($i.InterfaceAlias) -> Private" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Step 2: Enable Network Discovery & File Sharing ---
Write-Host "`n--- Step 2: Enable Sharing Services ---" -ForegroundColor Yellow

$services = @("FDResPub", "SSDPSRV", "upnphost", "fdPHost", "LanmanServer", "LanmanWorkstation")
foreach ($svc in $services) {
    try {
        Set-Service $svc -StartupType Automatic -ErrorAction Stop
        Start-Service $svc -ErrorAction SilentlyContinue
        Write-Host "  [OK] $svc -> Automatic" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] $svc -> $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Step 3: Enable Firewall Rules ---
Write-Host "`n--- Step 3: Enable Firewall Rules ---" -ForegroundColor Yellow
$groups = @("Network Discovery", "File And Printer Sharing", "Windows Remote Management")
foreach ($group in $groups) {
    try {
        Set-NetFirewallRule -DisplayGroup $group -Enabled True -ErrorAction Stop
        Write-Host "  [OK] Firewall: '$group' -> Enabled" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Firewall: '$group' -> $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Step 4: Allow Guest Auth for LAN ---
Write-Host "`n--- Step 4: Allow LAN Guest Auth ---" -ForegroundColor Yellow
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    Set-ItemProperty -Path $regPath -Name "AllowInsecureGuestAuth" -Value 1 -Type DWord -Force
    Write-Host "  [OK] Guest auth enabled" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Step 5: Share All Drives ---
Write-Host "`n--- Step 5: Share Drives ---" -ForegroundColor Yellow

$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match "^[A-Z]:\\\\" }
foreach ($drv in $drives) {
    $shareName = "$($drv.Name)_Drive"
    $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
    if ($existingShare) {
        Remove-SmbShare -Name $shareName -Force
    }
    try {
        New-SmbShare -Name $shareName -Path "$($drv.Root)" -FullAccess "Everyone" -Description "Full $($drv.Name): Drive Access" -ErrorAction Stop
        Write-Host "  [OK] Shared $($drv.Root) as '$shareName'" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] $shareName -> $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Step 6: Add DurgamYogi to Hosts ---
Write-Host "`n--- Step 6: Add DurgamYogi to Hosts ---" -ForegroundColor Yellow
$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsFile -Raw
if ($hostsContent -notmatch "192\.168\.1\.14") {
    Add-Content -Path $hostsFile -Value "`n192.168.1.14`tDurgamYogi"
    Write-Host "  [OK] Added: 192.168.1.14 -> DurgamYogi" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] DurgamYogi already in hosts file" -ForegroundColor Cyan
}

# --- Step 7: Enable WinRM ---
Write-Host "`n--- Step 7: Enable WinRM ---" -ForegroundColor Yellow
try {
    Enable-PSRemoting -Force -ErrorAction Stop
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.14,192.168.1.9,192.168.1.16,DurgamYogi,SHAMIIT,SHAMIITDSK" -Force
    Write-Host "  [OK] WinRM enabled" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] WinRM: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Step 8: Map DurgamYogi Drives ---
Write-Host "`n--- Step 8: Map DurgamYogi Shares ---" -ForegroundColor Yellow

# Map EduSHAMIIT project
net use Z: \\192.168.1.14\EduSHAMIIT /persistent:yes 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Z: -> \\DurgamYogi\EduSHAMIIT" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Z: drive may need credentials. Run:" -ForegroundColor Yellow
    Write-Host "         net use Z: \\192.168.1.14\EduSHAMIIT /user:DurgamYogi\nares YOUR_PASSWORD /persistent:yes" -ForegroundColor White
}

# --- Summary ---
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Client Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "`nYou can access DurgamYogi via:" -ForegroundColor White
Write-Host "  File Explorer: \\192.168.1.14 or \\DurgamYogi" -ForegroundColor White
Write-Host "  Mapped Drive: Z: -> EduSHAMIIT project" -ForegroundColor White
