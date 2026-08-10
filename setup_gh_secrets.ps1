#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup GitHub Actions secrets untuk keystore (base64)
.DESCRIPTION
    Encode keystore jadi base64 dan simpan ke GitHub repo secrets.
    Keystore: D:\KEYSTORE\fakegpspro.jks
    Password: Bushido321
#>

$KEYSTORE = "D:\KEYSTORE\fakegpspro.jks"
$REPO = "seandyadryan/Fake-GPS-PRO"
$PASSWORD = "Bushido321"
$ALIAS = "fakegpspro"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   GitHub Actions - Keystore Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Cek gh CLI
$gh = Get-Command "gh" -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "ERROR: GitHub CLI (gh) tidak ditemukan!" -ForegroundColor Red
    Write-Host "Install: winget install GitHub.cli"
    exit 1
}

# Cek auth
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Belum login ke GitHub!" -ForegroundColor Red
    Write-Host "Jalankan: gh auth login"
    exit 1
}

# Cek file keystore
if (-not (Test-Path $KEYSTORE)) {
    Write-Host "ERROR: Keystore tidak ditemukan di $KEYSTORE" -ForegroundColor Red
    exit 1
}

Write-Host "[1] Encode keystore ke base64..." -ForegroundColor Green
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($KEYSTORE))
Write-Host "    OK (${base64.Length} chars)" -ForegroundColor Green

Write-Host "[2] Setup GitHub secrets..." -ForegroundColor Green

gh secret set KEYSTORE_BASE64 --repo $REPO --body $base64
Write-Host "    KEYSTORE_BASE64 OK" -ForegroundColor Green

gh secret set KEYSTORE_PASSWORD --repo $REPO --body $PASSWORD
Write-Host "    KEYSTORE_PASSWORD OK" -ForegroundColor Green

gh secret set KEY_ALIAS --repo $REPO --body $ALIAS
Write-Host "    KEY_ALIAS OK" -ForegroundColor Green

gh secret set KEY_PASSWORD --repo $REPO --body $PASSWORD
Write-Host "    KEY_PASSWORD OK" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP SELESAI!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cara trigger build AAB + APK:" -ForegroundColor Yellow
Write-Host "    git tag v1.0.0 && git push origin v1.0.0" -ForegroundColor White
Write-Host ""
Write-Host "Atau manual: Actions -> Build AAB & APK -> Run workflow" -ForegroundColor White
Write-Host ""