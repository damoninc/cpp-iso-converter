# Release Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically build and publish a downloadable Windows release zip whenever releasable commits land on `master`.

**Architecture:** A GitHub Actions workflow runs on pushes to `master`, inspects commit subjects since the latest `vX.Y.Z` tag, computes the next semantic version from `feat:` and `fix:` prefixes, and exits early for `chore:`-only ranges. When a release is needed, the workflow tags the commit, builds the existing Visual Studio project on a Windows runner, runs the smoke test, creates a zip containing `ciso2iso.exe` and `README.md`, and uploads it to a GitHub Release.

**Tech Stack:** GitHub Actions, PowerShell, git tags, MSBuild, existing smoke test

---

### Task 1: Add Version And Packaging Helper Script

**Files:**
- Create: `scripts/release.ps1`
- Test: manual dry-run invocation in GitHub Actions shell style

- [ ] **Step 1: Write the failing test**

Document the expected helper behavior:

```text
Given commit subjects since the latest tag, the helper should:
- return no release for chore-only ranges
- choose a patch bump for fix-only ranges
- choose a minor bump when any feat commit is present
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release.ps1 plan
```

Expected: PowerShell reports that `scripts\release.ps1` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/release.ps1` with:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('plan', 'package')]
    [string]$Command,

    [string]$Version,

    [string]$ExePath,

    [string]$ReadmePath = 'README.md',

    [string]$OutputDir = 'dist'
)

$ErrorActionPreference = 'Stop'

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
        'release=false' | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        return
    }

    'release=true' | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

function New-ReleasePackage {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        throw 'Version is required for package mode.'
    }
    if ([string]::IsNullOrWhiteSpace($ExePath)) {
        throw 'ExePath is required for package mode.'
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

    Copy-Item -LiteralPath $ExePath -Destination (Join-Path $stageDir 'ciso2iso.exe')
    Copy-Item -LiteralPath $ReadmePath -Destination (Join-Path $stageDir 'README.md')

    $zipPath = Join-Path $OutputDir "ciso2iso-windows-x64-$Version.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stageDir '*') -DestinationPath $zipPath

    "asset_path=$zipPath" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

switch ($Command) {
    'plan' { New-ReleasePlan }
    'package' { New-ReleasePackage }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
$env:GITHUB_OUTPUT = Join-Path $PWD 'release-plan.out'
powershell -ExecutionPolicy Bypass -File .\scripts\release.ps1 plan
Get-Content .\release-plan.out
Remove-Item .\release-plan.out
```

Expected: the helper writes either `release=false` or both `release=true` and `version=vX.Y.Z`, depending on current commit history.

- [ ] **Step 5: Commit**

```powershell
git add scripts/release.ps1
git commit -m "chore: add release automation helper script"
```

### Task 2: Add GitHub Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Test: workflow YAML validation by visual inspection and local smoke build

- [ ] **Step 1: Write the failing test**

Document the required workflow behavior:

```text
Pushes to master should evaluate semantic commit prefixes and publish a GitHub Release only when feat or fix commits are present since the latest version tag.
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
Test-Path .github\workflows\release.yml
```

Expected: `False`

- [ ] **Step 3: Write minimal implementation**

Create `.github/workflows/release.yml` with:

```yaml
name: Release

on:
  push:
    branches:
      - master

permissions:
  contents: write

jobs:
  release:
    runs-on: windows-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up MSBuild
        uses: microsoft/setup-msbuild@v2

      - name: Plan release
        id: plan
        shell: pwsh
        run: |
          .\scripts\release.ps1 plan

      - name: Stop when no release is needed
        if: steps.plan.outputs.release != 'true'
        shell: pwsh
        run: |
          Write-Host 'No feat: or fix: commits found since the latest tag.'

      - name: Create tag
        if: steps.plan.outputs.release == 'true'
        shell: pwsh
        run: |
          $version = '${{ steps.plan.outputs.version }}'
          if (git rev-parse $version 2>$null) {
            throw "Tag $version already exists."
          }
          git config user.name 'github-actions[bot]'
          git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
          git tag $version
          git push origin $version

      - name: Build release binary
        if: steps.plan.outputs.release == 'true'
        shell: pwsh
        run: |
          msbuild ciso2iso.sln /p:Configuration=Release /p:Platform=x64

      - name: Run smoke test
        if: steps.plan.outputs.release == 'true'
        shell: pwsh
        run: |
          powershell -ExecutionPolicy Bypass -File .\tests\smoke.ps1

      - name: Package release asset
        if: steps.plan.outputs.release == 'true'
        id: package
        shell: pwsh
        run: |
          .\scripts\release.ps1 package `
            -Version '${{ steps.plan.outputs.version }}' `
            -ExePath '.\bin\Release\ciso2iso.exe'

      - name: Publish GitHub Release
        if: steps.plan.outputs.release == 'true'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.plan.outputs.version }}
          files: ${{ steps.package.outputs.asset_path }}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
Get-Content .github\workflows\release.yml
powershell -ExecutionPolicy Bypass -File .\tests\smoke.ps1
```

Expected: the workflow file exists with the expected trigger and release steps, and the local smoke test still passes.

- [ ] **Step 5: Commit**

```powershell
git add .github/workflows/release.yml
git commit -m "feat: add automatic release workflow"
```

### Task 3: Document Release Process And Commit Rules

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the failing test**

Document the required README behavior:

```text
The README should explain that releases are published automatically from master and that commit prefixes feat, fix, and chore control versioning behavior.
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
rg -n "Automatic Releases|feat:|fix:|chore:" README.md
```

Expected: no release-process section is present yet.

- [ ] **Step 3: Write minimal implementation**

Append this section to `README.md`:

```markdown
## Automatic Releases

This repository publishes downloadable Windows binaries from GitHub Releases.

Release automation runs on pushes to `master` and inspects commit subjects since the latest `vX.Y.Z` tag:

- `feat:` creates a new minor release
- `fix:` creates a new patch release
- `chore:` does not create a release

When a release is needed, GitHub Actions builds `ciso2iso.exe`, runs the smoke test, packages the executable with `README.md`, and uploads a versioned zip to GitHub Releases.
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
rg -n "Automatic Releases|feat:|fix:|chore:" README.md
```

Expected: matches are found in the new release-process section.

- [ ] **Step 5: Commit**

```powershell
git add README.md
git commit -m "chore: document automatic release process"
```

### Task 4: Verify Packaging Output Locally

**Files:**
- Modify: `scripts/release.ps1` if local package behavior needs adjustment
- Test: local package output under `dist/`

- [ ] **Step 1: Write the failing test**

Document the required packaging behavior:

```text
Packaging mode should create a zip named ciso2iso-windows-x64-vX.Y.Z.zip containing only ciso2iso.exe and README.md.
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
if (Test-Path .\dist) { Remove-Item .\dist -Recurse -Force }
$env:GITHUB_OUTPUT = Join-Path $PWD 'release-package.out'
powershell -ExecutionPolicy Bypass -File .\scripts\release.ps1 package -Version v9.9.9 -ExePath .\bin\Release\ciso2iso.exe
```

Expected: this fails before the helper exists or before packaging logic is correct.

- [ ] **Step 3: Write minimal implementation**

Adjust `scripts/release.ps1` only if needed so package mode writes the zip and `asset_path` output correctly for both local and GitHub Actions execution.

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
if (Test-Path .\dist) { Remove-Item .\dist -Recurse -Force }
$env:GITHUB_OUTPUT = Join-Path $PWD 'release-package.out'
powershell -ExecutionPolicy Bypass -File .\scripts\release.ps1 package -Version v9.9.9 -ExePath .\bin\Release\ciso2iso.exe
Get-ChildItem .\dist
Expand-Archive .\dist\ciso2iso-windows-x64-v9.9.9.zip -DestinationPath .\dist\unzipped
Get-ChildItem .\dist\unzipped
Remove-Item .\release-package.out, .\dist -Recurse -Force
```

Expected: the zip exists, and the expanded package contains `ciso2iso.exe` and `README.md` only.

- [ ] **Step 5: Commit**

```powershell
git add scripts/release.ps1
git commit -m "fix: finalize release packaging behavior"
```
