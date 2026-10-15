$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$tooling = Join-Path $projectRoot 'tooling'
$sdk = Join-Path $tooling 'rexglue-sdk'
if (Test-Path (Join-Path $sdk 'bin/rexglue.exe')) {
    Write-Output "SDK already available: $sdk"
    exit 0
}
New-Item -ItemType Directory -Force $tooling | Out-Null
$archive = Join-Path $tooling 'rexglue-sdk-0.10.0-win-amd64.zip'
Invoke-WebRequest 'https://github.com/rexglue/rexglue-sdk/releases/download/v0.10.0/rexglue-sdk-0.10.0-win-amd64.zip' -OutFile $archive
$expected = 'AD4485DA853FBE932E9F5DBB643F9B5FE85DC73775EBBAD4DF6879FE6DF0C11B'
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) {
    throw 'SDK archive hash mismatch. Do not run this download.'
}
$staging = Join-Path $tooling ('sdk-unpack-' + [Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $archive -DestinationPath $staging
Move-Item -LiteralPath (Join-Path $staging 'win-amd64') -Destination $sdk
Write-Output "SDK installed locally: $sdk"
