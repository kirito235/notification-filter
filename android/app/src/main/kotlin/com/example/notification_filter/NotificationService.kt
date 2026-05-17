package com.example.notification_filter

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Handler
import android.os.Looper
import android.util.Log

class NotificationService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("NOTIF_SERVICE", "✅ Listener connected!")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: "NO_TITLE"
        val text = extras.getCharSequence("android.text")?.toString() ?: "NO_TEXT"

        Log.d("NOTIF_SERVICE", "📱 $packageName | $title | $text")

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