<#
.SYNOPSIS
    Checks if a custom login background image has been configured in the Microsoft 365 tenant branding.
    This script uses REST API calls and does not require the Microsoft.Graph PowerShell module.

.DESCRIPTION
    This script authenticates against Microsoft Graph using an Azure AD App Registration (Client ID and Secret)
    to check the organization's branding settings. It then reports whether a custom background image is set
    and displays its URL if it exists.

    Before running:
    1. An Azure AD App Registration must be created.
    2. The App Registration must be granted the 'Organization.Read.All' API permission for Microsoft Graph (Application type).
    3. An admin must grant consent for this permission in Azure AD.
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
# Helper functions for authentication and data retrieval.
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

Function Check-CustomLoginImage {
    <#
    .SYNOPSIS
        Checks the tenant's organizational branding for a custom login image.
    .DESCRIPTION
        This function orchestrates the process of getting an access token and using it to query the
        Microsoft Graph API for branding information. It then inspects the response to determine if a
        custom login image is set.
    #>

    try {
        # Step 1: Get the access token required for API authentication.
        $AccessToken = Get-GraphApiAccessToken

        # If token acquisition failed, the previous function will throw an error and this part won't run.
        Write-Host "Successfully obtained Access Token." -ForegroundColor Green

        # Step 2: Query the Microsoft Graph API for organizational branding.
        Write-Host "Checking for custom login image in tenant branding..." -ForegroundColor Cyan

        # The API endpoint for organizational branding.
        $BrandingEndpoint = "https://graph.microsoft.com/v1.0/organization/$TenantID/branding"

        # Create the authorization header required for the API call.
        $Headers = @{
            "Authorization" = "Bearer $AccessToken"
            "Content-Type"  = "application/json"
        }

        # Make the API call to get branding details.
        $Branding = Invoke-RestMethod -Uri $BrandingEndpoint -Method Get -Headers $Headers -ErrorAction Stop

        # Step 3: Analyze the response and display the result.
        if ($null -ne $Branding.backgroundImageUrl) {
            Write-Host "RESULT: A custom login image is configured for the tenant." -ForegroundColor Green
            Write-Host "Image URL: $($Branding.backgroundImageUrl)"
        }
        else {
            Write-Host "RESULT: A custom login image is NOT set for this tenant." -ForegroundColor Yellow
            Write-Host "You can configure branding in the Microsoft Entra admin center under 'User experiences'."
        }
    }
    catch {
        # Handle specific errors, such as when no branding is configured at all.
        if ($_.Exception.Response.StatusCode -eq "404") {
            Write-Host "RESULT: No custom branding has been configured for this tenant." -ForegroundColor Yellow
            Write-Host "You can configure branding in the Microsoft Entra admin center under 'User experiences'."
        }
        else {
            # Handle other potential API errors.
            $ErrorMessage = $_.Exception.Message
            Write-Error "An unexpected error occurred while checking for the login image: $ErrorMessage"
        }
    }
}


#====================================================================================================
# MAIN EXECUTION
#
# The main block that executes the script's logic.
#====================================================================================================

Write-Host "Starting Script: Check M365 Custom Login Image" -ForegroundColor White -BackgroundColor DarkBlue

# Call the main function to perform the check.
Check-CustomLoginImage

Write-Host "`nScript execution completed." -ForegroundColor White -BackgroundColor DarkBlue