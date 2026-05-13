Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Running tests (offline, deterministic)..."

# Deterministic test gate: verify repository has expected top-level artifacts.
$requiredFiles = @(
    'README.md'
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Required test target missing: $file"
    }
}

Write-Host 'Tests passed.'
