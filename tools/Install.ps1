#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# NOTE:
# This is the only script in this repository permitted to perform outbound network calls.

$Required = [ordered]@{
    PowerShell        = '7.6.1'
    Pester            = '5.6.1'
    PSScriptAnalyzer  = '1.22.0'
    MetadataExtractor = '2.8.1'
}

function Fail-Closed {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [string[]] $Remediation = @()
    )

    Write-Error $Message
    if ($Remediation.Count -gt 0) {
        Write-Host ''
        Write-Host 'Manual remediation:' -ForegroundColor Yellow
        foreach ($step in $Remediation) {
            Write-Host "  - $step"
        }
    }
    exit 1
}

function Ensure-PowerShellExactVersion {
    param([Parameter(Mandatory)] [string] $Version)

    $current = $PSVersionTable.PSVersion.ToString()
    if ($current -eq $Version) {
        Write-Host "[ok] PowerShell $current"
        return
    }

    Fail-Closed -Message "Required PowerShell version is $Version but found $current." -Remediation @(
        "Install exact PowerShell version $Version.",
        'Windows: winget install --id Microsoft.PowerShell --version 7.6.1 --exact --source winget',
        'macOS/Linux: install PowerShell 7.6.1 from official Microsoft/GitHub packages.',
        'Open a new shell and re-run: pwsh ./tools/Install.ps1'
    )
}

function Ensure-ModuleExactVersion {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version
    )

    $match = Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq [version]$Version }
    if ($match) {
        Write-Host "[ok] $Name $Version is installed."
        return
    }

    Write-Host "[info] Installing $Name $Version from PSGallery..."
    try {
        Install-Module -Name $Name -RequiredVersion $Version -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    }
    catch {
        Fail-Closed -Message "Failed to install $Name $Version from PSGallery." -Remediation @(
            'Verify outbound access to PSGallery.',
            "Run manually: Install-Module -Name $Name -RequiredVersion $Version -Repository PSGallery -Scope CurrentUser -Force -AllowClobber",
            'Re-run: pwsh ./tools/Install.ps1'
        )
    }

    $postInstall = Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq [version]$Version }
    if (-not $postInstall) {
        Fail-Closed -Message "$Name $Version is still unavailable after installation attempt." -Remediation @(
            "Inspect installed versions: Get-Module -ListAvailable -Name $Name | Select-Object Name,Version,ModuleBase",
            'Install exact required version, then re-run: pwsh ./tools/Install.ps1'
        )
    }

    Write-Host "[ok] Installed $Name $Version."
}

function Ensure-MetadataExtractorPackage {
    param([Parameter(Mandatory)] [string] $Version)

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $targetDir = Join-Path $repoRoot "vendor/nuget/MetadataExtractor.$Version"
    $nupkgPath = Join-Path $targetDir "MetadataExtractor.$Version.nupkg"
    $contentDir = Join-Path $targetDir 'content'
    $nuspecPath = Join-Path $contentDir 'MetadataExtractor.nuspec'

    if ((Test-Path $nupkgPath) -and (Test-Path $nuspecPath)) {
        Write-Host "[ok] MetadataExtractor $Version already vendored at $targetDir"
        return
    }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    $tmpNupkg = Join-Path $targetDir "MetadataExtractor.$Version.download.tmp"

    try {
        $url = "https://www.nuget.org/api/v2/package/MetadataExtractor/$Version"
        Invoke-WebRequest -Uri $url -OutFile $tmpNupkg -MaximumRedirection 5 -ErrorAction Stop
    }
    catch {
        Remove-Item -Force $tmpNupkg -ErrorAction SilentlyContinue
        Fail-Closed -Message "Failed to download MetadataExtractor $Version from NuGet." -Remediation @(
            'Verify outbound access to www.nuget.org.',
            "Manually download: https://www.nuget.org/api/v2/package/MetadataExtractor/$Version",
            "Save as: $nupkgPath",
            "Extract to: $contentDir",
            'Re-run: pwsh ./tools/Install.ps1'
        )
    }

    Move-Item -Force -Path $tmpNupkg -Destination $nupkgPath

    if (Test-Path $contentDir) {
        Remove-Item -Recurse -Force $contentDir
    }
    New-Item -ItemType Directory -Path $contentDir -Force | Out-Null

    try {
        Expand-Archive -Path $nupkgPath -DestinationPath $contentDir -Force
    }
    catch {
        Fail-Closed -Message "Downloaded package could not be extracted: $nupkgPath" -Remediation @(
            "Delete corrupted package: $nupkgPath",
            "Re-run: pwsh ./tools/Install.ps1"
        )
    }

    if (-not (Test-Path $nuspecPath)) {
        Fail-Closed -Message "MetadataExtractor $Version download is incomplete. Missing MetadataExtractor.nuspec." -Remediation @(
            "Delete directory: $targetDir",
            'Re-run: pwsh ./tools/Install.ps1'
        )
    }

    Write-Host "[ok] Downloaded MetadataExtractor $Version into $targetDir"
}

Ensure-PowerShellExactVersion -Version $Required.PowerShell
Ensure-ModuleExactVersion -Name 'Pester' -Version $Required.Pester
Ensure-ModuleExactVersion -Name 'PSScriptAnalyzer' -Version $Required.PSScriptAnalyzer
Ensure-MetadataExtractorPackage -Version $Required.MetadataExtractor

Write-Host '[ok] Environment is fully compliant.' -ForegroundColor Green
