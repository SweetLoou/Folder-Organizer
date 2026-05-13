[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lintScript = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-Lint.ps1'
& $lintScript

Write-Host 'Test scaffold passed.'
