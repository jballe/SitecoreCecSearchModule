function Write-CecAttribute {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Attributes,
        [Parameter(Mandatory)][String]$Path,
        [Switch]$SkipFiles,

        [Switch]$Force
    )

    begin {
        If (-not (Test-Path $Path -PathType Container)) {
            New-item $Path -ItemType Directory | Out-Null
        }
    }

    process {

        if (-not $SkipFiles) {

            $attributesFolder = Join-Path $Path "attributes"
            If (-not (Test-Path $attributesFolder -PathType Container)) {
                New-item $attributesFolder -ItemType Directory | Out-Null
            }

            if ($Force -or $PSCmdlet.ShouldProcess($attributesFolder, 'Remve existing attributes files on disk')) {
                Get-ChildItem $attributesFolder -Include "*.json" -Recurse | Remove-item -Force:$true
            }

            foreach ($attr in $Attributes.items) {
                $name = $attr.name
                $scope = $attr.scope
                $scopeFolder = Join-Path $attributesFolder $scope
                If (-not (Test-Path $scopeFolder -PathType Container)) {
                    New-Item -Path $scopeFolder -ItemType Directory | Out-Null
                }

                $filePath = Join-Path $scopeFolder "${name}.json"

                if ($Force -or $PSCmdlet.ShouldProcess($filePath, 'Write attribute to disk')) {
                    Set-Content -Value ($attr | ConvertTo-Json -Depth 15) -Path $filePath
                }
            }
        }
        else {
            if ($Force -or $PSCmdlet.ShouldProcess($Path, 'Write attributes to disk')) {
                Set-Content -Path (Join-Path $Path "attributes.json") -Value (ConvertTo-Json -InputObject $Attributes -Depth 30)
            }
        }
    }
}

function Read-CecAttribute {
    param(
        [Parameter(Mandatory)]
        $Path,
        [Switch]$SkipFiles
    )

    if (-not $SkipFiles) {
        $config = [PSCustomObject]@{ items = @() }
        foreach ($attFile in Get-ChildItem (Join-Path $Path "attributes" -Resolve) -Recurse -Filter "*.json") {
            $att = Get-Content $attFile | ConvertFrom-Json
            $config.items += $att
        }
    }
    else {
        $config = Get-Content -Path (Join-Path $Path "attributes.json") | ConvertFrom-Json
    }

    $config
}
