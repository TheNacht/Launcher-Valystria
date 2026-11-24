$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    & $compiler /nologo /target:winexe '/out:Valystria Outbreak.exe' /reference:System.Windows.Forms.dll /resource:Iniciar.ps1 /resource:Valystria.ps1 /resource:actualizaciones.json /resource:logo-outbreak.png Launcher.cs
    if ($LASTEXITCODE) { throw 'Error al compilar el launcher.' }
} finally { Pop-Location }
