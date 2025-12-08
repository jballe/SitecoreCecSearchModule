function Write-CecFeatureConfig {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Features,
        [Parameter(Mandatory)][String]$Path,
        [Switch]$Subfolder
    )

    begin {
        if ($Subfolder) {
            $folder = Join-Path $Path "features"
        }
        else {
            $folder = Resolve-Path $Path
        }
    }

    process {

        Write-Verbose "## Writing features to $folder"
        foreach ($area in $Features.PSObject.Properties.Name) {
            if ($area -eq "enabled") { continue }
            Write-Verbose "### Writing $area"
            foreach ($fname in $Features.$area.PSObject.Properties.Name) {
                $relativeFolder = "features/${area}/${fname}"
                $folder = Join-Path $Path $relativeFolder
                If (-not (Test-Path $folder -PathType Container)) { New-Item $folder -ItemType Directory -Force | Out-Null }

                Write-Verbose "#### Writing $area.$fname to $folder"

                foreach ($obj in $Features.$area.$fname) {
                    if( $obj.PSObject.Properties.Name -contains "name" ) {
                        $name = $obj.name
                    }
                    else {
                        $name = $fname
                    }

                    $filename = Join-Path $folder "${name}.json"
                    Set-Content -Path $filename -Value ($obj | ConvertTo-Json -Depth 15)
                }
            }

            $Features.$area = "Exported to $relativeFolder"
            Write-Verbose "### Writing $area completed"
        }

        $json = $Features | ConvertTo-Json -Depth 15
        $filePath = Join-Path $Path "features/features.json"
        Set-Content -LiteralPath $filePath -Value $json -Force
    }
}