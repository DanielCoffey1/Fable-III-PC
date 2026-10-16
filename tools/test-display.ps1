$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'display-settings.ps1')
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('albion-display-'+[guid]::NewGuid().ToString('N')+'.json')
try {
    if((Get-Fable3RenderScale $temporary) -ne 1){throw 'Missing profile must use native scaling.'}
    [IO.File]::WriteAllText($temporary,'{"schemaVersion":1,"renderScale":3}')
    if((Get-Fable3RenderScale $temporary) -ne 3){throw '4K profile was not read.'}
    [IO.File]::WriteAllText($temporary,'{"schemaVersion":1,"renderScale":999}')
    if((Get-Fable3RenderScale $temporary) -ne 1){throw 'Invalid profile must fall back safely.'}
    $args4k=@(& (Join-Path $PSScriptRoot 'run.ps1') -DryRun -RenderScale 3)
    foreach($required in @('--fullscreen=true','--resolution_scale=3','--video_mode_width=1280','--video_mode_height=720','--fable3_frame_limit=60','--async_shader_compilation=false','--fable3_mesh_occlusion_workaround=true')){
        if($args4k -notcontains $required){throw "Missing launch setting: $required"}
    }
    $windowed=@(& (Join-Path $PSScriptRoot 'run.ps1') -DryRun -Windowed -RenderScale 1)
    if($windowed -notcontains '--fullscreen=false' -or $windowed -notcontains '--resolution_scale=1'){throw 'Windowed/native fallback failed.'}
    Write-Output 'Passed: display profile validation, fullscreen/4K arguments, 60 FPS and rendering-fix preservation, windowed/native fallback.'
}finally{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
