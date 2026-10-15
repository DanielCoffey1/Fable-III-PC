param(
    [ValidateSet('auto', 'rtv', 'rov')]
    [string]$RenderTargetPath = 'auto',
    [ValidateSet('none', 'fast', 'some', 'full')]
    [string]$ReadbackResolve = 'none',
    [ValidateSet('any', 'd3d12', 'vulkan')]
    [string]$Backend = 'any',
    [switch]$FrameStats,
    [switch]$Smooth60 = $true,
    [switch]$FuzzyAlpha,
    [switch]$SrgbRenderTargets,
    [switch]$SynchronousMemexport,
    [switch]$Bindful,
    [switch]$SynchronousShaders,
    [ValidateRange(0, 3600)]
    [int]$CaptureAfterSeconds = 0
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$executable = Join-Path $projectRoot 'out/build/win-amd64-release/fable_3.exe'
if (!(Test-Path -LiteralPath $executable)) { throw 'No native build exists yet. Run tools/build.ps1 first.' }
$gameRoot = Join-Path $projectRoot 'game'
$launchArguments = @('--game_data_root', ('"' + $gameRoot + '"'), '--no-fullscreen', '--window_width', '1280', '--window_height', '720')
if ($RenderTargetPath -ne 'auto') { $launchArguments += "--render_target_path_d3d12=$RenderTargetPath" }
$launchArguments += "--readback_resolve=$ReadbackResolve"
$launchArguments += "--fable3_gpu_backend=$Backend"
if ($FrameStats) { $launchArguments += '--fable3_frame_stats=true' }
if ($Smooth60) { $launchArguments += @('--vsync=false', '--fable3_frame_limit=60') }
if ($FuzzyAlpha) { $launchArguments += '--use_fuzzy_alpha_epsilon=true' }
if ($SrgbRenderTargets) { $launchArguments += '--gamma_render_target_as_unorm16=false' }
if ($SynchronousMemexport) { $launchArguments += '--readback_memexport_fast=false' }
if ($Bindful) { $launchArguments += '--d3d12_bindless=false' }
if ($SynchronousShaders) { $launchArguments += '--async_shader_compilation=false' }
if ($CaptureAfterSeconds) { $launchArguments += "--fable3_capture_after_seconds=$CaptureAfterSeconds" }
Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable) -ArgumentList $launchArguments -WindowStyle Normal
