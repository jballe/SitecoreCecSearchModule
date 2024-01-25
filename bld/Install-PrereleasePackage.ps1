param(
    [Parameter(Mandatory)]
    $User,
    [Parameter(Mandatory)]
    $PersonalAccessToken,
    $Feed = "https://nuget.pkg.github.com/jballe/index.json",
    $NugetSourceName = "GithubSitecoreCec",
    $LocalRegistryName = "PrivateNugetSource",
    $LocalRegistryPath = "./__modules",
    $PackageName = "SitecoreCecSearchModule",
    $Version = "0.1.0-betaworkflows0051",
    [Switch]$SkipCleanup
)
$ErrorActionPreference = "STOP"

## Add the package source
Write-Host "Register NuGet Source" -ForegroundColor Green
# Remove any existing 
nuget sources Remove -Name $NugetSourceName | Out-String | Out-Null
# Add source
nuget sources Add `
    -Name $NugetSourceName `
    -Source $Feed `
    -UserName $User `
    -Password $PersonalAccessToken `
    -Verbosity detailed `
    -NonInteractive `
    -Verbosity detailed
#-ConfigFile nuget.config `


## Create a directory for local repository
If (-not (Test-Path $LocalRegistryPath -PathType Container)) {
    New-Item $LocalRegistryPath -ItemType Directory | Out-Null
}

Install-Module Microsoft.PowerShell.PSResourceGet -Repository PSGallery -Force

## Register the local repository
Write-Host "Register Local PSRepository" -ForegroundColor Green
if ($Null -ne (get-psrepository -Name PrivateNugetSource -ErrorAction SilentlyContinue)) {
    Unregister-PSRepository -name $LocalRegistryName
}
Register-PSRepository `
    -Name $LocalRegistryName `
    -SourceLocation $LocalRegistryPath `
    -InstallationPolicy Trusted 

## Download package
Write-Host "Download package" -ForegroundColor Green
nuget install $PackageName `
    -Prerelease `
    -Version $Version `
    -DirectDownload `
    -OutputDirectory $LocalRegistryPath `
    -Source $NugetSourceName `
    -Verbosity detailed
Move-Item (Join-Path $LocalRegistryPath "${PackageName}.${Version}" "${PackageName}.${Version}.nupkg" -Resolve) $LocalRegistryPath -Force
Remove-Item (Join-Path $LocalRegistryPath "${PackageName}.${Version}" -Resolve) -Recurse -Force

## Install the module from the local repository
Write-Host "Install package $PackageName $Version Powershell Module" -ForegroundColor Green
Install-Module -Name $PackageName `
    -Repository $LocalRegistryName `
    -MinimumVersion $Version `
    -AllowPrerelease `
    -AcceptLicense `
    -Force `
    -SkipPublisherCheck

## Cleanup
if (-not $SkipCleanup) {
    Write-Host "Cleanup registrations" -ForegroundColor Green
    Unregister-PSRepository -Name $LocalRegistryName
    nuget sources Remove -Name $NugetSourceName
}

## Done
Write-Host "Done" -ForegroundColor Green
