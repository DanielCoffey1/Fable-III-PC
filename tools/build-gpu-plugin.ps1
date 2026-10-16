param([ValidateRange(1,32)][int]$Jobs = 8, [switch]$Stage)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sdk = Join-Path $projectRoot 'tooling/rexglue-sdk'
$work = Join-Path $projectRoot 'work/fable3-gpu'
$source = Join-Path $work 'sdk-source'
$build = Join-Path $work 'build'
$dll = Join-Path $build 'rexgpu-fable3.dll'
$sdkCommit = 'f5337cdc947ff6d4c4196737e2c807a48f2a1fc2'
$shaderCommit = 'b7350635be5a48a1b28b3bcf0e334b7f7c671abd'
$fetchPatch = Join-Path $projectRoot 'patches/rexglue-v0.10.0-signed16-integer-fetch.patch'
$geometryPatch = Join-Path $projectRoot 'patches/rexglue-v0.10.0-face-cull-diagnostic.patch'
$visibilityPatch = Join-Path $projectRoot 'patches/rexglue-v0.10.0-mesh-visibility.patch'
$resolvePatch = Join-Path $projectRoot 'patches/xenia-canary-b7350635-typed-resolve.patch'
$manifestPath = Join-Path $PSScriptRoot 'gpu-plugin/shader-sources.json'
if (!(Test-Path (Join-Path $sdk 'bin/rexruntime.dll'))) {
    throw 'Run tools/setup-sdk.ps1 before building the GPU plugin.'
}
New-Item -ItemType Directory -Force $work | Out-Null
$inputs = @($PSCommandPath, $fetchPatch, $geometryPatch, $visibilityPatch, $resolvePatch, $manifestPath,
    (Join-Path $PSScriptRoot 'gpu-plugin/CMakeLists.txt'), (Join-Path $sdk 'bin/rexruntime.dll'))
$signature = (($inputs | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }) -join ':')
$stampPath = Join-Path $work 'build-stamp.json'
$cached = $false
if ((Test-Path $dll) -and (Test-Path $stampPath)) {
    $stamp = Get-Content -LiteralPath $stampPath -Raw | ConvertFrom-Json
    $cached = $stamp.inputs -eq $signature -and $stamp.dll -eq (Get-FileHash $dll -Algorithm SHA256).Hash
}
if (!$cached) {
    if (!(Test-Path (Join-Path $source '.git'))) {
        & git clone --depth 1 --branch v0.10.0 https://github.com/rexglue/rexglue-sdk.git $source
        if ($LASTEXITCODE -ne 0) { throw 'GPU SDK source clone failed.' }
    }
    $head = & git -C $source rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $head -ne $sdkCommit) { throw 'Unexpected GPU SDK source revision.' }
    foreach ($sourcePatch in @($fetchPatch, $geometryPatch, $visibilityPatch)) {
        # A fresh checkout is expected to fail the reverse check. Windows
        # PowerShell otherwise promotes redirected native stderr to a fatal
        # NativeCommandError before we can inspect git's exit code.
        $previousPreference=$ErrorActionPreference
        try {
            $ErrorActionPreference='Continue'
            & git -C $source apply --reverse --check $sourcePatch 2>$null
            $reverseExit=$LASTEXITCODE
        } finally { $ErrorActionPreference=$previousPreference }
        if ($reverseExit -ne 0) {
            & git -C $source apply --check $sourcePatch
            if ($LASTEXITCODE -ne 0) { throw "GPU source patch does not apply cleanly: $sourcePatch" }
            & git -C $source apply $sourcePatch
            if ($LASTEXITCODE -ne 0) { throw "GPU source patch failed: $sourcePatch" }
        }
    }

    $shaderCache = Join-Path $work 'upstream-shaders'
    $shaderSource = Join-Path $work 'shader-source'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    foreach ($item in $manifest.PSObject.Properties) {
        $relative = $item.Name
        $cachedFile = Join-Path $shaderCache $relative
        if (!(Test-Path $cachedFile)) {
            New-Item -ItemType Directory -Force (Split-Path $cachedFile) | Out-Null
            Invoke-WebRequest "https://raw.githubusercontent.com/xenia-canary/xenia-canary/$shaderCommit/src/xenia/$relative" -OutFile $cachedFile
        }
        if ((Get-FileHash $cachedFile -Algorithm SHA256).Hash -ne $item.Value) {
            throw "Pinned upstream shader hash mismatch: $relative"
        }
        $preparedFile = Join-Path $shaderSource $relative
        New-Item -ItemType Directory -Force (Split-Path $preparedFile) | Out-Null
        Copy-Item -LiteralPath $cachedFile -Destination $preparedFile
    }
    & git -C $shaderSource apply --check $resolvePatch
    if ($LASTEXITCODE -ne 0) { throw 'Typed-UAV shader patch does not apply.' }
    & git -C $shaderSource apply $resolvePatch
    if ($LASTEXITCODE -ne 0) { throw 'Typed-UAV shader patch failed.' }

    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$vs) { throw 'Visual Studio C++ Build Tools are required.' }
    $devcmd = Join-Path $vs 'Common7/Tools/VsDevCmd.bat'
    $environment = & $env:ComSpec /d /c "call `"$devcmd`" -no_logo -arch=x64 -host_arch=x64 >nul && set"
    if ($LASTEXITCODE -ne 0) { throw 'VsDevCmd failed.' }
    foreach ($line in $environment) {
        if ($line -match '^([^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
    $fxc = Join-Path $env:WindowsSdkDir "bin/$($env:WindowsSDKVersion.TrimEnd('\'))/x64/fxc.exe"
    if (!(Test-Path $fxc)) { throw 'The Windows SDK HLSL compiler (fxc.exe) is required.' }
    foreach ($name in @('resolve_full_64bpp', 'resolve_full_64bpp_scaled')) {
        $inputFile = Join-Path $shaderSource "gpu/shaders/$name.cs.xesl"
        $outputFile = Join-Path $source "src/graphics/shaders/bytecode/d3d12_5_1/$($name)_cs.h"
        & $fxc /D SHADING_LANGUAGE_HLSL_XE=1 /I (Split-Path $inputFile) /Fh $outputFile /T cs_5_1 /Vn "$($name)_cs" /O3 /Qstrip_reflect /Qstrip_debug /Qstrip_priv /Gfp /nologo $inputFile
        if ($LASTEXITCODE -ne 0) { throw "HLSL compilation failed: $name" }
    }
    $env:PATH = "$(Join-Path $vs 'VC/Tools/Llvm/x64/bin');$(Join-Path $vs 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja');$env:PATH"
    $cmake = Join-Path $vs 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
    & $cmake -S (Join-Path $PSScriptRoot 'gpu-plugin') -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ "-DCMAKE_PREFIX_PATH=$sdk" "-DFABLE3_GPU_SDK_SOURCE=$source"
    if ($LASTEXITCODE -ne 0) { throw 'GPU plugin CMake configuration failed.' }
    & $cmake --build $build --parallel $Jobs
    if ($LASTEXITCODE -ne 0) { throw 'GPU plugin build failed.' }
    @{ inputs = $signature; dll = (Get-FileHash $dll -Algorithm SHA256).Hash } |
        ConvertTo-Json | Set-Content -LiteralPath $stampPath
}
if ($Stage) {
    $target = Join-Path $projectRoot 'out/build/win-amd64-release/rexgpu-fable3.dll'
    if (!(Test-Path (Split-Path $target))) { throw 'Build the native application before staging its GPU plugin.' }
    if (!(Test-Path $target) -or (Get-FileHash $target).Hash -ne (Get-FileHash $dll).Hash) {
        Copy-Item -LiteralPath $dll -Destination $target
    }
    Write-Output "Fable III GPU plugin staged: $target"
} else {
    Write-Output "Fable III GPU plugin built: $dll"
}
