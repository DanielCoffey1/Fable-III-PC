param(
    [ValidateSet('auto', 'rtv', 'rov')]
    [string]$RenderTargetPath = 'auto',
    [ValidateSet('none', 'fast', 'some', 'full')]
    [string]$ReadbackResolve = 'none',
    [ValidateSet('any', 'd3d12', 'vulkan')]
    [string]$Backend = 'any',
    [switch]$FrameStats,
    [switch]$Smooth60 = $true,
    [switch]$OriginalGpu,
    [switch]$DiagnosticTwoSidedGeometry,
    [switch]$DiagnosticForceMeshVisibility,
    [switch]$MeshOcclusionWorkaround = $true,
    [ValidateRange(1.0, 8.0)]
    [double]$StaticDrawDistanceMultiplier = 1.0,
    [switch]$FuzzyAlpha,
    [switch]$SrgbRenderTargets,
    [switch]$SynchronousMemexport,
    [switch]$Bindful,
    [switch]$SynchronousShaders = $true,
    [switch]$LightingDiagnostics,
    [switch]$ShaderIfFlow,
    [ValidateRange(-1, 65535)]
    [int]$CaptureLightmapRegion = -1,
    [ValidateRange(1, 2000)]
    [int]$CaptureMilliseconds = 250,
    [ValidateRange(0, 3600)]
    [int]$CaptureAfterSeconds = 0
)
$ErrorActionPreference = 'Stop'
if ($OriginalGpu -and ($DiagnosticTwoSidedGeometry -or $DiagnosticForceMeshVisibility)) {
    throw 'Geometry compatibility options require the Fable III GPU plugin.'
}
$projectRoot = Split-Path $PSScriptRoot -Parent
$executable = Join-Path $projectRoot 'out/build/win-amd64-release/fable_3.exe'
if (!(Test-Path -LiteralPath $executable)) { throw 'No native build exists yet. Run tools/build.ps1 first.' }
$gameRoot = Join-Path $projectRoot 'game'
$launchArguments = @('--game_data_root', ('"' + $gameRoot + '"'), '--no-fullscreen', '--window_width', '1280', '--window_height', '720')
if ($OriginalGpu) {
    $launchArguments += '--gpu_plugin=xenos'
} else {
    if (!(Test-Path (Join-Path (Split-Path $executable) 'rexgpu-fable3.dll'))) {
        throw 'The Fable III lighting plugin is missing. Run tools/build.ps1 or tools/build-gpu-plugin.ps1 -Stage.'
    }
    $launchArguments += @('--gpu_plugin=fable3', '--direct_host_resolve=false')
}
if ($RenderTargetPath -ne 'auto') { $launchArguments += "--render_target_path_d3d12=$RenderTargetPath" }
$launchArguments += "--readback_resolve=$ReadbackResolve"
$launchArguments += "--fable3_gpu_backend=$Backend"
if ($FrameStats) { $launchArguments += '--fable3_frame_stats=true' }
$launchArguments += "--fable3_static_draw_distance_multiplier=$($StaticDrawDistanceMultiplier.ToString([Globalization.CultureInfo]::InvariantCulture))"
if ($DiagnosticTwoSidedGeometry) { $launchArguments += '--fable3_diagnostic_no_face_cull=true' }
if ($DiagnosticForceMeshVisibility) { $launchArguments += '--fable3_diagnostic_force_mesh_visibility=true' }
if (!$OriginalGpu) {
    $launchArguments += "--fable3_mesh_occlusion_workaround=$($MeshOcclusionWorkaround.IsPresent.ToString().ToLowerInvariant())"
}
if ($Smooth60) { $launchArguments += @('--vsync=false', '--fable3_frame_limit=60') }
if ($FuzzyAlpha) { $launchArguments += '--use_fuzzy_alpha_epsilon=true' }
if ($SrgbRenderTargets) { $launchArguments += '--gamma_render_target_as_unorm16=false' }
if ($SynchronousMemexport) { $launchArguments += '--readback_memexport_fast=false' }
if ($Bindful) { $launchArguments += '--d3d12_bindless=false' }
$launchArguments += "--async_shader_compilation=$((!$SynchronousShaders.IsPresent).ToString().ToLowerInvariant())"
if ($LightingDiagnostics) { $launchArguments += '--fable3_lighting_diagnostics=true' }
if ($ShaderIfFlow) { $launchArguments += '--dxbc_switch=false' }
if ($CaptureLightmapRegion -ge 0) { $launchArguments += "--fable3_capture_lightmap_region=$CaptureLightmapRegion" }
if ($CaptureMilliseconds -ne 250) { $launchArguments += "--fable3_capture_milliseconds=$CaptureMilliseconds" }
if ($CaptureAfterSeconds) { $launchArguments += "--fable3_capture_after_seconds=$CaptureAfterSeconds" }
Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable) -ArgumentList $launchArguments -WindowStyle Normal
