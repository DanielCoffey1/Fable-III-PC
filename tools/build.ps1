param([ValidateRange(1,32)][int]$Jobs = 8, [switch]$ConfigureOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$xex = Join-Path $projectRoot 'game/default.xex'
$expected = 'FC725386570788EE08B72A3BFF06CF8227C17922E322FE45860348DDA31DDD54'
if (!(Test-Path -LiteralPath $xex) -or
    (Get-FileHash -LiteralPath $xex -Algorithm SHA256).Hash -ne $expected) {
    throw 'Missing or unsupported game/default.xex; this manifest targets the documented USA/Europe revision.'
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio 2022 Build Tools using .vsconfig first.' }
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'A complete MSVC x64 build tools installation was not found.' }
$devcmd = Join-Path $vs 'Common7/Tools/VsDevCmd.bat'
# Capture the official x64 developer environment into this process only.
$environment = & $env:ComSpec /d /c "call `"$devcmd`" -no_logo -arch=x64 -host_arch=x64 >nul && set"
if ($LASTEXITCODE -ne 0) { throw 'VsDevCmd failed.' }
foreach ($line in $environment) {
    if ($line -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}
$clang = Join-Path $vs 'VC/Tools/Llvm/x64/bin'
$cmake = Join-Path $vs 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
$ninja = Join-Path $vs 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja'
if (!(Test-Path (Join-Path $clang 'clang++.exe')) -or !(Test-Path $cmake)) {
    throw 'Add the C++ Clang and CMake components from .vsconfig.'
}
$env:PATH = "$clang;$ninja;$env:PATH"
& (Join-Path $PSScriptRoot 'setup-sdk.ps1')
if ($LASTEXITCODE -ne 0) { throw 'SDK setup failed.' }
$sdk = Join-Path $projectRoot 'tooling/rexglue-sdk'
& $cmake --preset win-amd64-release "-DCMAKE_PREFIX_PATH=$sdk"
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
if ($ConfigureOnly) { return }
& $cmake --build --preset win-amd64-release --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw 'Native build failed; inspect compiler diagnostics.' }
# The recompiler can emit fatal branch placeholders that still compile as C++.
$unresolved = Get-ChildItem (Join-Path $projectRoot 'generated/default') -Filter '*.cpp' |
    Select-String -SimpleMatch 'REX_FATAL("Unresolved branch'
if ($unresolved) {
    $unresolved | ForEach-Object { Write-Warning "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" }
    throw 'Generated code contains unresolved branch traps; fix function boundaries before running.'
}
& (Join-Path $PSScriptRoot 'build-gpu-plugin.ps1') -Jobs $Jobs -Stage
