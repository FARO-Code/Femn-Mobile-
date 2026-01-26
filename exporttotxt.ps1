Write-Host "Starting export of Dart files to notes/femn_summary.txt..." -ForegroundColor Cyan

$targetDir = "notes"
$targetFile = "$targetDir\femn_summary.txt"

# Ensure notes directory exists
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-Host "Created $targetDir directory." -ForegroundColor Yellow
}

# Clean start
if (Test-Path $targetFile) {
    Remove-Item $targetFile
    Write-Host "Cleaned up old summary file." -ForegroundColor Yellow
}

Write-Host "Scanning lib folder..." -ForegroundColor Cyan
$files = Get-ChildItem -Path lib -Recurse -Filter *.dart
$count = $files.Count
Write-Host "Found $count Dart files. Processing..." -ForegroundColor Cyan

# Process files
$i = 0
foreach ($file in $files) {
    $i++
    # Basic progress indication
    if ($i % 10 -eq 0) {
        Write-Host "Processed $i / $count files..." -ForegroundColor Gray
    }
    
    Add-Content -Path $targetFile -Value "`n`n--- $($file.FullName) ---`n"
    Get-Content $file.FullName | Add-Content -Path $targetFile
}

Write-Host "Export completed successfully!" -ForegroundColor Green
Write-Host "File saved to: $targetFile" -ForegroundColor Green
