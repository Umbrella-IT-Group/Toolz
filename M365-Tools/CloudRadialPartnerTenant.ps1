<#┌────────────────────────────────────────────────────────┐
  │ CLOUDRADIAL PARTNER SETUP APPLICATION                  │
  │ VERSION 2.0 - Released March 25, 2024                  │
  │ PORTIONS COPYRIGHT 2024, Azurative LLC                 │
  └────────────────────────────────────────────────────────┘#>
Function Write-Error($message) {
    Write-Host ""
    Write-Host "*************************************************************************************" -ForegroundColor Red
    Write-Host ""
    Write-Host $message -ForegroundColor Red
    Write-Host ""
    Write-Host "*************************************************************************************" -ForegroundColor Red
}
Function Write-Update($message) {
    Write-Host ""
    Write-Host ""
    Write-Host "*************************************************************************************" -ForegroundColor Green
    Write-Host $message -ForegroundColor Green
    Write-Host "*************************************************************************************" -ForegroundColor Green
}
# Check if the module is not already installed
if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph')) {
    Write-Host "Microsoft.Graph module is not installed. Preparing to install it..."
    # If not, ask for approval to install it
    $userInput = Read-Host -Prompt "Do you want to install it? (yes/no)"
    if ($userInput -eq "yes") {
        Write-Host "Installing Microsoft.Graph module..."
        # If approved, install it
        Install-Module -Name 'Microsoft.Graph' -Force -Scope CurrentUser
    }
    else {
        Write-Host "Microsoft.Graph module installation was not approved."
    }
}
else {
    Write-Host "Microsoft.Graph module is already installed."
}
Function Test-Modules {
    try {
        Write-Host "Verifying  Modules" -ForegroundColor Green
        if (Get-Module -ListAvailable -Name Microsoft.Graph) {
        } 
        else {
            #Import Module
            Import-Module Microsoft.Graph.Authentication #Install-Module -Name Microsoft.Graph.Authentication
            Import-Module Microsoft.Graph.Applications #Install-Module -Name Microsoft.Graph.Applications
            Import-Module Microsoft.Graph.Identity.DirectoryManagement #Install-Module -Name Microsoft.Graph.Identity.DirectoryManagement
        }
        return $True
    }
    catch {
        return $False
    }
}

$domain = "umbrellaitgroup.com"
$database = "umbrellaitgroup"

$permissions = @(
    @{
        Id   = "b0afded3-3588-46d8-8b3d-9842eff778da" # AuditLog.Read.All
        Type = "Role"
    },
    @{
        Id   = "798ee544-9d2d-430c-a058-570e29e34338" # Calendars.Read
        Type = "Role"
    },
    @{
        Id   = "a2611786-80b3-417e-adaa-707d4261a5f0" # CallRecord-PstnCalls.Read.All
        Type = "Role"
    },
    @{
        Id   = "45bbb07e-7321-4fd7-a8f6-3ff27e6a81c8" # CallRecords.Read.All
        Type = "Role"
    },
    @{
        Id   = "dc377aa6-52d8-4e23-b271-2a7ae04cedf3" # DeviceManagementConfiguration.Read.All
        Type = "Role"
    },
    @{
        Id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Directory.Read.All
        Type = "Role"
    },
    @{
        Id   = "dbb9058a-0e50-45d7-ae91-66909b5d4664" # Domain.Read.All
        Type = "Role"
    },    
    @{
        Id   = "230c1aed-a721-4c5d-9cb4-a90514e508ef" # Reports.Read.All
        Type = "Role"
    },
    @{
        Id   = "bf394140-e372-4bf9-a898-299cfc7564e5" # SecurityEvents.Read.All
        Type = "Role"
    },
    @{
        Id   = "79c261e0-fe76-4144-aad5-bdc68fbe4037" # ServiceHealth.Read.All
        Type = "Role"
    },
    @{
        Id   = "1b620472-6534-4fe6-9df2-4680e8aa28ec" # ServiceMessage.Read.All
        Type = "Role"
    },
    @{
        Id   = "83d4163d-a2d8-4d3b-9695-4ae3ca98f888" # SharePointTenantSettings.Read.All
        Type = "Role"
    },
    @{
        Id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
        Type = "Role"
    }
    #  The permission User.ReadWrite.All is optional in the list of permissions. 
    #  Without this permission, users will not be able to update their Office 365 details from within CloudRadial.
    #
    #  @{
    #   Id = "741f803b-c850-494e-b5df-cde7c675a1ca" # User.ReadWrite.All
    #   Type = "Role"
    #  }
)

Write-Host "┌────────────────────────────────────────────────────────┐"
Write-Host "│ CLOUDRADIAL PARTNER SETUP APPLICATION                  │"
Write-Host "│ VERSION 2.0 - Released March 25, 2024                  │"
Write-Host "│ COPYRIGHT 2024, Azurative LLC                          │"
Write-Host "└────────────────────────────────────────────────────────┘"
Write-Host ""
Write-Host "Instructions" -ForegroundColor Green
Write-Host "This script will install an application in your partner tenant that CloudRadial uses for authentication."
Write-Host "After it completes, you will be given the values to complete your CloudRadial setup."
Write-Host "If you rerun this script in the future, you will need to update your CloudRadial settings."
Write-Host "More information at https://radials.io/partnersetup"
Write-Host ""
$prompt = ""
$prompt = Read-Host -Prompt "Specify domain or press Enter for default ($domain)"
if ($prompt -ne "") {
    $domain = $prompt
    $homePage = "https://" + $domain
}

$homePage = "https://" + $domain

Write-Host ""
$success = Test-Modules

if ($success -eq $True) {
    Write-Host ""
    Write-Host "You will now be prompted for your log in. Log in as a Global Administrator for the following domain: "
    Write-Host ""
    Write-Host $domain -ForegroundColor Green
    Write-Host ""
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.Read.All" #-DeviceCode

    $adminAgentsGroup = Get-MgGroup -Filter "displayName eq 'Adminagents'"
    if ($null -eq $adminAgentsGroup) {
        Write-Error "This account is not setup as a Microsoft Partner" 
        return
    }
}
else {
    Write-Error "Rerun this script as an administrator to install the required modules." 
}

$AppName = "CloudRadial Partner Application ($database)"

# Check if the application already exists
$existingApp = Get-MgApplication -Filter "displayName eq '$AppName'" | Select-Object -First 1

if ($existingApp) {
    Write-Host "Existing Azure AD application found. Deleting it..."
    # If the application exists, delete it
    Remove-MgApplication -ApplicationId $existingApp.Id
    Write-Host "Existing Azure AD application deleted."
}

Write-Host "Creating new Azure AD application..."
# Create the application
$App = New-MgApplication -DisplayName $AppName `
    -Info @{
    "termsOfServiceUrl"   = "https://www.cloudradial.com/terms"
    "supportUrl"          = $homePage
    "privacyStatementUrl" = "https://www.cloudradial.com/privacy"
} `
    -SignInAudience AzureADMultipleOrgs `
    -Web @{
    RedirectUris = "https://login.microsoftonline.com/common/oauth2/nativeclient"
} `
    -RequiredResourceAccess @{
    ResourceAppId  = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    ResourceAccess = $permissions
}  

# Add a delay to ensure the application is created before continuing
Start-Sleep -Seconds 10

# Get the application
$App = Get-MgApplication | Where-Object { $_.DisplayName -eq $AppName }

# Check if the application was found
if ($null -eq $App) {
    Write-Error "There was a problem creating the application '$AppName'."
    return
}

# Define the password credential
$passwordCred = @{
    "displayName" = $AppName
    "endDateTime" = (Get-Date).AddMonths(+24)
}

Write-Host "Adding password to the application..."
# Add the password
$ClientSecret = Add-MgApplicationPassword -ApplicationId $App.Id -PasswordCredential $passwordCred

# Get the AppID, TenantId, and Realm
$TenantId = (Get-MgOrganization).Id
$TenantDomain = (Get-MgDomain).Id | Where-Object { $_ -like '*.onmicrosoft.com' }


Write-Host "Preparing to open browser for admin consent..."
############################################################################### 
#Grant Admin Consent - Opens URL in Browser 
############################################################################### 

$App = Get-MgApplication | Where-Object { $_.DisplayName -eq $AppName } 
$TenantID = (Get-MgOrganization).Id 
$AppId = $App.AppId 

$redirect_uri = "https://login.microsoftonline.com/common/oauth2/nativeclient"
$response_type = "code"
$response_mode = "query"
$scope = "https://graph.microsoft.com/.default"
$URL = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/authorize?client_id=$AppId&response_type=$response_type&redirect_uri=$redirect_uri&response_mode=$response_mode&scope=$scope" 

# Add a 10-second delay
Start-Sleep -Seconds 10

# Open the URL in the default browser
Invoke-Expression "start `"$URL`""

Write-Update "Opening Browser For Admin Consent"
Write-Host ""
Write-Host -Prompt "Please log in as a Global Administrator for the following domain: $domain"
Write-Host "Please close the browser window after you have finished authenticating."

Write-Host "Application created. Please copy the following values for CloudRadial Microsoft Partner setup entries:"
Write-Host ""
Write-Host ""
Write-Host "AppId:"
Write-Host $App.AppId -ForegroundColor Green
Write-Host ""
Write-Host "AppSecret:"
Write-Host $ClientSecret.SecretText -ForegroundColor Green
Write-Host ""
Write-Host "TenantId:"
Write-Host $TenantId -ForegroundColor Green
Write-Host ""
Write-Host "Realm:"
Write-Host $TenantDomain -ForegroundColor Green
Write-Host ""
Write-Host "Duration:"
Write-Host "The application secret is valid for two years. At that time, you will need to recreate and update the secret value in CloudRadial." -ForegroundColor Green
Write-Host ""
Write-Host ""
Write-Host "Be sure to grant admin consent in the browser window that just opened."
Write-Update "Application setup ran successfully."
