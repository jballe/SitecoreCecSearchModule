function Add-CecSitemapQueryString {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        $QueryStringKey,
        $QueryStringValue
    )

    begin {
        $segment = ("{0}={1}" -f $QueryStringKey, $QueryStringValue)
    }

    process {
        if ($Connector.content.crawler.PSObject.Properties.Name -contains "webCrawlerConfig") {
            foreach ($trigger in $Connector.content.crawler.webCrawlerConfig.triggers) {
                $type = $trigger.type
                $obj = $trigger.$type
                if ($obj.PSObject.Properties.Name -contains "urls") {
                    $obj.urls = @() + ($obj.urls | ForEach-Object {
                        $url = $_
                        $index = $url.IndexOf("?")
                        if ($index -gt 0) {
                            $url += "&" + $segment
                        }
                        else {
                            $url += "?" + $segment
                        }
                        $url
                    })
                }
            }
        }

        $Connector
    }
}

function Remove-CecSitemapQueryString {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        $QueryStringKey
    )

    process {
        if ($Connector.content.PSObject.Properties.Name -contains "crawler" -and $Connector.content.crawler.PSObject.Properties.Name -contains "webCrawlerConfig") {
            foreach ($trigger in $Connector.content.crawler.webCrawlerConfig.triggers) {
                if ($trigger.PSObject.Properties.Name -notcontains "sitemap" -or $trigger.sitemap.PSObject.Properties.Name -notcontains "urls") {
                    continue
                }

                $trigger.sitemap.urls = $trigger.sitemap.urls | ForEach-Object {
                    $url = $_
                    $startIndex = $url.IndexOf("?")
                    if ($startIndex -gt 0) {
                        $segmentIndex = $url.IndexOf($QueryStringKey + "=", $startIndex)
                        if ($segmentIndex -gt 0) {
                            $endIndex = $url.IndexOf("&", $segmentIndex)
                            if ($endIndex -gt 0) {
                                $url = $url.Remove($segmentIndex, $endIndex)
                            }
                            else {
                                $url = $url.Remove($segmentIndex)
                            }
                        }

                        $url = $url.TrimEnd("&", "?")
                    }

                    $url
                }
            }
        }

        $Connector
    }
}

function Add-CecCrawlerHeader {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        $HeaderKey,
        $HeaderValue
    )

    process {

        $requestObjs = $Null
        if ($Connector.content.crawler.PSObject.Properties.Name -contains "webCrawlerConfig") {
            $requestObjs = @($Connector.content.crawler.webCrawlerConfig)
        }
        elseif ($Connector.content.crawler.PSObject.Properties.Name -contains "apiCrawlerConfig" -and $Connector.content.crawler.apiCrawlerConfig.PSObject.Properties.Name -contains "triggers") {
            $requestObjs = $Connector.content.crawler.apiCrawlerConfig.triggers | ForEach-Object { [PSCustomObject]$_.request }
        }

        foreach ($obj in $requestObjs | Where-Object { $_ -ne $Null }) {
            if ($obj.PSObject.Properties.Name -notcontains "headers") {
                $obj | AddOrSetPropertyValue -PropertyName "headers" -Value @{
                    $HeaderKey = @() + @($HeaderValue)
                } | Out-Null
            }
            elseif ($obj.headers.GetType().Name -eq "Hashtable") {
                $obj.headers[$HeaderKey] = @() + @($HeaderValue)
            }
            elseif ($obj.headers.GetType().Name -eq "PSCustomObject") {
                $obj.headers | AddOrSetPropertyValue -PropertyName $HeaderKey -Value @($HeaderValue)
            }
            else {
                Write-Warning ("Unexpected type in Add-CecCrawlerHeader: {0}" -f $obj.headers.GetType().Name)
                $obj.headers[$HeaderKey] = @() + @($HeaderValue)
            }
        }

        $Connector
    }
}

function Remove-CecCrawlerHeader {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        $HeaderKey
    )

    process {
        $requestObjs = $Null
        if ($Connector.content.PSObject.Properties.Name -contains "crawler" -and $Connector.content.crawler.PSObject.Properties.Name -contains "webCrawlerConfig") {
            $requestObjs = @($Connector.content.crawler.webCrawlerConfig)
        }
        elseif ($Connector.content.PSObject.Properties.Name -contains "crawler" -and $Connector.content.crawler.PSObject.Properties.Name -contains "apiCrawlerConfig" -and $Connector.content.crawler.apiCrawlerConfig.PSObject.Properties.Name -contains "triggers") {
            $requestObjs = $Connector.content.crawler.apiCrawlerConfig.triggers | Select-Object -ExpandProperty "request"
        }

        foreach ($obj in $requestObjs | Where-Object { $_ -ne $Null }) {
            if ($obj.PSObject.Properties.Name -contains "headers" -and $obj.headers.PSObject.Properties.Name -contains $HeaderKey) {
                $obj.headers.PSObject.Properties.Remove($HeaderKey)
            }    
        }

        $Connector
    }
}

function Add-CecConnectorVercelBypassProtection {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector,
        $BypassProtectionKey
    )

    begin {
        $vercelKey = "x-vercel-protection-bypass"
    }

    process {
        if ("${BypassProtectionKey}" -eq "") {
            return $Connector
        }

        $Connector `
        | Add-CecCrawlerHeader -HeaderKey $vercelKey -HeaderValue $BypassProtectionKey `
        | Add-CecSitemapQueryString -QueryStringKey $vercelKey -QueryStringValue $BypassProtectionKey
    }
}

function Remove-CecConnectorVercelBypassProtection {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]$Connector
    )

    begin {
        $vercelKey = "x-vercel-protection-bypass"
    }

    process {
        $Connector `
        | Remove-CecCrawlerHeader -HeaderKey $vercelKey `
        | Remove-CecSitemapQueryString -QueryStringKey $vercelKey
    }
}
