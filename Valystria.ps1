param([string]$LauncherDirectory = $(if ($env:VALYSTRIA_LAUNCHER_DIR) { $env:VALYSTRIA_LAUNCHER_DIR } else { $PSScriptRoot }))
# Interfaz Valystria 9
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[Windows.Forms.Application]::EnableVisualStyles()
$settingsDir = Join-Path $env:LOCALAPPDATA 'ValystriaOutbreak'
[void][IO.Directory]::CreateDirectory($settingsDir)
$settingsFile = Join-Path $settingsDir 'juego.json'
$config = @{ carpeta=''; forge=''; cliente=''; local=$false; nombre='' }
if (Test-Path $settingsFile) {
    $saved = Get-Content $settingsFile -Raw | ConvertFrom-Json
    foreach ($key in @($config.Keys)) { $config[$key] = $saved.$key }
}
$config.carpeta = Join-Path $settingsDir 'Modpack'
[void][IO.Directory]::CreateDirectory((Join-Path $config.carpeta 'mods'))
Add-Type -Namespace Valystria -Name Taskbar -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("shell32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int SetCurrentProcessExplicitAppUserModelID(string id);
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int length);
"@
[void][Valystria.Taskbar]::SetCurrentProcessExplicitAppUserModelID('Valystria.Outbreak.Launcher')
$form = New-Object Windows.Forms.Form
$form.Text = 'Valystria Outbreak'
$form.ClientSize = New-Object Drawing.Size(936,548)
$iconPath = Join-Path $LauncherDirectory 'outbreak.ico'
if (Test-Path -LiteralPath $iconPath) {
    $form.Icon = New-Object Drawing.Icon($iconPath, 32, 32)
}
$captionColor = 0x00110832
[void][Valystria.Taskbar]::DwmSetWindowAttribute($form.Handle,35,[ref]$captionColor,4)
$captionText = 0x00e4deff
[void][Valystria.Taskbar]::DwmSetWindowAttribute($form.Handle,36,[ref]$captionText,4)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'None'
$form.MaximizeBox = $false
$form.BackColor = [Drawing.ColorTranslator]::FromHtml('#18070c')
$form.ForeColor = [Drawing.Color]::White
function Add-Label($caption,$top,$size,$height) {
    $label = New-Object Windows.Forms.Label
    $label.BackColor = [Drawing.Color]::Transparent
    $label.Text = $caption
    $label.SetBounds(32,$top,496,$height)
    $label.Font = New-Object Drawing.Font('Segoe UI',$size)
    $form.Controls.Add($label)
    return $label
}
function Add-Button($caption,$left,$top,$width,$handler) {
    $button = New-Object Windows.Forms.Button
    $button.Text = $caption
    $button.SetBounds($left,$top,$width,44)
    $button.FlatStyle = 'Flat'
    $button.Add_Click($handler)
    $form.Controls.Add($button)
    return $button
}

$minimize = Add-Button '―' 842 10 40 { $form.WindowState = 'Minimized' }
$close = Add-Button '×' 886 10 40 { $form.Close() }
foreach ($button in $minimize,$close) {
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = [Drawing.Color]::Transparent
    $button.Font = New-Object Drawing.Font('Segoe UI',15)
}
$minimize.AccessibleName = 'Minimizar'
$close.AccessibleName = 'Cerrar'
$form.Add_MouseDown({param($sender,$ev) if ($ev.Button -eq 'Left' -and $ev.Y -lt 78) { $script:dragStart = $ev.Location }})
$form.Add_MouseMove({param($sender,$ev) if ($script:dragStart -and $ev.Button -eq 'Left') { $pointer=[Windows.Forms.Cursor]::Position; $form.Location = New-Object Drawing.Point(($pointer.X-$script:dragStart.X),($pointer.Y-$script:dragStart.Y)) }})
$form.Add_MouseUp({ $script:dragStart=$null })
$scene = [Drawing.Image]::FromFile((Join-Path $LauncherDirectory 'zombies.png'))
$canvas = New-Object Drawing.Bitmap(936,548)
$gfx = [Drawing.Graphics]::FromImage($canvas)
$scale = [Math]::Max(936/$scene.Width,548/$scene.Height)
$w = [int]($scale*$scene.Width)
$h = [int]($scale*$scene.Height)
$scene.RotateFlip([Drawing.RotateFlipType]::RotateNoneFlipX)
$gfx.DrawImage($scene,[int]((936-$w)/2),[int]((548-$h)/2),$w,$h)
$bounds = New-Object Drawing.Rectangle(0,0,936,548)
$veil = New-Object Drawing.Drawing2D.LinearGradientBrush($bounds,[Drawing.Color]::FromArgb(80,30,2,10),[Drawing.Color]::FromArgb(10,114,0,20),12.0)
$gfx.FillRectangle($veil,$bounds)
$veil.Dispose()
$veil = New-Object Drawing.Drawing2D.LinearGradientBrush($bounds,[Drawing.Color]::Transparent,[Drawing.Color]::FromArgb(205,15,2,8),90.0)
$gfx.FillRectangle($veil,$bounds)
$veil.Dispose()
# Frameless inset account card and the crimson accent lines are painted into the scene.
$card = New-Object Drawing.Drawing2D.GraphicsPath
$card.AddRectangle((New-Object Drawing.Rectangle(635,89,270,357)))
$panelBrush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(115,25,12,20))
$edge = New-Object Drawing.Pen([Drawing.Color]::FromArgb(95,211,136,147))
$gfx.SmoothingMode = 'AntiAlias'
$gfx.FillPath($panelBrush,$card)
$gfx.DrawPath($edge,$card)
$gfx.DrawLine($edge,36,77,901,77)
$gfx.DrawLine($edge,658,164,881,164)
$accent = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(232,50,78))
$gfx.FillRectangle($accent,38,286,39,4)
$gfx.FillRectangle($accent,659,160,28,3)
$accent.Dispose()
$edge.Dispose()
$panelBrush.Dispose()
$card.Dispose()
$gfx.Dispose()
$scene.Dispose()
$form.BackgroundImage = $canvas
$brand = New-Object Windows.Forms.PictureBox
$brand.SetBounds(27,12,52,52)
$brand.SizeMode = 'Zoom'
$brand.BackColor = [Drawing.Color]::Transparent
$brand.Image = [Drawing.Image]::FromFile((Join-Path $LauncherDirectory 'logo-outbreak.png'))
$form.Controls.Add($brand)
$network = Add-Label 'VALYSTRIA' 22 15 30
$network.SetBounds(90,22,120,32)
$network.Font = New-Object Drawing.Font('Segoe UI Semibold',15)
$heading = Add-Label 'OUTBREAK' 291 46 87
$heading.Font = New-Object Drawing.Font('Segoe UI Black',48)
$heading.ForeColor = [Drawing.ColorTranslator]::FromHtml('#ffdee1')
$fonts = New-Object Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $LauncherDirectory 'nemo-regular.ttf'))
$heading.Text = ''
$heading.AccessibleName = 'Outbreak'
$heading.Visible = $false
$titleArt = New-Object Windows.Forms.PictureBox
$titleArt.AccessibleName = 'Valystria: Outbreak'
$titleArt.SetBounds(32,234,437,132)
$titleArt.BackColor = [Drawing.Color]::Transparent
$titleArt.Image = New-Object Drawing.Bitmap(437,132)
$ink = [Drawing.Graphics]::FromImage($titleArt.Image)
$ink.SmoothingMode='AntiAlias'
$glyphs=New-Object Drawing.Drawing2D.GraphicsPath
$family=New-Object Drawing.FontFamily('Segoe UI Black')
$glyphs.AddString('VALYSTRIA:',$family,0,62,[Drawing.PointF]::new(0,-7),[Drawing.StringFormat]::GenericTypographic)
$glyphs.AddString('OUTBREAK',$family,0,62,[Drawing.PointF]::new(0,53),[Drawing.StringFormat]::GenericTypographic)
$gold=New-Object Drawing.Drawing2D.LinearGradientBrush((New-Object Drawing.Rectangle(0,0,410,125)),[Drawing.Color]::LightSalmon,[Drawing.Color]::Wheat,15.0)
$ink.FillPath($gold,$glyphs)
$ink.SetClip($glyphs)
$random=New-Object Random(917)
$ink.CompositingMode='SourceCopy'
for($i=0;$i -lt 1550;$i++){
    $size=$random.Next(1,4)
    $ink.FillEllipse([Drawing.Brushes]::Transparent,$random.Next(420),$random.Next(130),$size,$random.Next(1,4))
}
$ink.Dispose();$gold.Dispose();$glyphs.Dispose();$family.Dispose()
$form.Controls.Add($titleArt)
$network.Text=''
$network.AccessibleName='Valystria'
$network.Add_Paint({
    param($sender,$ev)
    $path=New-Object Drawing.Drawing2D.GraphicsPath
    $path.AddString('Valystria',$fonts.Families[0],0,24,[Drawing.PointF]::new(0,0),[Drawing.StringFormat]::GenericTypographic)
    $phase = ($clock.Elapsed.TotalSeconds % 5.4)/5.4
    $shift = [int](200*[Math]::Min(1,[Math]::Max(0,($phase-0.18)/0.52)))-122
    $rect = New-Object Drawing.Rectangle($shift,0,140,32)
    $brush=New-Object Drawing.Drawing2D.LinearGradientBrush($rect,[Drawing.Color]::Wheat,[Drawing.Color]::Coral,15.0)
    $blend=New-Object Drawing.Drawing2D.ColorBlend
    $blend.Positions=[single[]](0,.38,.49,.54,.66,1)
    $blend.Colors=[Drawing.Color[]]@('#f2cebd','#f2cebd','#fffbdd','#ffb46a','#f2cebd','#f2cebd'|ForEach-Object {[Drawing.ColorTranslator]::FromHtml($_)})
    $brush.InterpolationColors=$blend
    $ev.Graphics.SmoothingMode='AntiAlias';$ev.Graphics.FillPath($brush,$path)
    $brush.Dispose();$path.Dispose()
})
$meta = Add-Label 'MINECRAFT 1.20.1    /    FORGE 47.4.28' 376 10 26
$meta.ForeColor = [Drawing.ColorTranslator]::FromHtml('#ffc1c8')
function Get-PackFile($relative) {
    if ($relative -notmatch '^(mods|config|defaultconfigs|resourcepacks|shaderpacks|kubejs|scripts|global_packs)/' -or
        $relative -match '[\\:*?"<>|\x00-\x1f]' -or ($relative.Split('/') | Where-Object { !$_ -or $_ -match '[ .]$|^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)' })) {
        throw "Ruta de pack no valida: $relative"
    }
    $file = Join-Path $config.carpeta $relative
    $item = $file
    while ($item -ne $settingsDir) {
        if ((Test-Path -LiteralPath $item) -and ((Get-Item -Force -LiteralPath $item).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Enlace local no permitido: $relative" }
        $item = Split-Path -Parent $item
    }
    return $file
}
function Get-BlobHash($file) {
    $stream = [IO.File]::OpenRead($file)
    $hash = [Security.Cryptography.SHA1]::Create()
    try {
        $prefix = [Text.Encoding]::ASCII.GetBytes("blob $($stream.Length)`0")
        [void]$hash.TransformBlock($prefix,0,$prefix.Length,$prefix,0)
        $buffer = New-Object byte[] 65536
        while (($read = $stream.Read($buffer,0,$buffer.Length)) -gt 0) { [void]$hash.TransformBlock($buffer,0,$read,$buffer,0) }
        [void]$hash.TransformFinalBlock($buffer,0,0)
        return [BitConverter]::ToString($hash.Hash).Replace('-','').ToLowerInvariant()
    } finally { $hash.Dispose(); $stream.Dispose() }
}
function Sync-Pack {
    $status.Text = 'Comprobando el modpack en GitHub...'
    $form.Refresh()
    $api = 'https://api.github.com/repos/TheNacht/Launcher-Valystria'
    try {
        $commit = (Invoke-RestMethod "$api/commits/main" -TimeoutSec 20).sha
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            throw 'Pack no disponible. Comprueba que TheNacht/Launcher-Valystria sea publico y tenga la rama main.'
        }
        throw
    }
    if ($commit -notmatch '^[a-f0-9]{40}$') { throw 'Respuesta de GitHub no valida.' }
    $tree = Invoke-RestMethod "$api/git/trees/${commit}?recursive=1" -TimeoutSec 30
    if ($tree.truncated -or !$tree.tree) { throw 'GitHub devolvio una lista incompleta.' }
    $files = @($tree.tree | Where-Object { $_.mode -in '100644','100755' -and $_.path -match '^Modpack/(mods|config|defaultconfigs|resourcepacks|shaderpacks|kubejs|scripts|global_packs)/' -and $_.path -notlike '*/.gitkeep' })

    $ledger = Join-Path $settingsDir 'archivos-pack.json'
    $old = @()
    if (Test-Path $ledger) { $old = @((Get-Content $ledger -Raw | ConvertFrom-Json).files) }
    $current = @{}
    foreach ($entry in $files) {
        $name = $entry.path.Substring(8)
        $file = Get-PackFile $name
        $current.Add($name,$true)
        if ([IO.File]::Exists($file) -and (Get-BlobHash $file) -eq $entry.sha) { continue }
        if ($splash -and $splash.Visible) { $loading.Text = "Descargando $name"; $splash.Refresh() }
        $status.Text = "Descargando $name"
        $form.Refresh()
        [void][IO.Directory]::CreateDirectory((Split-Path $file))
        $tmp = Join-Path $settingsDir ([guid]::NewGuid().ToString())
        try {
            $urlPath = ($entry.path.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
            Invoke-WebRequest "https://raw.githubusercontent.com/TheNacht/Launcher-Valystria/$commit/$urlPath" -OutFile $tmp -UseBasicParsing -TimeoutSec 180
            if ((Get-BlobHash $tmp) -ne $entry.sha) { throw "Descarga incompleta: $name" }
            [IO.File]::Copy($tmp,$file,$true)
        } finally { if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) } }
    }
    foreach ($name in $old) {
        if ($name -and !$current.ContainsKey($name)) { [IO.File]::Delete((Get-PackFile $name)) }
    }
    $journal = $ledger + '.new'
    @{files=@($current.Keys)} | ConvertTo-Json | Set-Content $journal -Encoding UTF8
    if ([IO.File]::Exists($ledger)) { [IO.File]::Replace($journal,$ledger,($ledger+'.bak')) } else { [IO.File]::Move($journal,$ledger) }
    $status.Text = Get-PackStatus
}
function Get-PackStatus {
    $mods = @(Get-ChildItem -LiteralPath (Join-Path $config.carpeta 'mods') -File -Filter '*.jar' -ErrorAction SilentlyContinue)
    if (!$mods.Count) { return 'Forge listo para jugar.' }
    return "Modpack listo: $($mods.Count) archivos .jar en mods."
}
$status = Add-Label (Get-PackStatus) 365 10 65
$status.SetBounds(658,335,224,98)
$accountTitle = Add-Label 'Cuenta de jugador' 118 17 36
$accountTitle.SetBounds(658,113,235,40)
$account = New-Object Windows.Forms.Button
$account.Font = New-Object Drawing.Font('Segoe UI Semibold',11)
$account.FlatStyle = 'Flat'
$account.FlatAppearance.BorderColor = [Drawing.ColorTranslator]::FromHtml('#a63851')
$account.BackColor = [Drawing.ColorTranslator]::FromHtml('#40101c')
$account.ForeColor = [Drawing.Color]::MistyRose
$account.TextAlign = 'MiddleLeft'
$account.Padding = New-Object Windows.Forms.Padding(12,0,0,0)
$account.SetBounds(658,184,224,40)
$account.FlatAppearance.BorderColor = [Drawing.ColorTranslator]::FromHtml('#af4a62')
$account.FlatAppearance.MouseOverBackColor = [Drawing.ColorTranslator]::FromHtml('#662138')
$account.Add_Paint({param($sender,$ev)
    foreach ($offset in 0,5,10) { $ev.Graphics.FillEllipse([Drawing.Brushes]::LightPink,($sender.Width-23+$offset),18,2,2) }
})
$account.AccessibleName = 'Elegir cuenta de jugador'
$choices = @('Premium · Microsoft','Sin cuenta · No premium')
$account.Tag = [int][bool]$config.local
$account.Text = $choices[$account.Tag]
$form.Controls.Add($account)
$menu = New-Object Windows.Forms.ContextMenuStrip
Add-Type -ReferencedAssemblies System.Drawing,System.Windows.Forms -TypeDefinition @"
using System.Drawing;
using System.Windows.Forms;
public sealed class OutbreakMenuRenderer : ToolStripProfessionalRenderer {
    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e) {
        using (var brush = new SolidBrush(e.Item.Selected ? Color.FromArgb(142,20,48) : Color.FromArgb(60,12,26)))
            e.Graphics.FillRectangle(brush, new Rectangle(Point.Empty,e.Item.Size));
    }
}
"@
$menu.Renderer = New-Object OutbreakMenuRenderer
$menu.BackColor = $account.BackColor
$menu.ShowImageMargin = $false
$menu.Padding = New-Object Windows.Forms.Padding(4)
$menu.ShowCheckMargin = $true
foreach ($choice in $choices) {
    $item = $menu.Items.Add($choice)
    $item.BackColor = $account.BackColor
    $item.ForeColor = $account.ForeColor
    $item.Font = $account.Font
    $item.AutoSize = $false; $item.Size = New-Object Drawing.Size(212,36)
}
$menu.Add_ItemClicked({
    param($sender,$eventArgs)
    $account.Tag = $sender.Items.IndexOf($eventArgs.ClickedItem)
    $account.Text = $choices[$account.Tag]
    Update-AccountFields
})
$account.Add_Click({ foreach ($option in $menu.Items) { $option.Checked = $option.Text -eq $account.Text }; $menu.Show($account,0,($account.Height+4)) })
$nameLabel = Add-Label 'Nombre de jugador' 205 11 25
$nameLabel.SetBounds(658,247,222,24)
$nameBox = New-Object Windows.Forms.TextBox
$nameBox.SetBounds(658,276,224,32)
$nameBox.Font = $account.Font
$nameBox.BorderStyle = 'FixedSingle'
$nameBox.BackColor = $account.BackColor
$nameBox.ForeColor = $account.ForeColor
$nameBox.AccessibleName = 'Nombre de jugador'
$nameBox.MaxLength = 16
$nameBox.Text = [string]$config.nombre
$form.Controls.Add($nameBox)
Add-Type -Path (Join-Path $LauncherDirectory 'SkinPreview.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms,System.Web.Extensions,System.Core
$avatar = New-Object SkinPreview
$avatar.LoadDefault((Join-Path $LauncherDirectory 'default-player.png'))
$avatar.SetBounds(719,310,102,132)
$avatar.BackColor = [Drawing.Color]::Transparent
$avatar.SizeMode = 'Zoom'
$form.Controls.Add($avatar)
$skinDelay = New-Object Windows.Forms.Timer
$skinDelay.Interval = 650
$skinDelay.Add_Tick({
    $skinDelay.Stop()
    $who = $nameBox.Text.Trim()
    if ($account.Tag -eq 0) {
        $profileFile = Join-Path $settingsDir 'perfil-premium.txt'
        $who = if (Test-Path $profileFile) { [IO.File]::ReadAllText($profileFile) } else { '' }
    }
    $avatar.Choose([string]$who)
})
$nameBox.Add_TextChanged({$skinDelay.Stop();$skinDelay.Start()})
function Update-AccountFields {
    $skinDelay.Stop();$skinDelay.Start()
    $nameBox.Visible = $account.Tag -eq 1
    $nameLabel.Visible = $account.Tag -eq 1
}

Update-AccountFields
$notes = Add-Label "Interfaz del launcher`r`n`r`nGotas de sangre descendentes, panel translúcido y navegación entre cuenta y notas." 185 11 150
$notes.SetBounds(658,184,223,160)
$notes.Visible = $false
$homeInfo = Add-Label "Minecraft Java Edition`r`nMinecraft 1.20.1 · Forge 47.4.28`r`n`r`nPuedes elegir tu perfil en Cuenta y consultar los cambios en Notas de parche." 183 11 150
$homeInfo.SetBounds(658,184,223,144)
function Select-LauncherTab([string]$page) {
    $isAccount = $page -eq 'Cuenta'
    $homeInfo.Visible = $page -eq 'Inicio'
    $notes.Visible = $page -eq 'Notas de parche'
    $status.Visible = $page -eq 'Inicio'
    $avatar.Visible = $isAccount
    $account.Visible = $isAccount
    $accountTitle.Text = if ($isAccount) {'Cuenta de jugador'} else {$page}
    $nameLabel.Visible = $isAccount -and $account.Tag -eq 1
    $nameBox.Visible = $isAccount -and $account.Tag -eq 1
    foreach ($tab in $tabHome,$tabAccount,$tabNotes) {
        $tab.Font = if ($tab.Text -eq $page) {$tabBold} else {$tabRegular}
    }
}
$tabRegular = New-Object Drawing.Font('Segoe UI',10)
$tabBold = New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
$tabHome = Add-Button 'Inicio' 213 15 74 { Select-LauncherTab 'Inicio' }
$tabAccount = Add-Button 'Cuenta' 292 15 85 { Select-LauncherTab 'Cuenta' }
$tabNotes = Add-Button 'Notas de parche' 382 15 145 { Select-LauncherTab 'Notas de parche' }
foreach ($tabButton in $tabHome,$tabAccount,$tabNotes) {
    $tabButton.BackColor = [Drawing.Color]::FromArgb(100,40,7,15)
    $tabButton.FlatAppearance.BorderSize = 0
    $tabButton.FlatAppearance.MouseOverBackColor = [Drawing.Color]::FromArgb(170,104,15,37)
}
Select-LauncherTab 'Inicio'
$tabNotes.Font = $tabRegular
function Get-LauncherPython {
    $root = Join-Path $settingsDir 'python-3.12.10'
    $python = Join-Path $root 'tools\python.exe'
    if (!(Test-Path -LiteralPath $python)) {
        $stage = Join-Path $settingsDir ([guid]::NewGuid().ToString())
        [void][IO.Directory]::CreateDirectory($stage)
        try {
            $zip = Join-Path $stage 'python.zip'
            Invoke-WebRequest 'https://api.nuget.org/v3-flatcontainer/python/3.12.10/python.3.12.10.nupkg' -UseBasicParsing -OutFile $zip -TimeoutSec 300
            $unpacked = Join-Path $stage 'unpacked'
            Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
            if (!(Test-Path (Join-Path $unpacked 'tools\python.exe'))) { throw 'Descarga de Python incompleta.' }
            [IO.Directory]::Move($unpacked,$root)
        } finally {
            if (Test-Path -LiteralPath $stage) { [IO.Directory]::Delete($stage,$true) }
        }
    }
    return $python
}
$play = Add-Button 'JUGAR' 38 426 208 {
    $play.Enabled = $false
    try {
        if (!$script:packReady) { Sync-Pack; $script:packReady = $true }
        $config.forge = '47.4.28'
        $config.local = $account.Tag -eq 1
        $config.nombre = $nameBox.Text.Trim()
        if ($config.local -and $config.nombre -notmatch '^[A-Za-z0-9_]{3,16}$') {
            throw 'Usa un nombre de 3 a 16 caracteres con letras, numeros o guion bajo.'
        }
        if (!$config.local -and !$config.cliente) {
            $config.cliente = (Get-Content (Join-Path $LauncherDirectory 'actualizaciones.json') -Raw | ConvertFrom-Json).microsoftClientId
            if (!$config.cliente) { throw 'El acceso Premium está pendiente de configurar por Valystria.' }
        }
        $config | ConvertTo-Json | Set-Content $settingsFile -Encoding UTF8
        Select-LauncherTab 'Inicio'
        $status.Text = 'Preparando el juego. El primer inicio puede tardar varios minutos.'
        $form.Refresh()
        $python = Get-LauncherPython
        & $python -m pip install --disable-pip-version-check 'minecraft-launcher-lib==8.0' 'keyring>=25,<26'
        if ($LASTEXITCODE) { throw 'No se pudieron preparar las dependencias de Python.' }
        $env:VALYSTRIA_HOME = $settingsDir
        $resultFile = Join-Path $settingsDir ('inicio-' + [guid]::NewGuid() + '.txt')
        $env:VALYSTRIA_RESULT = $resultFile
        $engine | & $python -
        if ($LASTEXITCODE) {
            if (Test-Path $resultFile) { throw (Get-Content $resultFile -Raw -Encoding UTF8) }
            throw 'Error al iniciar Minecraft.'
        }
        $form.Close()
    } catch { Select-LauncherTab 'Inicio'; $status.Text = $_.Exception.Message } finally {
        if ($resultFile -and (Test-Path $resultFile)) { Remove-Item -LiteralPath $resultFile }
        $play.Enabled = $true

    }
}
$engine = @"
import hashlib, json, os, shutil, subprocess, sys, uuid, webbrowser
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlsplit
import keyring
import minecraft_launcher_lib as mc
from minecraft_launcher_lib.exceptions import InvalidRefreshToken

def account(client):
    auth = mc.microsoft_account
    service = "Valystria Outbreak"
    refresh = keyring.get_password(service, client)
    if refresh:
        try:
            data = auth.complete_refresh(client, None, None, refresh)
        except InvalidRefreshToken:
            pass
        else:
            keyring.set_password(service, client, data["refresh_token"])
            return data
    class Callback(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass
        def do_GET(self):
            if urlsplit(self.path).path != "/callback":
                self.send_error(404)
                return
            server.reply = redirect + "?" + urlsplit(self.path).query
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Ya puedes volver a Valystria Outbreak.")
    with HTTPServer(("127.0.0.1", 0), Callback) as server:
        redirect = "http://localhost:%d/callback" % server.server_port
        url, state, verifier = auth.get_secure_login_data(client, redirect)
        server.timeout = 180
        server.reply = None
        webbrowser.open(url)
        server.handle_request()
        if not server.reply:
            raise RuntimeError("Inicio de sesion cancelado o caducado.")
        code = auth.parse_auth_code_url(server.reply, state)
    data = auth.complete_login(client, None, redirect, code, verifier)
    keyring.set_password(service, client, data["refresh_token"])
    return data

def start():
    home = Path(os.environ["VALYSTRIA_HOME"])
    config = json.loads((home / "juego.json").read_text(encoding="utf-8-sig"))
    game = Path(config["carpeta"])
    runtime = home / "minecraft"
    runtime.mkdir(exist_ok=True)
    version = "1.20.1"
    mc.install.install_minecraft_version(version, str(runtime))
    java = mc.runtime.get_executable_path("java-runtime-gamma", str(runtime))
    if not java:
        raise RuntimeError("No se pudo preparar Java 17 para Minecraft.")
    forge = version + "-" + config["forge"]
    version = mc.forge.forge_to_installed_version(forge)
    if not (runtime / "versions" / version / (version + ".json")).is_file():
        mc.forge.install_forge_version(forge, str(runtime), java=java)
    if config.get("local"):
        name = config["nombre"]
        digest = hashlib.md5(("OfflinePlayer:" + name).encode("utf-8")).digest()
        user = dict(name=name, id=uuid.UUID(bytes=digest, version=3).hex, access_token="0")
    else:
        user = account(config["cliente"])
        (home / "perfil-premium.txt").write_text(user["name"], encoding="utf-8")
    options = dict(username=user["name"], uuid=user["id"], token=user["access_token"],
                   gameDirectory=str(game), executablePath=java, launcherName="Valystria")
    command = mc.command.get_minecraft_command(version, str(runtime), options)
    with (home / "minecraft.log").open("wb") as log:
        subprocess.Popen(command, cwd=game, stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)

try:
    start()
except Exception as exc:
    detail = str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__
    Path(os.environ["VALYSTRIA_RESULT"]).write_text("No se pudo iniciar Minecraft: " + detail, encoding="utf-8")
    sys.exit(1)
"@
$play.Font = New-Object Drawing.Font('Segoe UI Semibold',13)
$play.FlatAppearance.BorderSize = 1
$play.FlatAppearance.BorderColor = [Drawing.ColorTranslator]::FromHtml('#ff6677')
$play.BackColor = [Drawing.Color]::FromArgb(145,148,13,39)
$play.Cursor = [Windows.Forms.Cursors]::Hand
$motion = @{ level=0; target=0; entrance=0 }
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 16
$timer.Add_Tick({
    $motion.entrance = [Math]::Min(1.0,$motion.entrance+0.085)
    $form.Opacity = 0.65 + 0.35*$motion.entrance
    $motion.level += ($motion.target-$motion.level)*0.26
    if ([Math]::Abs($motion.level-$motion.target) -lt 0.02) { $motion.level=$motion.target }
    $c = [Drawing.Color]::FromArgb(150,[int](148+66*$motion.level),[int](13+17*$motion.level),[int](39+24*$motion.level))
    $play.BackColor=$c
    $play.FlatAppearance.MouseOverBackColor=$c
    $play.FlatAppearance.MouseDownBackColor=$c
    $play.Top=426-[int](2*$motion.level)
    if ($motion.entrance -eq 1 -and $motion.level -eq $motion.target) { $timer.Stop() }
})
$play.Add_MouseEnter({ $motion.target=1; $timer.Start() })
$play.Add_MouseLeave({ $motion.target=0; $timer.Start() })
$play.Add_MouseDown({ $motion.target=-0.6; $timer.Start() })
$play.Add_MouseUp({ $motion.target=1; $timer.Start() })
$play.Add_GotFocus({ $motion.target=1; $timer.Start() })
$play.Add_LostFocus({ $motion.target=0; $timer.Start() })
$form.Opacity=0.65
$form.Add_Shown({ $timer.Start() })
$clock = [Diagnostics.Stopwatch]::StartNew()
$rain = New-Object Windows.Forms.PictureBox
$rain.SetBounds(0,0,936,548)
$rain.Image = $canvas.Clone($rain.Bounds,$canvas.PixelFormat)
$form.Controls.Add($rain)
$rain.SendToBack()
$rain.Add_Paint({
    param($sender,$eventArgs)
    $seconds = $clock.Elapsed.TotalSeconds
    $g=$eventArgs.Graphics
    $g.SmoothingMode='AntiAlias'
    $blood=New-Object Drawing.Drawing2D.LinearGradientBrush((New-Object Drawing.Rectangle(0,0,12,10)),[Drawing.Color]::FromArgb(112,23,26),[Drawing.Color]::FromArgb(50,5,11),90.0)
    $g.FillRectangle($blood,0,0,936,8)
    $blood.Dispose()
    foreach ($i in 0..35) {
        $x=10+26*$i
        $wave=(1-[Math]::Cos($seconds*(0.42+$i*0.025)+$i))/2
        $end=[single](16+(14+(13*$i % 65))*$wave)
        if($i -in 3,18,33){$end=[single](45+505*$wave)}
        $path=New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddBezier($x-13,6,$x-5,6,$x-2,17,$x-2,$end-7)
        $path.AddBezier($x-2,$end-7,$x-8,$end+4,$x+7,$end+4,$x+3,$end-6)
        $path.AddBezier($x+3,$end-6,$x+2,20,$x+6,7,$x+13,6)
        $path.CloseFigure()
        $glaze=New-Object Drawing.Drawing2D.LinearGradientBrush((New-Object Drawing.Rectangle(($x-5),0,11,10)),[Drawing.Color]::FromArgb(50,3,9),[Drawing.Color]::FromArgb(143,42,37),0.0)
        $g.FillPath($glaze,$path)
        $g.FillEllipse([Drawing.Brushes]::RosyBrown,[single]($x+1),[single]($end-3),[single]1.8,[single]2.8)
        $glaze.Dispose();$path.Dispose()
    }
})
$ambient = New-Object Windows.Forms.Timer
$ambient.Interval = 50
$ambient.Add_Tick({
    if ($form.WindowState -eq 'Minimized') { return }
    $brand.Top = 12 + [int](4*[Math]::Sin(2*$clock.Elapsed.TotalSeconds))
    $network.Invalidate();$rain.Invalidate()
})
$form.Add_Shown({ $ambient.Start() })
$watcher = New-Object IO.FileSystemWatcher $config.carpeta
$watcher.IncludeSubdirectories = $true
$null = $form.Handle
$watcher.SynchronizingObject = $form
$onChange = {
    if ($play.Enabled) { $status.Text = "Cambio detectado. " + (Get-PackStatus) }
}
$watcher.add_Created($onChange)
$watcher.add_Changed($onChange)
$watcher.add_Deleted($onChange)
$watcher.add_Renamed($onChange)
if ($splash) {
    $bar.Width = 316
    $loading.Text = 'Comprobando los archivos del modpack…'
    $splash.Refresh()
}
    try { Sync-Pack; $script:packReady = $true } catch { $status.Text = $_.Exception.Message }
if ($splash) { $splash.Close() }
$watcher.EnableRaisingEvents = $true
try { [void]$form.ShowDialog() } finally { $watcher.Dispose() }
$skinDelay.Dispose();$fonts.Dispose();$ambient.Dispose()
$rain.Image.Dispose()
$menu.Dispose()
$timer.Dispose()
$form.Dispose()
$canvas.Dispose()










