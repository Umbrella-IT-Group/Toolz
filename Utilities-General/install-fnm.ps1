# install-fnm.ps1
# Installs fnm (Fast Node Manager) and configures it for PowerShell.
# Run this in an elevated or standard PowerShell session.

# Install fnm via winget
winget install Schniz.fnm

# Add fnm initialization to PowerShell profile (creates profile if it doesn't exist)
$profileLine = 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression'

if (!(Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    Write-Host "Created PowerShell profile at $PROFILE"
}

if ((Get-Content $PROFILE -Raw) -notmatch 'fnm env') {
    Add-Content -Path $PROFILE -Value "`n# fnm (Fast Node Manager)`n$profileLine"
    Write-Host "Added fnm to PowerShell profile."
} else {
    Write-Host "fnm already in PowerShell profile, skipping."
}

# Load fnm into current session
fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# Install LTS and set as default
fnm install --lts
fnm default lts-latest

Write-Host "`nDone. Node $(node --version), npm $(npm --version)"
Write-Host "Restart PowerShell for profile changes to take effect."
