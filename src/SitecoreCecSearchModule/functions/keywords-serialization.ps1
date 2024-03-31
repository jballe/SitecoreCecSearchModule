function Write-CecKeywordInfo {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Keywords,
        [Parameter(Mandatory)][String]$Path,
        [Switch]$Subfolder,
        [Switch]$Clean
    )

    begin {
        if ($Subfolder) {
            $folder = Join-Path $Path "keywords" 
        }
        else {
            $folder = Resolve-Path $Path
        }

        if (-not (Test-Path $folder -PathType Container)) {
            New-Item $folder -ItemType Directory | Out-Null
        }

        if ($Clean) {
            Get-ChildItem $folder -Filter *.json | Remove-Item -Force -Recurse
        }
    }

    process {
        foreach ($obj in $Keywords.keywords) {

            $name = $obj.name
            $json = $obj | Remove-CecKeywordUserDate | ConvertTo-Json -Depth 15
            $filePath = Join-Path $folder ("{0}.json" -f $name)
            Set-Content -LiteralPath $filePath -Value $json -Force
        }
    }
}

function Remove-CecKeywordUserDate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$InputObject
    )

    process {
        $InputObject.PSObject.Properties.Remove('keywordId')
        $InputObject.PSObject.Properties.Remove('createdAt')
        $InputObject.PSObject.Properties.Remove('updatedAt')
        $InputObject.PSObject.Properties.Remove('userId')
        $InputObject.PSObject.Properties.Remove('version')

        if ($InputObject.status -eq "live") {
            $InputObject.PSObject.Properties.Remove('status')
            $InputObject.PSObject.Properties.Remove('operation')
        }

        $InputObject
    }
}