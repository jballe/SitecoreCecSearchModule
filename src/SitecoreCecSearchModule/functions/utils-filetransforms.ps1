function Convert-HttpJsonToGraph {
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })]
        $Path,
        #$GraphQlDestinationPath = ($Path.Replace(".http", ".graphql")),
        $DestinationPath = ($Path.Replace(".http", ".graph.http")),
        $Encoding = "UTF8"
    )

    $lines = Get-Content -Path $Path -Encoding $Encoding
    $newLines = @()
    $found = $false
    $body = ""
    foreach ($line in $lines) {
        if ("${line}" -eq "") {
            $found = $true
            $newLines += "X-REQUEST-TYPE: GraphQL"
            $newLines += $line
            continue;
        }

        if ($found) {
            $body += $line
        }
        else {
            $newLines += $line
        }
    }

    $graphql = Convert-HttpJsonToGraphBody -Body $body
    $newLines += $graphql
    #if ($Null -ne $GraphQlDestinationPath) { Set-Content -Path $GraphQlDestinationPath -Value $graphql -Encoding $Encoding }
    if ($Null -ne $DestinationPath) { Set-Content -Path $GraphHttpDestinationPath -Value $newLines -Encoding $Encoding }
}

function Convert-HttpGraphToJson {
    param(
        [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })]
        $Path,
        $DestinationPath = ($Path.Replace(".graph.http", ".http")),
        $Encoding = "UTF8"
    )

    $lines = Get-Content -Path $Path -Encoding $Encoding
    $newLines = @()
    $found = $false
    $body = @()
    foreach ($line in $lines) {
        if ("${line}" -eq "") {
            $found = $true
            continue;
        }

        if ($found) {
            $body += $line
        }
        elseif ($line.Trim() -ne "X-REQUEST-TYPE: GraphQL") {
            $newLines += $line
        }
    }

    $newLines += "`n" + (Convert-HttpGraphToJsonBody -Body ($body -join "`n"))
    Set-Content -Path $DestinationPath -Value $newLines -Encoding $Encoding
}

function Convert-HttpJsonToGraphBody {
    param(
        [Parameter(Mandatory)]
        $Body
    )

    $json = ConvertFrom-Json $Body
    $query = $json.query
    return $query
}

function Convert-HttpGraphToJsonBody {
    param(
        [Parameter(Mandatory)]
        $Body
    )

    return (@{ query = $Body } | ConvertTo-Json -Compress).Trim()
}

