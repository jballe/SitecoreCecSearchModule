param(
    $PackageName = "SitecoreCecSearchModule",
    $Version = "0.1.0-betaworkflows0051"
)
$ErrorActionPreference = "STOP"

Install-Module Microsoft.PowerShell.PSResourceGet -Repository PSGallery -Force

UnRegister-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue | Out-Null
Register-PSResourceRepository -psgallery -Trusted

Install-Module -Name $PackageName -Repository PSGallery -AllowPrerelease -AcceptLicense -Force -MinimumVersion $Version -SkipPublisherCheck

Write-Host "Done" -ForegroundColor Green
