function Write-CecFeatures {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Features,
        [Parameter(Mandatory)][String]$Path
    )

    process {
        $json = $Features | ConvertTo-Json -Depth 15
        $filePath = Join-Path $Path "features.json"
        Set-Content -LiteralPath $filePath -Value $json -Force
    }
}