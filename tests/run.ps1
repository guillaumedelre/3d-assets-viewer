# Runner GdUnit4 headless local (Windows / PowerShell 7).
#
#   pwsh tests/run.ps1                          # toute la suite tests/
#   pwsh tests/run.ps1 res://tests/xxx_test.gd  # une seule suite
#   pwsh tests/run.ps1 -GodotBin C:\...\Godot_console.exe
#
# Résolution du binaire : -GodotBin > $env:GODOT_BIN > défaut local ci-dessous.
# Le rapport va dans reports/all/ (gitignoré). Le code de sortie reflète celui de GdUnit (0 = vert).

param(
    [string]$Target = "res://tests",
    [string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if (-not $GodotBin) { $GodotBin = $env:GODOT_BIN }
if (-not $GodotBin) { $GodotBin = "C:\Users\gdelr\Downloads\Godot_v4.7-stable_win64_console.exe" }
if (-not (Test-Path $GodotBin)) {
    Write-Error "Godot introuvable: '$GodotBin'. Passe -GodotBin <chemin> ou pose `$env:GODOT_BIN."
    exit 1
}

if ($Target -notlike "res://*") { $Target = "res://" + ($Target -replace '\\', '/') }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host ""
Write-Host "  🧪 GdUnit4 ▶ $($Target -replace '^res://', '')" -ForegroundColor Green
Write-Host ""

$gargs = @(
    "--headless", "--path", $root, "-s", "-d", "--remote-debug", "tcp://127.0.0.1:0",
    "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode", "-c", "-rc", "1",
    "-rd", "res://reports/all", "-a", $Target
)
$out = & $GodotBin @gargs 2>&1
$out | ForEach-Object { Write-Host $_ }

# Godot peut planter au teardown APRÈS un run vert : on lit le verdict "Exit code:" de GdUnit.
$clean = ($out | Out-String) -replace "$([char]27)\[[0-9;]*m", ""
$m = [regex]::Matches($clean, "Exit code:\s*(\d+)")
$code = if ($m.Count -gt 0) { [int]$m[$m.Count - 1].Groups[1].Value } else { $LASTEXITCODE }

Write-Host ""
if ($code -eq 0) { Write-Host "  ✅ Tout est vert" -ForegroundColor Green }
else { Write-Host "  ❌ Échecs (code $code)" -ForegroundColor Red }
exit $code
