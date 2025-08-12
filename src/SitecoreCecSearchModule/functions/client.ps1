$defaultRequestArguments = @{
    UserAgent            = "SitecoreCecSearchModule"
    #Verbose              = $true
    #Proxy                = "http://127.0.0.1:8080"
    #SkipCertificateCheck = $true
}

function Set-CecClientRequestArguments {
    [CmdletBinding()]
    param(
        [hashtable] $Arguments
    )
    $global:defaultRequestArguments = $Arguments
}

function Invoke-CecLogin {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
    param(
        [String] $Email,
        [String] $Password
    )
    
    Invoke-CecPasswordAuthentication -Email $Email -Password $Password
    Invoke-RefreshAccessToken
}

function Invoke-CecPortalAuthentication {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
    param(
        $Email,
        [String] $Password,
        $OrganizationId = "org_Xe6mj0fXtjGPVzFs",
        $TenantId = "9e276386-a70c-4cc6-e5e7-08dda91b30c7"
    )
    $ErrorActionPreference = "STOP"

    Invoke-WebRequest -SessionVariable "CecLoginSession" -Uri "https://cec.sitecorecloud.io"  -Method GET -UseBasicParsing @defaultRequestArguments | Out-Null
    $response = Invoke-WebRequest -WebSession $CecLoginSession -Uri "https://account.sitecorecloud.io/login/?redirect=https%3A%2F%2Fcec.sitecorecloud.io&scope=%5B%22portal%22%2C%22search-rec%22%2C%22admin%22%2C%22internal%22%2C%22util%22%2C%22discover%22%2C%22event%22%2C%22ingestion%22%5D"  -Method GET -UseBasicParsing @defaultRequestArguments
    # Fetch chuncks
    Write-Host "Request account script bundles to find IDP definitions..."
    $idpDefinition = ([regex]"`"(/_next/[^`"]+.js)`"").Matches($response.Content) | ForEach-Object { 
        $url = "https://account.sitecorecloud.io$($_.Groups[1].Value)"
        $content = Invoke-RestMethod -Uri $url @defaultRequestArguments
        if ($content -match "prod:\s*\{.*?oauth2:\s*(\{sitecoreIdp:\s*\{.*?\}\})") {
            $Matches[1]
        }
    } | ConvertFrom-Json | Select-Object -ExpandProperty sitecoreIdp
    
    if($null -eq $idpDefinition) {
        throw "Could not find IDP definition in the response, please check the login URL or the response content."
    } else {
        Write-Host "Found IDP definition for  $($idpDefinition.authorizeUrl)"
    }

    $verifier = "kPvs5iL6Nl6YhM_-9U2N6lE4fvOquDAtI6FPbt5Dvp4" # This is random bytes converted with base64, removed =, changed + to - and / to _
    $challenge = "GQ7x9Q-IpB5Kq3ftkozIXyGRjcfsHDBnRA0HfyzKrqs" # This is HMAC hash of verifier
    $cookie = [System.Net.Cookie]::new('code_verifier', $verifier, "/", ".sitecorecloud.io")
    $CecLoginSession.Cookies.Add($cookie)
    $url = $idpDefinition.authorizeUrl + "?response_type=code" +
    "&client_id=" + $idpDefinition.clientId + 
    "&redirect_uri=" + [uri]::EscapeDataString($idpDefinition.redirectUrl) + 
    "&scope=" + [uri]::EscapeDataString($idpDefinition.scope) + 
    "&audience=" + [uri]::EscapeDataString($idpDefinition.audience) + 
    "&code_challenge=" + $challenge + 
    "&code_challenge_method=S256" +
    "&product_codes=Search%2CDiscover"
    if ("${organizationId}" -ne "") {
        $url += "&organization_id=${OrganizationId}"
    }
    if ("${tenantId}" -ne "") {
        $url += "&tenant_id=${TenantId}"
    }

    $response = Invoke-WebRequest -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction SilentlyContinue -WebSession $CecLoginSession -Uri $url -Method GET -UseBasicParsing @defaultRequestArguments
    $url = ([uri]$idpDefinition.authorizeUrl).GetLeftPart('Authority') + $response.Headers.Location
    $response = Invoke-WebRequest -WebSession $CecLoginSession -Uri $url -Method GET -UseBasicParsing @defaultRequestArguments

    do {
        $formData = New-FormResponseData -Response $response -Values @{
            username = $Email
            password = $Password
        }

        Write-Verbose "Submitting login form to $url"
        $response = Invoke-WebRequest -WebSession $CecLoginSession -Uri $url -Method POST -UseBasicParsing -Body $formData -ContentType "application/x-www-form-urlencoded" -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction SilentlyContinue @defaultRequestArguments
        while ($response.StatusCode -eq 302) {
            $newUrl = $response.Headers.Location | Select-Object -First 1
            if($newUrl -match "^\/") {
                $url = ([uri]$url).GetLeftPart('Authority') + $newUrl
                Write-Verbose "Got redirect to $newUrl will request $url"
            } else {
                $url = $newUrl
            }

            Write-Verbose "Requesting '$url'"
            $response = Invoke-WebRequest -WebSession $CecLoginSession -Uri $url -Method GET -UseBasicParsing -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction SilentlyContinue @defaultRequestArguments
        }
    } while ($response.StatusCode -eq 200 -and $response.Content -match "name=`"username`"")

    $code = $url -split "code=" | Select-Object -Last 1
    if ("${code}" -eq "") {
        throw "Could not login, there is no code in url $($url)"
    }

    $formData = @{
        grant_type    = "authorization_code"
        code          = $code
        code_verifier = $verifier
        client_id     = $idpDefinition.clientId
        redirect_uri  = $idpDefinition.redirectUrl
    }
    $response = Invoke-WebRequest -WebSession $CecLoginSession -Uri "https://auth.sitecorecloud.io/oauth/token" -Method POST -Body $formData -ContentType "application/x-www-form-urlencoded" -UseBasicParsing @defaultRequestArguments
    $token = $response.Content | ConvertFrom-Json
    Set-CecRefreshToken -RefreshToken $token.refresh_token
    Set-CecAccessToken -AccessToken $token.access_token
}

function New-FormResponseData {
    param(
        $Response,
        $Values = @{}
    )


    $formData = @{}
    $inputFields = ([regex]"<input[^>]+>").Matches($Response.Content)
    foreach ($f in $inputFields) {
        $name = ([regex]"name\s*=\s*""([^""]+)""").Match($f.Value).Groups[1].Value
        $value = ([regex]"value\s*=\s*""([^""]+)""").Match($f.Value).Groups[1].Value

        if ($Values.ContainsKey($name)) {
            $value = $Values[$name]
        }

        if ($name -and $value) {
            $formData[$name] = $value
        }
    }

    $formData
}

function Invoke-CecPasswordAuthentication {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
    param(
        $Email,
        [String] $Password
    )
    $ErrorActionPreference = "STOP"

    $url = "https://discover.sitecorecloud.io/account/1/authenticate/password/cec"
    $body = @{
        email    = $Email
        password = $Password
        scope    = @("portal", "search-rec", "admin", "internal", "util", "discover", "event", "ingestion")
        target   = "https://cec.sitecorecloud.io"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri $url -ContentType application/json -Method POST -Body $body @defaultRequestArguments
    if ($response.PSObject.Properties.Name -contains "error-id") {
        throw  ("Error from login: {0} {1} ({2})" -f $response.type, $response.message, $response.code)
    }
    if (-not $response.PSObject.Properties.Name -contains "redirectUrl") {
        throw ("Unexpected login response:`n{0}" -f ($response | ConvertTo-Json -Depth 15))
    }

    $redirectUrl = $response.redirectUrl
    $result = $redirectUrl -match "https://cec.sitecorecloud.io#refresh_token=([^&]+)$"
    if ($result -eq $false -or $Matches.Count -lt 2) {
        Write-Error $response
        throw "Could not login, did not find refresh_token"
    }

    $refreshToken = $Matches[1]
    Set-CecRefreshToken -RefreshToken $refreshToken
    Write-Information "Successfully authenticated"
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

    $tokenVar = Get-Variable -Name "CecAccessToken"
    $token = $tokenVar.Value
    $params = @{
        Uri         = "${BaseUrl}${Path}"
        Method      = $Method
        Headers     = @{ Authorization = "Bearer ${token}" }
        ContentType = "application/json"
    }
    Invoke-RestMethod @params @defaultRequestArguments -Body:$Body
}

function Set-CecDomainContext {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
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
        [string]$FullPath = $Null,
        [switch]$SkipHttpErrorCheck
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
    }
    if ($Null -ne $Body) {
        $params.Body = $Body | ConvertTo-Json -Depth 15
    }

    try {
        $response = Invoke-RestMethod @params @defaultRequestArguments -ErrorAction SilentlyContinue
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
