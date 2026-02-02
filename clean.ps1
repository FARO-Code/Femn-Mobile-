$E = [char]27
$Green = "$E[32m"
$Cyan = "$E[36m"
$Reset = "$E[0m"
$Bold = "$E[1m"

Write-Host "`n$Bold$Cyan[ Cleaning Project ]$Reset"

Write-Host "1. Flutter Clean..."
flutter clean
Write-Host "$Green[✅] Cleaned$Reset"

Write-Host "`n2. Pub Get..."
flutter pub get
Write-Host "$Green[✅] Dependencies Fetched$Reset"

Write-Host "`n$Green[✅] project is fresh and ready!$Reset`n"
