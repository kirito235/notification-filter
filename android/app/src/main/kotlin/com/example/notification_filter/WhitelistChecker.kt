package com.example.notification_filter

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

object WhitelistChecker {

    private const val PREFS_NAME = "whitelist_prefs"
    private val whitelist = mutableMapOf<String, MutableSet<String>>()
    private val filteredApps = setOf(
        "com.whatsapp.w4b",
        "com.whatsapp",
        "com.instagram.android",
        "com.snapchat.android"
    )
    private val perAppEnabled = mutableMapOf(
        "com.whatsapp.w4b" to true,
        "com.whatsapp" to true,
        "com.instagram.android" to true,
        "com.snapchat.android" to true
    )
    private var globalEnabled = true

    // Called on app launch from Flutter via MethodChannel
    fun updateWhitelist(pkg: String, contacts: List<String>) {
        whitelist[pkg] = contacts.toMutableSet()
        Log.d("WHITELIST", "Updated $pkg: $contacts")
    }

    fun setGlobalEnabled(enabled: Boolean) {
        globalEnabled = enabled
        Log.d("WHITELIST", "Global filter enabled: $enabled")
    }

    fun setAppEnabled(pkg: String, enabled: Boolean) {
        perAppEnabled[pkg] = enabled
        Log.d("WHITELIST", "App filter $pkg enabled: $enabled")
    }

    // Load directly from SharedPreferences — used when app is closed
    fun loadFromPrefs(context: Context) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        for (pkg in filteredApps) {
            val saved = prefs.getStringSet(pkg, emptySet()) ?: emptySet()
            whitelist[pkg] = saved.toMutableSet()
            val enabled = prefs.getBoolean("${pkg}_enabled", true)
            perAppEnabled[pkg] = enabled
        }
        globalEnabled = prefs.getBoolean("global_enabled", true)
        Log.d("WHITELIST", "Loaded from prefs: $whitelist")
    }

    fun isFilteredApp(pkg: String): Boolean = pkg in filteredApps

    fun isAllowed(pkg: String, title: String): Boolean {
        if (!globalEnabled) return true // filtering off — allow everything
        if (perAppEnabled[pkg] == false) return true // app filtering off
        val contacts = whitelist[pkg] ?: return true // no whitelist — allow
        if (contacts.isEmpty()) return true // empty whitelist — allow all
        return contacts.any { name ->
            title.lowercase().contains(name.lowercase())
        }
    }
}