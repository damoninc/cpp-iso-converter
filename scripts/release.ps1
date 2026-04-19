param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('plan', 'package')]
    [string]$Command,

    [string]$Version,

    [string]$ExePath,

    [string]$ReadmePath = 'README.md',

    [string]$OutputDir = 'dist',

    [string]$BinaryName = 'ciso2iso.exe',

    [string]$Target = 'windows-x64'
)

$ErrorActionPreference = 'Stop'

function Write-GitHubOutput {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
        Write-Host $Line
        return
    }

    $parent = Split-Path -Parent $env:GITHUB_OUTPUT
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $Line | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

function Get-LatestVersionTag {
    $tag = (git tag --list 'v*' --sort=-version:refname | Select-Object -First 1)
    return $tag
}

function Get-CommitSubjectsSinceTag {
    param([string]$Tag)

    if ([string]::IsNullOrWhiteSpace($Tag)) {
        return @(git log --format=%s)
    }

    return @(git log "$Tag..HEAD" --format=%s)
}

function Get-NextVersion {
    param(
        [string]$CurrentTag,
        [string[]]$Subjects
    )

    $hasFeat = $false
    $hasFix = $false

    foreach ($subject in $Subjects) {
        if ($subject -match '^\s*feat:') {
            $hasFeat = $true
            continue
        }
        if ($subject -match '^\s*fix:') {
            $hasFix = $true
        }
    }

    if (-not $hasFeat -and -not $hasFix) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($CurrentTag)) {
        if ($hasFeat) {
            return 'v0.1.0'
        }
        return 'v0.0.1'
    }

    if ($CurrentTag -notmatch '^v(\d+)\.(\d+)\.(\d+)$') {
        throw "Latest tag '$CurrentTag' is not in vX.Y.Z format."
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]

    if ($hasFeat) {
        return "v$major.$($minor + 1).0"
    }

    return "v$major.$minor.$($patch + 1)"
}

function New-ReleasePlan {
    $tag = Get-LatestVersionTag
    $subjects = Get-CommitSubjectsSinceTag -Tag $tag
    $version = Get-NextVersion -CurrentTag $tag -Subjects $subjects

    if ($null -eq $version) {
        Write-GitHubOutput 'release=false'
        return
    }

    Write-GitHubOutput 'release=true'
    Write-GitHubOutput "version=$version"
}

function New-ReleasePackage {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw 'Version is required for package mode.'
    }
    if ([string]::IsNullOrWhiteSpace($ExePath)) {
        throw 'ExePath is required for package mode.'
    }
    if ([string]::IsNullOrWhiteSpace($BinaryName)) {
        throw 'BinaryName is required for package mode.'
    }
    if ([string]::IsNullOrWhiteSpace($Target)) {
        throw 'Target is required for package mode.'
    }
    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "Executable not found at $ExePath"
    }
    if (-not (Test-Path -LiteralPath $ReadmePath)) {
        throw "README not found at $ReadmePath"
    }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    $stageDir = Join-Path $OutputDir 'package'
    if (Test-Path -LiteralPath $stageDir) {
        Remove-Item -LiteralPath $stageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

    Copy-Item -LiteralPath $ExePath -Destination (Join-Path $stageDir $BinaryName)
    Copy-Item -LiteralPath $ReadmePath -Destination (Join-Path $stageDir 'README.md')

    $zipPath = Join-Path $OutputDir "ciso2iso-$Target-$Version.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipPath

    Write-GitHubOutput "asset_path=$zipPath"
}

switch ($Command) {
    'plan' { New-ReleasePlan }
    'package' { New-ReleasePackage }
}
