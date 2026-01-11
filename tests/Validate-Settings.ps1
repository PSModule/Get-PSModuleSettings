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
Write-Host '========== Generated Settings JSON =========='
$settings = $SettingsJson | ConvertFrom-Json
Write-Host ($settings | ConvertTo-Json -Depth 10)
Write-Host '=============================================='

# Validate against JSON schema
Write-Host 'Validating settings against JSON schema...'
$schemaPath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'scripts', 'Settings.schema.json'
$schema = Get-Content $schemaPath -Raw
$isValid = Test-Json -Json $SettingsJson -Schema $schema

if (-not $isValid) {
    Write-Error 'Settings output does not conform to the JSON schema'
    exit 1
}
Write-Host '✓ Settings conform to JSON schema'
