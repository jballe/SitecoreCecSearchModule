function Invoke-CecLogin {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
    param(
        [String] $Email,
        [String] $Password
    )
    Invoke-CecPasswordAuthentication -Email $Email -Password $Password
    Invoke-RefreshAccessToken
}

function Invoke-CecPasswordAuthentication {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
    param(
        $Email,
        [String] $Password
    )
    $url = "https://discover.sitecorecloud.io/account/1/authenticate/password/cec"
    $body = @{
        email    = $Email
        password = $Password
        scope    = @("portal", "search-rec", "admin", "internal", "util", "discover", "event", "ingestion")
        target   = "https://cec.sitecorecloud.io"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $url -ContentType application/json -Method POST -Body $body
    $redirectUrl = $response.redirectUrl
    $result = $redirectUrl -match "https://cec.sitecorecloud.io#refresh_token=([^&]+)$"
    if ($result -eq $false -or $Matches.Count -lt 2) {
        Write-Error $response
        Write-Error "Could not login"
    }

    $refreshToken = $Matches[1]
    Set-CecRefreshToken -RefreshToken $refreshToken
    Write-Information "Successfully authenticated"
}

function Set-CecRefreshToken {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function')]
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function')]
    param(
        $RefreshToken
    )

    $url = "https://discover.sitecorecloud.io/account/1/access-token"
    $response = Invoke-RestMethod -Method PUT -Uri $url -Headers @{ Authorization = "Bearer ${RefreshToken}" } -ContentType application/json
    $accessToken = $response.accessToken
    Set-Variable -Name "CecAccessToken" -Value $accessToken -Scope Script
    $accessToken
}

function Invoke-CecGlobalMethod {
    param(
        [string]$BaseUrl = "https://discover.sitecorecloud.io",
        [string]$Path = "/account/1/user/domains",
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = "Get",
        [object]$Body
    )

    $tokenVar = Get-Variable -Name "CecAccessToken"
    $token = $tokenVar.Value
    Invoke-RestMethod -Uri "${BaseUrl}${Path}" -Method $Method -Headers @{ Authorization = "Bearer ${token}" } -ContentType "application/json" -Body:$Body
}

function Set-CecDomainContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function')]
    param(
        $Id
    )

    Set-Variable -Name "CecDomainContext" -Value $Id -Scope Script
}

function Get-CecDomainContext {
    (Get-Variable -Name "CecDomainContext").Value
}

function Invoke-CecDomainMethod {
    param(
        [string]$Path = "/micorservices/common-editor/connectors",
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = "Get",
        [object]$Body,
        [string]$DomainScope = "portal",
        [string]$Version = "v1",
        [string]$BaseUrl = "https://discover.sitecorecloud.io",
        [string]$FullPath = $Null
    )

    $token = (Get-Variable -Name "CecAccessToken").Value
    $domain = (Get-Variable -Name "CecDomainContext").Value

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
        #Proxy       = "http://127.0.0.1:8888"
    }
    if ($Null -ne $Body) {
        $params.Body = $Body | ConvertTo-Json -Depth 15
    }

    try {
        $response = Invoke-RestMethod @params -ErrorAction SilentlyContinue
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
