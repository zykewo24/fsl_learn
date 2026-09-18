param(
    [switch]$Install,
    [string]$Device
)

$ErrorActionPreference = 'Stop'

$SUPABASE_URL = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { 'https://uyjgnnfhkplwxjkpzsdd.supabase.co' }
$SUPABASE_ANON_KEY = if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV5amdubmZoa3Bsd3hqa3B6c2RkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzMTMxNjcsImV4cCI6MjEwMDg4OTE2N30.EXG9BMpYVjTFACRpnwHDgP7o9nWQDmFt3Uo2HLsW9eo' }
$PACKAGE   = 'com.signcorrect.fsl_learn'

# Pull version name from pubspec.yaml
$ver = (Get-Content pubspec.yaml | Select-String -Pattern '^\s*version:\s*([\d.]+)').Matches[0].Groups[1].Value
$ts   = Get-Date -Format 'yyyyMMdd-HHmm'
$dist = Join-Path $PSScriptRoot '..\dist'

if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }
$dest = Join-Path $dist "fsl-learn-v${ver}-${ts}.apk"

Write-Host "Building release APK v${ver}..." -ForegroundColor Cyan
flutter build apk --release `
  --dart-define=SUPABASE_URL="$SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

$src = 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $src)) { Write-Error "APK not found at $src"; exit 1 }

Copy-Item -LiteralPath $src -Destination $dest -Force
Write-Host "Saved: $dest" -ForegroundColor Green

if ($Install) {
    $adb = 'C:\Android\Sdk\platform-tools\adb.exe'
    $dev = if ($Device) { $Device } else { '9f02e98a' }
    Write-Host "Installing on device $dev..." -ForegroundColor Cyan
    & $adb -s $dev install -r $dest
    if ($LASTEXITCODE -ne 0) { Write-Error 'adb install failed'; exit 1 }
    & $adb -s $dev shell monkey -p $PACKAGE -c android.intent.category.LAUNCHER 1 *> $null
    Write-Host "Launched." -ForegroundColor Green
}
