#Requires -Version 7.0
Set-StrictMode -Version 3.0

New-Variable -Name CecRefreshToken -Value $Null -Scope Script -Force
New-Variable -Name CecAccessToken -Value $Null -Scope Script -Force
New-Variable -Name CecDomainContext -Value $Null -Scope Script -Force

$files = @(Get-ChildItem -Path $PSScriptRoot/functions -Include "*.ps1" -File -Recurse)

($files) | ForEach-Object {
    try
    {
        Write-Verbose "Importing $_"
        . $_.FullName
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}
