# Version Management Script for Windows (PowerShell)
# This script helps manage version code and version name in pubspec.yaml
#
# Usage:
#   .\version_manager.ps1                    # Show current version
#   .\version_manager.ps1 -Bump Patch       # Bump patch version (1.0.0 -> 1.0.1)
#   .\version_manager.ps1 -Bump Minor       # Bump minor version (1.0.0 -> 1.1.0)
#   .\version_manager.ps1 -Bump Major       # Bump major version (1.0.0 -> 2.0.0)
#   .\version_manager.ps1 -Build <number>   # Set build number
#   .\version_manager.ps1 -Set <version>    # Set version (format: x.y.z+build)

param(
    [Parameter(ParameterSetName="Bump")]
    [ValidateSet("Patch", "Minor", "Major")]
    [string]$Bump,
    
    [Parameter(ParameterSetName="Build")]
    [int]$Build,
    
    [Parameter(ParameterSetName="Set")]
    [string]$Set
)

# Navigate to project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$pubspecFile = Join-Path $projectRoot "pubspec.yaml"

if (-not (Test-Path $pubspecFile)) {
    Write-Host "Error: pubspec.yaml not found" -ForegroundColor Red
    exit 1
}

# Extract current version
function Get-CurrentVersion {
    $content = Get-Content $pubspecFile -Raw
    if ($content -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
        return @{
            Name = $matches[1]
            Code = [int]$matches[2]
        }
    }
    return @{
        Name = "1.0.0"
        Code = 1
    }
}

# Show current version
function Show-Version {
    $version = Get-CurrentVersion
    Write-Host "Current Version: $($version.Name) (Build: $($version.Code))" -ForegroundColor Cyan
}

# Bump version
function Bump-Version {
    param([string]$BumpType)
    
    $version = Get-CurrentVersion
    $parts = $version.Name -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($BumpType.ToLower()) {
        "patch" {
            $patch++
        }
        "minor" {
            $minor++
            $patch = 0
        }
        "major" {
            $major++
            $minor = 0
            $patch = 0
        }
        default {
            Write-Host "Error: Invalid bump type. Use: Patch, Minor, or Major" -ForegroundColor Red
            exit 1
        }
    }
    
    $newVersionName = "$major.$minor.$patch"
    $newVersionCode = $version.Code + 1
    
    Update-Version -VersionName $newVersionName -VersionCode $newVersionCode
    Write-Host "Version bumped: $($version.Name) -> $newVersionName" -ForegroundColor Green
    Write-Host "Build number: $($version.Code) -> $newVersionCode" -ForegroundColor Green
}

# Set build number
function Set-BuildNumber {
    param([int]$BuildNumber)
    
    $version = Get-CurrentVersion
    Update-Version -VersionName $version.Name -VersionCode $BuildNumber
    Write-Host "Build number set to: $BuildNumber" -ForegroundColor Green
}

# Set version
function Set-VersionString {
    param([string]$VersionString)
    
    if ($VersionString -notmatch "^(\d+\.\d+\.\d+)\+(\d+)$") {
        Write-Host "Error: Version format must be x.y.z+build (e.g., 1.2.3+4)" -ForegroundColor Red
        exit 1
    }
    
    $versionName = $matches[1]
    $versionCode = [int]$matches[2]
    
    Update-Version -VersionName $versionName -VersionCode $versionCode
    Write-Host "Version set to: $versionName (Build: $versionCode)" -ForegroundColor Green
}

# Update version in pubspec.yaml
function Update-Version {
    param(
        [string]$VersionName,
        [int]$VersionCode
    )
    
    # Create backup
    Copy-Item $pubspecFile "$pubspecFile.bak"
    
    # Read content and update version line
    $content = Get-Content $pubspecFile
    $newContent = $content | ForEach-Object {
        if ($_ -match "^version:") {
            "version: $VersionName+$VersionCode"
        } else {
            $_
        }
    }
    
    $newContent | Set-Content $pubspecFile
    Write-Host "Updated pubspec.yaml (backup saved as pubspec.yaml.bak)" -ForegroundColor Yellow
}

# Main script logic
if ($Bump) {
    Bump-Version -BumpType $Bump
} elseif ($Build) {
    Set-BuildNumber -BuildNumber $Build
} elseif ($Set) {
    Set-VersionString -VersionString $Set
} else {
    Show-Version
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\version_manager.ps1                    # Show current version" -ForegroundColor White
    Write-Host "  .\version_manager.ps1 -Bump Patch       # Bump patch version" -ForegroundColor White
    Write-Host "  .\version_manager.ps1 -Bump Minor       # Bump minor version" -ForegroundColor White
    Write-Host "  .\version_manager.ps1 -Bump Major       # Bump major version" -ForegroundColor White
    Write-Host "  .\version_manager.ps1 -Build <number>   # Set build number" -ForegroundColor White
    Write-Host "  .\version_manager.ps1 -Set <version>     # Set version (x.y.z+build)" -ForegroundColor White
}
