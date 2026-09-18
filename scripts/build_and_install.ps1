param(
  [switch]$SkipInstall,
  [switch]$Release
)

$ErrorActionPreference = 'Stop'

# Default dev values – override via environment variables or pass -SUPABASE_URL etc.
$SUPABASE_URL = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { 'https://uyjgnnfhkplwxjkpzsdd.supabase.co' }
$SUPABASE_ANON_KEY = if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV5amdubmZoa3Bsd3hqa3B6c2RkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzMTMxNjcsImV4cCI6MjEwMDg4OTE2N30.EXG9BMpYVjTFACRpnwHDgP7o9nWQDmFt3Uo2HLsW9eo' }

$BUILD_MODE = if ($Release) { '--release' } else { '--debug' }
$APK_PATH  = 'build\app\outputs\flutter-apk\app-debug.apk'
if ($Release) { $APK_PATH = 'build\app\outputs\flutter-apk\app-release.apk' }

$ADB = 'C:\Android\Sdk\platform-tools\adb.exe'
$DEVICE_ID = '9f02e98a'
$PACKAGE   = 'com.signcorrect.fsl_learn'

Write-Host "Building APK ($BUILD_MODE)..." -ForegroundColor Cyan
flutter build apk $BUILD_MODE `
  --dart-define=SUPABASE_URL="$SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

if (-not (Test-Path -LiteralPath $APK_PATH)) {
  Write-Error "APK not found at $APK_PATH"
  exit 1
}

if ($SkipInstall) {
  Write-Host "Build complete: $APK_PATH" -ForegroundColor Green
  exit 0
}

Write-Host "Installing on device $DEVICE_ID..." -ForegroundColor Cyan
& $ADB -s $DEVICE_ID install -r $APK_PATH
if ($LASTEXITCODE -ne 0) { Write-Error 'adb install failed'; exit 1 }

Write-Host "Relaunching app..." -ForegroundColor Cyan
& $ADB -s $DEVICE_ID shell am force-stop $PACKAGE
& $ADB -s $DEVICE_ID shell monkey -p $PACKAGE -c android.intent.category.LAUNCHER 1 2>$null

Start-Sleep -Seconds 3
$pid = (& $ADB -s $DEVICE_ID shell pidof $PACKAGE 2>$null)
if ($pid) {
  Write-Host "App running  (PID $pid)" -ForegroundColor Green
} else {
  Write-Host "Package launched - confirm on device" -ForegroundColor Yellow
}
