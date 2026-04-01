<#
.SYNOPSIS
    Checks and disables potentially insecure features within all Outlook Web App (OWA) mailbox policies in Exchange Online.
.DESCRIPTION
    This script connects to Exchange Online, retrieves all OWA mailbox policies, and checks the status of four specific settings:
    - LinkedIn contact synchronization (LinkedInEnabled)
    - Text messaging integration (TextMessagingEnabled)
    - Journaling (JournalEnabled)
    - Inbox rules (RulesEnabled)

    If any of these settings are enabled on a policy, the script will display the current configuration and prompt the user
    for confirmation before disabling them. This helps to harden the OWA environment by turning off features that could
    potentially be misused.

    The script is designed to run in a PowerShell 5.1 environment but requires the Exchange Online Management module
    to be installed to connect to the service. It handles connection, execution, and disconnection automatically.
.NOTES
    Author:      Alex Ivantsov
    Date:        10/06/2025
    Version:     1.0
    Requires:    PowerShell 5.1 and the Exchange Online Management PowerShell module.
                 Run this script in an elevated PowerShell session (Run as Administrator).
#>

#---------------------------------------------------------------------------------------------------------
# SCRIPT EXECUTION
#
# The main execution block that controls the script's workflow. No parameters are required to run.
#---------------------------------------------------------------------------------------------------------

# Wrap the entire script execution in a try/finally block to ensure that the connection to
# Exchange Online is always closed, even if errors occur during the script's run.
try {
    # Announce the start of the script.
    Write-Host "Starting: Check and Update Outlook Web App (OWA) Policies..." -ForegroundColor Cyan

    # Call the function to establish a connection to Exchange Online.
    # The session object is stored in a global variable for other functions to use.
    Connect-ToExchange

    # Call the function to perform the main task of checking and updating the policies.
    Set-SecureOwaPolicies
}
catch {
    # If any unhandled, script-terminating errors occur, display them in red.
    Write-Host "[ERROR] A critical error occurred: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # This block always runs, regardless of whether an error occurred.
    # It ensures the remote session to Exchange Online is properly terminated.
    Disconnect-FromExchange
}


#---------------------------------------------------------------------------------------------------------
# FUNCTIONS
#
# All operations are grouped into the functions below.
#---------------------------------------------------------------------------------------------------------

Function Connect-ToExchange {
    <#
    .SYNOPSIS
        Connects to Exchange Online using modern authentication.
    .DESCRIPTION
        This function establishes a remote PowerShell session to Exchange Online. It requires the
        ExchangeOnlineManagement module. The function will prompt the user for their credentials.
        The created session is stored in a global variable ($Global:ExoSession) for use by other functions.
    #>

    Write-Host "`n[INFO] Authenticating to Exchange Online..." -ForegroundColor Green
    Write-Host "[INFO] Please enter your credentials in the popup window." -ForegroundColor Gray

    try {
        # Check if the required module is available. If not, stop the script.
        if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
            throw "The 'ExchangeOnlineManagement' PowerShell module is not installed. Please install it by running: 'Install-Module -Name ExchangeOnlineManagement'"
        }

        # Use Connect-ExchangeOnline, which is the current standard for connecting. It handles modern auth and MFA seamlessly.
        # -ShowBanner:$false reduces the amount of text output on connection.
        Connect-ExchangeOnline -ShowBanner:$false

        Write-Host "[SUCCESS] Authenticated successfully." -ForegroundColor Green
    }
    catch {
        # If connection fails, output the error message and re-throw the exception to stop the script.
        Write-Host "[FAILURE] Failed to authenticate to Exchange Online: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

Function Set-SecureOwaPolicies {
    <#
    .SYNOPSIS
        Checks all OWA policies and disables specific features if they are enabled.
    .DESCRIPTION
        Retrieves all OWA Mailbox Policies. For each policy, it checks if LinkedIn, Text Messaging,
        Journaling, or Inbox Rules are enabled. If so, it prompts the user to disable them.
    #>
    try {
        Write-Host "`n[INFO] Retrieving all Outlook Web App (OWA) policies from the environment..." -ForegroundColor Cyan

        # Get all OwaMailboxPolicy objects from the connected Exchange Online session.
        $owaPolicies = Get-OwaMailboxPolicy

        # If no policies are found, inform the user and exit the function.
        if (-not $owaPolicies) {
            Write-Host "[WARNING] No OWA policies were found in the environment. Nothing to do." -ForegroundColor Yellow
            return
        }

        Write-Host "[INFO] Found $($owaPolicies.Count) OWA policies. Checking each one for insecure settings..." -ForegroundColor Cyan

        # Iterate through each policy that was found.
        foreach ($policy in $owaPolicies) {
            Write-Host "`n-----------------------------------------------------------------"
            Write-Host "[INFO] Checking OWA policy: $($policy.Identity)" -ForegroundColor Yellow

            # Check if any of the target settings are currently enabled.
            $isChangeNeeded = $false
            if ($policy.LinkedInEnabled -or $policy.TextMessagingEnabled -or $policy.JournalEnabled -or $policy.RulesEnabled) {
                $isChangeNeeded = $true
            }

            # Display the current status of the settings for this policy.
            Write-Host "[STATUS] LinkedIn Contact Sync : $($policy.LinkedInEnabled)"
            Write-Host "[STATUS] Text Messaging        : $($policy.TextMessagingEnabled)"
            Write-Host "[STATUS] Journaling            : $($policy.JournalEnabled)"
            Write-Host "[STATUS] Inbox Rules           : $($policy.RulesEnabled)"

            # If no changes are required, report it and move to the next policy.
            if (-not $isChangeNeeded) {
                Write-Host "`n[SUCCESS] No changes are required for policy '$($policy.Identity)'. All target settings are already disabled." -ForegroundColor Green
                continue # Skips to the next item in the foreach loop.
            }

            # If changes are needed, prompt the user for confirmation to proceed.
            Write-Host "`n[ACTION] One or more settings on policy '$($policy.Identity)' are enabled." -ForegroundColor Yellow
            $userResponse = Read-Host "Do you want to disable these settings for this policy? (Y/N)"

            # If the user confirms with 'Y' (case-insensitive).
            if ($userResponse -eq 'Y') {
                Write-Host "[INFO] Disabling insecure features for policy: $($policy.Identity)..." -ForegroundColor Yellow
                try {
                    # Execute the command to set all targeted features to $false.
                    # -ErrorAction Stop ensures that if this command fails, it will be caught by the 'catch' block.
                    Set-OwaMailboxPolicy -Identity $policy.Identity -LinkedInEnabled $false -TextMessagingEnabled $false -JournalEnabled $false -RulesEnabled $false -ErrorAction Stop

                    Write-Host "[SUCCESS] Insecure features have been disabled for policy: $($policy.Identity)." -ForegroundColor Green
                }
                catch {
                    # If the Set-OwaMailboxPolicy command fails, report the specific error.
                    Write-Host "[FAILURE] Error disabling features for policy '$($policy.Identity)': $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            else {
                # If the user enters anything other than 'Y', skip making changes.
                Write-Host "[INFO] No changes were made to policy: $($policy.Identity)."
            }
        }
    }
    catch {
        # Catch any errors that occurred during the policy retrieval or update process.
        Write-Host "[FAILURE] An error occurred while checking or updating OWA policies: $($_.Exception.Message)" -ForegroundColor Red
        throw # Re-throw the error to be caught by the main script block.
    }
}

Function Disconnect-FromExchange {
    <#
    .SYNOPSIS
        Disconnects the remote PowerShell session to Exchange Online.
    .DESCRIPTION
        This function finds any active remote sessions to Exchange Online (*.outlook.com) and closes them.
        It confirms that the session is closed before exiting.
    #>
    Write-Host "`n-----------------------------------------------------------------"
    Write-Host "[INFO] Disconnecting from Exchange Online..." -ForegroundColor Green

    # Get all active PSSessions and filter for the ones connected to Exchange Online.
    $activeSessions = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' }

    if ($activeSessions) {
        # If sessions are found, disconnect them.
        Disconnect-ExchangeOnline -Confirm:$false
        Write-Host "[SUCCESS] Disconnected successfully from Exchange Online." -ForegroundColor Green
    }
    else {
        # If no active sessions were found, inform the user.
        Write-Host "[INFO] No active Exchange Online session found to disconnect." -ForegroundColor Yellow
    }
}