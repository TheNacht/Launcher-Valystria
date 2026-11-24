$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'Valystria.ps1'
$settings = Join-Path $PSScriptRoot 'actualizaciones.json'
$temporary = $null
try {
    $source = (Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json).origen
    if ($source) {
        $cache = Join-Path $env:LOCALAPPDATA 'ValystriaOutbreak\actualizaciones'
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($source))).Replace('-','')
        } finally { $sha.Dispose() }
        $cache = Join-Path $cache $key
        [void][IO.Directory]::CreateDirectory($cache)
        $installed = Join-Path $cache 'Valystria.ps1'
        if ([IO.File]::Exists($installed)) { $launcher = $installed }
        $temporary = Join-Path $cache ([guid]::NewGuid().ToString() + '.ps1')
        if ($source -match '^https://') {
            Invoke-WebRequest -Uri $source -OutFile $temporary -UseBasicParsing -TimeoutSec 8 -MaximumRedirection 0
        } elseif ([IO.Path]::IsPathRooted($source)) {
            [IO.File]::Copy($source,$temporary)
        } else { throw 'El origen debe ser una URL HTTPS directa o una ruta absoluta.' }
        $errorsFound = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($temporary,[ref]$null,[ref]$errorsFound)
        if ($errorsFound.Count -or !$ast.EndBlock.Statements.Count -or $ast.Extent.Text.TrimStart().StartsWith('<')) {
            throw 'El archivo recibido no es un launcher valido.'
        }
        if ((Get-FileHash -LiteralPath $temporary).Hash -ne (Get-FileHash -LiteralPath $launcher).Hash) {
            if ([IO.File]::Exists($installed)) { [IO.File]::Replace($temporary,$installed,($installed + '.bak')) }
            else { [IO.File]::Move($temporary,$installed) }
            $launcher = $installed
        }
    }
} catch {
    Write-Warning $_.Exception.Message
} finally {
    if ($temporary -and [IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
}
$env:VALYSTRIA_LAUNCHER_DIR = $PSScriptRoot
& $launcher

