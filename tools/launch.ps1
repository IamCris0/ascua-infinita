param([switch]$Editor, [switch]$Check)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = $null
if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
    $engine = $env:GODOT_BIN
}
if (-not $engine) {
    foreach ($name in @('godot', 'godot4')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { $engine = $command.Source; break }
    }
}
if (-not $engine) {
    $downloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    $candidate = Get-ChildItem -LiteralPath $downloads -Filter 'Godot*.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'console|mono' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($candidate) { $engine = $candidate.FullName }
}
if (-not $engine) {
    Write-Host 'No se encontro Godot 4. Instala Godot o configura GODOT_BIN con la ruta del ejecutable.'
    exit 1
}
if ($Check) {
    & $engine --headless --version
    exit $LASTEXITCODE
}
# Import resources before a direct game launch, including on a fresh clone.
if (-not $Editor) {
    & $engine --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
if ($Editor) { & $engine --path $projectRoot --editor }
else { & $engine --path $projectRoot }
exit $LASTEXITCODE
