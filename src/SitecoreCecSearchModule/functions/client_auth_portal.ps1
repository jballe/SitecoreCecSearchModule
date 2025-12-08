function Invoke-CecPortalAuthentication {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
    param(
        $Email,
        [String] $Password,
        $OrganizationId = "org_Xe6mj0fXtjGPVzFs",
        $TenantId = "9e276386-a70c-4cc6-e5e7-08dda91b30c7"
    )
    $ErrorActionPreference = "STOP"
    $defaultRequestArguments = (Get-Variable -Scope Global -Name ClientDefaultProperties).Value

    Invoke-WebRequest -SessionVariable "CecLoginSession" -Uri "https://cec.sitecorecloud.io"  -Method GET -UseBasicParsing @defaultRequestArguments | Out-Null
    $response = Invoke-WebRequest -WebSession $CecLoginSession -Uri "https://account.sitecorecloud.io/login/?redirect=https%3A%2F%2Fcec.sitecorecloud.io&scope=%5B%22portal%22%2C%22search-rec%22%2C%22admin%22%2C%22internal%22%2C%22util%22%2C%22discover%22%2C%22event%22%2C%22ingestion%22%5D"  -Method GET -UseBasicParsing @defaultRequestArguments
    # Fetch chuncks
    Write-Information "Requesting account script bundles to find IDP definitions..."
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
        Write-Information "Found IDP definition for  $($idpDefinition.authorizeUrl)"
    }

    # Using OIDC PKCE (Proof Key for Code Exchange) to enhance security
    $pkce = CreatePkceValues
    $cookie = [System.Net.Cookie]::new('code_verifier', $pkce.Verifier, "/", ".sitecorecloud.io")
    $CecLoginSession.Cookies.Add($cookie)
    $url = $idpDefinition.authorizeUrl + "?response_type=code" +
    "&client_id=" + $idpDefinition.clientId +
    "&redirect_uri=" + [uri]::EscapeDataString($idpDefinition.redirectUrl) +
    "&scope=" + [uri]::EscapeDataString($idpDefinition.scope) +
    "&audience=" + [uri]::EscapeDataString($idpDefinition.audience) +
    "&code_challenge=" + $pkce.Challenge +
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
        code_verifier = $pkce.Verifier
        client_id     = $idpDefinition.clientId
        redirect_uri  = $idpDefinition.redirectUrl
    }
    $response = Invoke-WebRequest -WebSession $CecLoginSession -Uri "https://auth.sitecorecloud.io/oauth/token" -Method POST -Body $formData -ContentType "application/x-www-form-urlencoded" -UseBasicParsing @defaultRequestArguments
    $token = $response.Content | ConvertFrom-Json
    Set-CecRefreshToken -RefreshToken $token.refresh_token
    Set-CecAccessToken -AccessToken $token.access_token
}

function CreatePkceValues {
    # Using OIDC PKCE (Proof Key for Code Exchange) to enhance security
    # https://github.com/darrenjrobinson/PKCE/blob/main/PKCE.psm1
    param(
        # Length must be between 43 and 128 characters
        [int]$Length = 43
    )

    # Code verifier is just random string characters, in CEC it is using Crypto module random bytes and therefore base64 and then removing the padding and replacing characters
    # we will just generate a string of valid characters
    $codeVerifier = -join (((48..57) * 4) + ((65..90) * 4) + ((97..122) * 4) | Get-Random -Count $Length | ForEach-Object { [char]$_ })

    # Hash the verifier
    $hashAlgo = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    $hash = $hashAlgo.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($codeVerifier))
    $b64Hash = [System.Convert]::ToBase64String($hash)
    $code_challenge = $b64Hash.Substring(0, 43)

    # Encode by replacing characters
    $code_challenge = $code_challenge.Replace("/","_")
    $code_challenge = $code_challenge.Replace("+","-")
    $code_challenge = $code_challenge.Replace("=","")

    return @{
        Verifier  = $codeVerifier
        Challenge = $code_challenge
    }
}

function New-FormResponseData {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
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
