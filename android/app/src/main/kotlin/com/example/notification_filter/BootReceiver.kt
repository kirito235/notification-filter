package com.example.notification_filter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.d("BOOT_RECEIVER", "📱 Phone booted — reloading whitelist")
            WhitelistChecker.loadFromPrefs(context)
        }
    }
}