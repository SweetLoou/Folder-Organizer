[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Destination = (Join-Path -Path $PSScriptRoot -ChildPath '..' | Join-Path -ChildPath 'out')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath $Destination) {
    if ($PSCmdlet.ShouldProcess($Destination, 'Remove install directory')) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
}

Write-Host 'Uninstall scaffold complete.'
