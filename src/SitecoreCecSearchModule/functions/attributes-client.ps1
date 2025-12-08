$specsRequestPath = "/microservices/common-editor/configs/current/specs"
$configRequestPath = "/microservices/common-editor/configs/current"

function Get-CecSpec {
    (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath).productSpecs
}

function Get-CecEntityConfig {
    param(
        [string]$EntityName = $Null,
        [string]$Prefix = $Null,
        [string]$Suffix = $Null,
        [switch]$RemovePrefix
    )

    [Array]$entities = (Invoke-CecDomainMethod -Method GET -Path $configRequestPath).domainConfig.entities

    if ("" -ne "${EntityName}") {
        $entities = $entities | Where-Object { $_.name -ilike "${Prefix}${EntityName}${Suffix}" }
    }

    if ("" -ne "${Prefix}" -or "" -ne "${Suffix}") {
        $entities = $entities | Where-Object { $_.name -ilike "${Prefix}*${Suffix}" }
    }

    if ($RemovePrefix -and ("" -ne "${Prefix}" -or "" -ne "${Suffix}")) {
        $entities | Set-CecEntityConfigSuffixTemplate -Prefix:$Prefix -Suffix:$Suffix
    }

    $entities
}

function Set-CecEntityConfig {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [Array]$Entities,
        [string]$Prefix = $Null,
        [string]$Suffix = $Null,

        [Switch]$Force,
        [Switch]$Publish
    )

    begin {
        $doc = (Invoke-CecDomainMethod -Method GET -Path $configRequestPath)
        [Array]$currentEntities = $doc.domainConfig.entities
    }

    process {
        $entity = ($_ | Set-CecEntityConfigSuffixValue -Prefix:$Prefix -Suffix:$Suffix)
        $name = $entity.name
        if ($currentEntities.name -contains $name) {
            $existing = $entities | Where-Object { $_.name -ilike $name }
            $existing.displayName = $entity.name
        }
        else {
            $doc.domainConfig.entities = $currentEntities + @($Entity)
        }
    }

    end {
        $doc.domainConfig.PSObject.Properties.Remove("createdAt")
        $doc.domainConfig.PSObject.Properties.Remove("live")
        if ($doc.domainConfig.status -ne "draft") {
            $doc.domainConfig.version += 1
            $doc.domainConfig | AddOrSetPropertyValue -PropertyName "status" -Value "draft"
        }
        $doc.domainConfig.updatedAt = ([long](Get-Date -AsUTC -UFormat "%s")) * 1000
        $doc.domainConfig | AddOrSetPropertyValue -PropertyName "operation" -Value "UPDATE"

        if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {

            $response = (Invoke-CecDomainMethod -Method PUT -Path $configRequestPath -Body ($doc.domainConfig)) | Select-Object -ExpandProperty "domainConfig"
            if ($Publish) {
                $response = Publish-CecEntityConfig
            }

            $response
        }
    }
}

function Publish-CecEntityConfig {
    Invoke-CecDomainMethod -Method POST -Path "${configRequestPath}/versions/draft?"
}

function Remove-CecEntityConfigDraft {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Switch]$Force
    )

    if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {

        Invoke-CecDomainMethod -Method DELETE -Path "${configRequestPath}/versions/draft?"
    }
}

function Get-CecEntity {
    param(
        [string]$EntityName = $Null,
        [string]$Prefix = $Null,
        [string]$Suffix = $Null,
        [switch]$RemovePrefix
    )

    $entities = (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath).productSpecs.attributesV2

    if ("" -ne "${EntityName}") {
        $name = "${Prefix}${EntityName}${Suffix}"
        if ($entities.PSObject.Properties.Name -notcontains $name) {
            return $Null
        }
        else {
            return $entities.$name
        }
    }

    if ("" -ne "${Prefix}" -or "" -ne "${Suffix}") {
        $result = [PSCustomObject]@{}
        $names = $entities.PSObject.Properties.Name | Where-Object { $_ -ilike "${Prefix}*${Suffix}" }
        foreach ($name in $names) {
            $newName = $name
            if ($RemovePrefix) {
                $newName = Remove-Suffix -Value $newName -Prefix $Prefix -Suffix $Suffix
            }

            $obj = $entities.$name
            #$result[$newName] = $obj
            $result | AddOrSetPropertyValue -PropertyName $newName -Value $obj
        }

        return $result
    }

    if ("" -eq "${EntityName}") {
        return $entities
    }
    elseif ($entities.PSObject.Properties.Name -contains $EntityName) {
        return $entities.$EntityName
    }
    else {
        Write-Error "Entity '$EntityName' not found in specs"
        return $null
    }
}

function Set-CecEntity {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Entities,
        [string]$Prefix = $Null,
        [string]$Suffix = $Null,
        [switch]$AddPrefix,
        [Switch]$Force
    )

    process {
        $doc = (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath)
        $currentEntities = $doc.productSpecs.attributesV2

        $names = $Entities.PSObject.Properties.Name
        foreach ($name in $names) {
            $newName = $name
            if ($AddPrefix) {
                $newName = Add-Suffix -Value $newName -Prefix $Prefix -Suffix $Suffix
            }

            $currentEntities | AddOrSetPropertyValue -PropertyName $newName -Value $Entities.$name

            $doc.productSpecs.attributesV2.$newName.items = $Entities.$name.items
        }

        if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
            Invoke-CecDomainMethod -Method PUT -Path $specsRequestPath -Body $doc
        }
        else {
            $currentEntities
        }
    }
}


function Get-CecAttribute {
    param(
        [string]$EntityName = "content"
    )

    (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath).productSpecs.attributesV2 | Select-object -ExpandProperty $EntityName
}


function Set-CecAttribute {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Attributes,
        [Switch]$Force,

        [string]$EntityName = "content"
    )

    process {

        $doc = (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath)
        $entity = $doc.productSpecs.attributesV2 | Select-AzContext -ExpandProperty $EntityName

        $attributeNames = $entity.items.name
        $existing = @()
        foreach ($name in $attributeNames) {
            $existing += $Attributes.items | Where-Object { $_.name -eq $name }
        }
        $newAttributes = $Attributes.items | Where-object { -not $attributeNames -contains $_.name }
        $entity.items = $newAttributes + $existing

        if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
            Invoke-CecDomainMethod -Method PUT -Path $specsRequestPath -Body $doc | Out-Null
        }
    }
}