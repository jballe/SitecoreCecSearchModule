function Write-CecConnector {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        [Parameter(Mandatory)][String]$Path,
        $Suffix = "",
        $Prefix = "",
        [Switch]$Subfolder,
        [Switch]$SkipFiles,
        [Switch]$RemoveDates
    )

    begin {
        $suffixesAreSpecified = SuffixIsSpecified -Prefix $Prefix -Suffix $Suffix
    }

    process {

        $destinationPath = $Path
        if ($Subfolder) {
            $destinationPath = join-path $destinationPath (Remove-Suffix -Value $Connector.name -Suffix $Suffix -Prefix $Prefix)
        }

        if ($Connector.PSObject.Properties.Name -contains "connectorId") {
            Write-Information ("Writing connector {0} ({1}) to {2}" -f $Connector.name, $Connector.connectorId, $destinationPath)
        }
        else {
            Write-Information ("Writing connector {0} to {1}" -f $Connector.name, $destinationPath)
        }

        If (-not (Test-Path $destinationPath -PathType Container)) {
            New-item $destinationPath -ItemType Directory | Out-Null
        }

        $obj = $Connector | ConvertTo-Json -Depth 15 | ConvertFrom-Json

        if (-not $SkipFiles) {

            if ($suffixesAreSpecified) {
                $obj = Remove-CecConnectorPrefix -Connector $obj -Prefix $Prefix -Suffix $Suffix
            }

            if ($RemoveDates) {
                $obj = Remove-CecConnectorUserDates -Connector $obj
            }

            $crawlerTypes = @("webCrawlerConfig", "apiCrawlerConfig")
            foreach ($crawlerType in $crawlerTypes) {

                if (-not $obj.content.PSObject.Properties.Name.Contains('crawler')) {
                    continue
                }

                if (-not $obj.content.crawler.PSObject.Properties.Name.Contains($crawlerType)) {
                    continue
                }

                $crawlerConfig = $obj.content.crawler.$crawlerType
                if ($crawlerConfig.PSObject.Properties.Name -contains "extractors") {
                    $documents = $crawlerConfig.extractors.documents
                    $docIndex = 0
                    foreach ($doc in $documents) {
                        foreach ($tagger in $doc.taggers) {
                            Write-Tagger -ConnectorPath $destinationPath -DocumentExtractor $doc -Index $docIndex -Tagger $tagger
                        }

                        $docIndex++
                    }
                }

                if ($crawlerConfig.PSObject.Properties.Name -contains "triggers") {
                    $triggers = $crawlerConfig.triggers
                    $triggerIndex = 0
                    foreach ($trigger in $triggers) {
                        Write-Trigger -ConnectorPath $destinationPath -BaseKey "trigger_${triggerIndex}" -Trigger $trigger
                        $triggerIndex++
                    }
                }
            }
        }

        Set-Content -Path (Join-Path $destinationPath "connector.json") -Value (ConvertTo-Json -InputObject $obj -Depth 15)
    }
}

function Read-CecConnector {
    [CmdletBinding()]
    param(
        [ValidateScript({ Test-Path $_ -PathType Container })][Parameter(Mandatory)]
        [String]$Path,
        [Switch]$SkipFiles
    )

    $connectorPath = Join-Path $Path "connector.json"
    If (-not (Test-Path $connectorPath -PathType Leaf)) {
        Write-Error "Required file ${connectorPath}"
        return
    }

    $connector = Get-Content $connectorPath | ConvertFrom-Json

    if (-not $SkipFiles) {
        $crawlerTypes = @("webCrawlerConfig", "apiCrawlerConfig")
        foreach ($crawlerType in $crawlerTypes) {
            if (-not $connector.content.crawler.PSObject.Properties.Name.Contains($crawlerType)) {
                continue
            }

            $crawlerConfig = $connector.content.crawler.$crawlerType
            if ($crawlerConfig.PSObject.Properties.Name -contains "extractors") {
                $documents = $crawlerConfig.extractors.documents
                $docIndex = 0
                foreach ($doc in $documents) {
                    foreach ($tagger in $doc.taggers) {
                        Read-Tagger -ConnectorPath $Path -DocumentExtractor $doc -Index $docIndex -Tagger $tagger
                    }

                    $docIndex++
                }
            }

            if ($crawlerConfig.PSObject.Properties.Name -contains "triggers") {
                $triggers = $crawlerConfig.triggers
                $triggerIndex = 0
                foreach ($trigger in $triggers) {
                    Read-Trigger -ConnectorPath $Path -BaseKey "trigger_${triggerIndex}" -Trigger $trigger
                    $triggerIndex++
                }
            }
        }
    }

    $connector
}


function Write-Tagger {
    param(
        $ConnectorPath,
        $Tagger,
        $DocumentExtractor,
        $Index
    )

    $type = $DocumentExtractor.type
    $tag = $Tagger.tag
    $fileName = "extractor_${Index}_${tag}.${type}"
    $taggerPath = (Join-Path $ConnectorPath $fileName)
    if ($Null -ne $Tagger -and $Tagger.PSObject.Properties.Name -contains "source" -and $Null -ne $Tagger.Source) {
        $source = ($Tagger.source).Replace("\r\n", "`n").Replace("\n", "`n")
        Set-Content -Value $source -Path $taggerPath
        $tagger.source = "<exported to ${fileName}>"
    }
}

function Read-Tagger {
    param(
        $ConnectorPath,
        $Tagger,
        $DocumentExtractor,
        $Index
    )

    $type = $DocumentExtractor.type
    $tag = $Tagger.tag
    $fileName = "extractor_${Index}_${tag}.${type}"
    $taggerPath = (Join-Path $ConnectorPath $fileName)
    if (Test-Path $taggerPath) {
        $Tagger.source = (Get-Content $taggerPath -Raw).Trim()
    }
}

function Write-Trigger {
    param(
        $ConnectorPath,
        $BaseKey,
        $Trigger
    )

    $type = $Trigger.type
    if ($type -eq "request" -and $Null -ne $trigger.request) {
        $fileName = "${BaseKey}_${type}.http"
        $filePath = Join-Path $ConnectorPath $fileName

        $method = "GET"
        if ($trigger.request.PSObject.Properties.Name -contains "method") {
            $method = $trigger.request.method
        }

        $url = $trigger.request.url
        $fileContent = "${method} ${url}`n"

        if ($trigger.request.PSObject.Properties.Name -contains "headers") {
            $headers = $trigger.request.headers
            foreach ($key in $headers.PSObject.Properties.Name) {
                $values = $headers.$key
                foreach ($value in $values) {
                    $fileContent += "${key}: ${value}`n"
                }
            }
        }

        if ($trigger.request.PSObject.Properties.name -contains "body") {
            $body = $trigger.request.body.Replace("\r\n", "`n").Replace("\n", "`n")
            $fileContent += "`n${body}"
        }

        Set-Content -Path $filePath -Value $fileContent
        $trigger.request = "<exported to ${fileName}>"
    }
    else {
        foreach ($p in $Trigger.PSObject.Properties.Name) {
            if (-not $Trigger.$p.PSObject.Properties.Name.Contains("urls")) {
                continue
            }

            $obj = $Trigger.$p
            $obj.urls = [Array]$obj.urls
        }
    }
}

function Read-Trigger {
    param(
        $ConnectorPath,
        $BaseKey,
        $Trigger
    )

    $type = $Trigger.type
    $filePath = Join-Path $ConnectorPath "${BaseKey}_${type}.http"
    If (Test-Path $filePath) {
        $body = ""
        $method = $Null
        $url = $Null
        $headers = @{}
        $fileContent = Get-Content $filePath
        $isBody = $false
        foreach ($line in $fileContent) {
            if (-not $isBody) {
                if ($line.StartsWith("#")) { continue }
                if ($line.Trim() -eq "") {
                    $isBody = $true
                    continue
                }
                if ($null -eq $method) {
                    $index = $line.IndexOf(" ")
                    $method = $line.Substring(0, $index).Trim()
                    $url = $line.Substring($index + 1).Trim()
                }
                else {
                    $index = $line.IndexOf(":")
                    $key = $line.Substring(0, $index)
                    $value = $line.Substring($index + 1).Trim()
                    $headers[$key] ??= @()
                    $headers[$key] = @(, $value) + $headers[$key]
                }
            }
            else {
                $body += $line + "\n"
            }
        }

        # Remove the last \n
        while ($body.EndsWith("\n")) {
            $body = $body.Substring(0, $body.Length - 2)
        }

        $trigger.request = @{
            method  = $method
            url     = $url
            headers = $headers
            body    = $body.Trim()
        }
    }
    else {
        foreach ($p in $Trigger.PSObject.Properties.Name) {
            if (-not $Trigger.$p.PSObject.Properties.Name.Contains("urls")) {
                continue
            }

            $obj = $Trigger.$p
            $obj.urls = [Array]$obj.urls
        }
    }
}