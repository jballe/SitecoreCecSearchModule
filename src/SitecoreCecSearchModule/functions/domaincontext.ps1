function Get-CecDomain {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Url', Justification = 'false positive')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Name', Justification = 'false positive')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Region', Justification = 'false positive')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'AccountId', Justification = 'false positive')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Active', Justification = 'false positive')]
    param(
        $Url = $Null,
        $Name = $Null,
        $Region = $Null,
        $AccountId = $Null,
        $Active = $True
    )
    $result = Invoke-CecGlobalMethod -Path "/account/1/user/domains"
    $result = @() + $result | Where-Object { `
            $_.active -eq $Active -and `
        ($Null -eq $Url -or $_.url -eq $Url) -and `
        ($Null -eq $Name -or $_.name -eq $Name) -and `
        ($Null -eq $Region -or $_.region -eq $Region) -and `
        ($Null -eq $AccountId -or $_.account_id -eq $AccountId)
    }

    return $result
}

function Set-CecDomainContextBy {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function')]
    param(
        $Url = $Null,
        $Name = $Null,
        $Region = $Null,
        $AccountId = $Null,
        $Active = $True
    )

    $domain = Get-CecDomain -Url $Url -Name $Name -Region $Region -AccountId $AccountId -Active $Active

    if ($domain.Count -ne 1) {
        Write-Error ("Found {0} domains, must match a single domain" -f $domain.Count)
        return
    }

    $id = $domain.id
    Set-CecDomainContext -id $id
    Write-Information ("Successfully set CEC domain context to {0}" -f $id)
}