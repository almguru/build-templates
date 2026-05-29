<#
.SYNOPSIS
Converts bicep-deploy overrideParameters into a JSON object string for BicepDeploy@0.

.DESCRIPTION
Parses legacy overrideParameters in key=value format and converts them to a JSON object
string for BicepDeploy@0. If OverrideParameters is empty, an empty object ({}) is produced.

The script is pipeline-agnostic: it returns only the resulting JSON string to stdout.

.PARAMETER OverrideParameters
Override parameters string.

#>
param(
    [string]$OverrideParameters = ''
)

$ErrorActionPreference = "Stop"

$OverrideParameters = $OverrideParameters -replace '\r?\n', ' ' -replace '\s+', ' '
$OverrideParameters = $OverrideParameters.Trim()

if ([string]::IsNullOrWhiteSpace($OverrideParameters)) {
    Write-Output '{}'
    exit 0
}

# Split OverrideParameters while preserving quoted and JSON values.
$parameterList = @()
$currentParam = ''
$inQuotes = $false
$i = 0
$braceCount = 0
$bracketCount = 0

while ($i -lt $OverrideParameters.Length) {
    $char = $OverrideParameters[$i]

    if ($char -eq '`' -and ($i + 1) -lt $OverrideParameters.Length) {
        $nextChar = $OverrideParameters[$i + 1]
        if ($nextChar -eq '"') {
            $currentParam += $char + $nextChar
            $inQuotes = -not $inQuotes
            $i += 2
            continue
        }
    }
    elseif ($char -eq '"') {
        $inQuotes = -not $inQuotes
        $currentParam += $char
    }
    elseif ($char -eq '{') {
        $braceCount++
        $currentParam += $char
    }
    elseif ($char -eq '}') {
        $braceCount--
        $currentParam += $char
    }
    elseif ($char -eq '[') {
        $bracketCount++
        $currentParam += $char
    }
    elseif ($char -eq ']') {
        $bracketCount--
        $currentParam += $char
    }
    elseif ($char -eq ' ' -and -not $inQuotes -and $braceCount -eq 0 -and $bracketCount -eq 0) {
        if ($currentParam.Trim()) {
            $parameterList += $currentParam.Trim()
        }
        $currentParam = ''
    }
    else {
        $currentParam += $char
    }

    $i++
}

if ($currentParam.Trim()) {
    $parameterList += $currentParam.Trim()
}

$parameterObject = [ordered]@{}
foreach ($param in $parameterList) {
    if ($param -notmatch '^([^=\s]+)=(.+)$') {
        throw "Invalid override parameter format '$param'. Expected 'name=value'."
    }

    $paramName = $matches[1]
    $paramValue = $matches[2].Trim()
    $decodedValue = $paramValue -replace '`"', '"'

    if ($decodedValue.Length -ge 2 -and $decodedValue.StartsWith('"') -and $decodedValue.EndsWith('"')) {
        $decodedValue = $decodedValue.Substring(1, $decodedValue.Length - 2)
    }

    if ($decodedValue -match '^[\s]*[{\[].*[}\]][\s]*$') {
        try {
            $parameterObject[$paramName] = $decodedValue | ConvertFrom-Json -Depth 100
            continue
        }
        catch {
            # Keep as string if the value is JSON-like but invalid JSON.
        }
    }

    if ($decodedValue -match '^(?i:true|false)$') {
        $parameterObject[$paramName] = [System.Convert]::ToBoolean($decodedValue)
        continue
    }

    $numberValue = 0
    if ([double]::TryParse($decodedValue, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$numberValue)) {
        $parameterObject[$paramName] = $numberValue
        continue
    }

    $parameterObject[$paramName] = $decodedValue
}

$parametersJson = $parameterObject | ConvertTo-Json -Compress -Depth 100
Write-Output $parametersJson
