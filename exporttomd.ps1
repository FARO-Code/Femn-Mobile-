Write-Host "Starting export of Dart files to notes/femn_summary.md..." -ForegroundColor Cyan

$targetDir = "notes"
$targetFile = "$targetDir\femn_summary.md"
$libPath = "lib"

# Ensure notes directory exists
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Header for the Markdown file
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$header = @"
# 📱 Femn Project Code Summary
> **Generated on:** $date

This document contains a complete summary of the codebase located in the `lib` directory.

---

## 📂 Table of Contents
"@

# Get all Dart files
$files = Get-ChildItem -Path $libPath -Recurse -Filter *.dart

# Build TOC
$tocList = @()
foreach ($file in $files) {
    # Get relative path
    $relativePath = $file.FullName.Substring($PWD.Path.Length + 1)
    # Create a simple unique ID for the anchor
    $anchorId = "file-" + $relativePath -replace '[\\/.]', '-' -replace ' ', '-'
    $tocList += "- [$relativePath](#$anchorId)"
}

$tocContent = $tocList -join "`n"

# Start writing to file (Overwrite existing)
Set-Content -Path $targetFile -Value "$header`n$tocContent`n`n---`n"

Write-Host "Found $($files.Count) Dart files. Processing..." -ForegroundColor Cyan

$i = 0
foreach ($file in $files) {
    $i++
    if ($i % 10 -eq 0) { Write-Host "Processed $i / $($files.Count)..." -ForegroundColor Gray }
    
    $relativePath = $file.FullName.Substring($PWD.Path.Length + 1)
    # Match the anchor ID logic used in TOC
    $anchorId = "file-" + $relativePath -replace '[\\/.]', '-' -replace ' ', '-'
    
    # Read file content
    $fileContent = Get-Content $file.FullName -Raw

    # Note: escaped backticks for PowerShell double-quoted string
    $mdBlock = @"

## <a id="$anchorId"></a>📄 $relativePath

```dart
$fileContent
```

[⬆️ Back to Top](#table-of-contents)

---
"@
    Add-Content -Path $targetFile -Value $mdBlock
}

Write-Host "Export completed successfully!" -ForegroundColor Green
Write-Host "File saved to: $targetFile" -ForegroundColor Green
