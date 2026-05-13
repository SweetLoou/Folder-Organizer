#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NOTE:
# This is the only script in this repository permitted to perform outbound network calls.
# Keep all package/feed downloads centralized here.

$Required = [ordered]@{
    PowerShell       = '7.6.1'
    Pester           = '5.6.1'
    PSScriptAnalyzer = '1.22.0'
    MetadataExtractor = '2.8.1'
}

function Fail-Closed {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [string[]] $Remediation
    )

    Write-Error $Message
    if ($Remediation -and $Remediation.Count -gt 0) {
        Write-Host ''
        Write-Host 'Manual remediation:' -ForegroundColor Yellow
        foreach ($step in $Remediation) {
            Write-Host ("  - {0}" -f $step)
        }
    }
    exit 1
}

function Assert-ExactVersion {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Actual,
        [Parameter(Mandatory)] [string] $Expected
    )

    if ($Actual -ne $Expected) {
        Fail-Closed -Message "Required $Name version is $Expected but found $Actual." -Remediation @(
            "Install exact version $Expected for $Name.",
            "Re-run: pwsh ./tools/Install.ps1"
        )
    }
}

function Ensure-ModuleExactVersion {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version
    )

    $available = Get-Module -ListAvailable -Name $Name |
        Where-Object { $_.Version -eq [version]$Version } |
        Sort-Object Version -Descending

    if ($available) {
        Write-Host "[ok] $Name $Version is installed."
        return
    }

    Write-Host "[info] Installing $Name $Version..."
    try {
        Install-Module -Name $Name -RequiredVersion $Version -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
    }
    catch {
        Fail-Closed -Message "Could not install $Name $Version from PSGallery. Exact version is required." -Remediation @(
            "Verify internet access and PSGallery availability.",
            "Run manually: Install-Module -Name $Name -RequiredVersion $Version -Scope CurrentUser -Repository PSGallery -Force -AllowClobber",
            "If unavailable, obtain an internal mirror that hosts exact version $Version and install from that trusted source.",
            "Re-run: pwsh ./tools/Install.ps1"
        )
    }

    $installed = Get-Module -ListAvailable -Name $Name |
        Where-Object { $_.Version -eq [version]$Version }

    if (-not $installed) {
        Fail-Closed -Message "$Name $Version was not found after installation attempt." -Remediation @(
            "Run: Get-Module -ListAvailable -Name $Name | Select-Object Name,Version,ModuleBase",
            "Ensure exact version $Version exists, then re-run: pwsh ./tools/Install.ps1"
        )
    }

    Write-Host "[ok] Installed $Name $Version."
}

function Ensure-MetadataExtractorPackage {
    param(
        [Parameter(Mandatory)] [string] $Version
    )

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $targetDir = Join-Path $repoRoot ("vendor/nuget/MetadataExtractor.{0}" -f $Version)
    $nupkgPath = Join-Path $targetDir ("MetadataExtractor.{0}.nupkg" -f $Version)
    $expandedDir = Join-Path $targetDir 'content'

    $isCompliant = (Test-Path $nupkgPath) -and (Test-Path $expandedDir)
    if ($isCompliant) {
        Write-Host "[ok] MetadataExtractor $Version already present at $targetDir"
        return
    }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    $source = 'https://api.nuget.org/v3/index.json'
    $tempRoot = Join-Path $targetDir '.tmp'
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        $pkg = Save-Package -Name 'MetadataExtractor' -RequiredVersion $Version -Source $source -Path $tempRoot -ProviderName NuGet -Force -ErrorAction Stop
    }
    catch {
        Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
        Fail-Closed -Message "Failed to download MetadataExtractor $Version from NuGet. Exact version is required." -Remediation @(
            "Verify internet access to api.nuget.org.",
            "Manual download URL pattern: https://www.nuget.org/api/v2/package/MetadataExtractor/$Version",
            "Place the downloaded file at: $nupkgPath",
            "Extract it into: $expandedDir",
            "Re-run: pwsh ./tools/Install.ps1"
        )
    }

    $saved = Get-ChildItem -Path $tempRoot -Filter "MetadataExtractor.$Version.nupkg" -Recurse -File | Select-Object -First 1
    if (-not $saved) {
        Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
        Fail-Closed -Message "NuGet did not return MetadataExtractor.$Version.nupkg." -Remediation @(
            "Use manual download URL: https://www.nuget.org/api/v2/package/MetadataExtractor/$Version",
            "Copy to: $nupkgPath",
            "Extract contents into: $expandedDir",
            "Re-run: pwsh ./tools/Install.ps1"
        )
    }

    Move-Item -Path $saved.FullName -Destination $nupkgPath -Force

    if (Test-Path $expandedDir) {
        Remove-Item -Recurse -Force $expandedDir
    }
    New-Item -ItemType Directory -Path $expandedDir -Force | Out-Null

    try {
        Expand-Archive -Path $nupkgPath -DestinationPath $expandedDir -Force
    }
    catch {
        Fail-Closed -Message "Downloaded package could not be extracted: $nupkgPath" -Remediation @(
            "Delete and re-download: $nupkgPath",
            "Ensure it is a valid NuGet package archive.",
            "Re-run: pwsh ./tools/Install.ps1"
        )
    }
    finally {
        Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
    }

    Write-Host "[ok] Downloaded MetadataExtractor $Version into $targetDir"
}

# 1) Verify exact PowerShell version
$psVersion = $PSVersionTable.PSVersion.ToString()
Assert-ExactVersion -Name 'PowerShell' -Actual $psVersion -Expected $Required.PowerShell
Write-Host "[ok] PowerShell $psVersion"

# 2) Ensure exact tool module versions
Ensure-ModuleExactVersion -Name 'Pester' -Version $Required.Pester
Ensure-ModuleExactVersion -Name 'PSScriptAnalyzer' -Version $Required.PSScriptAnalyzer

# 3) Ensure exact NuGet package in repository-local vendor path only
Ensure-MetadataExtractorPackage -Version $Required.MetadataExtractor

Write-Host '[ok] Environment is fully compliant.' -ForegroundColor Green
