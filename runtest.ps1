# Set encoding to handle the bullet points and other UTF8 characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$E = [char]27
$Green = "$E[32m"
$Cyan = "$E[36m"
$Yellow = "$E[33m"
$Red = "$E[31m"
$Magenta = "$E[35m"
$Reset = "$E[0m"
$Bold = "$E[1m"

# The bullet character used by Flutter
$bullet = [char]0x2022

Write-Host "`n$Bold$Magenta=========================================="
Write-Host "       FEMN DEVICE SELECTOR & RUNNER"
Write-Host "==========================================$Reset"

$targets = @()

# --- 1. Get Connected Devices ---
# We use -ErrorAction SilentlyContinue in case flutter is not in path or other issues
$devicesText = flutter devices 2>$null
$foundDevicesHeader = $false
foreach ($line in $devicesText) {
    if ($line -match "connected device") { $foundDevicesHeader = $true; continue }
    if ($foundDevicesHeader -and $line.Contains($bullet)) {
        $parts = $line.Split($bullet)
        if ($parts.Count -ge 2) {
            $name = $parts[0].Trim()
            $id = $parts[1].Trim()
            $targets += [PSCustomObject]@{
                Type = "Device"
                Label = "$name ($id)"
                Id = $id
                Name = $name
            }
        }
    }
}

# --- 2. Get Available Emulators ---
$emulatorsText = flutter emulators 2>$null
$foundEmulatorsHeader = $false
foreach ($line in $emulatorsText) {
    if ($line -match "available emulator") { $foundEmulatorsHeader = $true; continue }
    if ($foundEmulatorsHeader -and $line.Contains($bullet)) {
        $parts = $line.Split($bullet)
        if ($parts.Count -ge 2) {
            $id = $parts[0].Trim()
            $name = $parts[1].Trim()
            
            # Skip header
            if ($id -eq "Id" -and $name -eq "Name") { continue }
            
            # Check if this emulator is already in connected devices to label it better
            $isStarted = $false
            foreach($d in $devices) {
                if ($d.Id -eq $id -or $d.Name -eq $name) { $isStarted = $true; break }
            }

            $prefix = if ($isStarted) { "[RUNNING]" } else { "[LAUNCH]" }
            
            $targets += [PSCustomObject]@{
                Type = "Emulator"
                Label = "$prefix $name ($id)"
                Id = $id
                Name = $name
                IsStarted = $isStarted
            }
        }
    }
}

# --- 3. Display and Select ---
if ($targets.Count -eq 0) {
    Write-Host "$Red`nNo devices or emulators found!$Reset"
    Write-Host "`nTry running 'flutter devices' manually to check connectivity."
    exit
}

Write-Host "`n$Yellow[ Available Targets ]$Reset"
for ($i = 0; $i -lt $targets.Count; $i++) {
    $t = $targets[$i]
    $color = if ($t.Type -eq "Emulator") { $Cyan } else { $Green }
    Write-Host "$Bold$color$($i + 1).$Reset $($t.Label)"
}

Write-Host "`n$Bold$Yellow" -NoNewline
$selection = Read-Host "Select a target number (1-$($targets.Count))"
Write-Host "$Reset"

if ($selection -match '^\d+$') {
    $selectedIndex = [int]$selection - 1
    if ($selectedIndex -ge 0 -and $selectedIndex -lt $targets.Count) {
        $selected = $targets[$selectedIndex]
        
        if ($selected.Type -eq "Emulator" -and -not $selected.IsStarted) {
            Write-Host "`n$Green Launching emulator: $($selected.Name)...$Reset"
            flutter emulators --launch $($selected.Id)
            
            Write-Host "$Green Waiting for emulator to initialize...$Reset"
            Start-Sleep -Seconds 5
            
            Write-Host "$Green Running app...$Reset"
            flutter run
        } else {
            Write-Host "`n$Green Running app on: $($selected.Name)...$Reset"
            flutter run -d $($selected.Id)
        }
    } else {
        Write-Host "`n$Red Invalid selection!$Reset"
    }
} else {
    Write-Host "`n$Red Selection cancelled.$Reset"
}

Write-Host "`n$Bold$Magenta==========================================$Reset`n"
