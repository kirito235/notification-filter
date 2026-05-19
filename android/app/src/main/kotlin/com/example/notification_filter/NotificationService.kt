package com.example.notification_filter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat

class NotificationService : NotificationListenerService() {

    private val filteredApps = setOf(
        "com.whatsapp.w4b",
        "com.whatsapp",
        "com.instagram.android",
        "com.snapchat.android"
    )

    companion object {
        const val CHANNEL_ID = "notif_filter_service"
        const val NOTIF_ID = 1
    }

    override fun onCreate() {
        super.onCreate()
        startForegroundService()
    }

    private fun startForegroundService() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Notification Filter Service",
            NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = "Keeps notification filtering active"
            setShowBadge(false)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)

        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Notification Filter Active")
            .setContentText("Filtering your notifications")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()

        startForeground(NOTIF_ID, notification)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("NOTIF_SERVICE", "✅ Listener connected!")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        Log.d("NOTIF_SERVICE", "📱 $packageName | $title | $text")

        if (packageName in filteredApps) {
            val isAllowed = WhitelistChecker.isAllowed(packageName, title)
            if (!isAllowed) {
                cancelNotification(sbn.key)
                Log.d("NOTIF_SERVICE", "🚫 Suppressed: $title")
            }
        }

        // Always send to Flutter
        val data = mapOf(
            "packageName" to packageName,
            "title" to title,
            "text" to text
        )

        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod("onNotification", data)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {}

    override fun onDestroy() {
        super.onDestroy()
        // Restart service if killed
        val intent = Intent(this, NotificationService::class.java)
        startService(intent)
    }
}