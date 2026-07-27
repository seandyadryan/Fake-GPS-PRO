package com.deploydulupulangnanti.fake_gps_pro

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class MockLocationService : Service() {

    private val CHANNEL_ID = "fake_gps_pro_channel"
    private val NOTIFICATION_ID = 1001
    private var isRunning = false
    private var currentLat = 0.0
    private var currentLng = 0.0

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                currentLat = intent.getDoubleExtra(EXTRA_LAT, 0.0)
                currentLng = intent.getDoubleExtra(EXTRA_LNG, 0.0)
                startForeground(NOTIFICATION_ID, createNotification())
                setupMockProvider()
                updateMockLocationLoop()
            }
            ACTION_UPDATE -> {
                currentLat = intent.getDoubleExtra(EXTRA_LAT, currentLat)
                currentLng = intent.getDoubleExtra(EXTRA_LNG, currentLng)
                updateMockLocation(currentLat, currentLng)
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                removeMockProvider()
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

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

    private fun updateMockLocationLoop() {
        isRunning = true
        Thread {
            while (isRunning) {
                updateMockLocation(currentLat, currentLng)
                SystemClock.sleep(5000)
            }
        }.start()
    }

    @SuppressLint("MissingPermission")
    private fun removeMockProvider() {
        isRunning = false
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        try {
            locationManager.setTestProviderEnabled(LocationManager.GPS_PROVIDER, false)
            locationManager.removeTestProvider(LocationManager.GPS_PROVIDER)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Fake GPS PRO",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mock location service notification"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Fake GPS PRO")
            .setContentText("Mock location active: $currentLat, $currentLng")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val ACTION_START = "com.deploydulupulangnanti.fakegpspro.START"
        const val ACTION_UPDATE = "com.deploydulupulangnanti.fakegpspro.UPDATE"
        const val ACTION_STOP = "com.deploydulupulangnanti.fakegpspro.STOP"
        const val EXTRA_LAT = "latitude"
        const val EXTRA_LNG = "longitude"

        fun start(context: Context, lat: Double, lng: Double) {
            val intent = Intent(context, MockLocationService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_LAT, lat)
                putExtra(EXTRA_LNG, lng)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, lat: Double, lng: Double) {
            val intent = Intent(context, MockLocationService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_LAT, lat)
                putExtra(EXTRA_LNG, lng)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, MockLocationService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
