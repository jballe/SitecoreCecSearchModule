[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Obsolete')]
param(
    $Email,
    $Password,
    $EnvName,
    $AccountDomain,
    $Path = (Join-Path $PSScriptRoot "../../out/${AccountDomain}"),
    [Switch]$Force
)

$ErrorActionPreference = "STOP"

Invoke-CecLogin -Email $Email -Password $Password
Set-CecDomainContextBy -Url $AccountDomain

$connectors = Get-CecConnectorInfo -Suffix "_${EnvName}" `

$connectors | Format-Table -Property name, status, updatedAt, message

$connectors `
| Start-CecConnectorRescan `
| Format-Table -Property name, status, updatedAt, message
