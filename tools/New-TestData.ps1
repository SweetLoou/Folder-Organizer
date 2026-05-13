[CmdletBinding()]
param(
    [string]$Path = (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'tests/data')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

$sampleFile = Join-Path -Path $Path -ChildPath 'sample.txt'
Set-Content -Path $sampleFile -Value 'sample test data' -NoNewline

Write-Host "Generated test data at: $sampleFile"
