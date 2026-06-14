# ============================================================
# Docker Swarm Load Distribution Setup
# Run on DurgamYogi (Manager Node) in ELEVATED PowerShell
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Docker Swarm - Load Distribution Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "`n[ERROR] Run as Administrator!" -ForegroundColor Red
    exit 1
}

# --- Step 1: Check Docker ---
Write-Host "`n--- Step 1: Check Docker ---" -ForegroundColor Yellow
$dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
if ($dockerVersion) {
    Write-Host "  [OK] Docker version: $dockerVersion" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Docker is not running! Start Docker Desktop first." -ForegroundColor Red
    exit 1
}

# --- Step 2: Open Swarm Firewall Ports ---
Write-Host "`n--- Step 2: Open Swarm Firewall Ports ---" -ForegroundColor Yellow

$swarmPorts = @(
    @{ Name = "Docker Swarm Mgmt"; Port = 2377; Protocol = "TCP" },
    @{ Name = "Docker Swarm Nodes TCP"; Port = 7946; Protocol = "TCP" },
    @{ Name = "Docker Swarm Nodes UDP"; Port = 7946; Protocol = "UDP" },
    @{ Name = "Docker Overlay Network"; Port = 4789; Protocol = "UDP" }
)

foreach ($p in $swarmPorts) {
    $existing = Get-NetFirewallRule -DisplayName $p.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -DisplayName $p.Name -Direction Inbound -Protocol $p.Protocol -LocalPort $p.Port -Action Allow -Profile Private -ErrorAction SilentlyContinue
        Write-Host "  [OK] Firewall: $($p.Name) ($($p.Protocol)/$($p.Port))" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] $($p.Name) already exists" -ForegroundColor Cyan
    }
}

# --- Step 3: Initialize Swarm ---
Write-Host "`n--- Step 3: Initialize Docker Swarm ---" -ForegroundColor Yellow

$swarmInfo = docker info --format '{{.Swarm.LocalNodeState}}' 2>$null
if ($swarmInfo -eq "active") {
    Write-Host "  [OK] Swarm already active!" -ForegroundColor Green
    $joinToken = docker swarm join-token worker -q 2>$null
} else {
    Write-Host "  Initializing swarm on 192.168.1.14..." -ForegroundColor White
    docker swarm init --advertise-addr 192.168.1.14 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Swarm initialized!" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Swarm init failed!" -ForegroundColor Red
    }
    $joinToken = docker swarm join-token worker -q 2>$null
}

# --- Step 4: Generate Join Commands ---
Write-Host "`n--- Step 4: Worker Join Commands ---" -ForegroundColor Yellow
Write-Host "`nRun this on SHAMIIT (192.168.1.9):" -ForegroundColor Cyan
Write-Host "  docker swarm join --token $joinToken 192.168.1.14:2377" -ForegroundColor White

Write-Host "`nRun this on SHAMIITDSK (192.168.1.16):" -ForegroundColor Cyan
Write-Host "  docker swarm join --token $joinToken 192.168.1.14:2377" -ForegroundColor White

# Save join command to file for easy copy
$joinCmd = "docker swarm join --token $joinToken 192.168.1.14:2377"
$joinCmd | Out-File -FilePath "E:\EduSHAMIIT\network-setup\swarm_join_command.txt" -Force
Write-Host "`n  [OK] Join command saved to: E:\EduSHAMIIT\network-setup\swarm_join_command.txt" -ForegroundColor Green

# --- Step 5: Label Nodes (after workers join) ---
Write-Host "`n--- Step 5: After workers join, label them ---" -ForegroundColor Yellow
Write-Host @"

Run these commands AFTER the other PCs join:

  docker node update --label-add role=manager DurgamYogi
  docker node update --label-add role=worker-1 SHAMIIT
  docker node update --label-add role=worker-2 SHAMIITDSK

Then deploy the stack:
  docker stack deploy -c E:\EduSHAMIIT\docker-compose-swarm.yml edushamiit

"@ -ForegroundColor White

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Swarm Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
