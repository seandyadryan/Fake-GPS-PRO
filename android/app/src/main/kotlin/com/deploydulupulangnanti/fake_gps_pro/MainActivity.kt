package com.deploydulupulangnanti.fake_gps_pro

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
                else -> result.notImplemented()
            }
        }
    }
}
