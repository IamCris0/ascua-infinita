param([string]$EnginePath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $EnginePath) {
    $downloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    $EnginePath = (Get-ChildItem -LiteralPath $downloads -Filter 'Godot_v4.7.2-stable_win64_console.exe' -File -Recurse | Select-Object -First 1).FullName
}
if (-not $EnginePath -or -not (Test-Path -LiteralPath $EnginePath)) { throw 'Indica Godot 4.7.2 con -EnginePath o GODOT_BIN.' }
$version = & $EnginePath --headless --version
if ($version -notmatch '^4\.7\.2\.stable') { throw 'La plantilla requiere Godot 4.7.2 estable.' }
$templateDir = Join-Path $projectRoot '.godot/export-templates'
$template = Join-Path $templateDir 'windows_release_x86_64.exe'
if (-not (Test-Path -LiteralPath $template)) {
    $archive = Join-Path $projectRoot '.godot/export-templates-4.7.2.tpz'
    New-Item -ItemType Directory -Force -Path $templateDir | Out-Null
    if (-not (Test-Path -LiteralPath $archive)) {
        & curl.exe -L --fail --retry 2 --silent --show-error -o $archive 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar la plantilla oficial.' }
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011') { throw 'La descarga no coincide con el SHA256 oficial.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $entry = $zip.GetEntry('templates/windows_release_x86_64.exe')
        if (-not $entry) { throw 'La plantilla Windows no existe en el archivo.' }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $template, $true)
    } finally { $zip.Dispose() }
}
$output = Join-Path $projectRoot 'builds/windows'
New-Item -ItemType Directory -Force -Path $output | Out-Null
# Piping makes PowerShell wait even if GODOT_BIN points to the GUI executable.
& $EnginePath --headless --path $projectRoot --editor --import --quit | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Falló la importación.' }
& $EnginePath --headless --path $projectRoot --export-release 'Windows Desktop' (Join-Path $output 'AscuaInfinita.exe') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Falló la exportación.' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/LEEME-WINDOWS.txt') -Destination (Join-Path $output 'LEEME.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/THIRD-PARTY-NOTICES.txt') -Destination $output -Force
Compress-Archive -LiteralPath (Join-Path $output 'AscuaInfinita.exe'),(Join-Path $output 'AscuaInfinita.pck'),(Join-Path $output 'LEEME.txt'),(Join-Path $output 'THIRD-PARTY-NOTICES.txt') -DestinationPath (Join-Path $projectRoot 'builds/AscuaInfinita-Windows-0.3.0-dev.zip') -Force
Write-Host "Versión portátil lista en $output"
