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

                    if ($crawlerConfig.extractors.PSObject.Properties.Name -contains "locales") {
                        $locales = $crawlerConfig.extractors.locales
                        $localesIndex = 0
                        foreach ($locale in $locales | Where-object { $_.type -eq "js" }) {
                            Write-LocaleExtractor -ConnectorPath $destinationPath -LocaleObj $locale -Type $locale.type -Index $localesIndex
                            $localesIndex++
                        }
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

        if (-not $connector.content.PSObject.Properties.Name.Contains("crawler")) {
            continue
        }

        $crawlerTypes = @("webCrawlerConfig", "apiCrawlerConfig")
        foreach ($crawlerType in $crawlerTypes) {
            if (-not $connector.content.crawler.PSObject.Properties.Name.Contains($crawlerType)) {
                continue
            }

            $crawlerConfig = $connector.content.crawler.$crawlerType
            if ($crawlerConfig.PSObject.Properties.Name -contains "extractors") {
                $documents = $crawlerConfig.extractors.documents
                foreach ($doc in $documents) {
                    foreach ($tagger in $doc.taggers) {
                        Read-Tagger -ConnectorPath $Path -Tagger $tagger
                    }
                }

                if ($crawlerConfig.extractors.PSObject.Properties.Name -contains "locales") {
                    foreach ($locale in $crawlerConfig.extractors.locales) {
                        Read-LocaleExtractor -ConnectorPath $Path -LocaleObj $locale
                    }
                }
            }

            if ($crawlerConfig.PSObject.Properties.Name -contains "triggers") {
                $triggers = $crawlerConfig.triggers
                foreach ($trigger in $triggers) {
                    Read-Trigger -ConnectorPath $Path -Trigger $trigger
                }
            }
        }
    }

    $connector
}

$taggerSuffix = "`nmodule.exports = { extract };`n"

function Write-InlineSourceFunction {
    param(
        $FilePath,
        $Obj,
        $Type
    )

    if ($Null -ne $Obj -and $Obj.PSObject.Properties.Name -contains "source" -and $Null -ne $Obj.source) {
        $source = ($Obj.source).Replace("\r\n", "`n").Replace("\n", "`n")
        if ($Type -eq "js") {
            $source += $taggerSuffix
        }

        Set-Content -Value $source -Path $FilePath
        $Obj.source = "<exported to ${fileName}>"
    }
}

function Read-ExportedFilePath {
    param(
        $Value,
        $BasePath
    )

    if (-not ($Value -match "\<exported to (.*?\.(js|http))\>")) {
        return
    }

    $fileName = $Matches[1]
    $fullPath = (Join-Path $BasePath $fileName)
    if (Test-Path $fullPath) {
        return $fullPath
    }
}

function Read-InlineSourceFunction {
    param(
        $BasePath,
        $Obj
    )

    if ($Null -eq $Obj -or $Obj.PSObject.Properties.Name -notcontains "source" -or $Null -eq $Obj.Source) {
        return
    }

    $fullPath = Read-ExportedFilePath -BasePath $BasePath -Value $Obj.source
    $result = (Get-Content $fullPath -Raw).Trim().Replace($taggerSuffix.Trim(), "").Replace("`r`n", "`n")
    $Obj.source = $result
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
    Write-InlineSourceFunction -FilePath $taggerPath -Obj $Tagger -Type $type
}

function Read-Tagger {
    param(
        $ConnectorPath,
        $Tagger
    )

    Read-InlineSourceFunction -BasePath $ConnectorPath -Obj $Tagger
}

function Write-LocaleExtractor {
    param(
        $ConnectorPath,
        $LocaleObj,
        $Index,
        $Type
    )

    $fileName = "locales_${Index}.${type}"
    $filePath = (Join-Path $ConnectorPath $fileName)
    Write-InlineSourceFunction -FilePath $filePath -Obj $LocaleObj -Type $Type
}

function Read-LocaleExtractor {
    param(
        $ConnectorPath,
        $LocaleObj
    )

    Read-InlineSourceFunction -BasePath $ConnectorPath -Obj $LocaleObj
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
            if ($Null -ne $headers -and @($headers.PSObject.Properties).Count -gt 0) {
                foreach ($key in $headers.PSObject.Properties.Name) {
                    $values = $headers.$key
                    foreach ($value in $values) {
                        $fileContent += "${key}: ${value}`n"
                    }
                }
            }
        }

        if ($trigger.request.PSObject.Properties.Name -contains "body") {
            $body = $trigger.request.body.Replace("\r\n", "`n").Replace("\n", "`n")
            $fileContent += "`n${body}"
        }

        Set-Content -Path $filePath -Value $fileContent.TrimEnd()
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
        $Trigger
    )

    $type = $Trigger.type
    if($Trigger.PSObject.Properties.Name -contains $Type) {
        $filePath = Read-ExportedFilePath -BasePath $ConnectorPath -Value $Trigger.$Type
    } else {
        $filePath = $Null
    }

    If ($Null -ne $filePath -and (Test-Path $filePath)) {
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
                $body += $line + "`n"
            }
        }

        # Remove the last \n
        $body = $body.TrimEnd()

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