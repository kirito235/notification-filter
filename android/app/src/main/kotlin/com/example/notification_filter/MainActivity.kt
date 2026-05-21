package com.example.notification_filter

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.provider.ContactsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        var methodChannel: MethodChannel? = null
        private const val CONTACT_PICK_CODE = 1001
        private const val PREFS_NAME = "whitelist_prefs"
    }

    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Notifications channel ──────────────────────────────────
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "notifications"
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
                    result.success(null)
                }
                "openBatterySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            .apply { data = Uri.parse("package:$packageName") }
                        startActivity(intent)
                    } catch (e: Exception) {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    }
                    result.success(null)
                }
                else -> result.success(null)
            }
        }

        // ── Whitelist sync channel ─────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "whitelist_sync"
        ).setMethodCallHandler { call, result ->
            val prefs: SharedPreferences =
                getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val editor = prefs.edit()

            when (call.method) {
                // Legacy allowlist sync
                "sync" -> {
                    val args = call.arguments as Map<*, *>
                    for ((pkg, contacts) in args) {
                        val list = (contacts as List<*>).map { it.toString() }
                        WhitelistChecker.updateAllowlist(pkg.toString(), list)
                        editor.putStringSet("${pkg}_allowlist", list.toSet())
                    }
                    editor.apply()
                    result.success(null)
                }
                // Blocklist sync
                "syncBlocklist" -> {
                    val args = call.arguments as Map<*, *>
                    for ((pkg, contacts) in args) {
                        val list = (contacts as List<*>).map { it.toString() }
                        WhitelistChecker.updateBlocklist(pkg.toString(), list)
                        editor.putStringSet("${pkg}_blocklist", list.toSet())
                    }
                    editor.apply()
                    result.success(null)
                }
                // Mode sync
                "syncModes" -> {
                    val args = call.arguments as Map<*, *>
                    for ((pkg, mode) in args) {
                        WhitelistChecker.updateMode(pkg.toString(), mode.toString())
                        editor.putString("${pkg}_mode", mode.toString())
                    }
                    editor.apply()
                    result.success(null)
                }
                "setGlobalEnabled" -> {
                    val enabled = call.arguments as Boolean
                    WhitelistChecker.setGlobalEnabled(enabled)
                    editor.putBoolean("global_enabled", enabled).apply()
                    result.success(null)
                }
                "setAppEnabled" -> {
                    val args = call.arguments as Map<*, *>
                    val pkg = args["pkg"] as String
                    val enabled = args["enabled"] as Boolean
                    WhitelistChecker.setAppEnabled(pkg, enabled)
                    editor.putBoolean("${pkg}_enabled", enabled).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Contacts picker channel ────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "contacts"
        ).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                pendingContactResult = result
                val intent = Intent(Intent.ACTION_PICK).apply {
                    type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE
                }
                startActivityForResult(intent, CONTACT_PICK_CODE)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CONTACT_PICK_CODE) {
            if (resultCode == RESULT_OK && data != null) {
                val cursor = contentResolver.query(
                    data.data!!,
                    arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME),
                    null, null, null
                )
                cursor?.use {
                    pendingContactResult?.success(
                        if (it.moveToFirst()) it.getString(0) else null
                    )
                }
            } else {
                pendingContactResult?.success(null)
            }
            pendingContactResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        methodChannel = null
    }
}
