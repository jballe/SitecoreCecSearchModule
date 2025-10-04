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
    $ErrorActionPreference = "STOP"
    $defaultRequestArguments = (Get-Variable -Scope Global -Name ClientDefaultProperties).Value

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
