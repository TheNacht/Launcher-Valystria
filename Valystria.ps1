param([string]$LauncherDirectory = $(if ($env:VALYSTRIA_LAUNCHER_DIR) { $env:VALYSTRIA_LAUNCHER_DIR } else { $PSScriptRoot }))
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
$form = New-Object Windows.Forms.Form
$form.Text = 'Valystria Outbreak'
$form.ClientSize = New-Object Drawing.Size(560,385)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [Drawing.ColorTranslator]::FromHtml('#17211d')
$form.ForeColor = [Drawing.Color]::White
function Add-Label($caption,$top,$size,$height) {
    $label = New-Object Windows.Forms.Label
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

$logoPath = Join-Path $LauncherDirectory 'logo-outbreak.png'
if (Test-Path -LiteralPath $logoPath -PathType Leaf) {
    $logo = New-Object Windows.Forms.PictureBox
    $logo.SetBounds(32,4,496,113)
    $logo.SizeMode = 'Zoom'
    $logo.Image = [Drawing.Image]::FromFile($logoPath)
    $logo.AccessibleName = 'Valystria Outbreak'
    $form.Controls.Add($logo)
} else {
    $null = Add-Label 'Valystria Outbreak' 36 31 65
}
$null = Add-Label 'MINECRAFT JAVA   /   FORGE 1.20.1' 118 10 25
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
    if (!($files | Where-Object path -like 'Modpack/mods/*.jar')) { throw 'Todavia no hay mods publicados en GitHub.' }
    $ledger = Join-Path $settingsDir 'archivos-pack.json'
    $old = @()
    if (Test-Path $ledger) { $old = @((Get-Content $ledger -Raw | ConvertFrom-Json).files) }
    $current = @{}
    foreach ($entry in $files) {
        $name = $entry.path.Substring(8)
        $file = Get-PackFile $name
        $current.Add($name,$true)
        if ([IO.File]::Exists($file) -and (Get-BlobHash $file) -eq $entry.sha) { continue }
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
    if (!$mods.Count) { return 'Coloca los archivos .jar del pack en Modpack\mods.' }
    return "Modpack listo: $($mods.Count) archivos .jar en mods."
}
$status = Add-Label (Get-PackStatus) 145 12 88
$offline = New-Object Windows.Forms.CheckBox
$offline.Text = 'Sin cuenta (no premium)'
$offline.SetBounds(32,235,195,32)
$offline.Checked = [bool]$config.local
$form.Controls.Add($offline)
$nameLabel = Add-Label 'Nombre' 235 10 24
$nameLabel.SetBounds(238,240,65,24)
$nameBox = New-Object Windows.Forms.TextBox
$nameBox.SetBounds(305,238,223,28)
$nameBox.MaxLength = 16
$nameBox.Text = [string]$config.nombre
$nameBox.Enabled = $offline.Checked
$form.Controls.Add($nameBox)
$offline.Add_CheckedChanged({ $nameBox.Enabled = $offline.Checked; if ($offline.Checked) { $nameBox.Focus() } })
$play = Add-Button 'JUGAR' 32 298 496 {
    $play.Enabled = $false
    try {
        if (!$script:packReady) { Sync-Pack; $script:packReady = $true }
        if (!(Get-ChildItem -LiteralPath (Join-Path $config.carpeta 'mods') -File -Filter '*.jar' -ErrorAction SilentlyContinue | Select-Object -First 1)) { throw (Get-PackStatus) }
        if (!$config.forge) {
            $version = [Microsoft.VisualBasic.Interaction]::InputBox('Version exacta de Forge de tu pack (47.x.x)', 'Valystria Outbreak')
            if ($version -notmatch '^47\.\d+\.\d+$') { throw 'Se necesita la version exacta de Forge.' }
            $config.forge = $version
        }
        $config.local = $offline.Checked
        $config.nombre = $nameBox.Text.Trim()
        if ($config.local -and $config.nombre -notmatch '^[A-Za-z0-9_]{3,16}$') {
            throw 'Usa un nombre de 3 a 16 caracteres con letras, numeros o guion bajo.'
        }
        if (!$config.local -and !$config.cliente) {
            $client = [Microsoft.VisualBasic.Interaction]::InputBox('ID publico de la aplicacion Microsoft de Valystria', 'Valystria Outbreak')
            if ($client -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') { throw 'Falta un ID de aplicacion valido.' }
            $config.cliente = $client
        }
        $config | ConvertTo-Json | Set-Content $settingsFile -Encoding UTF8
        $status.Text = 'Preparando el juego. El primer inicio puede tardar varios minutos.'
        $form.Refresh()
        $python = Join-Path $settingsDir 'runtime\Scripts\python.exe'
        if (!(Test-Path $python)) {
            & python -m venv (Join-Path $settingsDir 'runtime')
            if (!(Test-Path $python)) { throw 'Instala Python 3.11 o posterior para Windows y activa la opcion de agregar Python al PATH.' }
        }
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
    } catch { $status.Text = $_.Exception.Message } finally {
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
    java = shutil.which("java")
    if not java:
        raise RuntimeError("Instala Java 17 de 64 bits y agrega java al PATH.")
    game = Path(config["carpeta"])
    runtime = home / "minecraft"
    forge = "1.20.1-" + config["forge"]
    version = mc.forge.forge_to_installed_version(forge)
    if not (runtime / "versions" / version / (version + ".json")).is_file():
        runtime.mkdir(exist_ok=True)
        mc.forge.install_forge_version(forge, str(runtime), java=java)
    if config.get("local"):
        name = config["nombre"]
        digest = hashlib.md5(("OfflinePlayer:" + name).encode("utf-8")).digest()
        user = dict(name=name, id=uuid.UUID(bytes=digest, version=3).hex, access_token="0")
    else:
        user = account(config["cliente"])
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
$play.BackColor = [Drawing.ColorTranslator]::FromHtml('#38684e')
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
$form.Add_Shown({
    try { Sync-Pack; $script:packReady = $true } catch { $status.Text = $_.Exception.Message }
})
$watcher.EnableRaisingEvents = $true
try { [void]$form.ShowDialog() } finally { $watcher.Dispose() }
$form.Dispose()





