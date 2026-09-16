package com.deploydulupulangnanti.fake_gps_pro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Criteria
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ResultReceiver
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class MockLocationService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val manager by lazy { getSystemService(Context.LOCATION_SERVICE) as LocationManager }
    private val tick = object : Runnable {
        override fun run() {
            if (!isActive) return
            try {
                publishLocation()
                handler.postDelayed(this, 1000)
            } catch (e: Exception) {
                lastError = e.message ?: "Izin mock location berubah."
                finishMocking()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Mock location", NotificationManager.IMPORTANCE_LOW))
        }
    }

    @Suppress("DEPRECATION")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val receiver = intent?.getParcelableExtra<ResultReceiver>("receiver")
        try {
            when (intent?.action) {
                ACTION_START -> {
                    latitude = intent.getDoubleExtra("latitude", Double.NaN)
                    longitude = intent.getDoubleExtra("longitude", Double.NaN)
                    require(latitude.isFinite() && longitude.isFinite() && latitude in -90.0..90.0 && longitude in -180.0..180.0)
                    val notification = notification()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
                    } else startForeground(NOTIFICATION_ID, notification)
                    handler.removeCallbacks(tick)
                    if (!isActive && providers.isNotEmpty()) {
                        removeProviders()?.let { throw IllegalStateException(it) }
                    }
                    if (providers.isEmpty()) {
                        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                            manager.addTestProvider(provider, false, false, false, false,
                                true, true, true, Criteria.POWER_LOW, Criteria.ACCURACY_FINE)
                            providers.add(provider)
                            manager.setTestProviderEnabled(provider, true)
                        }
                    }
                    // Acknowledge only after Android accepts the first location.
                    publishLocation()
                    lastError = null
                    isActive = true
                    handler.postDelayed(tick, 1000)
                }
                ACTION_UPDATE -> {
                    check(isActive) { "Mock location sudah berhenti." }
                    latitude = intent.getDoubleExtra("latitude", latitude)
                    longitude = intent.getDoubleExtra("longitude", longitude)
                    require(latitude.isFinite() && longitude.isFinite() && latitude in -90.0..90.0 && longitude in -180.0..180.0)
                    publishLocation()
                    getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification())
                }
                ACTION_STOP -> {
                    val cleanupError = finishMocking()
                    if (cleanupError != null) throw IllegalStateException(cleanupError)
                    lastError = null
                }
                else -> finishMocking()
            }
            receiver?.send(0, Bundle())
        } catch (e: Exception) {
            lastError = e.message ?: "Android menolak mock location."
            finishMocking()
            receiver?.send(1, Bundle().apply { putString("error", lastError) })
        }
        // A killed/stopped service must never silently restart spoofing.
        return START_NOT_STICKY
    }

    private fun publishLocation() {
        for (provider in providers) {
            manager.setTestProviderLocation(provider, Location(provider).apply {
                latitude = MockLocationService.latitude
                longitude = MockLocationService.longitude
                altitude = 0.0
                accuracy = 3.0f
                time = System.currentTimeMillis()
                elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                bearing = 0.0f
                speed = 0.0f
            })
        }
    }

    private fun removeProviders(): String? {
        var error: String? = null
        for (provider in providers.toList()) {
            try {
                manager.removeTestProvider(provider)
                providers.remove(provider)
            } catch (_: IllegalArgumentException) {
                providers.remove(provider)
            } catch (e: Exception) {
                error = "Gagal memulihkan provider lokasi. Pilih ulang Fake GPS PRO di Developer Options, lalu tekan Stop. ${e.message.orEmpty()}"
            }
        }
        return error
    }

    private fun finishMocking(): String? {
        isActive = false
        handler.removeCallbacks(tick)
        val error = removeProviders()
        if (error != null) lastError = error
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        return error
    }

    private fun notification(): Notification {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), flags)
        val stop = PendingIntent.getService(this, 1,
            Intent(this, MockLocationService::class.java).setAction(ACTION_STOP), flags)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Mock location aktif")
            .setContentText("%.6f, %.6f".format(latitude, longitude))
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(open)
            .addAction(android.R.drawable.ic_media_pause, "Stop mock location", stop)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    override fun onDestroy() {
        isActive = false
        handler.removeCallbacks(tick)
        removeProviders()?.let { lastError = it }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val CHANNEL_ID = "fake_gps_pro_channel"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.deploydulupulangnanti.fakegpspro.START"
        const val ACTION_UPDATE = "com.deploydulupulangnanti.fakegpspro.UPDATE"
        const val ACTION_STOP = "com.deploydulupulangnanti.fakegpspro.STOP"
        private val providers = mutableSetOf<String>()
        val hasProviders: Boolean get() = providers.isNotEmpty()
        var isActive = false
            private set
        var latitude = 0.0
            private set
        var longitude = 0.0
            private set
        var lastError: String? = null
            private set
    }
}
