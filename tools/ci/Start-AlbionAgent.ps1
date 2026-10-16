param([Parameter(Mandatory)][string]$ConfigPath)
$ErrorActionPreference='Stop'
$config=Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$runner=Join-Path $config.root 'runner'
$listener=Join-Path $runner 'bin\Runner.Listener.exe'
if(@(Get-Process -Name Runner.Listener -ErrorAction SilentlyContinue | Where-Object {try{$_.Path -eq $listener}catch{$false}}).Count){return}
$env:ALBION_AGENT_CONFIG=$ConfigPath
Start-Process -FilePath (Join-Path $runner 'run.cmd') -WorkingDirectory $runner -WindowStyle Hidden
