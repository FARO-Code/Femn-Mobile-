$E = [char]27
$Green = "$E[32m"
$Cyan = "$E[36m"
$Reset = "$E[0m"
$Bold = "$E[1m"

Write-Host "`n$Bold$Cyan[ Updating App Assets ]$Reset"

Write-Host "1. Generating Launcher Icons..."
dart run flutter_launcher_icons
if ($LASTEXITCODE -eq 0) { Write-Host "$Green[✅] Icons Generated$Reset" } else { Write-Host "$Red[❌] Icon Gen Failed$Reset" }

Write-Host "`n2. Generating Native Splash..."
dart run flutter_native_splash:create
if ($LASTEXITCODE -eq 0) { Write-Host "$Green[✅] Splash Generated$Reset" } else { Write-Host "$Red[❌] Splash Gen Failed$Reset" }

Write-Host "`n$Green[✅] Asset Update Complete!$Reset`n"
