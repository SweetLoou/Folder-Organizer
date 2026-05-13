[CmdletBinding()]
param(
    [string]$Destination = (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'out')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Verbose "Installing Folder-Organizer assets to: $Destination"

if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

Write-Host 'Install scaffold complete.'
Write-Host 'Note: Network-enabled dependency installation is permitted only from this script.'
