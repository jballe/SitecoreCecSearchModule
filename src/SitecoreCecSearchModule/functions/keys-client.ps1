function Get-CecApiKey {
    param(

    )

    (Invoke-CecDomainMethod -Path "/api-keys" -DomainScope "admin" -Version "1")
}
