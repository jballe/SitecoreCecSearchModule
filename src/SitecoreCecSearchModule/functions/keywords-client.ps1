function Get-CecKeywordInfo {
    param(

    )

    $result = (Invoke-CecDomainMethod -Path "/microservices/common-editor/global/resources/keywords")
    $result
}
