package com.example.notification_filter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ServiceRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WhitelistChecker.loadFromPrefs(context)
    }
}