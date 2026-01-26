Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "       STARTING GIT PUSH SEQUENCE         " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "`n[1/3] Adding all changes..." -ForegroundColor Yellow
git add .
if ($LASTEXITCODE -ne 0) { Write-Host "Error in Git Add" -ForegroundColor Red; exit $LASTEXITCODE }

Write-Host "`n[2/3] Committing with timestamp..." -ForegroundColor Yellow
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
git commit -m "$timestamp"

if ($LASTEXITCODE -ne 0) { 
    Write-Host "Error in Git Commit (or nothing to commit)" -ForegroundColor Red
    exit $LASTEXITCODE 
}

Write-Host "`n[3/3] Pushing to remote..." -ForegroundColor Yellow
git push
if ($LASTEXITCODE -ne 0) { Write-Host "Error in Git Push" -ForegroundColor Red; exit $LASTEXITCODE }

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "         GIT PUSH COMPLETED!              " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
