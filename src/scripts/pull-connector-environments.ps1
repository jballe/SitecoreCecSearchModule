[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
param(
    $Email,
    $Password,
    $Environments = @("TST", "UAT", "PRD"),
    $AccountDomain,
    $Domains,
    $Path = (Join-Path $PSScriptRoot "../../out/${AccountDomain}")
)

$ErrorActionPreference = "STOP"

Invoke-CecLogin -Email $Email -Password $Password
Set-CecDomainContextBy -Url $AccountDomain

foreach ($name in $Environments) {
    $Suffix = "_${name}"
    $TextToken = $name
    $ScriptToken = $Suffix
    $connectorsPath = Join-Path $Path "connectors-${name}"
    Write-Host "Fetching ${name} to ${connectorsPath}"

    Get-CecConnectorInfo -Suffix $Suffix | Get-CecConnector `
    | Remove-CecConnectorPrefix -Suffix $Suffix -TextToken:$TextToken -ScriptToken $ScriptToken -Domain:$Domains `
    | Write-CecConnector -Path $connectorsPath -Subfolder
}
