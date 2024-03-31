[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
param(
    $Email,
    $Password,
    $EnvName = "PRD",
    $AccountDomain,
    $SiteUrlWww,
    $SiteUrlApp,
    $SiteUrlCm,
    $Path = (Join-Path $PSScriptRoot "../../out/${AccountDomain}")
)

$ErrorActionPreference = "STOP"

Invoke-CecLogin -Email $Email -Password $Password
Set-CecDomainContextBy -Url $AccountDomain

$domains = @{ 
    "https://www" = $SiteUrlWww
    "https://app" = $SiteUrlApp
    "https://cm"  = $SiteUrlCm
}

$connectorsPath = Join-Path $Path "connectors"
Get-CecConnectorInfo -Suffix $Suffix -Prefix $Prefix | Get-CecConnector `
| Remove-CecConnectorPrefix -Suffix:$Suffix -Prefix:$Prefix -TextToken:$TextToken -ScriptToken:$ScriptToken -Domains:$Domains `
| Write-CecConnector -Path $connectorsPath -Subfolder
