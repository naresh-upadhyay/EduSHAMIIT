# ============================================================
# DurgamYogi Server Setup Script
# Run this in an ELEVATED (Admin) PowerShell terminal
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DurgamYogi Server Setup - EduSHAMIIT" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check for admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[OK] Running as Administrator" -ForegroundColor Green

# --- Step 1: Enable Network Discovery Services ---
Write-Host "`n--- Step 1: Enable Network Discovery Services ---" -ForegroundColor Yellow

$services = @("FDResPub", "SSDPSRV", "upnphost", "fdPHost", "LanmanServer", "LanmanWorkstation")
foreach ($svc in $services) {
    try {
        Set-Service $svc -StartupType Automatic -ErrorAction Stop
        Start-Service $svc -ErrorAction SilentlyContinue
        Write-Host "  [OK] $svc -> Automatic + Running" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] $svc -> $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Step 2: Enable Firewall Rules ---
Write-Host "`n--- Step 2: Enable Firewall Rules ---" -ForegroundColor Yellow

$groups = @(
    "Network Discovery",
    "File And Printer Sharing",
    "Windows Remote Management"
)
foreach ($group in $groups) {
    try {
        Set-NetFirewallRule -DisplayGroup $group -Enabled True -ErrorAction Stop
        Write-Host "  [OK] Firewall: '$group' -> Enabled" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Firewall: '$group' -> $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Step 3: Set Network Profile to Private ---
Write-Host "`n--- Step 3: Set Network Profile to Private ---" -ForegroundColor Yellow
try {
    $profile = Get-NetConnectionProfile -InterfaceAlias "Wi-Fi" -ErrorAction Stop
    if ($profile.NetworkCategory -ne "Private") {
        Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
        Write-Host "  [OK] Wi-Fi set to Private" -ForegroundColor Green
    } else {
        Write-Host "  [OK] Wi-Fi already Private" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] Could not set network profile: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Step 4: Share EduSHAMIIT Project Folder ---
Write-Host "`n--- Step 4: Share EduSHAMIIT Project ---" -ForegroundColor Yellow

# Remove old share if exists
$existingShare = Get-SmbShare -Name "EduSHAMIIT" -ErrorAction SilentlyContinue
if ($existingShare) {
    Remove-SmbShare -Name "EduSHAMIIT" -Force
    Write-Host "  [INFO] Removed existing 'EduSHAMIIT' share" -ForegroundColor Cyan
}

try {
    New-SmbShare -Name "EduSHAMIIT" -Path "E:\EduSHAMIIT" -FullAccess "Everyone" -Description "EduSHAMIIT Project - Full Access" -ErrorAction Stop
    Write-Host "  [OK] Shared 'E:\EduSHAMIIT' as 'EduSHAMIIT' with Full Access" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed to create share: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Step 5: Share E: Drive ---
Write-Host "`n--- Step 5: Share E: Drive ---" -ForegroundColor Yellow

$existingShare = Get-SmbShare -Name "E_Drive" -ErrorAction SilentlyContinue
if ($existingShare) {
    Remove-SmbShare -Name "E_Drive" -Force
}
try {
    New-SmbShare -Name "E_Drive" -Path "E:\" -FullAccess "Everyone" -Description "Full E: Drive Access" -ErrorAction Stop
    Write-Host "  [OK] Shared 'E:\' as 'E_Drive' with Full Access" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Step 6: Share D: Drive ---
Write-Host "`n--- Step 6: Share D: Drive ---" -ForegroundColor Yellow

$existingShare = Get-SmbShare -Name "D_Drive" -ErrorAction SilentlyContinue
if ($existingShare) {
    Remove-SmbShare -Name "D_Drive" -Force
}
try {
    New-SmbShare -Name "D_Drive" -Path "D:\" -FullAccess "Everyone" -Description "Full D: Drive Access" -ErrorAction Stop
    Write-Host "  [OK] Shared 'D:\' as 'D_Drive' with Full Access" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed: $($_.Exception.Message)" -ForegroundColor Red
}

# --- Step 7: Add Hosts File Entries ---
Write-Host "`n--- Step 7: Add Hosts File Entries ---" -ForegroundColor Yellow

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"
$hostsContent = Get-Content $hostsFile -Raw

$entries = @{
    "192.168.1.9"  = "SHAMIIT"
    "192.168.1.16" = "SHAMIITDSK"
}

foreach ($ip in $entries.Keys) {
    $hostname = $entries[$ip]
    if ($hostsContent -notmatch [regex]::Escape($ip)) {
        Add-Content -Path $hostsFile -Value "`n$ip`t$hostname"
        Write-Host "  [OK] Added: $ip -> $hostname" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] $ip already in hosts file" -ForegroundColor Cyan
    }
}

# --- Step 8: Enable WinRM for Remote Management ---
Write-Host "`n--- Step 8: Enable WinRM ---" -ForegroundColor Yellow
try {
    Enable-PSRemoting -Force -ErrorAction Stop
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.1.9,192.168.1.16,SHAMIIT,SHAMIITDSK" -Force
    Write-Host "  [OK] WinRM enabled, trusted hosts set" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] WinRM: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Step 9: Enable Password-less File Sharing (Guest Access) ---
Write-Host "`n--- Step 9: Enable Guest Access for Shares ---" -ForegroundColor Yellow
try {
    Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force
    # Allow guest access to shares (for easy LAN access)
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    Set-ItemProperty -Path $regPath -Name "AllowInsecureGuestAuth" -Value 1 -Type DWord -Force
    Write-Host "  [OK] Guest/insecure auth enabled for LAN sharing" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Guest access: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Step 10: Set NTFS Permissions on shared folders ---
Write-Host "`n--- Step 10: Set NTFS Permissions ---" -ForegroundColor Yellow
try {
    $acl = Get-Acl "E:\EduSHAMIIT"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl "E:\EduSHAMIIT" $acl
    Write-Host "  [OK] NTFS permissions set on E:\EduSHAMIIT" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] NTFS permissions: $($_.Exception.Message)" -ForegroundColor Yellow
}

# --- Summary ---
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "`nOther PCs can now access:" -ForegroundColor White
Write-Host "  \\DurgamYogi\EduSHAMIIT  ->  E:\EduSHAMIIT" -ForegroundColor White
Write-Host "  \\DurgamYogi\E_Drive     ->  E:\" -ForegroundColor White
Write-Host "  \\DurgamYogi\D_Drive     ->  D:\" -ForegroundColor White
Write-Host "  \\192.168.1.14\EduSHAMIIT (by IP)" -ForegroundColor White
Write-Host "`nThis PC's IP: 192.168.1.14" -ForegroundColor Cyan
