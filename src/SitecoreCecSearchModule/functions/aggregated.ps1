function Invoke-GetAndWriteAllCecConfiguration {
    param(
        $Path,
        $EnvToken,
        $Suffix,
        $Prefix,
        $TextToken,
        $ScriptToken,
        $Domains
    )

    Get-CecAttribute | Write-CecAttribute -Path $Path -Force

    if("${EnvToken}" -ne "" -and "${Suffix}" -eq "" -and "${Prefix}" -eq "" -and "${TextToken}" -eq "" -and "${ScriptToken}" -eq "") {
        $Suffix = "_${EnvToken}"
        $TextToken = "${EnvToken}"
        $ScriptToken = "_${EnvToken}"
    }

    $connectorsPath = Join-Path $Path "connectors"
    Get-CecConnectorsInfo -Suffix $Suffix -Prefix $Prefix | Get-CecConnector `
    | Remove-CecConnectorPrefix -Suffix:$Suffix -Prefix:$Prefix -TextToken:$TextToken -ScriptToken:$ScriptToken -Domains:$Domains `
    | Write-CecConnector -Path $connectorsPath -Subfolder

    Get-CecFeatureConfig | Write-CecFeatureConfig -Path $Path

    Get-CecWidgetInfo | Get-CecWidget | Write-CecWidget -Path $Path -Subfolder -Clean
}

