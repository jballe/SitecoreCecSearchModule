function Set-CecEntityConfigSuffixTemplate {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $Entity,

        [string]$Prefix = $Null,
        [string]$Suffix = $Null
    )

    $Entity.displayName = Add-SuffixTemplate -Value $Entity.displayName -Prefix $Prefix -Suffix $Suffix
    $Entity.name = Add-SuffixTemplate -Value $Entity.name -Prefix "${Prefix}".ToLower() -Suffix "${Suffix}".ToLower()

    $Entity
}

function Set-CecEntityConfigSuffixValue {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        $Entity,

        [string]$Prefix = $Null,
        [string]$Suffix = $Null
    )

    $Entity.displayName = Set-SuffixTemplateValues -Value $Entity.displayName -Prefix $Prefix -Suffix $Suffix
    $Entity.name = Set-SuffixTemplateValues -Value $Entity.name -Prefix "${Prefix}".ToLower() -Suffix "${Suffix}".ToLower()

    $Entity
}