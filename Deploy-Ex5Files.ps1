# Deploy-Ex5Files.ps1
# Deploys .ex5 files from EA/_Release/ to MQL5\Experts\EAsReleases

param(
    [switch]$Verbose,
    [switch]$WhatIf
)

function Write-Info { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $ScriptDir

$TerminalPath = Split-Path -Parent (Split-Path -Parent $ProjectRoot)

$SourceDir = Join-Path $ProjectRoot "_Release"
$DestDir = Join-Path $TerminalPath "Experts\EAsReleases"

Write-Info "================================================"
Write-Info "    DEPLOY .EX5 FILES TO EAsReleases"
Write-Info "================================================"
Write-Host ""

if (-not (Test-Path $SourceDir)) {
    Write-Error "Source directory not found: $SourceDir"
    exit 1
}

$ex5Files = Get-ChildItem -Path $SourceDir -Filter "*.ex5"
if ($ex5Files.Count -eq 0) {
    Write-Warning "No .ex5 files found in: $SourceDir"
    exit 0
}

Write-Info "Source: $SourceDir"
Write-Info "Destination: $DestDir"
Write-Host ""
Write-Info "Found $($ex5Files.Count) .ex5 file(s):"
foreach ($file in $ex5Files) {
    Write-Host "  $($file.Name) ($([math]::Round($file.Length/1KB, 2)) KB)" -ForegroundColor Gray
}
Write-Host ""

if (-not (Test-Path $DestDir)) {
    if ($WhatIf) {
        Write-Info "[WHAT-IF] Would create directory: $DestDir"
    } else {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        Write-Success "Created directory: $DestDir"
    }
} else {
    if ($Verbose) {
        Write-Info "Directory already exists: $DestDir"
    }
}

$successCount = 0
$errorCount = 0

foreach ($file in $ex5Files) {
    $destFile = Join-Path $DestDir $file.Name
    
    if ($WhatIf) {
        Write-Info "[WHAT-IF] Would copy: $($file.Name)"
    } else {
        try {
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            Write-Success "Deployed: $($file.Name)"
            if ($Verbose) {
                $destSize = [math]::Round((Get-Item $destFile).Length/1KB, 2)
                Write-Host "    Size: $destSize KB" -ForegroundColor Gray
            }
            $successCount++
        } catch {
            Write-Error "Failed to copy $($file.Name): $_"
            $errorCount++
        }
    }
}

Write-Host ""

if (-not $WhatIf) {
    Write-Info "================================================"
    if ($errorCount -eq 0) {
        Write-Success "Deployment completed successfully!"
        Write-Info "Successfully deployed: $successCount file(s)"
    } else {
        Write-Warning "Deployment completed with errors"
        Write-Info "Successfully deployed: $successCount file(s)"
        Write-Error "Failed: $errorCount file(s)"
    }
    Write-Info "================================================"
    Write-Host ""
    Write-Info "Tip: Files are now available in MetaTrader 5"
    Write-Info "Navigate to: Experts\EAsReleases"
} else {
    Write-Info "================================================"
    Write-Info "WHAT-IF mode - No files were modified"
    Write-Info "Remove -WhatIf to perform actual deployment"
    Write-Info "================================================"
}

Write-Host "" 
