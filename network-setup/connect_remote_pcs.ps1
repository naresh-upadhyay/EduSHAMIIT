# ============================================================
# Connect to Remote PCs - Map Network Drives
# Run on DurgamYogi AFTER server setup is complete
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Connect to SHAMIIT & SHAMIITDSK" -ForegroundColor Cyan  
Write-Host "============================================" -ForegroundColor Cyan

# --- Try connecting to SHAMIITDSK (192.168.1.16) ---
Write-Host "`n--- Connecting to SHAMIITDSK (192.168.1.16) ---" -ForegroundColor Yellow
Write-Host "SHAMIITDSK has file sharing active. Trying admin shares..." -ForegroundColor White

# Try with current credentials first
$shamiitdskAccess = Test-Path "\\192.168.1.16\C$" 2>$null
if ($shamiitdskAccess) {
    Write-Host "  [OK] Can access SHAMIITDSK with current credentials!" -ForegroundColor Green
    
    # Map K: drive to SHAMIITDSK C$
    $existing = Get-PSDrive -Name K -ErrorAction SilentlyContinue
    if ($existing) { Remove-PSDrive -Name K -Force }
    net use K: "\\192.168.1.16\C$" /persistent:yes 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] K: -> \\SHAMIITDSK\C$" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] Need credentials for SHAMIITDSK." -ForegroundColor Yellow
    Write-Host "  Enter credentials for SHAMIITDSK:" -ForegroundColor White
    
    $cred = Get-Credential -Message "Enter SHAMIITDSK credentials (e.g., SHAMIITDSK\nares)"
    if ($cred) {
        $user = $cred.UserName
        $pass = $cred.GetNetworkCredential().Password
        
        # Map C$ drive
        net use K: "\\192.168.1.16\C$" /user:$user $pass /persistent:yes 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] K: -> \\SHAMIITDSK\C$" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Could not map C$. Trying named shares..." -ForegroundColor Yellow
            
            # Try listing available shares
            net view \\192.168.1.16 /user:$user 2>$null
        }
    }
}

# --- Try connecting to SHAMIIT (192.168.1.9) ---
Write-Host "`n--- Connecting to SHAMIIT (192.168.1.9) ---" -ForegroundColor Yellow
Write-Host "SHAMIIT needs file sharing enabled first." -ForegroundColor White

$shamiitAccess = Test-Path "\\192.168.1.9\C$" 2>$null
if ($shamiitAccess) {
    Write-Host "  [OK] Can access SHAMIIT!" -ForegroundColor Green
    
    $existing = Get-PSDrive -Name S -ErrorAction SilentlyContinue
    if ($existing) { Remove-PSDrive -Name S -Force }
    net use S: "\\192.168.1.9\C$" /persistent:yes 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] S: -> \\SHAMIIT\C$" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] SHAMIIT file sharing is not accessible yet." -ForegroundColor Yellow
    Write-Host "  You need to run setup_client_pc.ps1 on SHAMIIT first." -ForegroundColor White
    Write-Host "  Copy the script from: \\DurgamYogi\EduSHAMIIT\network-setup\setup_client_pc.ps1" -ForegroundColor White
    
    # Try with credentials anyway
    Write-Host "`n  Trying with credentials..." -ForegroundColor Cyan
    $cred = Get-Credential -Message "Enter SHAMIIT credentials (e.g., SHAMIIT\username)"
    if ($cred) {
        $user = $cred.UserName
        $pass = $cred.GetNetworkCredential().Password
        
        net use S: "\\192.168.1.9\C$" /user:$user $pass /persistent:yes 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] S: -> \\SHAMIIT\C$" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] Cannot connect. Run setup_client_pc.ps1 on SHAMIIT." -ForegroundColor Red
        }
    }
}

# --- Summary ---
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  Connection Status" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

net use 2>$null

Write-Host "`nFile Explorer shortcuts:" -ForegroundColor White
Write-Host "  \\SHAMIIT or \\192.168.1.9" -ForegroundColor White
Write-Host "  \\SHAMIITDSK or \\192.168.1.16" -ForegroundColor White
