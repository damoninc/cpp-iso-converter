$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$root = Split-Path -Parent $PSScriptRoot
$vsDevCmd = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
$msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe"

$buildCommand = "`"$vsDevCmd`" -arch=x64 && `"$msbuild`" ciso2iso.sln /p:Configuration=Release /p:Platform=x64"
cmd.exe /c $buildCommand
if ($LASTEXITCODE -ne 0) {
    throw "Build failed"
}

$exe = Join-Path $root "bin\Release\ciso2iso.exe"
if (-not (Test-Path $exe)) {
    throw "Executable not produced at $exe"
}

function Invoke-CommandCapture {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        $startProcessArgs = @{
            FilePath = $FilePath
            Wait = $true
            PassThru = $true
            NoNewWindow = $true
            RedirectStandardOutput = $stdoutPath
            RedirectStandardError = $stderrPath
        }
        if ($Arguments.Count -gt 0) {
            $startProcessArgs.ArgumentList = $Arguments
        }

        $process = Start-Process @startProcessArgs

        $stdout = Get-Content -LiteralPath $stdoutPath -Raw
        $stderr = Get-Content -LiteralPath $stderrPath -Raw

        return @{
            ExitCode = $process.ExitCode
            Output = ($stdout + $stderr)
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
    }
}

$usageResult = Invoke-CommandCapture -FilePath $exe -Arguments @()
if ($usageResult.ExitCode -eq 0) {
    throw "Expected usage invocation to fail"
}
if ($usageResult.Output -notmatch "Usage: ciso2iso <input.cso> <output.iso>") {
    throw "Usage output did not match expected text"
}

$badInput = Join-Path $PSScriptRoot "invalid_magic.cso"
$badOutput = Join-Path $PSScriptRoot "invalid_magic.iso"
if (Test-Path $badOutput) {
    Remove-Item -LiteralPath $badOutput
}

$invalidResult = Invoke-CommandCapture -FilePath $exe -Arguments @($badInput, $badOutput)
if ($invalidResult.ExitCode -eq 0) {
    throw "Expected invalid fixture to fail"
}
if ($invalidResult.Output -notmatch "invalid CISO header magic") {
    throw "Invalid fixture did not report the expected header error"
}

Write-Host "Smoke test passed"
