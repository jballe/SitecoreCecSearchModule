function Write-CecWidget {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Widget,
        [Parameter(Mandatory)][String]$Path,
        [Switch]$Subfolder,
        [Switch]$Clean
    )

    begin {
        $destinationPath = $Path
        if ($Subfolder) {
            $destinationPath = join-path $destinationPath "widgets"
        }
        If (-not (Test-Path $destinationPath -PathType Container)) {
            New-Item $destinationPath -ItemType Directory | Out-Null
        }
        $destinationPath = Resolve-Path $destinationPath

        if($Clean) {
            Get-ChildItem $destinationPath | Remove-Item -Force
        }
    }

    process {
        $type = $Widget.type
        $folder = Join-Path $destinationPath $type
        If (-not (Test-Path $folder -PathType Container)) {
            New-Item $folder -ItemType Directory | Out-Null
        }

        $json = $Widget | Remove-CecWidgetUserDate | ConvertTo-Json -Depth 15
        $filePath = Join-Path $folder ("{0}.json" -f $Widget.name)
        Set-Content -LiteralPath $filePath -Value $json -Force
    }
}

function Remove-CecWidgetUserDate {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Widget
    )

    process {
        $Widget.PSObject.Properties.Remove('createdAt')
        $Widget.PSObject.Properties.Remove('updatedAt')
        $Widget.PSObject.Properties.Remove('status')
        $Widget.PSObject.Properties.Remove('userId')
        $Widget.PSObject.Properties.Remove('version')
        $Widget.PSObject.Properties.Remove('widgetId')
        $Widget.PSObject.Properties.Remove('parentWidgetId')
        $Widget.PSObject.Properties.Remove('live')

        foreach ($v in $Widget.variations) {
            $v.PSObject.Properties.Remove('createdAt')
            $v.PSObject.Properties.Remove('updatedAt')
            $v.PSObject.Properties.Remove('status')
            $v.PSObject.Properties.Remove('userId')
            $v.PSObject.Properties.Remove('version')
            $v.PSObject.Properties.Remove('variationId')
        }

        $Widget
    }
}
