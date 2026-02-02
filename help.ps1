$E = [char]27
$Green = "$E[32m"
$Cyan = "$E[36m"
$Yellow = "$E[33m"
$Red = "$E[31m"
$Magenta = "$E[35m"
$Reset = "$E[0m"
$Bold = "$E[1m"

Write-Host "`n$Bold$Magenta=========================================="
Write-Host "       FEMN SYSTEM COMMANDS HELP"
Write-Host "==========================================$Reset"

Write-Host "`n$Yellow[ Available Commands ]$Reset"
Write-Host "$Bold$Cyan./help$Reset            - Display this helpful command list"
Write-Host "$Bold$Cyan./updatewebapp$Reset    - Full build and deploy cycle to Firebase Hosting"
Write-Host "$Bold$Cyan./pushtogit$Reset       - Fast git add/commit/push with auto-timestamp"
Write-Host "$Bold$Cyan./clean$Reset           - Deep clean project (flutter clean + pub get)"
Write-Host "$Bold$Cyan./check$Reset           - Run code analysis and tests (Health Check)"
Write-Host "$Bold$Cyan./updateassets$Reset    - Regenerate Icons and Splash Screens"
Write-Host "$Bold$Cyan./exporttomd$Reset      - Compile all Dart source code into a single Markdown file"
Write-Host "$Bold$Cyan./exporttotxt$Reset     - Compile all Dart source code into a single Text file"
Write-Host "$Bold$Cyan./updateapk$Reset       - Build release APK and update it on the web info page"
Write-Host "$Bold$Cyan./runtest$Reset         - Interactive device/emulator selector and runner"

Write-Host "`n$Bold$Magenta==========================================$Reset`n"

