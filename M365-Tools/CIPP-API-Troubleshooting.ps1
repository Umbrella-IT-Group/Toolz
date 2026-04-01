# =============================================================================
# CIPP API Debug Script
# =============================================================================
# Purpose:  Tests connectivity and authentication against the CIPP
#           (CyberDrain Improved Partner Portal) Azure Web App API.
#           Calls the /api/ListLogs endpoint using a Bearer token and
#           outputs verbose debug info at each stage — token validation,
#           header construction, request execution, and response/error
#           inspection. Intended for troubleshooting auth or connectivity
#           issues, not for production use.
#
# Usage:    1. Paste a valid CIPP API Bearer token into $token below.
#           2. Run the script in PowerShell.
#           3. Review the color-coded debug output.
#
# Endpoint: GET /api/ListLogs
# Auth:     Bearer token (passed via Authorization header)
# =============================================================================

# 1. Setup - I replaced your token with a variable for safety.
# PASTE YOUR TOKEN BELOW inside the quotes
$token = "PASTE_YOUR_FULL_TOKEN_STRING_HERE"

$CIPPAPIUrl = "https://cippu7jai.azurewebsites.net"

# 2. Verbose Checkpoint: Verify Token Format
Write-Host "--- DEBUG: Checking Token Data ---" -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Error "Token is empty."
    return
}
Write-Host "Token length: $($token.Length)" -ForegroundColor Gray

# 3. Construct Header
# FIX: Removed '.access_token'. The variable $token IS the access token.
$AuthHeader = @{ 
    Authorization = "Bearer $token" 
}

Write-Host "--- DEBUG: Header Construction ---" -ForegroundColor Cyan
Write-Host "Target URI: $CIPPAPIUrl/api/ListLogs" -ForegroundColor Gray
# careful printing full headers in prod, but for debugging we look at the start
Write-Host "Auth Header constructed. Preview: $($AuthHeader.Authorization.Substring(0, 20))..." -ForegroundColor Gray

# 4. Execute Request with Error Trapping
Write-Host "--- DEBUG: Executing Request ---" -ForegroundColor Cyan

try {
    # Using -Verbose to force PowerShell to show handshake details
    # Storing in $response variable to inspect properties
    $response = Invoke-RestMethod -Uri "$CIPPAPIUrl/api/ListLogs" `
        -Method GET `
        -Headers $AuthHeader `
        -ContentType "application/json" `
        -Verbose `
        -ErrorAction Stop

    Write-Host "--- SUCCESS: API Responded ---" -ForegroundColor Green
    
    # 5. Output Data Analysis
    if ($null -eq $response) {
        Write-Warning "The API returned HTTP 200 OK, but the Body was empty."
    }
    else {
        Write-Host "Data received type: $($response.GetType().Name)" -ForegroundColor Gray
        Write-Host "Dumping response data..." -ForegroundColor Yellow
        $response | Format-List *
    }

}
catch {
    # 6. Verbose Error Handling
    Write-Host "--- ERROR: Request Failed ---" -ForegroundColor Red
    
    # Check if it's a web exception (HTTP 4xx/5xx)
    if ($_.Exception.Response) {
        $httpStatus = $_.Exception.Response.StatusCode.value__
        $httpDesc = $_.Exception.Response.StatusDescription
        
        Write-Host "HTTP Status Code: $httpStatus ($httpDesc)" -ForegroundColor Red
        
        # Try to read the body of the error (APIs often hide the real error message here)
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            $errorBody = $reader.ReadToEnd()
            Write-Host "API Error Body: $errorBody" -ForegroundColor Yellow
        }
    }
    else {
        # Standard PowerShell error (DNS, Network, etc)
        Write-Error $_.Exception.Message
    }
}