<#
.SYNOPSIS
    This script audits and exports user permissions from all site collections and their subsites in a SharePoint Online tenant.

.DESCRIPTION
    The script performs the following actions:
    1. Checks if the required 'Microsoft.Online.SharePoint.PowerShell' module is installed, and installs it if missing.
    2. Prompts the user for the SharePoint Admin Center URL and connects to the service.
    3. Iterates through every site collection and all of its subsites (webs).
    4. For each site, it retrieves a list of all users and groups that have been granted permissions.
    5. Compiles the collected data, including site details and user information.
    6. Exports the complete permissions report to a CSV file on the local machine.
    7. Ensures disconnection from the SharePoint Online service, even if errors occur.

.NOTES
    Author: Alex Ivantsov
    Date:   June 10, 2025
    Version: 1.1
    Requires: PowerShell 5.1 and an internet connection.
#>

#---------------------------------------------------------------------------------------------------
#                                   USER-DEFINED VARIABLES
#---------------------------------------------------------------------------------------------------
# Define the path where the final permissions report will be saved.
# Please ensure the directory (e.g., C:\Temp) exists before running the script.
$csvFilePath = "C:\Temp\SharePoint_User_Permissions.csv"


#---------------------------------------------------------------------------------------------------
#                                           FUNCTIONS
#---------------------------------------------------------------------------------------------------

function Ensure-SharePointModule {
    <#
    .SYNOPSIS
        Checks for and installs the necessary SharePoint Online PowerShell module.
    #>
    try {
        Write-Host "Checking for the 'Microsoft.Online.SharePoint.PowerShell' module..." -ForegroundColor Yellow

        # Check if the module is available on the system.
        $module = Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell
        
        if (-not $module) {
            Write-Host "Module not found. Attempting to install from PSGallery..." -ForegroundColor Yellow
            
            # Install the module. -Force overwrites if it exists but is corrupted.
            # -AllowClobber prevents errors if cmdlets from this module conflict with existing ones.
            Install-Module Microsoft.Online.SharePoint.PowerShell -Force -AllowClobber -Scope CurrentUser
            
            Write-Host "Module 'Microsoft.Online.SharePoint.PowerShell' installed successfully." -ForegroundColor Green
        }
        else {
            Write-Host "SharePoint module is already installed." -ForegroundColor Green
        }
    }
    catch {
        # Catch any errors during the installation process.
        Write-Error "Failed to install the SharePoint module. Please install it manually and try again."
        Write-Error "Error details: $($_.Exception.Message)"
        # Stop the script if the module can't be installed, as it's a critical dependency.
        exit
    }
}

function Connect-ToSharePoint {
    <#
    .SYNOPSIS
        Prompts the user for the SharePoint Admin URL and establishes a connection.
    .OUTPUTS
        Returns the SPO connection object upon success, or $null on failure.
    #>
    Write-Host "Please provide your SharePoint Admin Center URL to connect." -ForegroundColor Yellow
    Write-Host "Example: https://yourtenant-admin.sharepoint.com" -ForegroundColor Cyan
    
    # Prompt the user to enter the URL for the SharePoint Admin site
    $adminUrl = Read-Host "Enter the URL"

    try {
        Write-Host "Connecting to SharePoint Online at '$($adminUrl)'..." -ForegroundColor Yellow
        
        # Connect to the SharePoint Online service using the provided URL.
        # This will trigger a pop-up for credentials.
        $connection = Connect-SPOService -Url $adminUrl
        
        Write-Host "Successfully connected to SharePoint Online." -ForegroundColor Green
        return $connection
    }
    catch {
        # Catch connection errors (e.g., incorrect URL, permissions issue).
        Write-Error "Failed to connect to SharePoint Online. Please check the URL and your credentials."
        Write-Error "Error details: $($_.Exception.Message)"
        return $null
    }
}

function Get-AllSitePermissions {
    <#
    .SYNOPSIS
        Gathers user and group permissions from all sites and subsites.
    .OUTPUTS
        An array of PSCustomObjects, with each object representing a single permission entry.
    #>
    # This is an efficient way to collect objects from a loop.
    # The 'foreach' loop itself becomes the source of the array.
    $permissionEntries = foreach ($siteCollection in (Get-SPOSite -Limit All)) {
        try {
            Write-Host "Processing Site Collection: $($siteCollection.Url)" -ForegroundColor Cyan
            
            # Get the root web and all recursive subsites for the current site collection.
            # Using -ErrorAction SilentlyContinue to prevent one broken subsite from stopping the whole script.
            $allWebs = Get-SPOWeb -Site $siteCollection.Url -Recurse -ErrorAction SilentlyContinue

            foreach ($web in $allWebs) {
                Write-Host "`t-> Checking Subsite: $($web.Url)"

                # Get all users and groups with explicit permissions on the current subsite (web).
                $usersAndGroups = Get-SPOUser -Site $web.Url -ErrorAction SilentlyContinue

                foreach ($principal in $usersAndGroups) {
                    # Create a custom PowerShell object to hold the permission details for this entry.
                    # This object will be added to the $permissionEntries array.
                    [PSCustomObject]@{
                        SiteCollectionUrl = $siteCollection.Url
                        SiteUrl           = $web.Url
                        SiteTitle         = $web.Title
                        PrincipalName     = $principal.DisplayName
                        PrincipalLogin    = $principal.LoginName
                        # CORRECTED: Use a PowerShell 5.1 compatible if/else statement inside a subexpression.
                        PrincipalType     = $(if ($principal.IsGroup) { "Group" } else { "User" })
                        IsSiteAdmin       = $principal.IsSiteAdmin
                    }
                }
                
                # Clean up the web object to release memory.
                $web.Dispose()
            }
        }
        catch {
            # Log an error for the specific site collection but continue with the next one.
            Write-Warning "Could not process site collection '$($siteCollection.Url)'. Error: $($_.Exception.Message)"
        }
    }
    
    return $permissionEntries
}

function Export-PermissionsToCsv {
    <#
    .SYNOPSIS
        Exports the collected permission data to a CSV file.
    .PARAMETER PermissionsData
        The array of permission objects to export.
    .PARAMETER FilePath
        The full path for the output CSV file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$PermissionsData,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        Write-Host "Exporting $($PermissionsData.Count) permission entries to CSV..." -ForegroundColor Yellow
        
        # Ensure the directory exists before trying to save the file.
        $directory = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path -Path $directory)) {
            New-Item -ItemType Directory -Path $directory | Out-Null
        }

        # Export the data array to a CSV file without type information headers.
        $PermissionsData | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host "Report successfully exported to '$($FilePath)'" -ForegroundColor Green
    }
    catch {
        # Catch errors related to file access or export process.
        Write-Error "Failed to export data to CSV file at '$($FilePath)'."
        Write-Error "Error details: $($_.Exception.Message)"
    }
}


#---------------------------------------------------------------------------------------------------
#                                         MAIN EXECUTION
#---------------------------------------------------------------------------------------------------

# Use a global variable to track connection status for the 'finally' block.
$Global:SPOConnection = $null

try {
    # Step 1: Ensure the required module is present.
    Ensure-SharePointModule
    
    # Step 2: Connect to SharePoint Online. The script will only proceed if connection is successful.
    $Global:SPOConnection = Connect-ToSharePoint
    if ($Global:SPOConnection) {
        
        # Step 3: Gather all permissions. This is the most time-consuming step.
        Write-Host "Gathering permissions from all SharePoint sites. This may take a long time..." -ForegroundColor Green
        $allPermissions = Get-AllSitePermissions
        
        # Step 4: Export the gathered data to a CSV file, if any data was found.
        if ($allPermissions -and $allPermissions.Count -gt 0) {
            Export-PermissionsToCsv -PermissionsData $allPermissions -FilePath $csvFilePath
        }
        else {
            Write-Warning "No permissions data was gathered. The report will be empty."
        }
    }
    else {
        Write-Error "Could not establish a connection to SharePoint. Script will now exit."
    }
}
catch {
    # Catch any unexpected, script-terminating errors from the main block.
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
}
finally {
    # This block will always run, whether the script succeeded or failed.
    # It ensures we disconnect the session to clean up resources.
    if ($Global:SPOConnection) {
        Write-Host "Disconnecting from SharePoint Online session." -ForegroundColor Yellow
        Disconnect-SPOService
    }
    Write-Host "Script execution finished." -ForegroundColor Green
}