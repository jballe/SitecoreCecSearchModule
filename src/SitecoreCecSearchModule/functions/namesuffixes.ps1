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

    if ("${Prefix}" -ne "" -and $Value.StartsWith($Prefix)) {
        $Value = $Value.Substring($Prefix.Length)
    }

    if ("${Suffix}" -ne "" -and $Value.EndsWith($Suffix)) {
        $Value = $Value.Substring(0, $Value.Length - $Suffix.Length)
    }

    $Value
}

function Add-Suffix {
    Param(
        [string]$Value,
        [string]$Prefix,
        [string]$Suffix
    )

    if ("${Prefix}" -ne "") {
        $Value = $Prefix + $Value
    }

    if ("${Suffix}" -ne "") {
        $Value = $Value + $Suffix
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
        $Value = "{Prefix}_" + $Value.Substring($Prefix.Length)
    }

    if ("${Suffix}" -ne "" -and $Value.EndsWith($Suffix)) {
        $Value = $Value.Substring(0, $Value.Length - $Suffix.Length) + "_{Suffix}"
    }

    $Value

}