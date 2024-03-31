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

# Import-Module (Join-Path $PSScriptRoot "../SitecoreCecSearchModule") -Force

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted

$moduleName = "SitecoreCecSearchModule"
Install-Module -Repository PSGallery $moduleName  -SkipPublisherCheck
Write-Host ("Using version {0}" -f  (Get-InstalledModule $moduleName).Version.ToString() -join ",")

Invoke-CecLogin -Email $Email -Password $Password
Set-CecDomainContextBy -Url $AccountDomain

$domains = @{ 
    "https://www" = $SiteUrlWww
    "https://app" = $SiteUrlApp
    "https://cm"  = $SiteUrlCm
}

Write-Host "Exporting to $Path ..."
Invoke-GetAndWriteAllCecConfiguration -Path $Path -EnvToken $EnvName -Domains $domains
