[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'folder-organizer.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Warning "Configuration file not found: $ConfigPath"
    exit 0
}

$content = Get-Content -Path $ConfigPath -Raw
try {
    $null = $content | ConvertFrom-Json
}
catch {
    throw "Invalid JSON in config file: $ConfigPath"
}

Write-Host 'Configuration is valid JSON.'
