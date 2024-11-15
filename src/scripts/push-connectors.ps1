[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
param(
    $Email,
    $Password,
    $EnvName,
    $AccountDomain,
    $SiteUrlApp,
    $SiteUrlWww,
    $SiteUrlCm,
    $Path = (Join-Path $PSScriptRoot "../../out/${AccountDomain}"),
    $VercelBypassKey,
    [Switch]$Force
)

$ErrorActionPreference = "STOP"
$connectorsPath = Join-Path ${Path} "connectors" -Resolve

Invoke-CecLogin -Email $Email -Password $Password
Set-CecDomainContextBy -Url $AccountDomain

$domains = @{ 
    "https://app" = $SiteUrlApp
    "https://www" = $SiteUrlWww
    "https://cm"  = $SiteUrlCm
}
$folders = Get-ChildItem $connectorsPath -Directory
foreach($f in $folders) {
    $connector = Read-CecConnector -Path $f.FullName
    $connector `
    | Add-CecConnectorPrefix  -Suffix "_${EnvName}" -Domains $domains -TextToken "${EnvName}" -ScriptToken "_${EnvName}" `
    | Add-CecConnectorVercelBypassProtection -BypassProtectionKey $VercelBypassKey
    | Update-CecConnectorModelWithId -FetchConnectorWithSameName `
    | Set-CecConnector -Publish -Force:$Force `
    | Format-Table -Property name, status, connectorId -AutoSize
}
