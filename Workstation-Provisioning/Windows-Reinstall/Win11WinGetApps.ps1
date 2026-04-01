# Requires Run as Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Elevation required. Please run as Administrator."
    break
}

Write-Host "Starting Winget Package Deployment..." -ForegroundColor Cyan

# Array of successfully mapped Winget IDs
$WingetApps = @(
    "7zip.7zip",
    "Git.Git",
    "Mozilla.Firefox",
    "VideoLAN.VLC",
    "NickeManarin.ScreenToGif"
    "Zoom.Zoom",
    "Logitech.OptionsPlus",
    "Adobe.Acrobat.Reader.64-bit",
    "dorssel.usbipd-win",
    "mRemoteNG.mRemoteNG",
    "Tailscale.Tailscale",
    "Microsoft.VCRedist.2010.x86",
    "Anthropic.ClaudeCode",
    "Greenshot.Greenshot",
    "MongoDB.Compass.Full",
    "Microsoft.VisualStudioCode",
    "Anthropic.Claude",
    "Microsoft.SurfaceApp",
    "Microsoft.WindowsApp",
    "Canva.Canva",
    "TradingView.TradingViewDesktop",
    "Termius.Termius",
    "Microsoft.PowerToys"
)

# Loop and install
foreach ($App in $WingetApps) {
    Write-Host "`n[i] Installing $App..." -ForegroundColor Yellow
    # -e ensures exact ID match, avoids interactive prompts if multiple names match
    winget install --id $App -e --accept-package-agreements --accept-source-agreements --silent
}

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host "WINGET DEPLOYMENT COMPLETE" -ForegroundColor Cyan
Write-Host "=================================================`n"

Write-Host "ATTENTION REQUIRED: The following applications require manual installation." -ForegroundColor Red
Write-Host "These are typically RMM agents, bespoke enterprise tools, or unmapped Store apps.`n"

# Curated list of actual missing software (OS components and PWAs removed)
$ManualInstalls = @(
    "CloudieConnect",
    "ScreenConnect Client",
    "TechIDClient",
    "Command Palette",
    "Spotify"
)

foreach ($ManualApp in $ManualInstalls) {
    Write-Host "  [ ] $ManualApp" -ForegroundColor White
}

Write-Host "`nNote: IT Glue, Planner, Autotask, ChatGPT, Gemini, and Messages were identified as Progressive Web Apps (PWAs). Reinstall these via your web browser.`n" -ForegroundColor DarkGray