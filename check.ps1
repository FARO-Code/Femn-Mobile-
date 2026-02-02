$E = [char]27
$Green = "$E[32m"
$Cyan = "$E[36m"
$Red = "$E[31m"
$Reset = "$E[0m"
$Bold = "$E[1m"

Write-Host "`n$Bold$Cyan[ Health Check ]$Reset"

Write-Host "1. Running Analyzer..."
flutter analyze
if ($LASTEXITCODE -eq 0) { 
    Write-Host "$Green[✅] No Issues Found$Reset" 
} else { 
    Write-Host "$Red[⚠️] Issues Detected$Reset" 
}

Write-Host "`n2. Running Tests..."
flutter test
if ($LASTEXITCODE -eq 0) { 
    Write-Host "$Green[✅] All Tests Passed$Reset" 
} else { 
    Write-Host "$Red[❌] Some Tests Failed$Reset" 
}

Write-Host "`n$Cyan[ℹ️] Health Check Complete$Reset`n"
