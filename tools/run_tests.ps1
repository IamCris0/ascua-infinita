param([string]$EnginePath = $env:GODOT_BIN, [switch]$Soak, [switch]$Balance)
# Runs every test suite with the arguments it needs. Suites that open the real
# scene always receive --qa, so they never read or write the player's save.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $EnginePath) {
    foreach ($name in @('godot', 'godot4')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { $EnginePath = $command.Source; break }
    }
}
if (-not $EnginePath) {
    $downloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    $candidate = Get-ChildItem -LiteralPath $downloads -Filter 'Godot_v4*.exe' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'mono' } |
        Sort-Object @{ Expression = { $_.Name -match 'console' }; Descending = $true }, LastWriteTime -Descending |
        Select-Object -First 1
    if ($candidate) { $EnginePath = $candidate.FullName }
}
if (-not $EnginePath -or -not (Test-Path -LiteralPath $EnginePath)) {
    Write-Host 'No se encontro Godot 4. Indica -EnginePath o configura GODOT_BIN.'
    exit 1
}
$suites = @(
    @('tests/test_progression.gd'),
    @('tests/test_assets.gd'),
    @('tests/test_audio.gd'),
    @('tests/test_journey.gd'),
    @('tests/test_combat_timing.gd'),
    @('tests/test_enemy_roles.gd'),
    @('tests/test_bell_keeper.gd'),
    @('tests/test_forge_keeper.gd'),
    @('tests/test_synergies.gd'),
    @('tests/test_legacy_tree.gd'),
    @('tests/test_boss_intro.gd'),
    @('tests/test_eclipse.gd'),
    @('tests/test_active_combat.gd'),
    @('tests/test_collection.gd', '--qa'),
    @('tests/test_ui.gd', '--qa')
)
if ($Soak) { $suites += , @('tests/soak.gd', '--qa') }
if ($Balance) { $suites += , @('tools/simulate.gd', '--sample') }
# Piping waits for the GUI build of Godot and records its exit code.
& $EnginePath --headless --path $projectRoot --editor --import --quit | Out-Host
if ($LASTEXITCODE -ne 0) { Write-Host 'Fallo la importacion.'; exit $LASTEXITCODE }
$failed = @()
foreach ($suite in $suites) {
    Write-Host ''
    Write-Host "== $($suite[0])"
    $arguments = @('--headless', '--path', $projectRoot, '--script', $suite[0])
    if ($suite.Count -gt 1) { $arguments += @('--') + $suite[1..($suite.Count - 1)] }
    & $EnginePath @arguments | Out-Host
    if ($LASTEXITCODE -ne 0) { $failed += $suite[0] }
}
Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host "FALLAN $($failed.Count) de $($suites.Count): $($failed -join ', ')"
    exit 1
}
Write-Host "OK: $($suites.Count) suites aprobadas."
exit 0
