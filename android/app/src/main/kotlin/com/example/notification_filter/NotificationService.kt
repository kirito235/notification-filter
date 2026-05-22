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

    companion object {
        const val CHANNEL_ID = "filternotif_service"
        const val NOTIF_ID = 1
    }

    private val filteredApps = setOf(
        "com.whatsapp.w4b", "com.whatsapp",
        "com.instagram.android", "com.snapchat.android"
    )

    private val waSystemTitles = setOf(
        "Checking for messages…", "Checking for messages",
        "Ongoing call", "Incoming call", "Ringing…", "Ringing",
        "Connected", "Video call", "Voice call",
        "WhatsApp Web", "End-to-end encrypted", "Tap to return to call"
    )

    private val summaryPatterns = listOf(
        Regex("""\d+ messages from \d+ chats"""),
        Regex("""\d+ new messages"""),
        Regex("""\d+ notifications"""),
        Regex("""^Updating messages"""),
        Regex("""^\d+ new Snaps?$"""),
        Regex("""^You have \d+ new"""),
    )

    private val summaryTitles = setOf(
        "WA Business", "WhatsApp", "Instagram", "Snapchat",
        "Updating messages…", "Updating messages"
    )

    override fun onCreate() {
        super.onCreate()
        startForegroundNotif()
        WhitelistChecker.loadFromPrefs(applicationContext)
    }

    private fun startForegroundNotif() {
        val manager = getSystemService(NotificationManager::class.java)

        // Create channel with IMPORTANCE_MIN — no sound, no peek, no status bar icon
        val channel = NotificationChannel(
            CHANNEL_ID,
            "FilterNotif",
            NotificationManager.IMPORTANCE_MIN  // lowest possible
        ).apply {
            description = "Keeps notification filtering active"
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_SECRET // hidden on lock screen
        }
        manager.createNotificationChannel(channel)

        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FilterNotif")
            .setContentText("Running in background")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentIntent(pendingIntent)
            // These three together make it as invisible as possible
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
            // No icon shown in status bar
            .setShowWhen(false)
            .setNotificationSilent()
            .build()

        // Apply flag to hide from status bar icon tray
        notification.flags = notification.flags or
                Notification.FLAG_NO_CLEAR or
                Notification.FLAG_ONGOING_EVENT

        startForeground(NOTIF_ID, notification)

        // After starting foreground, hide notification from the shade on Android 8+
        // This keeps the service alive but removes the visual entry entirely
        manager.cancel(NOTIF_ID)
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
        if ((pkg == "com.whatsapp" || pkg == "com.whatsapp.w4b")
            && isWaSystemNotif(title, text)) return

        val normalizedTitle = normalizeTitle(pkg, title)
        Log.d("NOTIF_SERVICE", "📱 $pkg | $normalizedTitle")

        if (WhitelistChecker.isFilteredApp(pkg) &&
            !WhitelistChecker.isAllowed(pkg, normalizedTitle)) {
            cancelNotification(sbn.key)
            Log.d("NOTIF_SERVICE", "🚫 Suppressed: $normalizedTitle")
        }

        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod(
                "onNotification",
                mapOf(
                    "packageName" to pkg,
                    "title" to normalizedTitle,
                    "text" to text
                )
            )
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {}

    override fun onDestroy() {
        super.onDestroy()
        startService(Intent(this, NotificationService::class.java))
    }

    private fun normalizeTitle(pkg: String, title: String): String {
        if (pkg == "com.instagram.android" && title.contains(": ")) {
            return title.substringAfter(": ").trim()
        }
        return title
    }

    private fun isWaSystemNotif(title: String, text: String): Boolean {
        if (waSystemTitles.contains(title)) return true
        if (text.contains("Checking for messages", ignoreCase = true)) return true
        if (text.contains("end-to-end encrypted", ignoreCase = true)) return true
        if (text.contains("tap to return to call", ignoreCase = true)) return true
        return false
    }

    private fun isSummary(pkg: String, title: String, text: String): Boolean {
        if (summaryPatterns.any { it.containsMatchIn(text) }) return true
        if (summaryPatterns.any { it.containsMatchIn(title) }) return true
        if (summaryTitles.contains(title) && text.isEmpty()) return true
        if (pkg == "com.snapchat.android" && title.startsWith("Updating")) return true
        return false
    }
}