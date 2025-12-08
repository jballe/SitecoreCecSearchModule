function Get-CecWidgetInfo {
    param(
        $Sort = "-updatedAt",
        $Filter,
        [Switch]$GlobalWidgets,
        [Switch]$PreviewSearch,
        [Switch]$Recommendation,
        [Switch]$ContentGrid,
        [Switch]$Banner,
        [Switch]$HtmlBlock,
        [Switch]$EmailRecommendation,
        [Switch]$TriggerStrip
    )

    if ("${Filter}" -eq "") {
        $types = @()
        if ($GlobalWidgets) { $types += @{ "type" = "global" } }
        if ($PreviewSearch) { $types += @{ "type" = "preview_search" } }
        if ($Recommendation) { $types += @{ "type" = "recommendation" } }
        if ($ContentGrid) { $types += @{ "type" = "content_grid" } }
        if ($Banner) { $types += @{ "type" = "banner" } }
        if ($HtmlBlock) { $types += @{ "type" = "html_block" } }
        if ($EmailRecommendation) { $types += @{ "type" = "email_recommendation" } }
        if ($TriggerStrip) { $types += @{ "type" = "trigger_strip" } }

        if ($types.Length -gt 0) {
            $json = @{
                "`$or" = $types
            } | ConvertTo-Json -Compress
            $Filter = [uri]::EscapeUriString($json)
        }
    }

    $url = "/microservices/common-editor/widgets?filter={0}&sort={1}" -f $Filter, $Sort
    Invoke-CecDomainMethod -Path $url | Select-Object -ExpandProperty "widgets"
}

function Get-CecWidget {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]$WidgetId
    )

    process {
        if ("${WidgetId}" -eq "") {
            return
        }

        $widget = (Invoke-CecDomainMethod -Path "/microservices/common-editor/widgets/${WidgetId}").widget
        $Widget.PSObject.Properties.Remove('variations')
        $variations = (Invoke-CecDomainMethod -Path "/microservices/common-editor/widgets/${WidgetId}/variations").variations
        $widget | AddOrSetPropertyValue -PropertyName "variations" -Value $variations
        $widget
    }
}
