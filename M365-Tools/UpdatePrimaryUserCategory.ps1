<#
.SYNOPSIS
	Batch update Intune device category and/or primary user
    Batch update ownership to corporate.
	Batch update Intune device an input file or using a naming prefix ,
	or direct names via the -ComputerName, -CategoryName, and/or -UserName parameter(s).
.PARAMETER ComputerName
	Name of one or more computers
.PARAMETER IntputFile
	Path and name of .CSV input file
	CSV file must have a column named "ComputerName"
    Must have column named "UserName" if CSV is used also for primary user.
.PARAMETER SetCategory
    True/False value to determine whether the device category is being set.
.PARAMETER CategoryName
	A valid category name. If the name does not exist in the
	Intune subscription, it will return an error.
    Required is SetCategory is $True.
.PARAMETER SetPrimaryUser
    True/False value to determine whether the primary user is being set.
.PARAMETER LastLogonUser
    True/False value whether to use the last logon user as primary user.
.PARAMETER UserName
    Name of one or more users. Required if PrimaryUser is $True.
    Cannot be used with LastLogonUser
    Can be provided in .CSV
.PARAMETER ComputerPrefix
    Specify the prefix of computer names to set category
    Cannot be used with InputFile nor ComputerName
.EXAMPLE
 .\Set-UserAndCategory.ps1 -ComputerName COMPUTER-12345 -SetPrimaryUser $True -UserName jmarcum@systemcenteradmin.com -SetOwner $True -Owner Company -SetCategory $False -SetLastLoggonUser $False
 .\Set-UserAndCategory.ps1 -ComputerName COMPUTER-12345 -SetPrimaryUser $True -UserName jmarcum@systemcenteradmin.com -SetOwner $True -Owner Company
 .\Set-UserAndCategory.ps1 -ComputerName COMPUTER-12345 -LastLogonUser $True -SetCategory $True -CategoryName Accounting

.NOTES
    Requires modules AzureAD,Microsoft.Graph.Intune,Microsoft.Graph

    7.0 - 3-21-2023 - John Marcum - csv import and last logged on user tested and confirmed to work.
    9.0 - 3-22-2024 - John Marcum - Fixed bugs, added tons of logging, added ability to use Intune Device ID instead of computer name.
	10.1 - 3-25-2024  fix bugs reported by James Vincent @LinkedIn
#>

[CmdletBinding()]
param (
    [parameter(Mandatory = $False)][string]$ComputerName = "",
    [parameter(Mandatory = $False)][string]$IntuneID = "",
    [parameter(Mandatory = $False)][string]$ComputerPrefix = "",
    [parameter(Mandatory = $False)][string]$InputFile = "",
    [parameter(Mandatory = $True)][bool]$SetCategory = $False,
    [parameter(Mandatory = $False)][string]$CategoryName = "",
    [parameter(Mandatory = $True)][bool]$SetPrimaryUser = $False,
    [parameter(Mandatory = $True)][bool]$LastLogonUser = $False,    
    [parameter(Mandatory = $False)][string]$UserName = "",
    [parameter(Mandatory = $True)][bool]$SetOwner = $False,
    [parameter(Mandatory = $False)][ValidateSet("Company", "Personal")][string]$Owner = "Company"
)

######## Begin Functions ########

####################################################

# Check for required modules, install if not present
function Assert-ModuleExists([string]$ModuleName) {
    $module = Get-Module $ModuleName -ListAvailable -ErrorAction SilentlyContinue
    if (!$module) {
        Write-Host "Installing module $ModuleName ..."
        Install-Module -Name $ModuleName -Force -Scope Allusers
        Write-Host "Module installed"
    }    
}


####################################################

# Get device info from Intune
function Get-DeviceInfo {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)][string] $Computername
    )
    Get-IntuneManagedDevice -Filter "Startswith(DeviceName, '$Computername') and operatingSystem eq 'Windows'" -Top 1000 `
    | Get-MSGraphAllPages `
    | Select-Object DeviceName, UserPrincipalName, id, userId, DeviceCategoryDisplayName, ManagedDeviceOwnerType, chassisType, usersLoggedOn
}



# Get device info from Intune
function Get-DeviceInfoByID {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)][string] $managedDeviceId
    )
    Get-IntuneManagedDevice -managedDeviceId $IntuneID `
    | Select-Object DeviceName, UserPrincipalName, id, userId, DeviceCategoryDisplayName, ManagedDeviceOwnerType, chassisType, usersLoggedOn
}




####################################################

# Set the device categories
function Set-DeviceCategory {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)][string] $DeviceID,
        [parameter(Mandatory)][string] $CategoryID
    )
    Write-Host "Updating device category for $Computer"
    $requestBody = @{
        "@odata.id" = "$baseUrl/deviceManagement/deviceCategories/$CategoryID" # $CategoryName
    }
    $url = "$baseUrl/deviceManagement/managedDevices/$DeviceID/deviceCategory/`$ref"
    Write-Host "request-url: $url"
        
    $null = Invoke-MSGraphRequest -HttpMethod PUT -Url $url -Content $requestBody
    Write-Host "Device category for $Computer updated"
}
        

####################################################

# Set the device ownership
function Set-Owner {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)][string] $DeviceID,
        [parameter(Mandatory)][string] $Owner       
    )
    Write-Host "Updating owner for $Computer"

      
                
    $JSON = @"
{
ownerType:"$Owner"
}
"@

    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')"
    Invoke-MSGraphRequest -Url $uri -HttpMethod PATCH -Content $Json
}
        

####################################################

# Get Intune Primary User
function Get-IntuneDevicePrimaryUser {

    [CmdletBinding()]
    param (
        [parameter(Mandatory)][string] $DeviceID   
    )

     
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

    try {
        
        $primaryUser = Invoke-MSGraphRequest -Url $uri -HTTPMethod Get

        return $primaryUser.value."id"
        
    }
    catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEND();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        throw "Get-IntuneDevicePrimaryUser error"
    }
        
}


####################################################

# Set the Intune primary user
function Set-IntuneDevicePrimaryUser {
    [cmdletbinding()]
    param

    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DeviceId,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $userId
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices('$DeviceId')/users/`$ref"     

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    $userUri = "https://graph.microsoft.com/$graphApiVersion/users/" + $userId
        

    $JSON = @"

{"@odata.id":"$userUri"}

"@
     

    Invoke-MSGraphRequest -HttpMethod POST -Url $uri -Content $JSON  
}


####################################################

# Set the primary user of the device to the last logged on user if it they are not already the same user
function Set-LastLogon {    

        
    #Check if there is a Primary user set on the device already
    $IntuneDevicePrimaryUser = Get-IntuneDevicePrimaryUser -deviceId $DeviceID
    if (!($IntuneDevicePrimaryUser)) {
        Write-Host "No Intune Primary User Id set for Intune Managed Device" $Device.deviceName
    }
    else {
        #  A primary user is there already. Find out who it is. 
        $PrimaryAADUser = Get-AzureADUser -ObjectId $IntuneDevicePrimaryUser
        Write-Host $Device.deviceName "Device has a primary user. Current primary user:" $PrimaryAADUser.displayName
    }
   
    # Using the objectID of the last logged on user, get the user info from Microsoft Graph for logging purposes
    $LastLoggedOnAdUser = Get-AzureADUser -ObjectId $LastLoggedOnUser
    Write-Host "Matched the last logged on user id:" $LastLoggedOnUser "to the AAD user info:" $LastLoggedOnAdUser.Objectid 
    Write-Host "Last logged on user name is:"  $LastLoggedOnAdUser.UserPrincipalName

    #Check if the current primary user of the device is the same as the last logged in user
    if ($IntuneDevicePrimaryUser -ne $LastLoggedOnUser) {
        #If the user does not match, then set the last logged in user as the new Primary User
        Write-Host $Device.deviceName "Device has a primary user but not the last logged on user. Current primary user:" $PrimaryAADUser.displayName "Last logged on user:"  $LastLoggedOnAdUser.displayName
        Set-IntuneDevicePrimaryUser -DeviceId $DeviceID -userId $LastLoggedOnUser

        # Get the primary user to see if that worked.
        $Result = Get-IntuneDevicePrimaryUser -deviceId $DeviceID
        if ($Result -eq $LastLoggedOnUser) {
            Write-Host "User" $LastLoggedOnAdUser.displayName "successfully set as primary user for device" $Device.deviceName
        }
        else {
            #If the result does not match the expecation something did not work right
            Write-Host "Failed to set as Primary User for device" $Device.deviceName
        
        }
    }
    else {
        write-host "Last logged on uer:" $LastLoggedOnAdUser.displayName "and the primary user:" $PrimaryAADUser.displayName "already match."  "Nothing to do on:" $Device.deviceName
    }

}

####################################################

######## *** END *** Functions ########


######## Script Entry Point ########

$Today = Get-Date -Format "MM-dd-yyyy-HH-mm"


# Create the temp folder if it doesn't exist
if (-not (Test-Path 'C:\Temp')) {
    New-Item -Path 'C:\Temp' -ItemType Directory
}

# Start logging
$LogPath = "C:\Temp\Set_Primary_User" + $Today + ".Log"
Start-Transcript $LogPath
Write-Host "Script started at $Today"






# Install required modules
if ($SetPrimaryUser) {
    Assert-ModuleExists -ModuleName "AzureAD"
}
Assert-ModuleExists -ModuleName "Microsoft.Graph.Intune"
Assert-ModuleExists -ModuleName "MSGraph"

# Import modules
if ($SetPrimaryUser) {
    Import-Module "AzureAD"
}
Import-Module "Microsoft.Graph.Intune"
Import-Module "MSGraph"

# Connect to Azure to get user ID's
if ($SetPrimaryUser) {
    Write-Host "connecting to: azure ad"
    if (!($azconn)) { 
        $azconn = Connect-AzureAD
        Write-Host "connected to $azconn.TenantDomain"
    }
}

# Connect to Graph API
Write-Host "connecting to: msgraph"
[string]$baseUrl = "https://graph.microsoft.com/beta"
if (!($GraphCon)) {
    $GraphCon = Connect-MSGraph -NoWelcome
}
Update-MSGraphEnvironment -SchemaVersion beta



# Get the computers that we want to work on
if (($ComputerPrefix) -and ($InputFile)) {
    $Msg = @'
Prefix And InputFile Cannot
    Used Together!
        EXITING!
'@
    [System.Windows.MessageBox]::Show($Msg, 'Error!', 'Ok', 'Error')
    # Exit 1
}

if ([string]::IsNullOrEmpty($ComputerName)) {
    if ($InputFile) {
        Write-Host "computername was not provided, checking intputfile parameter"
        if (-not(Test-Path $InputFile)) {
            throw "file not found: $InputFile"
        }
        else {
            if ($InputFile.ENDsWith(".csv")) {
                [array]$computers = Import-Csv -Path $InputFile | Select-Object ComputerName, UserName, IntuneID
                Write-Host "Found $($Computers.Count) devices in file"             

            }
            else {
                throw "Only .csv files are supported"
            }
        }
    } 
    if ($ComputerPrefix) {
        Write-Host "Getting computers with the prefix from Intune"
        # Confirm that you really want to run against all computers!
        $Msg = @'
Seleting all devices with prefix!
ARE YOU SURE YOU WANT TO DO THIS?
THIS HAS POTENTIAL TO DO DAMAGE! 
'@
        $Result = [System.Windows.MessageBox]::Show($Msg, 'CAUTION!', 'YesNo', 'Warning')
        Write-Host "Your choice is $Result"
        if ($Result -eq 'No') {
            throw 'Exiting to prevent a disater!'
            Exit 1
        }
        $Computers = Get-MgDeviceManagementManagedDevice -Filter "Startswith(DeviceName, '$ComputerPrefix') and operatingSystem eq 'Windows'" -Top 1000 | Get-MSGraphAllPages | Select-Object DeviceName, UserPrincipalName, id, userId, DeviceCategoryDisplayName, ManagedDeviceOwnerType
        Write-Host "Found $($Computers.Count) devices in Intune"
   
    }
}
else {
    Write-Host "computer name was provided via command line"
    $Computers = $ComputerName -split ','
}


# Set Device Category
if ($SetCategory) {
    # Get the categories from Intune so we have the ID
    Write-Host "Getting List of Categories from Intune"
    $Categories = Get-DeviceManagement_DeviceCategories
    $CatNames = $Categories.DisplayName
    Write-host "Found $($Categories.Count) Categories in Intune"  
        
    if ($CategoryName) {
        # Validate category name is valid        
        Write-Host "validating requested category: $CategoryName"
        $Category = $Categories | Where-Object { $_.displayName -eq $CategoryName }
        if (!($Category)) { 
            Write-Warning  "Category name $CategoryName not valid" 
        }
        $CategoryID = $Category.id
        Write-Host "$CategoryName is $CategoryID"
    }
    else {
        Write-Warning  "No category name specified"
       
    } 

    # Set the device categories
    foreach ($Computer in $Computers) {
        Write-host "** BEGIN **- settting category for next device" 
        if ($InputFile) {
            $ComputerName = $Computer.ComputerName
            $IntuneID = $Computer.IntuneID
        }         
          
                  
        If ($ComputerName) {
            Write-host "** BEGIN ** - settting category for $ComputerName" 
            $Device = Get-DeviceInfo -ComputerName $ComputerName

            Write-Host "Found $ComputerName in Intune"
            if (!($device)) {
                Write-Warning "$ComputerName not found in Intune."
            }
            else {
                $DeviceID = $Device.id
                if ($Device.deviceCategoryDisplayName -ne $CategoryName) {
                    Write-Progress -Status "Updating Device Category" -Activity "$computer ($deviceId) --> $($device.deviceCategoryDisplayName)"
                    Write-Host "Device Name = $Computer"
                    Write-Host "Device ID = $DeviceID"
                    Write-Host "Current category is $($Device.deviceCategoryDisplayName)"
                    Write-Host "Setting category to $CategoryName"
                    Set-DeviceCategory -DeviceID $DeviceID -category $CategoryID
                    Write-host "*** END ***- settting category for $ComputerName" 
                }
                else {
                    write-host "$Computer is already in $CategoryName"
                    Write-host "*** END ***- settting category for $ComputerName" 
                }
            }
        }              
        
        If (!($ComputerName)) {     
            If ($IntuneID) {
                Write-host "** BEGIN ** - settting category for $IntuneID" 
                $Device = Get-DeviceInfoByID -managedDeviceId $IntuneID
                Write-Host "Found $IntuneID in Intune"
                if (!($device)) {
                    Write-Warning "$IntuneID not found in Intune."
                }
                else {
                    $DeviceID = $Device.id
                    $DeviceName = $Device.deviceName
                    if ($Device.deviceCategoryDisplayName -ne $CategoryName) {
                        Write-Progress -Status "Updating Device Category" -Activity "$DeviceName ($deviceId)"
                        Write-Host "Device Name = $DeviceName"
                        Write-Host "Device ID = $DeviceID"
                        Write-Host "Current category is $($Device.deviceCategoryDisplayName)"
                        Write-Host "Setting category to $CategoryName"
                        Set-DeviceCategory -DeviceID $DeviceID -category $CategoryID
                        Write-host "*** END *** - settting category for $DeviceID" 
                    }
                    else {
                        write-host "$DeviceName is already in $CategoryName"
                        Write-host "*** END *** - settting category for $DeviceID" 
                    }
                }
            }
        }
    


    }
}


# Set Device Ownership
if ($SetOwner) {
    foreach ($Computer in $Computers) {
        Write-host "** BEGIN **- settting owner for next device" 
        if ($InputFile) {
            $ComputerName = $Computer.ComputerName
            $IntuneID = $Computer.IntuneID
        }   

                          
        If ($ComputerName) {
            Write-host "** BEGIN ** - settting owner for $ComputerName" 
            $Device = Get-DeviceInfo -ComputerName $ComputerName
            if ($Device) {
                Write-Host "Found $ComputerName in Intune"
                if ($Device.ManagedDeviceOwnerType -ne $Owner) {
                    $DeviceID = $Device.id
                    Write-Progress -Status "Updating Device Owner" -Activity "$computer ($deviceId) --> $($device.ManagedDeviceOwnerType)"
                    Write-Host "Device Name = $Computer"
                    Write-Host "Device ID = $DeviceID"
                    Write-Host "Current ownership is $($Device.ManagedDeviceOwnerType)"
                    Write-Host "Setting ownership to $Owner"
                    Set-Owner -DeviceID $DeviceID -owner $Owner
                    Write-host "*** END *** - settting owner for $ComputerName" 
                }                
                else {
                    write-host $Device.DeviceName "is already set to $Owner"
                    Write-host "*** END *** - settting owner for$ComputerName" 
                }
            }       

            else {
                Write-Warning "$ComputerName not found in Intune."
                Write-host "*** END *** - settting owner for $ComputerName" 
            }
        }

        If (!($ComputerName)) {     
            If ($IntuneID) {
                Write-host "*** END *** - settting owner for $DeviceID" 
                $Device = Get-DeviceInfoByID -managedDeviceId $IntuneID
                Write-Host "Found $IntuneID in Intune"
                if ($device) {
                    $DeviceID = $Device.id
                    $DeviceName = $Device.deviceName
                    Write-Host "Current ownership is $($Device.ManagedDeviceOwnerType)"
                    if ($Device.ManagedDeviceOwnerType -ne $Owner) {
                        Write-Progress -Status "Updating Device Owner" -Activity "$computer ($deviceId) --> $($device.ManagedDeviceOwnerType)"
                        Write-Host "Device Name = $Computer"
                        Write-Host "Device ID = $DeviceID"                        
                        Write-Host "Setting ownership to $Owner"
                        Set-Owner -DeviceID $DeviceID -owner $Owner
                        Write-host "*** END *** - settting owner for $DeviceID" 
                    }   
                    else {
                        write-host $Device.DeviceName "is already set to $Owner"
                        Write-host "*** END *** - settting owner for $DeviceID" 
                    }             
                }

                else {
                    Write-Warning "$IntuneID not found in Intune."
                    Write-host "*** END *** - settting owner for $DeviceID" 
                }    
            }
        }
    }
}

# Set Primary User
if ($SetPrimaryUser) {    
    Write-Host "Setting primary user on devices."    
    if ([string]::IsNullOrEmpty($UserName)) {
        # This will not run if there is a username in the csv or on the command line!
        if ($LastLogonUser) {
            # Last logged on user variable is true. No matter how we got a list of computers to work on we are using last logged on user to set primary user!
            Write-Host "Setting primary user on devices based on the last logged on user."

            foreach ($computer in $computers) {
                Write-host "** BEGIN ** settting user for next device:" $computer.ComputerName $Computer.IntuneID 
                if ($InputFile) {
                    $ComputerName = $Computer.ComputerName
                    $IntuneID = $Computer.IntuneID
                }  
                If ($ComputerName) {
                    Write-host "** BEGIN ** - settting user for next $ComputerName"
                    # If we get here the computer name was specified somewhere. Might be in the csv, or might be somewhere else. 
                    $Device = Get-DeviceInfo -ComputerName $ComputerName
                    if ($Device) {
                        # Found the computer in Intune!
                        Write-Host "Found $ComputerName in Intune"
                        $Name = $Device.deviceName
                        Write-Host "Found $Name in Intune"
                        # Make sure we have a last logged on user
                        $LastLoggedOnUser = ($Device.usersLoggedOn[-1]).userId
              
                        if ($LastLoggedOnUser) {
                            #We have a last logged on user!
                            Write-Host "Found last logged on user: $LastLoggedOnUser"
                            # Go run the function to set the primary user if it needs to be set.
                            Write-host "Checking to see if primary user match last logged on user. If not we will set:" $Name "to" $LastLoggedOnUser
                            $DeviceID = $Device.id                                              
                            Set-LastLogon   
                            Write-host "*** END *** - settting user for next $ComputerName"
                                                
                        }
                        else {
                            write-host "We can't find the last logged on user. Cannot work on this device!"
                            Write-host "*** END *** - settting user for next $ComputerName"
                        }
                    }   
                             
                    else {
                        Write-Warning "Not found in Intune."
                        Write-host "*** END *** - settting user for next $ComputerName"
                    }    
                }              
                         
                
                If (!($ComputerName)) {  
                    # If we get here the computer name was not specified. Probably using the Intune device ID from the csv.    
                    If ($IntuneID) {
                        Write-host "** BEGIN ** - settting user for next device" $IntuneID
                        $Device = Get-DeviceInfoByID -managedDeviceId $IntuneID
                        Write-Host "Found $IntuneID in Intune"
                        if ($device) {
                            # Found the computer in Intune!
                            $DeviceID = $Device.id
                            $DeviceName = $Device.deviceName 
                            $Name = $Device.deviceName                         
                            Write-Host "Found $DeviceName Intune"                          
                            
                            # Make sure we have a last logged on user
                            $LastLoggedOnUser = ($Device.usersLoggedOn[-1]).userId              
                            if ($LastLoggedOnUser) {
                                #We have a last logged on user!
                                Write-Host "Found last logged on user: $LastLoggedOnUser"
                                # Go run the function to set the primary user if it needs to be set.
                                Write-host "Checking to see if primary user match last logged on user. If not we will set:" $DeviceName "to" $LastLoggedOnUser                                            
                                Set-LastLogon
                                Write-host "*** END *** - settting user for device!"  $IntuneID                    
                            }
                            else {
                                write-host "We can't find the last logged on user. Cannot work on this device!"
                                Write-host "*** END *** - settting user for device"  $IntuneID 
                            }

                        }
                        else {
                            Write-Warning "$IntuneID Not found in Intune" 
                            Write-host "*** END *** - settting user for device"  $IntuneID 
                        } 


                    }
                }
            }
        }
                
    }
    if (!($LastLogonUser)) {
        # The last logged on user varilable is not set to true. Let's check the input file for device/user pairs and set the user that way. 
        if ($Inputfile) {
                               
            foreach ($Row in $computers) {
                $Computer = $Row.ComputerName
                $User = $Row.UserName
                $Device = Get-DeviceInfo -Computername $Computer
                Write-Host "Found $Device in Intune"
                $Userid = Get-AzureADUser -Filter "userPrincipalName eq '$User'" | Select -ExpandProperty ObjectId
                Write-Host "Found $User $Userid"
                if (!($device -and $Userid)) {
                    Write-Warning "$Computer and/or $UserName not found"
                }
                else {
                    $DeviceID = $Device.id
                    $CurrentUser = Get-IntuneDevicePrimaryUser -DeviceId $deviceID
                    if ($CurrentUser -ne $Userid) {
                        Set-IntuneDevicePrimaryUser -DeviceId $deviceID -userId $userID 
                    }
                    else {
                        Write-Host "No change in user is needed"
                    }
                }
            }
        }

        else {
            foreach ($computer in $computers) {
                write-host "UserName was specified on the command line"
                $Device = Get-DeviceInfo -Computername $Computer
                Write-Host "Found $($Device.Count) devices in Intune"
                $Userid = Get-AzureADUser -Filter "userPrincipalName eq '$Username'" | Select -ExpandProperty ObjectId
                Write-Host "Found $User $Userid"
                if (!($device -and $Userid)) {
                    Write-Warning "$Computer and/or $UserName not found"
                }
                else {
                    $DeviceID = $Device.id
                    $CurrentUser = Get-IntuneDevicePrimaryUser -DeviceId $deviceID
                    if ($CurrentUser -ne $Userid) {
                        Set-IntuneDevicePrimaryUser -DeviceId $deviceID -userId $userID
                    }
                    else {
                        Write-Host "No change in user is needed"
                    }
                }
            }
        }
    }
}


$Now = Get-Date -Format "MM-dd-yyyy-HH-mm"
Write-Host "Work completed at $Now"
Write-host "All Done. Enjoy The rest of your day!"
Stop-Transcript