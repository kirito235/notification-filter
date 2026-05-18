package com.example.notification_filter

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Handler
import android.os.Looper
import android.util.Log

class NotificationService : NotificationListenerService() {

    // Apps we actively filter
    private val filteredApps = setOf(
        "com.whatsapp.w4b",
        "com.whatsapp",
        "com.instagram.android",
        "com.snapchat.android"
    )

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

        // Only interfere with apps we filter
        if (packageName in filteredApps) {
            val isAllowed = WhitelistChecker.isAllowed(packageName, title)

            if (!isAllowed) {
                // Cancel it — remove from notification bar
                cancelNotification(sbn.key)
                Log.d("NOTIF_SERVICE", "🚫 Suppressed: $title")
                return
            }
        }

        // Send to Flutter UI
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
}