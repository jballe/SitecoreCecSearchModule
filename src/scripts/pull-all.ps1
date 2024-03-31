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

Write-Host "Exporting to $Path ..."
Invoke-GetAndWriteAllCecConfiguration -Path $Path -EnvToken $EnvName -Domains $domains
