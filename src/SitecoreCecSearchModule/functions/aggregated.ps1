function Invoke-GetAndWriteAllCecConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Path,
        [string]$EnvToken,
        [string]$Suffix,
        [string]$Prefix,
        [string]$TextToken,
        [string]$ScriptToken,
        $Domains
    )

    Get-CecAttribute | Write-CecAttribute -Path $Path -Force

    if("${EnvToken}" -ne "" -and "${Suffix}" -eq "" -and "${Prefix}" -eq "" -and "${TextToken}" -eq "" -and "${ScriptToken}" -eq "") {
        $Suffix = "_${EnvToken}"
        $TextToken = "${EnvToken}"
        $ScriptToken = "_${EnvToken}"
    }

    $connectorsPath = Join-Path $Path "connectors"
    Get-CecConnectorInfo -Suffix $Suffix -Prefix $Prefix | Get-CecConnector `
    | Remove-CecConnectorPrefix -Suffix:$Suffix -Prefix:$Prefix -TextToken:$TextToken -ScriptToken:$ScriptToken -Domains:$Domains `
    | Write-CecConnector -Path $connectorsPath -Subfolder

    Get-CecFeatureConfig | Write-CecFeatureConfig -Path $Path

    Get-CecWidgetInfo | Get-CecWidget | Write-CecWidget -Path $Path -Subfolder -Clean

    Get-CecKeywordInfo | Write-CecKeywordInfo -Path $Path -Subfolder -Clean
}

