function Get-Fable3RenderScale {
    param([string]$SettingsPath=(Join-Path $env:LOCALAPPDATA 'AlbionReborn\fable3-display.json'))
    try {
        $value=Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if($value.schemaVersion -eq 1 -and [string]$value.renderScale -in @('1','2','3')){return [int]$value.renderScale}
    } catch { }
    return 1
}
function Get-Fable3Resolution {
    if($env:ALBION_RESOLUTION -in @('1080p','1440p','4k')){return $env:ALBION_RESOLUTION}
    try{
        $path=Join-Path $env:LOCALAPPDATA 'AlbionReborn\display-settings.json'
        $value=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if($value.schemaVersion -eq 1 -and $value.resolution -in @('1080p','1440p','4k')){return [string]$value.resolution}
    }catch{}
    return '1080p'
}
