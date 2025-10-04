$specsRequestPath = "/microservices/common-editor/configs/current/specs"

function Get-CecSpec {
    (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath).productSpecs

}

function Get-CecEntity {
    param(
        [string]$EntityName = $Null
    )

    $entities = (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath).productSpecs.attributesV2

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