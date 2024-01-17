function Get-CecDnsEntry {
    (Invoke-CecDomainMethod -Path "/domain/dns-entries" -DomainScope "portal" -Version "1")
}

function Get-CecEndpoint {
    param(
        $Type = "discover"
    )

    $domains = Get-CecDnsEntry
    $apiHost = $domains.apis.$Type.url
    if($domains.status -eq "PENDING") {
        $apiHost = $domains.apis.$Type.defaultUrl
    }

    return $apiHost
}
