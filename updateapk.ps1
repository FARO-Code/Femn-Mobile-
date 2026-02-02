$E = [char]27
$Green = "$E[32m"
$Cyan = "$E[36m"
$Yellow = "$E[33m"
$Red = "$E[31m"
$Magenta = "$E[35m"
$Reset = "$E[0m"
$Bold = "$E[1m"

Write-Host "`n$Bold$Magenta=========================================="
Write-Host "    FEMN APK UPDATE & DEPLOY SEQUENCE"
Write-Host "==========================================$Reset`n"

function Show-Step($msg) {
    Write-Host "$Cyan[🛠️ ] $msg...$Reset"
}

function Show-Success($msg) {
    Write-Host "$Green[✅] $msg$Reset"
}

function Show-Error($msg) {
    Write-Host "$Red[❌] ERROR: $msg$Reset"
    exit 1
}

# 1. Build APK
Show-Step "Building Flutter APK (Release Mode)"
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Show-Error "Flutter APK build failed" }
Show-Success "APK build completed"

# 2. Update Public File
Show-Step "Updating APK in public/info"
$apkSource = "build\app\outputs\flutter-apk\app-release.apk"
$apkDest = "public\info\femn_install.apk"

if (-not (Test-Path $apkSource)) {
    Show-Error "Source APK not found at $apkSource"
}

if (-not (Test-Path "public\info")) {
    New-Item -ItemType Directory -Path "public\info" | Out-Null
}

Copy-Item -Path $apkSource -Destination $apkDest -Force
Show-Success "APK updated in public/info"

# 3. Deploy
Show-Step "Deploying to Firebase Hosting"
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Show-Error "Firebase deployment failed" }

Write-Host "`n$Bold$Green=========================================="
Write-Host "    APK UPDATE COMPLETED SUCCESSFULLY! 🚀"
Write-Host "==========================================$Reset`n"
Write-Host "Download Link: https://femn-9cabb.web.app/info/femn_install.apk`n"
