function SuffixIsSpecified {
    Param(
        [string]$Prefix,
        [string]$Suffix
    )

    return ("${Prefix}" -ne "") -or ("${Suffix}" -ne "")
}

function Remove-Suffix {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function')]
    Param(
        [string]$Value,
        [string]$Prefix,
        [string]$Suffix
    )

    if ("${Prefix}" -ne "" -and $Value -ilike "${Prefix}*") {
        $Value = $Value.Substring($Prefix.Length)
    }

    if ("${Suffix}" -ne "" -and $Value -ilike "*${Suffix}") {
        $Value = $Value.Substring(0, $Value.Length - $Suffix.Length)
    }

    $Value
}

function Add-Suffix {
    Param(
        [string]$Value,
        [string]$Prefix,
        [string]$Suffix,
        [switch]$AddSpace
    )

    $spacer = ""
    if($AddSpace) {
        $spacer = " "
    }

    if ("${Prefix}" -ne "") {
        $Value = $Prefix + $spacer + $Value
    }

    if ("${Suffix}" -ne "") {
        $Value = $Value + $spacer + $Suffix
    }

    $Value
}

function Add-SuffixTemplate {
    Param(
        [string]$Value,
        [string]$Prefix,
        [string]$Suffix
    )

    if ("${Prefix}" -ne "" -and $Value.StartsWith($Prefix)) {
        $Value = "{Prefix}" + $Value.Substring($Prefix.Length)
    }

    if ("${Suffix}" -ne "" -and $Value.EndsWith($Suffix)) {
        $Value = $Value.Substring(0, $Value.Length - $Suffix.Length) + "{Suffix}"
    }

    $Value
}

function Set-SuffixTemplateValues {
    Param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string]$Value,
        [string]$Prefix,
        [string]$Suffix
    )

    $Value = $Value.Replace("{Prefix}", $Prefix).Replace("{Suffix}", $Suffix)

    $Value
}