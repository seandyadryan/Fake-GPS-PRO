#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup Google Maps API Key untuk Fake GPS PRO
.DESCRIPTION
    Script ini akan:
    1. Minta input Google Maps API Key (atau buat via gcloud jika tersedia)
    2. Update android/app/src/main/AndroidManifest.xml
    3. Update lib/config/app_config.dart
    4. Tampilkan SHA-1 fingerprint untuk konfigurasi API key restriction di Google Cloud Console
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
                Write-Host "    Belum ada project aktif. Masukkan ID project..." -ForegroundColor Yellow
                $projectName = Read-Host "    Project ID (contoh: fake-gps-pro)"
                gcloud config set project $projectName
                $project = $projectName
            }
            Write-Host "    Mengaktifkan Maps SDK for Android & Geocoding API..." -ForegroundColor Yellow
            gcloud services enable maps-android-backend.googleapis.com --project $project 2>$null
            gcloud services enable geocoding-backend.googleapis.com --project $project 2>$null

            Write-Host "    Membuat API Key..." -ForegroundColor Yellow
            $apiKey = gcloud services api-keys create --project $project --display-name="Fake GPS PRO Key" --format="value(response.keyString)" 2>$null
            if (-not $apiKey) {
                Write-Host "    Pembuatan otomatis via gcloud memerlukan izin tambahan." -ForegroundColor Yellow
                $apiKey = Read-Host "    Masukkan API Key manual"
            } else {
                Write-Host "    API Key berhasil dibuat!" -ForegroundColor Green
            }
        } catch {
            Write-Host "    Gagal via gcloud: $_" -ForegroundColor Red
            $apiKey = Read-Host "    Masukkan API Key manual"
        }
    } else {
        $apiKey = Read-Host "[1] Masukkan Google Maps API Key"
    }
} else {
    Write-Host "[1] Masukkan Google Maps API Key:" -ForegroundColor Yellow
    $apiKey = Read-Host "    API Key"
}

if (-not $apiKey -or $apiKey -eq "YOUR_GOOGLE_MAPS_API_KEY") {
    Write-Host "ERROR: API Key tidak valid!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[2] Update AndroidManifest.xml..." -ForegroundColor Green
if (Test-Path $MANIFEST) {
    $content = Get-Content $MANIFEST -Raw
    $content = $content -replace 'android:value="[^"]*"(\s*/>\s*<!--\s*\^\^\^\s*Ganti YOUR_GOOGLE_MAPS_API_KEY)', "android:value=`"$apiKey`"`$1"
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
    $content = $content -replace "defaultValue:\s*'[^']*'", "defaultValue: '$apiKey'"
    Set-Content $CONFIG -Value $content -NoNewline
    Write-Host "    OK - $CONFIG" -ForegroundColor Green
} else {
    Write-Host "    WARNING: $CONFIG tidak ditemukan!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[4] SHA-1 fingerprint untuk API restriction:" -ForegroundColor Green

$keytoolCmd = if (Get-Command "keytool" -ErrorAction SilentlyContinue) {
    "keytool"
} elseif (Test-Path "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe") {
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
} else {
    $null
}

# Release keystore
if (Test-Path $KEYSTORE) {
    Write-Host "    Release keystore:" -ForegroundColor Cyan
    if ($keytoolCmd) {
        & $keytoolCmd -list -v -keystore $KEYSTORE -alias fakegpspro -storepass Bushido321 -keypass Bushido321 2>&1 | Select-String "SHA1:"
    }
} else {
    Write-Host "    Release keystore tidak ditemukan di $KEYSTORE" -ForegroundColor Yellow
}

# Debug keystore
if (Test-Path $DEBUG_KEYSTORE) {
    Write-Host "    Debug keystore:" -ForegroundColor Cyan
    if ($keytoolCmd) {
        & $keytoolCmd -list -v -keystore $DEBUG_KEYSTORE -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String "SHA1:"
    }
} else {
    Write-Host "    Debug keystore tidak ditemukan di $DEBUG_KEYSTORE" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SETUP SELESAI!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Langkah selanjutnya:" -ForegroundColor Yellow
Write-Host "1. Buka https://console.cloud.google.com/apis/credentials" -ForegroundColor White
Write-Host "2. Klik API Key Anda -> Application restrictions -> Android apps" -ForegroundColor White
Write-Host "3. Tambahkan Package Name: com.deploydulupulangnanti.fake_gps_pro beserta SHA-1 di atas" -ForegroundColor White
Write-Host "4. API restrictions -> Restrict key -> centang 'Maps SDK for Android' & 'Geocoding API'" -ForegroundColor White
Write-Host "5. Jalankan aplikasi: flutter run" -ForegroundColor Green
Write-Host ""
