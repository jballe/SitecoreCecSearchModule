$specsRequestPath = "/microservices/common-editor/configs/current/specs"

function Get-CecAttribute {
    param(

    )

    (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath).productSpecs.attributesV2.content
}


function Set-CecAttribute {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Attributes,
        [Switch]$Force
    )

    process {

        $doc = (Invoke-CecDomainMethod -Method GET -Path $specsRequestPath)
        $attributeNames = $doc.productSpecs.attributesV2.content.items.name
        $existing = @()
        foreach ($name in $attributeNames) {
            $existing += $Attributes.items | Where-Object { $_.name -eq $name }
        }
        $newAttributes = $Attributes.items | Where-object { -not $attributeNames -contains $_.name }

        $doc.productSpecs.attributesV2.content.items = $newAttributes + $existing


        if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
            Invoke-CecDomainMethod -Method PUT -Path $specsRequestPath -Body $doc | Out-Null
        }
    }
}