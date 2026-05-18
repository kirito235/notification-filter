package com.example.notification_filter

object WhitelistChecker {

    private val whitelist = mutableMapOf<String, MutableSet<String>>()

    fun updateWhitelist(pkg: String, contacts: List<String>) {
        whitelist[pkg] = contacts.toMutableSet()
        android.util.Log.d("WHITELIST", "Updated $pkg: $contacts")
    }

    fun isAllowed(pkg: String, title: String): Boolean {
        val contacts = whitelist[pkg] ?: return false
        if (contacts.isEmpty()) return false
        return contacts.any { name ->
            title.lowercase().contains(name.lowercase())
        }
    }
}