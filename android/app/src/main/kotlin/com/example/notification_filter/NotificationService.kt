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

    // FIX 5: WhatsApp system notification titles to ignore
    private val waSystemTitles = setOf(
        "Checking for messages…",
        "Checking for messages",
        "Ongoing call",
        "Incoming call",
        "Ringing…",
        "Ringing",
        "Connected",
        "Video call",
        "Voice call",
        "WhatsApp Web",
        "End-to-end encrypted",
        "Tap to return to call"
    )

    // FIX 2 + 5: Summary/system patterns
    private val summaryPatterns = listOf(
        Regex("""\d+ messages from \d+ chats"""),
        Regex("""\d+ new messages"""),
        Regex("""\d+ notifications"""),
        Regex("""^Updating messages"""),       // FIX 2: Snapchat
        Regex("""^\d+ new Snaps?$"""),         // FIX 2: Snapchat batch
        Regex("""^You have \d+ new"""),        // FIX 2: Snapchat batch
    )

    private val summaryTitles = setOf(
        "WA Business", "WhatsApp", "Instagram", "Snapchat",
        "Updating messages…", "Updating messages"  // FIX 2
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

        // FIX 5: Skip WhatsApp system/call notifications
        if ((pkg == "com.whatsapp" || pkg == "com.whatsapp.w4b")
            && isWaSystemNotif(title, text)) return

        Log.d("NOTIF_SERVICE", "📱 $pkg | $title | $text")

        // FIX 3: Normalize Instagram title before checking
        val normalizedTitle = normalizeTitle(pkg, title)

        if (WhitelistChecker.isFilteredApp(pkg) &&
            !WhitelistChecker.isAllowed(pkg, normalizedTitle)) {
            cancelNotification(sbn.key)
            Log.d("NOTIF_SERVICE", "🚫 Suppressed: $title")
        }

        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod(
                "onNotification",
                mapOf(
                    "packageName" to pkg,
                    "title" to normalizedTitle,  // send normalized title to Flutter
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

    // FIX 3: Extract sender from Instagram format "yourusername: SenderName"
    // FIX 4: WA Business handled same as WA via shared whitelist in WhitelistChecker
    private fun normalizeTitle(pkg: String, title: String): String {
        if (pkg == "com.instagram.android" && title.contains(": ")) {
            // "justvaibhavv: William" → "William"
            return title.substringAfter(": ").trim()
        }
        return title
    }

    // FIX 5: Detect WhatsApp system/call notifications
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
        // FIX 2: Snapchat "Updating messages" title regardless of text
        if (pkg == "com.snapchat.android" && title.startsWith("Updating")) return true
        return false
    }
}
