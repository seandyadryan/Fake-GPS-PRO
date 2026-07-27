package com.deploydulupulangnanti.fake_gps_pro

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.deploydulupulangnanti.fakegpspro/location"
    private var isMocking = false

    @SuppressLint("MissingPermission")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableMockMode" -> {
                    try {
                        if (!isMocking) {
                            setupMockProvider()
                        }
                        isMocking = true
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "disableMockMode" -> {
                    try {
                        if (isMocking) {
                            removeMockProvider()
                        }
                        isMocking = false
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "setMockLocation" -> {
                    try {
                        val lat = call.argument<Double>("latitude") ?: 0.0
                        val lng = call.argument<Double>("longitude") ?: 0.0
                        updateMockLocation(lat, lng)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun setupMockProvider() {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager.addTestProvider(
                LocationManager.GPS_PROVIDER,
                false, false, false, false, true, true, true, 0, 5
            )
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    @SuppressLint("MissingPermission")
    private fun updateMockLocation(latitude: Double, longitude: Double) {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val mockLocation = Location(LocationManager.GPS_PROVIDER).apply {
            this.latitude = latitude
            this.longitude = longitude
            accuracy = 3.0f
            time = System.currentTimeMillis()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                elapsedRealtimeNanos = System.nanoTime()
            }
            bearing = 0.0f
            speed = 0.0f
        }
        try {
            locationManager.setTestProviderLocation(LocationManager.GPS_PROVIDER, mockLocation)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    @SuppressLint("MissingPermission")
    private fun removeMockProvider() {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, false)
            locationManager.removeTestProvider(LocationManager.GPS_PROVIDER)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
