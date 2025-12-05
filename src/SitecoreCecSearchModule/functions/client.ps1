New-Variable -Name ClientDefaultProperties -Scope Global -Force -Value @{
    UserAgent = "SitecoreCecSearchModule"
    #Verbose              = $true
    #Proxy                = "http://127.0.0.1:8080"
    #SkipCertificateCheck = $true
}

New-Variable -Name LogDetails -Scope Global -Force -Value @{
    LogRequest  = $false
    LogResponse = $false
}

function Set-CecClientDefaultProperties {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Scope = 'Function')]
    param(
        [hashtable] $Value
    )

    Set-Variable -Scope Global -Name ClientDefaultProperties -Value $Value | Out-Null
}

function Set-CecClientLogDetails {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Scope = 'Function')]
    param(
        [Switch]$LogRequest,
        [Switch]$LogResponse
    )

    Set-Variable -Scope Global -Name LogDetails -Value @{
        LogRequest  = $LogRequest.IsPresent
        LogResponse = $LogResponse.IsPresent
    } | Out-Null
}

function Set-CecRefreshToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        $RefreshToken
    )
    Set-Variable -Name "CecRefreshToken" -Value $RefreshToken -Scope Script
}


function Get-CecRefreshToken {
    $tokenVar = Get-Variable -Name "CecRefreshToken"
    $token = $tokenVar.Value
    $token
}

function Invoke-RefreshAccessToken {
    $token = Get-CecRefreshToken
    New-CecAccessToken -RefreshToken $token | Out-Null
}

function New-CecAccessToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        $RefreshToken
    )

    $defaultRequestArguments = (Get-Variable -Scope Global -Name ClientDefaultProperties).Variable
    $url = "https://discover.sitecorecloud.io/account/1/access-token"

    $response = Invoke-RestMethod -Method PUT -Uri $url -Headers @{ Authorization = "Bearer ${RefreshToken}" } -ContentType application/json @defaultRequestArguments
    $accessToken = $response.accessToken
    Set-CecAccessToken -AccessToken $accessToken
    $accessToken
}

function Set-CecAccessToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        $AccessToken
    )

    Set-Variable -Name "CecAccessToken" -Value $AccessToken -Scope Script
}

function Invoke-CecGlobalMethod {
    param(
        [string]$BaseUrl = "https://discover.sitecorecloud.io",
        [string]$Path = "/account/1/user/domains",
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = "Get",
        [object]$Body
    )

    $defaultRequestArguments = (Get-Variable -Scope Global -Name ClientDefaultProperties).Value
    $tokenVar = Get-Variable -Name "CecAccessToken"
    $token = $tokenVar.Value

    $params = @{
        Uri         = "${BaseUrl}${Path}"
        Method      = $Method
        Headers     = @{ Authorization = "Bearer ${token}" }
        ContentType = "application/json"
    }
    
    Write-Verbose "Invoking global method ${Path}"
    Invoke-RestMethod @params @defaultRequestArguments -Body:$Body
}

function Set-CecDomainContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        $Id
    )

    process {
        Set-Variable -Name "CecDomainContext" -Value $Id -Scope Script
    }
}

function Get-CecDomainContext {
    (Get-Variable -Name "CecDomainContext").Value
}

function Invoke-CecDomainMethod {
    param(
        [string]$Path = "/microservices/common-editor/connectors",
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = "Get",
        [object]$Body,
        [string]$DomainScope = "portal",
        [string]$Version = "v1",
        [string]$BaseUrl = "https://discover.sitecorecloud.io",
        [string]$FullPath = $Null
    )

    $token = (Get-Variable -Name "CecAccessToken").Value
    $domain = (Get-Variable -Name "CecDomainContext").Value
    $defaultRequestArguments = (Get-Variable -Scope Global -Name ClientDefaultProperties).Value

    if ($Null -eq $token) { Write-Error "Missing required login, please run Invoke-CecLogin"; throw; }
    if ($Null -eq $domain) { Write-Error "Missing required domain context, please set context with Set-CecDomainContext"; throw; }

    if ("${FullPath}" -ne "") {
        $fullUrl = "${BaseUrl}/${FullPath}"
    }
    else {
        $fullUrl = "${BaseUrl}/${DomainScope}/{domain}/${Version}"
    }

    $url = "${fullUrl}${Path}".Replace("{domain}", $domain)
    $params = @{
        Uri         = $url
        Method      = $Method
        Headers     = @{ Authorization = "Bearer ${token}" }
        ContentType = "application/json"
    }
    if ($Null -ne $Body) {
        $params.Body = $Body | ConvertTo-Json -Depth 15
    }
    $logDetails = (Get-Variable -Name "LogDetails").Value
    if ($logDetails.LogRequest) {
        $params | ConvertTo-Json -Depth 50 | Write-Host
    }

    try {
        Write-Verbose "Invoking CEC Domain method ${Path} at ${url} with ${Method} method"
        $response = Invoke-RestMethod @params @defaultRequestArguments -ErrorAction SilentlyContinue

        if ($logDetails.LogResponse) {
            $response | ConvertTo-Json -Depth 50 | Write-Host
        }

        return $response
    }
    catch {
        if ($Null -ne $_.Exception -and $_.Exception.PSObject.Properties.Name.Contains("Response")) {
            try {
                $response = $_.Exception.Response
                $errorContent = $response.Content
                $errorDetails = $errorContent.ReadAsStringAsync()
                $errorObj = $errorDetails | ConvertFrom-Json
                $errMessage = $errorObj.message
                $errCode = $errorObj.code
            }
            catch {
                $errMessage = ""
                $errCode = ""
            }

            Write-Error ("Error during {1} request to {0} gave status {2} error was: {3} ({4})" -f $params.Uri, $params.Method, $response.StatusCode, $errMessage, $errCode)
        }
        else {
            Write-Error ("Error during {1} request to {0} was: {2}" -f $params.Uri, $params.Method, $_.Exception.Message)
        }
    }
}
