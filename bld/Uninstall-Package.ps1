param(
    $PackageName = "SitecoreCecSearchModule"
)
$ErrorActionPreference = "STOP"

Uninstall-Module -Name $PackageName -ErrorAction SilentlyContinue
Write-Host "Done" -ForegroundColor Green
