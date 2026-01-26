Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "    STARTING FEMN WEB UPLOAD SEQUENCE    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "`n[1/5] Cleaning Project..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) { Write-Host "Error in Flutter Clean" -ForegroundColor Red; exit $LASTEXITCODE }
Write-Host "Clean Complete!" -ForegroundColor Green

Write-Host "`n[2/5] Running Flutter Pub Get..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "Error in Flutter Pub Get" -ForegroundColor Red; exit $LASTEXITCODE }
Write-Host "Pub Get Complete!" -ForegroundColor Green

Write-Host "`n[3/5] Building APK (Release mode)..." -ForegroundColor Yellow
flutter build apk
if ($LASTEXITCODE -ne 0) { Write-Host "Error in Flutter Build" -ForegroundColor Red; exit $LASTEXITCODE }
Write-Host "Build Complete!" -ForegroundColor Green

Write-Host "`n[4/5] Copying and Renaming APK..." -ForegroundColor Yellow
$source = "build\app\outputs\flutter-apk\app-release.apk"
$dest = "public\femn_install.apk"

if (Test-Path $source) {
    Copy-Item -Path $source -Destination $dest -Force
    Write-Host "Successfully copied $source to $dest" -ForegroundColor Green
} else {
    Write-Host "Error: APK not found at $source" -ForegroundColor Red
    exit 1
}

Write-Host "`n[5/5] Final Firebase Hosting Deploy..." -ForegroundColor Yellow
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Write-Host "Error in Final Firebase Deploy" -ForegroundColor Red; exit $LASTEXITCODE }

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "       UPLOAD SEQUENCE COMPLETED!         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
