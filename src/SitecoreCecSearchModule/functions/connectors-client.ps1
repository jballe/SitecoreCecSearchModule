function Get-CecConnectorsInfo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Prefix', Justification = 'false positive')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Suffix', Justification = 'false positive')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Name', Justification = 'false positive')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        $Prefix = $Null,
        $Suffix = $Null,
        $Name = $Null,
        [Switch]$Force
    )

    $urlPath = "/microservices/common-editor/connectors"

    if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
        $result = (Invoke-CecDomainMethod -Path $urlPath).connectors
        Write-Verbose ("Received {0} connectors" -f $result.Length)
        $result = $result `
        | Where-Object { $Null -eq $Prefix -or $_.name -like "${Prefix}*" } `
        | Where-Object { $Null -eq $Suffix -or $_.name -like "*${Suffix}" } `
        | Where-Object { $Null -eq $Name -or $_.name -eq $Name }
        return $result
    }
    else {
        Write-Information "Would have made request for $urlPath"
    }
}

function Get-CecConnectorInfo {
    param(
        [Parameter(Mandatory)]
        $Name
    )

    $connector = Get-CecConnectorsInfo -Name $Name

    if ($Null -eq $connector -or $connector.Length -ne 1) {
        Write-Error ("Found {0} connector, must match a single source" -f $connector.Count)
        return
    }

    $connector[0]
}

function Get-CecConnector {
    param(
        [Parameter(ValueFromPipeline)][object]$Connector,
        [string]$Id = $Null,
        [string]$Name = $Null
    )

    process {
        $id = $Id

        if ($Null -ne $Connector -and $Connector.PSObject.Properties.Name -contains "connectorId") {
            $id = $Connector.connectorId
        }
        if ("${id}" -eq "") {
            $info = Get-CecConnectorInfo -Name $Name
            if ($Null -eq $info) { return }
            $id = $info.connectorId
        }

        if ("${id}" -eq "") {
            Write-Error "Missing connector id"
            return
        }

        $result = (Invoke-CecDomainMethod -Path "/microservices/common-editor/connectors/${Id}").connector
        Write-Verbose ("Fetched connector {0}: {1}" -f $result.connectorId, $result.name)
        return $result
    }
}

function Set-CecConnector {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $Connector,

        [Switch]$Publish,

        [Switch]$Force
    )

    process {
        $url = "/microservices/common-editor/connectors"
        $versionPath = ""

        $id = $null
        if ($Connector.PSObject.Properties.Name -contains "connectorId" -and $Null -ne $Connector.connectorId) {
            $id = $Connector.connectorId
        }

        try {
            if ($Null -eq $id) {
                $obj = $Connector | ConvertTo-Json -Depth 15 | ConvertFrom-Json
                $obj.content.PSObject.Properties.Remove("crawler")
                $result = Invoke-CecDomainMethod -Path $url -Method POST -Body $obj
                $id = $result.connector.connectorId
                $Connector | Update-CecConnectorModelWithIds -ConnectorWithIds $result
            }

            $urlPath = "${url}/${id}${versionPath}"
            if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
                $result = Invoke-CecDomainMethod -Path $urlPath -Method PUT -Body $Connector
            }
            else {
                Write-Information ("Would have called PUT on ${urlPath} with body:`n{0}" -f ($Connector | ConvertTo-Json -Depth 30))
            }

            if ($Publish) {
                try {
                    Publish-CecConnector -ConnectorId $result.connector.connectorId -Force:$Force
                }
                catch {
                    Write-Warning ("Could not publish connector {1} ({2}) due to {0}" -f $_, $Connector.name, $id)
                }
            }
        }
        catch {
            Write-Error ("Error during Set-CecConnector due to {0}" -f $_)
        }
    }
}

function Remove-CecConnector {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        $ConnectorId,

        [Switch]$Force
    )

    $urlPath = "/microservices/common-editor/connectors/${ConnectorId}"
    if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
        Invoke-CecDomainMethod -Path $urlPath -Method DELETE
    }
    else {
        Write-Information "Would have made DELETE request to $urlPath"
    }
}

function Publish-CecConnector {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]$ConnectorId,
        [Switch]$Force
    )

    $url = "/microservices/common-editor/connectors/${ConnectorId}/versions/draft"
    if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
        Invoke-CecDomainMethod -Path $url -Method POST | Out-Null
    }
    else {
        Write-Information "Would have made POST request to $url"
    }
}

function Start-CecConnectorRescan {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline)]$Connector,
        $ConnectorId,
        $ConnectorType
    )

    process {

        if ($Null -ne $Connector) {
            $ConnectorId = $Connector.connectorId
            $ConnectorType = $Connector.content.type
        }

        $body = @{
            job = @{
                type   = $ConnectorType
                source = @{
                    connector = @{
                        id = $ConnectorId
                    }
                }
            }
        }

        $urlPath = "/microservices/job-orchestrator/jobs"
        if ($Force -or $PSCmdlet.ShouldProcess("SitecoreCeCSearch", 'Send request to service')) {
            Invoke-CecDomainMethod -Path $urlPath -Method POST -Body $body
        }
        else {
            Write-Information ("Would have called PUT on ${urlPath} with body:`n{0}" -f ($body | ConvertTo-Json -Depth 30))
        }
    }
}

function Get-CecConnectorJobStatus {
    param(
        $ConnectorId,
        $Limit = 1,
        $Sort = "-createdAt"
    )

    Get-CecJobStatus -Filter @{ connectorId = $ConnectorId } -Limit $Limit -Sort $Sort
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
