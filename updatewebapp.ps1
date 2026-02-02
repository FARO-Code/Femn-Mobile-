$E = [char]27
$Green = "$E[32m"
$Cyan = "$E[36m"
$Yellow = "$E[33m"
$Red = "$E[31m"
$Magenta = "$E[35m"
$Reset = "$E[0m"
$Bold = "$E[1m"

Write-Host "`n$Bold$Magenta=========================================="
Write-Host "    FEMN WEB APP DEPLOYMENT SEQUENCE"
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

# 1. Flutter Build Sequence
Show-Step "Cleaning Flutter project"
flutter clean | Out-Null
Show-Success "Project cleaned"

Show-Step "Fetching dependencies"
flutter pub get | Out-Null
Show-Success "Dependencies updated"

Show-Step "Building Flutter Web (Release Mode)"
flutter build web --release --no-tree-shake-icons
if ($LASTEXITCODE -ne 0) { Show-Error "Flutter build failed" }
Show-Success "Web build completed"

# 2. Smart Migration to Public
Show-Step "Preparing 'public' directory (keeping advert site & config)"
if (-not (Test-Path "public")) {
    New-Item -ItemType Directory -Path "public" | Out-Null
}

# Identify items to keep
$itemsToKeep = @("info", ".well-known")

# Remove app-specific items from public
$publicItems = Get-ChildItem -Path "public"
foreach ($item in $publicItems) {
    if ($itemsToKeep -notcontains $item.Name) {
        Remove-Item -Path $item.FullName -Recurse -Force | Out-Null
    }
}
Show-Success "Public directory prepared"

Show-Step "Migrating new build to public"
Copy-Item -Path "build\web\*" -Destination "public\" -Recurse -Force
Show-Success "Build migrated to public"

# 3. Firebase Deployment
Show-Step "Deploying to Firebase Hosting"
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Show-Error "Firebase deployment failed" }

Write-Host "`n$Bold$Green=========================================="
Write-Host "    DEPLOYMENT COMPLETED SUCCESSFULLY! 🚀"
Write-Host "==========================================$Reset`n"
Write-Host "Live App: https://femn-9cabb.web.app"
Write-Host "Advert Site: https://femn-9cabb.web.app/info/`n"
