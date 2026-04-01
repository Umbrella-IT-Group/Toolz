$UninstallKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

Write-Host "Querying registry for Edge Web Apps..." -ForegroundColor Cyan

Get-ItemProperty -Path $UninstallKey -ErrorAction SilentlyContinue | 
Where-Object { $_.UninstallString -match "msedge\.exe" -and $_.UninstallString -match "--app-id" } | 
Select-Object DisplayName, 
@{Name = "AppID"; Expression = { if ($_.UninstallString -match "--app-id=(?<id>[a-z]+)") { $Matches['id'] } } } |
Format-Table -AutoSize