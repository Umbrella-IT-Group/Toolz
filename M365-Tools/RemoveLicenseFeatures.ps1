<#
.SYNOPSIS
    Disables specified unused services in Microsoft 365 for all licensed users.

.DESCRIPTION
    This script identifies all licensed users within the Microsoft 365 tenant. For each user, it disables a predefined list of service plans (e.g., Sway, Yammer) across all their assigned licenses without removing the licenses themselves. This is a common hardening step to reduce the attack surface and simplify the user environment.

    This script is designed for PowerShell 5.1 and uses the MSOnline module.

.NOTES
    Author: Alex Ivantsov
    Date:   June 10, 2025
#>

#---------------------------------------------------------------------------------------------
# Script Functions
#---------------------------------------------------------------------------------------------

Function Ensure-MSOnlineModule {
    <#
    .SYNOPSIS
        Checks for the presence of the MSOnline module and installs it if missing.
    #>
    Write-Host "[INFO] Checking for the MSOnline module..." -ForegroundColor Cyan

    try {
        # Check if the module is available. If not, install it.
        if (-not (Get-Module -Name MSOnline -ListAvailable)) {
            Write-Host "[WARN] The MSOnline module is not installed. Installing now..." -ForegroundColor Yellow
            # Install the module for the current user.
            Install-Module -Name MSOnline -Scope CurrentUser -Force -AllowClobber
            Write-Host "[SUCCESS] The MSOnline module has been installed." -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] The MSOnline module is already installed." -ForegroundColor Green
        }

        # Import the module into the current session.
        Import-Module MSOnline -ErrorAction Stop
        Write-Host "[SUCCESS] The MSOnline module has been imported successfully." -ForegroundColor Green
    }
    catch {
        # Catch any errors during the installation or import process.
        Write-Host "[ERROR] A critical error occurred while ensuring the MSOnline module is available." -ForegroundColor Red
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        # Terminate the script if the module cannot be loaded.
        throw
    }
}

Function Connect-MSOnlineService {
    <#
    .SYNOPSIS
        Connects to the Microsoft Online service.
    #>
    Write-Host "[INFO] Attempting to connect to Microsoft Online Services..." -ForegroundColor Cyan

    try {
        # Check if a connection already exists to avoid re-authenticating unnecessarily.
        if (-not (Get-MsolUser -UserPrincipalName "admin" -ErrorAction SilentlyContinue)) {
            # Prompt for credentials and establish a connection.
            Connect-MsolService
            Write-Host "[SUCCESS] Successfully authenticated and connected to Microsoft Online Services." -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] An existing connection to Microsoft Online Services was found." -ForegroundColor Green
        }
    }
    catch {
        # Catch any authentication errors.
        Write-Host "[ERROR] Failed to connect to Microsoft Online Services." -ForegroundColor Red
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        # Terminate the script if the connection fails.
        throw
    }
}

Function Set-M365UserServices {
    <#
    .SYNOPSIS
        Disables a predefined list of services for all licensed users in the tenant.
    #>

    #--------------------------------------------------------------------------------------
    # ==> USER-CONFIGURABLE VARIABLES <==
    # Define the service plans that you want to disable for all users.
    # To find more service plan names, you can run:
    # (Get-MsolUser -UserPrincipalName "user@yourdomain.com").Licenses.ServiceStatus
    #--------------------------------------------------------------------------------------
    $servicesToDisable = @(
        "SWAY", # Sway
        "YAMMER_ENTERPRISE", # Yammer Enterprise
        "KAIZALA_O365_P2", # Kaizala Pro
        "STREAM_O365_E1", # Microsoft Stream for O365
        "FORMS_PLAN_E1", # Microsoft Forms
        "Deskless", # Microsoft StaffHub
        "MYANALYTICS_P2"        # Microsoft MyAnalytics / Viva Insights
    )

    Write-Host "[INFO] Starting process to disable the following services for all licensed users:" -ForegroundColor Cyan
    $servicesToDisable | ForEach-Object { Write-Host " - $_" }

    try {
        # Retrieve all users who have at least one license assigned.
        Write-Host "[INFO] Retrieving all licensed users from the tenant. This may take a moment..." -ForegroundColor Cyan
        $licensedUsers = Get-MsolUser -All | Where-Object { $_.isLicensed -eq $true }

        if (-not $licensedUsers) {
            Write-Host "[WARN] No licensed users were found in the tenant. Exiting." -ForegroundColor Yellow
            return
        }

        Write-Host "[INFO] Found $($licensedUsers.Count) licensed users. Beginning service modification process..." -ForegroundColor Green

        # Iterate through each licensed user.
        foreach ($user in $licensedUsers) {
            $userPrincipalName = $user.UserPrincipalName
            Write-Host "------------------------------------------------------------------"
            Write-Host "[PROCESS] Processing user: $userPrincipalName" -ForegroundColor Cyan

            try {
                # Get all license packages (SKUs) assigned to the current user.
                $userLicenses = $user.Licenses

                # Iterate through each license package for the user.
                foreach ($license in $userLicenses) {
                    $accountSkuId = $license.AccountSkuId
                    Write-Host "[INFO] Checking license package '$accountSkuId' for user '$userPrincipalName'."

                    # Create a new license options object. This object specifies which service plans
                    # should be disabled within a specific license package (SKU).
                    $licenseOptions = New-MsolLicenseOptions -AccountSkuId $accountSkuId -DisabledPlans $servicesToDisable

                    # Apply the license options to the user. The Set-MsolUserLicense cmdlet updates the user's
                    # license assignment with the new service plan settings.
                    Set-MsolUserLicense -UserPrincipalName $userPrincipalName -LicenseOptions $licenseOptions
                    
                    Write-Host "[SUCCESS] Applied service plan modifications for license '$accountSkuId' to user '$userPrincipalName'." -ForegroundColor Green
                }
            }
            catch {
                # This catches errors specific to a single user (e.g., license conflicts)
                # and allows the script to continue with the next user.
                Write-Host "[ERROR] Failed to modify services for user '$userPrincipalName'." -ForegroundColor Red
                Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    catch {
        # This catches script-terminating errors (e.g., failure to get the user list).
        Write-Host "[ERROR] A critical error occurred while processing users." -ForegroundColor Red
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

#---------------------------------------------------------------------------------------------
# Main Execution Block
#---------------------------------------------------------------------------------------------
Write-Host "=================================================================="
Write-Host "Microsoft 365 Service Hardening Script - Disable Unused Services"
Write-Host "=================================================================="

try {
    # Step 1: Ensure the required MSOnline module is ready.
    Ensure-MSOnlineModule

    # Step 2: Connect to the Microsoft 365 service.
    Connect-MSOnlineService

    # Step 3: Run the main function to disable the specified services.
    Set-M365UserServices
}
catch {
    # A catch block to handle any script-terminating errors from the functions.
    Write-Host "`n[FATAL] The script encountered a fatal error and could not complete." -ForegroundColor Red
}
finally {
    # This block executes regardless of whether an error occurred.
    Write-Host "------------------------------------------------------------------"
    Write-Host "[COMPLETE] Script execution has finished." -ForegroundColor Cyan
    Write-Host "=================================================================="
}