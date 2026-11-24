$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'Valystria.ps1'
$settings = Join-Path $PSScriptRoot 'actualizaciones.json'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$splash = New-Object Windows.Forms.Form
$splash.Text = 'Valystria Outbreak'
$splash.StartPosition = 'CenterScreen'
$splash.FormBorderStyle = 'None'
$splash.ControlBox = $false
$splash.ClientSize = New-Object Drawing.Size(556,262)
$splash.BackColor = [Drawing.ColorTranslator]::FromHtml('#200810')
$splash.Icon = New-Object Drawing.Icon((Join-Path $PSScriptRoot 'outbreak.ico'),32,32)
$art = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'zombies.png'))
$backdrop = New-Object Drawing.Bitmap(556,262)
$graphics = [Drawing.Graphics]::FromImage($backdrop)
$graphics.DrawImage($art,0,-58,556,417)
$shade = New-Object Drawing.Drawing2D.LinearGradientBrush((New-Object Drawing.Rectangle(0,0,556,262)),[Drawing.Color]::FromArgb(223,25,3,11),[Drawing.Color]::FromArgb(42,31,3,9),0.0)
$graphics.FillRectangle($shade,0,0,556,262)
$graphics.Dispose();$shade.Dispose();$art.Dispose()
$splash.BackgroundImage = $backdrop
$emblem = New-Object Windows.Forms.PictureBox
$emblem.SetBounds(25,17,75,75)
$emblem.SizeMode = 'Zoom'
$emblem.BackColor = [Drawing.Color]::Transparent
$emblem.Image = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'logo-outbreak.png'))
$splash.Controls.Add($emblem)
$title = New-Object Windows.Forms.Label
$title.SetBounds(27,99,460,65)
$title.Font = New-Object Drawing.Font('Segoe UI Black',30)
$title.ForeColor = [Drawing.Color]::MistyRose
$title.BackColor = [Drawing.Color]::Transparent
$title.Text = 'OUTBREAK'
$splash.Controls.Add($title)
$loading = New-Object Windows.Forms.Label
$loading.SetBounds(31,184,495,35)
$loading.BackColor = [Drawing.Color]::Transparent
$loading.ForeColor = [Drawing.Color]::White
$loading.Font = New-Object Drawing.Font('Segoe UI',11)
$loading.Text = 'Comprobando actualizaciones del launcher…'
$splash.Controls.Add($loading)
$track = New-Object Windows.Forms.Panel
$track.SetBounds(32,230,492,4)
$track.BackColor = [Drawing.Color]::FromArgb(85,45,51)
$bar = New-Object Windows.Forms.Panel
$bar.SetBounds(0,0,112,4)
$bar.BackColor = [Drawing.Color]::FromArgb(246,82,97)
$track.Controls.Add($bar)
$splash.Controls.Add($track)
$splash.Show()
$splash.Refresh()
$temporary = $null
try {
    $source = (Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json).origen
    if ($source) {
        $cache = Join-Path $env:LOCALAPPDATA 'ValystriaOutbreak\actualizaciones/v9'
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
        $packSync = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Sync-Pack'}, $true)
        if (!$ast.Extent.Text.Contains('# Interfaz Valystria 9') -or !$packSync -or $errorsFound.Count -or !$ast.EndBlock.Statements.Count -or $ast.Extent.Text.TrimStart().StartsWith('<')) {
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
try { & $launcher } finally { $splash.Dispose();$backdrop.Dispose();$emblem.Image.Dispose() }



