function Get-CecConnectorJobStatus {
    param(
        [Parameter(ValueFromPipelineByPropertyName)]$ConnectorId,
        [Parameter(ValueFromPipelineByPropertyName)]$Name,
        $Limit = 1,
        $Sort = "-createdAt"
    )

    process {
        $result = Get-CecJobStatus -Filter @{ connectorId = $ConnectorId } -Limit $Limit -Sort $Sort
        $result | Add-Member -Name "connectorId" -Type NoteProperty -Value $ConnectorId
        $result | Add-Member -Name "name" -Type NoteProperty -Value $Name
        return $result
    }
}

function Get-CecJobStatus {
    param(
        $Filter,
        $Limit = 1,
        $Sort = "-createdAt"
    )

    $url = "/microservices/job-orchestrator/jobs?limit=${Limit}&sort=${Sort}"

    if ($Null -ne $Filter) {
        $url += "&filter=" + [System.Web.HttpUtility]::UrlEncode( $($Filter | ConvertTo-Json -Compress) )
    }

    Invoke-CecDomainMethod -Path $url | Select-Object -ExpandProperty jobs
}

function Get-CecJobErrors {
    param(
        [Parameter(ValueFromPipelineByPropertyName)]$JobId,
        [Parameter(ValueFromPipeline)]$Job
    )

    process {
        $result = Invoke-CecDomainMethod -Path "/microservices/job-orchestrator/jobs/${JobId}/errors"
        $result | Add-Member -Name "job" -Type NoteProperty -Value $Job
        return $result
    }
}
