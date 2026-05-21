package com.example.notification_filter

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

object WhitelistChecker {

    private const val PREFS_NAME = "whitelist_prefs"

    private val allowlists = mutableMapOf<String, MutableSet<String>>()
    private val blocklists = mutableMapOf<String, MutableSet<String>>()
    private val modes = mutableMapOf<String, String>() // "allowlist" or "blocklist"

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

    // ── Called from Flutter MethodChannel ────────────────────────

    fun updateAllowlist(pkg: String, contacts: List<String>) {
        allowlists[pkg] = contacts.toMutableSet()
        Log.d("CHECKER", "Allowlist $pkg: $contacts")
    }

    fun updateBlocklist(pkg: String, contacts: List<String>) {
        blocklists[pkg] = contacts.toMutableSet()
        Log.d("CHECKER", "Blocklist $pkg: $contacts")
    }

    fun updateMode(pkg: String, mode: String) {
        modes[pkg] = mode
        Log.d("CHECKER", "Mode $pkg: $mode")
    }

    fun setGlobalEnabled(enabled: Boolean) {
        globalEnabled = enabled
    }

    fun setAppEnabled(pkg: String, enabled: Boolean) {
        perAppEnabled[pkg] = enabled
    }

    // ── Load from SharedPreferences (when app is closed) ─────────

    fun loadFromPrefs(context: Context) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        for (pkg in filteredApps) {
            val allow = prefs.getStringSet("${pkg}_allowlist", emptySet()) ?: emptySet()
            val block = prefs.getStringSet("${pkg}_blocklist", emptySet()) ?: emptySet()
            val mode = prefs.getString("${pkg}_mode", "allowlist") ?: "allowlist"
            allowlists[pkg] = allow.toMutableSet()
            blocklists[pkg] = block.toMutableSet()
            modes[pkg] = mode
            perAppEnabled[pkg] = prefs.getBoolean("${pkg}_enabled", true)
        }
        globalEnabled = prefs.getBoolean("global_enabled", true)
        Log.d("CHECKER", "Loaded from prefs. Global: $globalEnabled")
    }

    // ── Core filter logic ─────────────────────────────────────────

    fun isFilteredApp(pkg: String): Boolean = pkg in filteredApps

    fun isAllowed(pkg: String, title: String): Boolean {
        if (!globalEnabled) return true
        if (perAppEnabled[pkg] == false) return true

        val mode = modes[pkg] ?: "allowlist"

        return if (mode == "blocklist") {
            // Blocklist mode: allow all except explicitly blocked
            val blocked = blocklists[pkg] ?: return true
            if (blocked.isEmpty()) return true
            !blocked.any { name ->
                title.lowercase().contains(name.lowercase())
            }
        } else {
            // Allowlist mode: only allow explicitly allowed
            val allowed = allowlists[pkg] ?: return true
            if (allowed.isEmpty()) return false
            allowed.any { name ->
                title.lowercase().contains(name.lowercase())
            }
        }
    }
}
