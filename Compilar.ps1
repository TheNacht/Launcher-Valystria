$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $automation = (Get-ChildItem "$env:WINDIR/Microsoft.NET/assembly/GAC_MSIL/System.Management.Automation" -Recurse -Filter System.Management.Automation.dll | Select-Object -First 1).FullName
    & $compiler "/reference:$automation" /nologo /target:winexe /win32icon:outbreak.ico /resource:outbreak.ico '/out:Valystria Outbreak.exe' /reference:System.Windows.Forms.dll /resource:Iniciar.ps1 /resource:Valystria.ps1 /resource:actualizaciones.json /resource:logo-outbreak.png /resource:zombies.png /resource:nemo-regular.ttf /resource:SkinPreview.cs /resource:default-player.png Launcher.cs
    if ($LASTEXITCODE) { throw 'Error al compilar el launcher.' }
} finally { Pop-Location }



