function Get-CecDomainConfig {
    param(
        $Domain = "{domain}"
    )

    (Invoke-CecDomainMethod -Path "/microservices/common-editor/domains/${Domain}").domain
}

function Get-CecCustomerKey {
    param(
        $Domain = "{domain}"
    )

    $config = Get-CecDomainConfig -Domain $Domain
    return @($config.accountId, $config.domainId) -join "-"
}
