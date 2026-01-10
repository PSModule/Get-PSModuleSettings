#Requires -Version 7.0

<#
.SYNOPSIS
    Validates the settings output from Get-PSModuleSettings action.

.DESCRIPTION
    This script validates that the settings JSON output:
    1. Is not empty
    2. Conforms to the JSON schema (Settings.schema.json)
    3. Has the expected structure matching the reference (Settings.json)

    The settings JSON is expected to be provided via the SETTINGS_JSON environment variable.

.EXAMPLE
    $env:SETTINGS_JSON = $settingsJson
    .\Validate-Settings.ps1
#>

[CmdletBinding()]
param()

# Check if settings JSON is provided via environment variable
$SettingsJson = $env:SETTINGS_JSON
if (-not $SettingsJson) {
    Write-Error 'Settings output is empty. SETTINGS_JSON environment variable must be set.'
    exit 1
}
Write-Host '✓ Settings retrieved successfully'

# Display the generated settings JSON
Write-Host "`n========== Generated Settings JSON =========="
$settings = $SettingsJson | ConvertFrom-Json
Write-Host ($settings | ConvertTo-Json -Depth 10)
Write-Host '=============================================='

# Validate against JSON schema
Write-Host "`nValidating settings against JSON schema..."
$schemaPath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'scripts', 'Settings.schema.json'
$schema = Get-Content $schemaPath -Raw
$isValid = Test-Json -Json $SettingsJson -Schema $schema

if (-not $isValid) {
    Write-Error 'Settings output does not conform to the JSON schema'
    exit 1
}
Write-Host '✓ Settings conform to JSON schema'

# Load expected reference settings
Write-Host "`nComparing with reference settings..."
$referencePath = Join-Path $PSScriptRoot 'Settings.json'
$expectedSettings = Get-Content $referencePath -Raw | ConvertFrom-Json

<#
.SYNOPSIS
    Compares the structure of two objects.

.DESCRIPTION
    Recursively compares the structure of an actual object against an expected object,
    validating that all expected properties exist in the actual object.

.OUTPUTS
    System.String[]
    Returns an array of error messages for any structural mismatches.
#>
function Test-ObjectStructure {
    [CmdletBinding()]
    param(
        # The actual object to validate.
        $Actual,

        # The expected object structure to validate against.
        $Expected,

        # The current path in the object hierarchy (used for error reporting).
        $Path = 'Root'
    )

    $errors = @()

    # Get all properties from expected object
    $expectedProps = $Expected.PSObject.Properties.Name
    foreach ($prop in $expectedProps) {
        $currentPath = "$Path.$prop"

        if (-not $Actual.PSObject.Properties.Name.Contains($prop)) {
            $errors += "Missing property: $currentPath"
            continue
        }

        $actualValue = $Actual.$prop
        $expectedValue = $Expected.$prop

        # Check if both are objects (not arrays or primitives)
        if ($expectedValue -is [PSCustomObject] -and $actualValue -is [PSCustomObject]) {
            $errors += Test-ObjectStructure -Actual $actualValue -Expected $expectedValue -Path $currentPath
        } elseif ($expectedValue -is [array] -and $actualValue -is [array]) {
            # For arrays, just verify they're both arrays - don't compare contents
            Write-Host "  ✓ Array property: $currentPath"
        } elseif ($null -eq $expectedValue -and $null -eq $actualValue) {
            # Both null is fine
            Write-Host "  ✓ Null property: $currentPath"
        } elseif (($null -eq $expectedValue -and $null -ne $actualValue) -or ($null -ne $expectedValue -and $null -eq $actualValue)) {
            # One null, one not - this might be okay depending on context
            Write-Host "  ⚠ Null mismatch at $currentPath (Expected: $($null -eq $expectedValue), Actual: $($null -eq $actualValue))"
        }
    }

    return $errors
}

$structureErrors = Test-ObjectStructure -Actual $settings -Expected $expectedSettings

if ($structureErrors.Count -gt 0) {
    Write-Error "Structure validation failed with $($structureErrors.Count) error(s):"
    $structureErrors | ForEach-Object { Write-Error "  - $_" }
    exit 1
}

Write-Host '✓ Settings structure matches expected layout'
