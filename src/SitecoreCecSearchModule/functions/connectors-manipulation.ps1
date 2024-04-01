function Add-CecConnectorPrefix {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        [String]$Suffix = "",
        [String]$Prefix = "",
        [String]$Domain = "",
        [String]$ScriptToken = "" ,
        [String]$TextToken = "",
        [String]$DomainReplacement = "https://domain",
        [String]$ScriptReplacement = "{ENV}",
        [String]$TextReplacement = "{ENV}",
        [Hashtable]$Domains = @{}
    )

    begin {
        if ("${Domain}" -ne "" -and "${DomainReplacement}" -ne "") {
            $Domains[$Domain] = $DomainReplacement
        }
    }

    process {
        $Connector.name = Add-Suffix -Value $Connector.name -Prefix $Prefix -Suffix $Suffix

        $params = @{
            Domains  = $Domains
            TextFrom = $TextReplacement
            TextTo   = $TextToken
        }
        if ("${ScriptToken}" -ne "") {
            $params.ScriptTo = ("'{0}'" -f $ScriptToken)
            $params.ScriptFrom = ("'{0}'" -f $ScriptReplacement)
        }
        $Connector | Invoke-CecConnectorReplacement @params | Out-Null

        return $Connector
    }
}

function Remove-CecConnectorPrefix {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        [String]$Suffix = "",
        [String]$Prefix = "",
        [String]$Domain = "",
        [String]$ScriptToken = "" ,
        [String]$TextToken = "",
        [String]$DomainReplacement = "https://domain",
        [String]$ScriptReplacement = "{ENV}",
        [String]$TextReplacement = "{ENV}",
        [Hashtable]$Domains,
        [Switch]$KeepIds
    )

    begin {
        if ("${Domain}" -ne "" -and "${DomainReplacement}" -ne "") {
            $Domains[$DomainReplacement] = $Domain
        }
    }

    process {
        $Connector.name = Remove-Suffix -Value $Connector.name -Prefix $Prefix -Suffix $Suffix
        if (-not $KeepIds) {
            $Connector.PSObject.Properties.Remove('connectorId')
            if ($Connector.PSObject.Properties.Name.Contains("content")) {
                $Connector.content.PSObject.Properties.Remove('externalId')
            }
        }

        $params = @{
            Domains  = $Domains
            TextFrom = $TextToken
            TextTo   = $TextReplacement
        }
        if ("${ScriptToken}" -ne "") {
            $params.ScriptFrom = @(
                ("'{0}'" -f $ScriptToken),
                ('"{0}"' -f $ScriptToken)
            )
            $params.ScriptTo = ("'{0}'" -f $ScriptReplacement)
        }
        $result = $Connector `
        | Invoke-CecConnectorReplacement @params `
        | Remove-CecConnectorUserDate

        return $result
    }
}

function Set-CecConnectorCrawlerSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        [ValidateSet('hour', 'day', 'week', $null)]
        $Frequency = $null,
        $Interval = $null
    )

    process {
        if (-not $Connector.PSObject.Properties.Name.Contains("content")) {
            return $Connector
        }

        if (-not $Connector.content.PSObject.Properties.Name.Contains("crawler")) {
            return $Connector
        }

        if (-not $Connector.content.crawler.PSObject.Properties.Name.Contains("recurrence")) {
            return $Connector
        }

        if ($Null -ne $Frequency) {
            $Connector.content.crawler.recurrence.frequency = $Frequency
        }

        if ($Null -ne $Interval) {
            $Connector.content.crawler.recurrence.interval = $Interval
        }
        
        return $Connector
    }
}

function Invoke-CecConnectorReplacement {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        [hashtable]$Domains = @(),
        [String]$DomainTo,
        [String]$TextFrom,
        [String]$TextTo,
        [Array]$ScriptFrom,
        [String]$ScriptTo
    )

    process {

        if ($Null -eq $Domains) {
            return $Connector
        }

        foreach ($domainValue in $Domains.Keys) {
            $domainTo = $Domains[$domainValue]
            if ("${domainValue}" -ne "" -and "${domainTo}" -ne "") {
                $Connector.description = $Connector.description.Replace("${domainValue}", "${domainTo}")

                $crawlerTypes = @("webCrawlerConfig", "apiCrawlerConfig")
                foreach ($crawlerType in $crawlerTypes) {
                    if (-not $Connector.content.PSObject.Properties.Name.Contains('crawler')) {
                        continue
                    }

                    if (-not $Connector.content.crawler.PSObject.Properties.Name.Contains($crawlerType)) {
                        continue
                    }

                    $crawlerConfig = $Connector.content.crawler.$crawlerType
                    if ($crawlerConfig.PSObject.Properties.Name.Contains("triggers")) {
                        foreach ($t in $crawlerConfig.triggers) {
                            if ($t.PSObject.Properties.Name.Contains("sitemapIndex")) {
                                $t.sitemapIndex.urls = [Array]($t.sitemapIndex.urls | ForEach-Object { $_.Replace($domainValue, $domainTo) })
                            }
                            if ($t.PSObject.Properties.Name.Contains("sitemap")) {
                                $t.sitemap.urls = [Array]($t.sitemap.urls | ForEach-Object { $_.Replace($domainValue, $domainTo) })
                            }
                            if ($t.PSObject.Properties.Name.Contains("request")) {
                                $t.request.url = $t.request.url.Replace($domainValue, $domainTo)
                            }
                        }
                    }

                    if ($crawlerConfig.PSObject.Properties.Name -contains "extractors") {
                        $documents = $crawlerConfig.extractors.documents
                        foreach ($doc in $documents) {
                            foreach ($tagger in $doc.taggers) {
                                if ($tagger.PSObject.properties.Name -contains "source") {
                                    $tagger.source = $tagger.source.Replace($domainValue, $domainTo)
                                }
                            }
                        }
                    }
                }
            }
        }

        if ("${TextFrom}" -ne "" -and "${TextTo}" -ne "") {
            $Connector.description = $Connector.description.Replace("${TextFrom}", "${TextTo}")
        }

        foreach ($scriptValue in $ScriptFrom) {

            if ("${scriptValue}" -ne "" -and "${ScriptTo}" -ne "") {
                $crawlerTypes = @("webCrawlerConfig", "apiCrawlerConfig")
                foreach ($crawlerType in $crawlerTypes) {
                    if (-not $Connector.content.PSObject.Properties.Name.Contains('crawler')) {
                        continue
                    }

                    if (-not $Connector.content.crawler.PSObject.Properties.Name.Contains($crawlerType)) {
                        continue
                    }

                    $crawlerConfig = $Connector.content.crawler.$crawlerType
                    if ($crawlerConfig.PSObject.Properties.Name -contains "extractors") {
                        $documents = $crawlerConfig.extractors.documents
                        foreach ($doc in $documents) {
                            foreach ($tagger in $doc.taggers) {
                                if ($Null -ne $tagger -and $tagger.PSObject.Properties.Name -contains "source" -and $Null -ne $tagger.Source) {
                                    $tagger.Source = $tagger.Source.Replace($scriptValue, $ScriptTo)
                                }
                            }
                        }
                    }
                }
            }
        }

        $Connector
    }
}

function Update-CecConnectorModelWithId {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,

        $ConnectorWithIds,

        [Switch]$FetchConnectorWithSameName
    )

    process {
        if ($FetchConnectorWithSameName) {
            try {
                $ConnectorWithIds = Get-CecConnector -name $Connector.name
            }
            catch {
                Write-Information ("Could not get connector with name {0}" -f $Connector.name)
            }
        }

        if ($Null -eq $ConnectorWithIds) {
            Write-Information "No TargetConnector specified so no changes"
            return $Connector
        }

        $Connector | AddOrSetPropertyValue -PropertyName "connectorId" -Value $ConnectorWithIds.connectorId
        $Connector | AddOrSetPropertyValue -PropertyName "status" -Value  $ConnectorWithIds.status
        $Connector.content | AddOrSetPropertyValue -PropertyName "externalId" -Value  $ConnectorWithIds.content.externalId

        return ($Connector | Update-CecConnectorVersion -ConnectorWithVersion $ConnectorWithIds)
    }
}

function Update-CecConnectorVersion {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        $ConnectorWithVersion
    )

    process {

        if($null -eq $ConnectorWithVersion) {
            $ConnectorWithVersion = $Connector
        }

        $newVersion = $ConnectorWithVersion.version
        if ($ConnectorWithVersion.status -ne "draft") {
            $newVersion = $ConnectorWithVersion.version + 1
        }
        $Connector | AddOrSetPropertyValue -PropertyName "version" -Value $newVersion

        return $Connector
    }
}

function Remove-CecConnectorUserDate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector
    )

    process {
        $Connector.PSObject.Properties.Remove('createdAt')
        $Connector.PSObject.Properties.Remove('updatedAt')
        $Connector.PSObject.Properties.Remove('userId')
        $Connector.PSObject.Properties.Remove('version')
        $Connector.PSObject.Properties.Remove('status')
        $Connector.PSObject.Properties.Remove('isValid')
        $Connector.PSObject.Properties.Remove('operation')
        $Connector.PSObject.Properties.Remove('live')

        return $Connector
    }
}
