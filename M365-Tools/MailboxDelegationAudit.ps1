<#
.SYNOPSIS
    This script connects to Exchange Online and retrieves a report of all non-inherited mailbox permissions,
    excluding the default 'NT AUTHORITY\SELF' user.

.DESCRIPTION
    The script first establishes a connection to Exchange Online using modern authentication.
    It then iterates through all mailboxes to gather their permissions. It filters these permissions
    to show only explicitly assigned (non-inherited) rights, providing a clean report of
    user access to mailboxes.

.NOTES
    Author: Alex Ivantsov
    Date: 06/11/2025
    PowerShell Version: 5.1
#>

#================================================================================
# User-configurable variables
#================================================================================

# No variables need to be configured for this script to run.
# The script will prompt for credentials when executed.

#================================================================================
# Functions
#================================================================================

function Connect-To-ExchangeOnline {
    <#
    .SYNOPSIS
        Connects to both the MSOnline and Exchange Online services.
    .DESCRIPTION
        This function prompts the user for their credentials and uses them to connect
        to the required Microsoft online services. It handles the creation and
        import of the remote PowerShell session for Exchange Online.
    .OUTPUTS
        A PSSession object for the Exchange Online connection.
    #>

    # Get credentials from the user
    $credential = Get-Credential

    # Connect to the MSOnline service
    Write-Host "Connecting to MSOnline Service..." -ForegroundColor Cyan
    try {
        # The MsOnline module is required for this connection.
        # This will attempt to import it if available.
        Import-Module MsOnline -ErrorAction Stop
        Connect-MsolService -Credential $credential
        Write-Host "Successfully connected to MSOnline." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to MSOnline. Please ensure the MsOnline module is installed."
        # The script will stop execution if this connection fails.
        return
    }


    # Define the connection URI for Exchange Online PowerShell
    $connectionUri = "https://outlook.office365.com/powershell-liveid/"

    # Create a new PowerShell session to Exchange Online
    Write-Host "Creating a new PowerShell session to Exchange Online..." -ForegroundColor Cyan
    $exchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $connectionUri -Credential $credential -Authentication "Basic" -AllowRedirection

    # Import the commands from the session into the current session
    Write-Host "Importing Exchange Online commands..." -ForegroundColor Cyan
    Import-PSSession $exchangeSession -DisableNameChecking

    # Return the session object so it can be disconnected later
    return $exchangeSession
}

function Get-MailboxAccessReport {
    <#
    .SYNOPSIS
        Retrieves and displays mailbox permissions.
    .DESCRIPTION
        This function gets all mailboxes and their permissions. It then filters the
        permissions to exclude default system users and inherited permissions,
        and displays the results in a formatted table.
    #>

    Write-Host "Retrieving mailbox permissions... This may take a while for a large number of mailboxes." -ForegroundColor Cyan

    # Retrieve all mailboxes and their permissions
    $mailboxPermissions = Get-Mailbox -ResultSize Unlimited | Get-MailboxPermission

    # Filter the permissions
    $filteredPermissions = $mailboxPermissions | Where-Object {
        # Exclude the default 'NT AUTHORITY\SELF' user principal
        $_.User -ne "NT AUTHORITY\SELF" -and
        # Exclude permissions that are inherited
        $_.IsInherited -eq $false
    }

    # Select the desired properties for the report
    $report = $filteredPermissions | Select-Object Identity, User, IsInherited, AccessRights

    # Display the report in a formatted table
    if ($report) {
        Write-Host "Mailbox Permission Report:" -ForegroundColor Green
        $report | Format-Table -AutoSize
    }
    else {
        Write-Host "No non-inherited mailbox permissions found." -ForegroundColor Yellow
    }
}

function Disconnect-From-ExchangeOnline {
    <#
    .SYNOPSIS
        Disconnects the remote PowerShell session.
    .DESCRIPTION
        This function takes a PSSession object and closes it, cleaning up
        the connection to Exchange Online.
    .PARAMETER Session
        The PSSession object to be disconnected.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Runspaces.PSSession]
        $Session
    )

    Write-Host "Disconnecting the Exchange Online session..." -ForegroundColor Cyan
    Remove-PSSession -Session $Session
    Write-Host "Session disconnected." -ForegroundColor Green
}

#================================================================================
# Main script execution
#================================================================================

# Establish the connection to Exchange Online
# The session object is stored to be used for disconnection later.
$session = Connect-To-ExchangeOnline

# The script will only proceed if the connection was successful.
if ($session) {
    try {
        # Run the function to get the permission report
        Get-MailboxAccessReport
    }
    finally {
        # Ensure the session is always disconnected, even if errors occur
        Disconnect-From-ExchangeOnline -Session $session
    }
}
else {
    Write-Error "Could not proceed with the script as the connection to Exchange Online failed."
}