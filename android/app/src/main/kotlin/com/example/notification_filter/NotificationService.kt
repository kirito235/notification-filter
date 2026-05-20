package com.example.notification_filter

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

    companion object {
        const val CHANNEL_ID = "filternotif_service"
        const val NOTIF_ID = 1
    }

    private val filteredApps = setOf(
        "com.whatsapp.w4b", "com.whatsapp",
        "com.instagram.android", "com.snapchat.android"
    )

    private val summaryPatterns = listOf(
        Regex("\\d+ messages from \\d+ chats"),
        Regex("\\d+ new messages"),
        Regex("\\d+ notifications")
    )

    override fun onCreate() {
        super.onCreate()
        startForegroundNotif()
        WhitelistChecker.loadFromPrefs(applicationContext)
    }

    private fun startForegroundNotif() {
        val channel = NotificationChannel(
            CHANNEL_ID, "FilterNotif Service",
            NotificationManager.IMPORTANCE_MIN
        ).apply { setShowBadge(false) }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)

        val pi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        startForeground(
            NOTIF_ID,
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("FilterNotif Active")
                .setContentText("Filtering your notifications")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pi)
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setOngoing(true).setSilent(true).build()
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d("NOTIF_SERVICE", "✅ Connected")
        WhitelistChecker.loadFromPrefs(applicationContext)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName
        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""

        if (pkg == applicationContext.packageName) return
        if (pkg == "android") return
        if (isSummary(pkg, title, text)) return

        Log.d("NOTIF_SERVICE", "📱 $pkg | $title")

        if (pkg in filteredApps && !WhitelistChecker.isAllowed(pkg, title)) {
            cancelNotification(sbn.key)
            Log.d("NOTIF_SERVICE", "🚫 Suppressed: $title")
        }

        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod(
                "onNotification",
                mapOf("packageName" to pkg, "title" to title, "text" to text)
            )
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {}

    override fun onDestroy() {
        super.onDestroy()
        startService(Intent(this, NotificationService::class.java))
    }

    private fun isSummary(pkg: String, title: String, text: String): Boolean {
        if (summaryPatterns.any { it.containsMatchIn(text) }) return true
        if (setOf("WA Business","WhatsApp","Instagram","Snapchat").contains(title)
            && text.isEmpty()) return true
        if (pkg == "com.snapchat.android" &&
            text.contains("new snap", ignoreCase = true)) return true
        return false
    }
}
