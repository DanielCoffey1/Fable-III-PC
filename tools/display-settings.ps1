function Get-Fable3RenderScale {
    param([string]$SettingsPath=(Join-Path $env:LOCALAPPDATA 'AlbionReborn\fable3-display.json'))
    try {
        $value=Get-Content -LiteralPath $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if($value.schemaVersion -eq 1 -and [string]$value.renderScale -in @('1','2','3')){return [int]$value.renderScale}
    } catch { }
    return 1
}
