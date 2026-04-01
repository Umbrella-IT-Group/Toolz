# PowerShell Environment Setup Script
# Windows equivalent of shellSetup.sh - by Alex Ivantsov @Exploitacious
# Run in an ELEVATED PowerShell window: powershell -ExecutionPolicy Bypass -File .\psSetup.ps1

# --- COLORS & FORMATTING ---
function Write-Header { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Info   { param($msg) Write-Host "[*] $msg" -ForegroundColor Blue }
function Write-Ok     { param($msg) Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn   { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err    { param($msg) Write-Host "[x] $msg" -ForegroundColor Red }

# --- ASCII ART HEADER ---
Clear-Host
Write-Host @"

    ____                        ____  __          _ __
   / __ \____ _      _____  ___/ __ \/ /___  (_) / /_
  / /_/ / __ \ | /| / / _ \/ _/ /_/ / / __ \/ / __/
 / ____/ /_/ / |/ |/ /  __/ // ____/ / /_/ / / /_
/_/    \____/|__/|__/\___/_//_/   /_/\____/_/\__/

   Created by Alex Ivantsov @Exploitacious
"@ -ForegroundColor Cyan

# --- ADMIN CHECK ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator. Winget installs may require elevation."
    Write-Warn "Tip: Re-run with: powershell -ExecutionPolicy Bypass -File .\psSetup.ps1"
}

# --- INSTALL OH MY POSH ---
Write-Header "Installing Oh My Posh"
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Write-Info "Oh My Posh already installed. Updating..."
    winget upgrade --id JanDeDobbeleer.OhMyPosh --accept-source-agreements --accept-package-agreements
} else {
    Write-Info "Installing Oh My Posh via winget..."
    winget install --id JanDeDobbeleer.OhMyPosh --accept-source-agreements --accept-package-agreements
}

# Refresh PATH for current session
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

Write-Ok "Oh My Posh ready."

# --- INSTALL FASTFETCH ---
Write-Header "Installing Fastfetch"
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    Write-Info "Fastfetch already installed."
} else {
    Write-Info "Installing Fastfetch via winget..."
    winget install --id Fastfetch-cli.Fastfetch --accept-source-agreements --accept-package-agreements
}
Write-Ok "Fastfetch ready."

# --- INSTALL POWERSHELL MODULES ---
Write-Header "Installing PowerShell Modules"

# Terminal-Icons: colored file/folder icons in directory listings
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Write-Info "Terminal-Icons already installed."
} else {
    Write-Info "Installing Terminal-Icons..."
    Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser
}

# PSReadLine update (ships with PS5 but we want the latest for prediction features)
Write-Info "Updating PSReadLine..."
Install-Module -Name PSReadLine -Repository PSGallery -Force -Scope CurrentUser -AllowPrerelease -SkipPublisherCheck -AllowClobber -ErrorAction SilentlyContinue
if (-not $?) {
    # Fallback without -AllowPrerelease for PS5 compatibility
    Install-Module -Name PSReadLine -Repository PSGallery -Force -Scope CurrentUser -SkipPublisherCheck -AllowClobber -ErrorAction SilentlyContinue
}

# z: directory jumper (like autojump/zoxide)
if (Get-Module -ListAvailable -Name z) {
    Write-Info "z (directory jumper) already installed."
} else {
    Write-Info "Installing z (directory jumper)..."
    Install-Module -Name z -Repository PSGallery -Force -Scope CurrentUser
}

Write-Ok "PowerShell modules ready."

# --- DEPLOY POWERSHELL PROFILE ---
Write-Header "Deploying PowerShell Profile"

$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) {
    Write-Info "Creating profile directory: $profileDir"
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$profileSource = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile.ps1"
if (Test-Path $profileSource) {
    if (Test-Path $PROFILE) {
        $backupPath = "$PROFILE.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Write-Warn "Backing up existing profile to: $backupPath"
        Copy-Item $PROFILE $backupPath
    }
    Copy-Item $profileSource $PROFILE -Force
    Write-Ok "Profile deployed to: $PROFILE"
} else {
    Write-Err "Profile template not found at: $profileSource"
    Write-Err "Make sure Microsoft.PowerShell_profile.ps1 is in the same folder as this script."
}

# --- SET EXECUTION POLICY ---
Write-Header "Configuring Execution Policy"
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
    Write-Info "Setting execution policy to RemoteSigned for current user..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Ok "Execution policy set to RemoteSigned."
} else {
    Write-Info "Execution policy already set to: $currentPolicy"
}

# --- SUMMARY ---
Write-Host ""
Write-Header "Setup Complete!"
Write-Host ""
Write-Ok "Installed: Oh My Posh, Fastfetch, Terminal-Icons, PSReadLine, z"
Write-Ok "Profile deployed to: $PROFILE"
Write-Host ""
Write-Info "Restart your terminal to see the changes."
Write-Info "If Oh My Posh symbols look broken, make sure Windows Terminal font is set to 'MesloLGM Nerd Font'."
Write-Host ""
