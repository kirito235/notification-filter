package com.example.notification_filter

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

object WhitelistChecker {

    private const val PREFS_NAME = "whitelist_prefs"

    private val allowlists = mutableMapOf<String, MutableSet<String>>()
    private val blocklists = mutableMapOf<String, MutableSet<String>>()
    private val modes = mutableMapOf<String, String>()

    private val filteredApps = setOf(
        "com.whatsapp.w4b", "com.whatsapp",
        "com.instagram.android", "com.snapchat.android"
    )
    private val perAppEnabled = mutableMapOf(
        "com.whatsapp.w4b" to true,
        "com.whatsapp" to true,
        "com.instagram.android" to true,
        "com.snapchat.android" to true
    )
    private var globalEnabled = true
    private var focusModeActive = false

    fun updateAllowlist(pkg: String, contacts: List<String>) {
        allowlists[pkg] = contacts.toMutableSet()
    }

    fun updateBlocklist(pkg: String, contacts: List<String>) {
        blocklists[pkg] = contacts.toMutableSet()
    }

    fun updateMode(pkg: String, mode: String) {
        modes[pkg] = mode
    }

    fun setGlobalEnabled(enabled: Boolean) { globalEnabled = enabled }
    fun setAppEnabled(pkg: String, enabled: Boolean) { perAppEnabled[pkg] = enabled }
    fun setFocusMode(active: Boolean) {
        focusModeActive = active
        Log.d("CHECKER", "Focus mode: $active")
    }

    fun loadFromPrefs(context: Context) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        for (pkg in filteredApps) {
            allowlists[pkg] = (prefs.getStringSet("${pkg}_allowlist", emptySet()) ?: emptySet()).toMutableSet()
            blocklists[pkg] = (prefs.getStringSet("${pkg}_blocklist", emptySet()) ?: emptySet()).toMutableSet()
            modes[pkg] = prefs.getString("${pkg}_mode", "allowlist") ?: "allowlist"
            perAppEnabled[pkg] = prefs.getBoolean("${pkg}_enabled", true)
        }
        globalEnabled = prefs.getBoolean("global_enabled", true)
        focusModeActive = prefs.getBoolean("focus_mode_active", false)
        Log.d("CHECKER", "Loaded. Focus: $focusModeActive Global: $globalEnabled")
    }

    fun isFilteredApp(pkg: String): Boolean = pkg in filteredApps

    fun isAllowed(pkg: String, title: String): Boolean {
        if (!globalEnabled) return true
        if (perAppEnabled[pkg] == false) return true

        // Focus mode forces allowlist logic for all apps
        val mode = if (focusModeActive) "allowlist" else (modes[pkg] ?: "allowlist")

        return if (mode == "blocklist") {
            val blocked = blocklists[pkg] ?: return true
            if (blocked.isEmpty()) return true
            !blocked.any { title.lowercase().contains(it.lowercase()) }
        } else {
            val allowed = allowlists[pkg] ?: return true
            if (allowed.isEmpty()) return false
            allowed.any { title.lowercase().contains(it.lowercase()) }
        }
    }
}
