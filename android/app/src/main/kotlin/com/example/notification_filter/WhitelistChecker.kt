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

    // FIX 4: WA and WA Business share the same prefs key
    private val prefsKeyFor = mapOf(
        "com.whatsapp.w4b" to "com.whatsapp",   // WA Business → use WA key
        "com.whatsapp" to "com.whatsapp",
        "com.instagram.android" to "com.instagram.android",
        "com.snapchat.android" to "com.snapchat.android"
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
        val key = prefsKeyFor[pkg] ?: pkg
        allowlists[key] = contacts.toMutableSet()
        // FIX 4: keep both WA packages in sync
        if (key == "com.whatsapp") {
            allowlists["com.whatsapp.w4b"] = contacts.toMutableSet()
        }
    }

    fun updateBlocklist(pkg: String, contacts: List<String>) {
        val key = prefsKeyFor[pkg] ?: pkg
        blocklists[key] = contacts.toMutableSet()
        if (key == "com.whatsapp") {
            blocklists["com.whatsapp.w4b"] = contacts.toMutableSet()
        }
    }

    fun updateMode(pkg: String, mode: String) {
        val key = prefsKeyFor[pkg] ?: pkg
        modes[key] = mode
        if (key == "com.whatsapp") modes["com.whatsapp.w4b"] = mode
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
            val key = prefsKeyFor[pkg] ?: pkg
            val allow = (prefs.getStringSet("${key}_allowlist", emptySet()) ?: emptySet()).toMutableSet()
            val block = (prefs.getStringSet("${key}_blocklist", emptySet()) ?: emptySet()).toMutableSet()
            val mode = prefs.getString("${key}_mode", "allowlist") ?: "allowlist"
            allowlists[pkg] = allow
            blocklists[pkg] = block
            modes[pkg] = mode
            perAppEnabled[pkg] = prefs.getBoolean("${pkg}_enabled", true)
        }
        globalEnabled = prefs.getBoolean("global_enabled", true)
        focusModeActive = prefs.getBoolean("focus_mode_active", false)
        Log.d("CHECKER", "Loaded. Focus: $focusModeActive")
    }

    fun isFilteredApp(pkg: String): Boolean = pkg in filteredApps

    fun isAllowed(pkg: String, title: String): Boolean {
        if (!globalEnabled) return true
        if (perAppEnabled[pkg] == false) return true

        val mode = if (focusModeActive) "allowlist" else (modes[pkg] ?: "allowlist")

        return if (mode == "blocklist") {
            val blocked = blocklists[pkg] ?: return true
            if (blocked.isEmpty()) return true
            !blocked.any { title.lowercase().contains(it.lowercase()) }
        } else {
            val allowed = allowlists[pkg] ?: return false
            // FIX 1: empty allowlist = block all in allowlist mode
            if (allowed.isEmpty()) return false
            allowed.any { title.lowercase().contains(it.lowercase()) }
        }
    }
}
