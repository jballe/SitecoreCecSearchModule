function Invoke-GetAndWriteAllCecConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Path,
        [string]$EnvToken,
        [string]$Suffix,
        [string]$Prefix,
        [string]$TextToken,
        [string]$ScriptToken,
        $Domains,
        [Switch]$SkipConnectorReplacement
    )

    Get-CecEntity | Write-CecEntity -Path (Join-Path $Path "entities") -Force

    Invoke-GetAndWriteCecConnectorConfiguration -Path:$Path -EnvToken:$EnvToken -Suffix:$Suffix -Prefix:$Prefix -TextToken:$TextToken -ScriptToken:$ScriptToken -Domains:$Domains -SkipConnectorReplacement:$SkipConnectorReplacement

    Get-CecFeatureConfig | Write-CecFeatureConfig -Path $Path

    Get-CecWidgetInfo | Get-CecWidget | Write-CecWidget -Path $Path -Subfolder -Clean

    Get-CecKeywordInfo | Write-CecKeywordInfo -Path $Path -Subfolder -Clean

    Write-Output "Cec configuration written to $(Resolve-Path $Path)"
}

function Invoke-GetAndWriteCecConnectorConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Path,
        [string]$EnvToken,
        [string]$Suffix,
        [string]$Prefix,
        [string]$TextToken,
        [string]$ScriptToken,
        $Domains,
        [Switch]$SkipConnectorReplacement
    )

    if ("${EnvToken}" -ne "" -and "${Suffix}" -eq "" -and "${Prefix}" -eq "" -and "${TextToken}" -eq "" -and "${ScriptToken}" -eq "") {
        $Suffix = "_${EnvToken}"
        $TextToken = "${EnvToken}"
        $ScriptToken = "_${EnvToken}"
    }

    $connectorsPath = Join-Path $Path "connectors"
    $connectors = Get-CecConnectorInfo -Suffix $Suffix -Prefix $Prefix | Get-CecConnector
    if (-not $SkipConnectorReplacement) {
        $connectors = $connectors | Remove-CecConnectorPrefix -Suffix:$Suffix -Prefix:$Prefix -TextToken:$TextToken -ScriptToken:$ScriptToken -Domains:$Domains
        $connectors = $connectors | Remove-CecConnectorVercelBypassProtection
    }

    $connectors | Write-CecConnector -Path $connectorsPath -Subfolder
}