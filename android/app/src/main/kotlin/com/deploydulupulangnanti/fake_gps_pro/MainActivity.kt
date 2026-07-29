package com.deploydulupulangnanti.fake_gps_pro

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.deploydulupulangnanti.fakegpspro/location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableMockMode" -> {
                    try {
                        val lat = call.argument<Double>("latitude") ?: 0.0
                        val lng = call.argument<Double>("longitude") ?: 0.0
                        MockLocationService.start(this, lat, lng)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "disableMockMode" -> {
                    try {
                        MockLocationService.stop(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "setMockLocation" -> {
                    try {
                        val lat = call.argument<Double>("latitude") ?: 0.0
                        val lng = call.argument<Double>("longitude") ?: 0.0
                        MockLocationService.update(this, lat, lng)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openSettings" -> {
                    try {
                        val type = call.argument<String>("type") ?: ""
                        val intent = when (type) {
                            "dev" -> Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                            "about" -> Intent(Settings.ACTION_DEVICE_INFO_SETTINGS)
                            else -> Intent(Settings.ACTION_SETTINGS)
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
