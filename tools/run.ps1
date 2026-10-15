$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$executable = Join-Path $projectRoot 'out/build/win-amd64-release/fable_3.exe'
if (!(Test-Path -LiteralPath $executable)) { throw 'No native build exists yet. Run tools/build.ps1 first.' }
$gameRoot = Join-Path $projectRoot 'game'
Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable) -ArgumentList @('--game_data_root', ('"' + $gameRoot + '"')) -WindowStyle Hidden
