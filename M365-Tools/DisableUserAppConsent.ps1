<#
.SYNOPSIS
    Checks and disables the ability for non-admin users to grant consent to applications.

.DESCRIPTION
    This script hardens a Microsoft 365 tenant by disabling user consent to applications.
    It authenticates to the Microsoft Graph API using a pre-configured Azure AD App Registration,
    retrieves the current admin consent policy, and if user consent is enabled, it prompts the
    administrator to disable it.

    This script uses REST API calls and does not require any external PowerShell modules.

    Before running:
    1. An Azure AD App Registration must be created.
    2. The App Registration must be granted the 'Directory.ReadWrite.All' API permission for Microsoft Graph (Application type).
    3. An administrator must grant consent for this permission in Azure AD.
    4. A client secret must be generated for the App Registration.
    5. The Tenant ID, Client ID, and Client Secret must be entered into the variables below.

.AUTHOR
    Alex Ivantsov

.DATE
    June 10, 2025
#>

#====================================================================================================
# SCRIPT CONFIGURATION
#
# Please configure the variables below before executing the script.
#====================================================================================================

# Enter your Azure Tenant ID.
# This can be found on the overview page of your Azure Active Directory.
$TenantID = "YOUR_TENANT_ID_HERE"

# Enter the Application (client) ID of your Azure AD App Registration.
$ClientID = "YOUR_CLIENT_ID_HERE"

# Enter the client secret for your Azure AD App Registration.
# It is recommended to use Azure Key Vault for production environments instead of plain text secrets.
$ClientSecret = "YOUR_CLIENT_SECRET_HERE"


#====================================================================================================
# FUNCTIONS
#
# Helper functions for authentication and policy management.
#====================================================================================================

Function Get-GraphApiAccessToken {
    <#
    .SYNOPSIS
        Acquires an OAuth 2.0 access token from Microsoft Entra ID.
    .DESCRIPTION
        Uses the provided tenant ID, client ID, and client secret to authenticate against the
        Microsoft identity platform and retrieve an access token for calling the Microsoft Graph API.
    .RETURNS
        [string] The access token.
    #>
    Write-Host "Requesting Access Token from Microsoft Entra ID..." -ForegroundColor Cyan

    # Define the endpoint for token acquisition.
    $TokenEndpoint = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token"

    # Construct the request body for the token request.
    $Body = @{
        client_id     = $ClientID
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    try {
        # Send the POST request to the token endpoint.
        $TokenResponse = Invoke-RestMethod -Uri $TokenEndpoint -Method Post -Body $Body -ErrorAction Stop
        Write-Host "Successfully obtained Access Token." -ForegroundColor Green
        # Return the access token from the response.
        return $TokenResponse.access_token
    }
    catch {
        # Write a detailed error message if token acquisition fails.
        Write-Error "Failed to acquire Access Token. Please check your Tenant ID, Client ID, and Client Secret."
        Write-Error "Error details: $($_.Exception.Message)"
        # Stop the script execution.
        throw
    }
}

Function Manage-UserConsentPolicy {
    <#
    .SYNOPSIS
        Checks and updates the tenant's user consent policy.
    .DESCRIPTION
        This function orchestrates the process of getting an access token, querying the Graph API
        for the current consent policy, and updating it if the administrator confirms the change.
    #>

    try {
        # Step 1: Get the access token required for API authentication.
        $AccessToken = Get-GraphApiAccessToken

        # Define the API endpoint for the admin consent request policy
        $PolicyEndpoint = "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy"

        # Create the authorization header required for all API calls.
        $Headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type"  = "application/json"
        }

        # Step 2: Get the current user consent policy.
        Write-Host "Retrieving current user consent policy..." -ForegroundColor Cyan
        $CurrentPolicy = Invoke-RestMethod -Uri $PolicyEndpoint -Method Get -Headers $Headers -ErrorAction Stop

        # Step 3: Check if user consent is currently enabled.
        # The property 'isUserConsentForAppsEnabled' controls this setting.
        if ($CurrentPolicy.isUserConsentForAppsEnabled) {
            Write-Host "POLICY STATUS: User consent to applications is currently ENABLED." -ForegroundColor Yellow

            # Prompt the administrator for confirmation before making changes.
            $Confirmation = Read-Host "Do you want to disable user consent to applications? (Y/N)"

            if ($Confirmation -eq 'Y') {
                # Step 4: Disable user consent by updating the policy.
                Write-Host "Disabling user consent. Sending update to Microsoft Graph..." -ForegroundColor Yellow

                # The body of the PATCH request specifies the new value for the setting.
                $UpdateBody = @{
                    "isUserConsentForAppsEnabled" = $false
                } | ConvertTo-Json

                # Send the PATCH request to update the policy. Note the -Method 'Patch'.
                Invoke-RestMethod -Uri $PolicyEndpoint -Method 'Patch' -Headers $Headers -Body $UpdateBody -ErrorAction Stop

                Write-Host "SUCCESS: User consent to applications has been disabled." -ForegroundColor Green
            }
            else {
                # If user declines, take no action.
                Write-Host "ACTION CANCELED: User consent policy remains enabled." -ForegroundColor Yellow
            }
        }
        else {
            # If the policy is already in the desired state, report it and exit.
            Write-Host "POLICY STATUS: User consent to applications is already DISABLED. No action needed." -ForegroundColor Green
        }
    }
    catch {
        # Handle potential API errors during the process.
        $ErrorMessage = $_.Exception.Message
        Write-Error "An unexpected error occurred: $ErrorMessage"
        # Stop the script execution.
        throw
    }
}


#====================================================================================================
# MAIN EXECUTION
#
# The main block that executes the script's logic.
#====================================================================================================

Write-Host "Starting Script: Disable User Consent to Applications" -ForegroundColor White -BackgroundColor DarkBlue

# Call the main function to perform the check and update.
Manage-UserConsentPolicy

Write-Host "`nScript execution completed." -ForegroundColor White -BackgroundColor DarkBlue