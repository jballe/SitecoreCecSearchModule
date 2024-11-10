function AddOrSetPropertyValue {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory)]
        $PropertyName,

        [Parameter(Mandatory)]
        $Value
    )

    process {

        if (@($InputObject.PSObject.Properties).Count -gt 0 -and $InputObject.PSObject.Properties.Name -contains $PropertyName) {
            $InputObject.$PropertyName = $Value
        }
        else {
            $InputObject | Add-Member -Name $PropertyName -Type NoteProperty -Value $Value
        }
    }
}
