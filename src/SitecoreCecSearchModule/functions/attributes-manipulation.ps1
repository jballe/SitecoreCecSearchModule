function Set-CecEntityConfigSuffixTemplate {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'false positive')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $Entity,

        [string]$Prefix = $Null,
        [string]$Suffix = $Null
    )

    process {
        $Entity.displayName = Add-SuffixTemplate -Value $Entity.displayName -Prefix $Prefix -Suffix $Suffix
        $Entity.name = Add-SuffixTemplate -Value $Entity.name -Prefix "${Prefix}".ToLower() -Suffix "${Suffix}".ToLower()

        $Entity
    }
}

function Set-CecEntityConfigSuffixValue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'false positive')]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $Entity,

        [string]$Prefix = $Null,
        [string]$Suffix = $Null
    )

    process {

        $Entity.displayName = Set-SuffixTemplateValue -Value $Entity.displayName -Prefix $Prefix -Suffix $Suffix
        $Entity.name = Set-SuffixTemplateValue -Value $Entity.name -Prefix "${Prefix}".ToLower() -Suffix "${Suffix}".ToLower()

        $Entity
    }
}