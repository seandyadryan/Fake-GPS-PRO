package com.deploydulupulangnanti.fake_gps_pro

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.ResultReceiver
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.deploydulupulangnanti.fakegpspro/location").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getStatus" -> result.success(status())
                    "enableMockMode", "setMockLocation" -> {
                        val lat = call.argument<Double>("latitude")
                        val lng = call.argument<Double>("longitude")
                        if (lat == null || lng == null || !lat.isFinite() || !lng.isFinite() ||
                            lat !in -90.0..90.0 || lng !in -180.0..180.0) {
                            result.error("INVALID_COORDINATES", "Koordinat tidak valid.", null)
                            return@setMethodCallHandler
                        }
                        val status = status()
                        val error = when {
                            status["developerEnabled"] != true -> "Aktifkan Developer Mode terlebih dahulu."
                            status["mockAppSelected"] != true -> "Pilih Fake GPS PRO sebagai aplikasi mock location."
                            status["locationEnabled"] != true -> "Aktifkan layanan lokasi perangkat."
                            status["locationPermissionGranted"] != true -> "Izinkan akses lokasi terlebih dahulu."
                            else -> null
                        }
                        if (error != null) {
                            result.error("SETUP_REQUIRED", error, null)
                        } else if (call.method == "setMockLocation" && !MockLocationService.isActive) {
                            result.error("NOT_RUNNING", "Mock location sudah berhenti.", null)
                        } else {
                            sendCommand(if (call.method == "enableMockMode") MockLocationService.ACTION_START
                                else MockLocationService.ACTION_UPDATE, lat, lng, result)
                        }
                    }
                    "disableMockMode" -> {
                        if (!MockLocationService.isActive && !MockLocationService.hasProviders) result.success(true)
                        else sendCommand(MockLocationService.ACTION_STOP, null, null, result)
                    }
                    "openSettings" -> {
                        val action = when (call.argument<String>("type")) {
                            "dev" -> Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS
                            "about" -> Settings.ACTION_DEVICE_INFO_SETTINGS
                            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
                            else -> Settings.ACTION_SETTINGS
                        }
                        try { startActivity(Intent(action)) }
                        catch (_: android.content.ActivityNotFoundException) {
                            startActivity(Intent(Settings.ACTION_SETTINGS))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("NATIVE_ERROR", e.message ?: "Operasi Android gagal.", null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun status(): Map<String, Any?> {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mockSelected = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_MOCK_LOCATION, Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
        } else false
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return mapOf(
            "developerEnabled" to (Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1),
            "mockAppSelected" to mockSelected,
            "locationEnabled" to LocationManagerCompat.isLocationEnabled(manager),
            "locationPermissionGranted" to (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED),
            "isMocking" to MockLocationService.isActive,
            "hasProviders" to MockLocationService.hasProviders,
            "latitude" to MockLocationService.latitude,
            "longitude" to MockLocationService.longitude,
            "error" to MockLocationService.lastError
        )
    }

    private fun sendCommand(action: String, lat: Double?, lng: Double?, result: MethodChannel.Result) {
        var completed = false
        val timeout = Runnable {
            if (!completed) {
                completed = true
                result.error("TIMEOUT", "Android belum mengonfirmasi. Periksa status lalu coba lagi.", null)
            }
        }
        val receiver = object : ResultReceiver(handler) {
            override fun onReceiveResult(code: Int, data: Bundle?) {
                if (completed) return
                completed = true
                handler.removeCallbacks(timeout)
                if (code == 0) result.success(true)
                else result.error("SERVICE_ERROR", data?.getString("error") ?: "Mock location gagal.", null)
            }
        }
        val intent = Intent(this, MockLocationService::class.java).apply {
            this.action = action
            if (lat != null) putExtra("latitude", lat)
            if (lng != null) putExtra("longitude", lng)
            putExtra("receiver", receiver)
        }
        handler.postDelayed(timeout, 10000)
        try {
            if (action == MockLocationService.ACTION_START) ContextCompat.startForegroundService(this, intent)
            else startService(intent)
        } catch (e: Exception) {
            completed = true
            handler.removeCallbacks(timeout)
            result.error("SERVICE_ERROR", e.message, null)
        }
    }
}
