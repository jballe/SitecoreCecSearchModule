function Get-CecFeatures {
    [CmdletBinding(DefaultParameterSetName='-Current')]
    param(
        [Parameter(ParameterSetName='-Current')][Switch]$Current,
        [Parameter(ParameterSetName='-Live')][Switch]$Live,
        [Parameter(ParameterSetName='-All')][Switch]$All
    )

    $result = (Invoke-CecDomainMethod -Path "/microservices/common-editor/configs/current/features").features
    if($All) {
        return $result
    }

    if($Live) {
        return $result.live.search
    }

    return $result.search
}

function Set-CecFeatures {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Features,
        [Switch]$Force,
        [Switch]$Publish
    )

    process {
        $existing = Get-CecFeatures -All

        $body = @{
            featureConfigId = $existing.featureConfigId
            version = $existing.version
            search = $existing.search
        }

        $urlPath = "/microservices/common-editor/configs/current/features"

        if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
            $result = Invoke-CecDomainMethod -Path $urlPath -Method PUT -Body $body
        }
        else {
            Write-Information ("Would have called PUT on ${urlPath} with body:`n{0}" -f ($Connector | ConvertTo-Json -Depth 30))
        }

        $result.features
    }
}
