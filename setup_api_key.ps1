#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup Google Maps API Key untuk Fake GPS PRO
.DESCRIPTION
    Script ini akan:
    1. Minta input Google Maps API Key
    2. Update AndroidManifest.xml
    3. Update lib/config/app_config.dart
    4. Tampilkan SHA-1 untuk restriction
#>

$MANIFEST = "android\app\src\main\AndroidManifest.xml"
$CONFIG = "lib\config\app_config.dart"
$KEYSTORE = "D:\KEYSTORE\fakegpspro.jks"
$DEBUG_KEYSTORE = "$env:USERPROFILE\.android\debug.keystore"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Fake GPS PRO - API Key Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Cek Google Cloud CLI
$gcloudAvailable = $null -ne (Get-Command "gcloud" -ErrorAction SilentlyContinue)

if ($gcloudAvailable) {
    Write-Host "[1] Google Cloud CLI terdeteksi." -ForegroundColor Green
    $createKey = Read-Host "    Buat API Key baru via gcloud? (y/N)"
    if ($createKey -eq 'y') {
        try {
            $project = gcloud config get-value project 2>$null
            if (-not $project) {
                Write-Host "    Belum ada project. Buat project dulu..." -ForegroundColor Yellow
                $projectName = Read-Host "    Nama project (contoh: fake-gps-pro)"
                gcloud projects create $projectName --name="Fake GPS PRO"
                gcloud config set project $projectName
                $project = $projectName
            }
            Write-Host "    Mengaktifkan Maps SDK & Geocoding API..." -ForegroundColor Yellow
            gcloud services enable maps-sdk-android.googleapis.com --project $project
            gcloud services enable geocoding-backend.googleapis.com --project $project

            Write-Host "    Membuat API Key..." -ForegroundColor Yellow
            $apiKey = gcloud alpha services api-keys create --project $project --display-name="Fake GPS PRO Key" 2>$null
            if (-not $apiKey) {
                # Fallback: manual
                Write-Host "    gcloud alpha services api-keys belum tersedia." -ForegroundColor Yellow
                $apiKey = Read-Host "    Masukkan API Key manual"
            } else {
                Write-Host "    API Key berhasil dibuat!" -ForegroundColor Green
            }
        } catch {
            Write-Host "    Gagal: $_" -ForegroundColor Red
            $apiKey = Read-Host "    Masukkan API Key manual"
        }
    } else {
        $apiKey = Read-Host "[1] Masukkan Google Maps API Key"
    }
} else {
    Write-Host "[1] gcloud CLI tidak ditemukan." -ForegroundColor Yellow
    Write-Host "    Install dari: https://cloud.google.com/sdk/docs/install"
    Write-Host ""
    $apiKey = Read-Host "    Masukkan Google Maps API Key"
}

if (-not $apiKey -or $apiKey -eq "YOUR_GOOGLE_MAPS_API_KEY") {
    Write-Host "ERROR: API Key tidak valid!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2] Update AndroidManifest.xml..." -ForegroundColor Green
if (Test-Path $MANIFEST) {
    $content = Get-Content $MANIFEST -Raw
    $content = $content -replace 'YOUR_GOOGLE_MAPS_API_KEY', $apiKey
    Set-Content $MANIFEST -Value $content -NoNewline
    Write-Host "    OK - $MANIFEST" -ForegroundColor Green
} else {
    Write-Host "    ERROR: $MANIFEST tidak ditemukan!" -ForegroundColor Red
}

Write-Host ""
Write-Host "[3] Update lib/config/app_config.dart..." -ForegroundColor Green
if (Test-Path $CONFIG) {
    $content = Get-Content $CONFIG -Raw
    $content = $content -replace 'YOUR_GOOGLE_MAPS_API_KEY', $apiKey
    Set-Content $CONFIG -Value $content -NoNewline
    Write-Host "    OK - $CONFIG" -ForegroundColor Green
} else {
    Write-Host "    WARNING: $CONFIG tidak ditemukan!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[4] SHA-1 fingerprint untuk API restriction:" -ForegroundColor Green

# Release keystore
if (Test-Path $KEYSTORE) {
    Write-Host "    Release keystore:" -ForegroundColor Cyan
    & "keytool" -list -v -keystore $KEYSTORE -alias fakegpspro -storepass password -keypass password 2>&1 | Select-String "SHA1:"
} else {
    Write-Host "    Release keystore tidak ditemukan di $KEYSTORE" -ForegroundColor Yellow
}

# Debug keystore
if (Test-Path $DEBUG_KEYSTORE) {
    Write-Host "    Debug keystore:" -ForegroundColor Cyan
    & "keytool" -list -v -keystore $DEBUG_KEYSTORE -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String "SHA1:"
} else {
    Write-Host "    Debug keystore tidak ditemukan" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP SELESAI!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Langkah selanjutnya:" -ForegroundColor Yellow
Write-Host "1. Buka https://console.cloud.google.com/apis/credentials" -ForegroundColor White
Write-Host "2. Klik API Key -> Application restrictions -> Android apps" -ForegroundColor White
Write-Host "3. Tambahkan SHA-1 dari atas, package name: com.deploydulupulangnanti.fake_gps_pro" -ForegroundColor White
Write-Host "4. API restrictions -> Restrict key -> centang Maps SDK + Geocoding API" -ForegroundColor White
Write-Host "5. Jalankan: flutter run" -ForegroundColor Green
Write-Host ""
