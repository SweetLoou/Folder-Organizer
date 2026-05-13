[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
$scriptFiles = Get-ChildItem -Path (Join-Path $repoRoot 'tools') -Filter '*.ps1' -File

if (-not $scriptFiles) {
    Write-Host 'No PowerShell files found to lint.'
    exit 0
}

$failed = $false
foreach ($file in $scriptFiles) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failed = $true
        Write-Error "Parse errors in $($file.Name): $($errors.Count)"
    }
}

if ($failed) {
    throw 'Lint failed due to parser errors.'
}

Write-Host 'Lint passed.'
