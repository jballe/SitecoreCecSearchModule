function Write-CecEntityConfig {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)][Array]$Entity,
        [Parameter(Mandatory)][String]$Path,

        [Switch]$Force
    )

    begin {
        If (-not (Test-Path $Path -PathType Container)) {
            New-item $Path -ItemType Directory | Out-Null
        }
    }

    process {
        $folderName = $_.name.Replace("{Prefix}", "").Replace("{Suffix}", "")
        $targetFolder = Join-Path $Path $folderName
        If(-not (Test-Path $targetFolder -PathType Container)) { New-Item $targetFolder -ItemType Directory | Out-Null }
        $targetPath = Join-Path $Path "${targetFolder}/entity.json"
        if ($Force -or $PSCmdlet.ShouldProcess($Path, "Write entities config to disk ${targetPath}")) {
            Set-Content -Path $targetPath -Value (ConvertTo-Json -InputObject $_ -Depth 30)
        }
    }
}

function Read-CecEntityConfig {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $Path
    )

    process {
        [Array]$result = Get-ChildItem $Path -Recurse -Depth 2 -Filter "entity.json" | ForEach-Object { Get-Content $_ | ConvertFrom-Json }

        $result
    }
}

function Write-CecEntity {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Entities,
        [Parameter(Mandatory)][String]$Path,

        # Don't split into individual files, just write a single file
        [Switch]$SkipFiles,

        [Switch]$Force
    )

    begin {
        If (-not (Test-Path $Path -PathType Container)) {
            New-item $Path -ItemType Directory | Out-Null
        }
    }

    process {

        if ($SkipFiles) {
            if ($Force -or $PSCmdlet.ShouldProcess($Path, 'Write attributes to disk')) {
                Set-Content -Path (Join-Path $Path "attributes.json") -Value (ConvertTo-Json -InputObject $Attributes -Depth 30)
            }
            return
        }

        $names = $Entities.PSObject.Properties.Name
        foreach ($entityName in $names) {
            $folderPath = Join-Path $Path $entityName
            $attributes = $Entities.$entityName
            Write-CecAttribute -Attributes $attributes -Path $folderPath -SkipFiles:$SkipFiles -Force:$Force
        }
    }
}

function Read-CecEntity {
    param(
        [Parameter(Mandatory)][String]$Path,
        [Switch]$SkipFiles
    )

    $names = Get-ChildItem $Path -Directory | Select-Object -ExpandProperty Name
    $result = [PSCustomObject]@{  }
    foreach ($entityName in $names) {
        $folderPath = Join-Path $Path $entityName
        $attributes = Read-CecAttribute -Path $folderPath -SkipFiles:$SkipFiles
        $result | AddOrSetPropertyValue -PropertyName $entityName -Value $attributes
    }

    $result
}

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
