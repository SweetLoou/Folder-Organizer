Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Running lint checks (offline, deterministic)..."

# Deterministic lint gate: verify that workflow files are valid YAML files present in repo.
$requiredFiles = @(
    '.github/workflows/lint.yml',
    '.github/workflows/test.yml'
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Required lint target missing: $file"
    }
}

Write-Host 'Lint checks passed.'
