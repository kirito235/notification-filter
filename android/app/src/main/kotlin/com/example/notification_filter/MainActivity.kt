package com.example.notification_filter

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.ContactsContract
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
                    val intent = Intent(
                        "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
                    )
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.success(null)
            }
        }

        // ── Whitelist sync channel ─────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "whitelist_sync"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    val prefs: SharedPreferences =
                        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    val args = call.arguments as Map<*, *>
                    for ((pkg, contacts) in args) {
                        val contactList =
                            (contacts as List<*>).map { it.toString() }
                        // Update in-memory checker
                        WhitelistChecker.updateWhitelist(
                            pkg.toString(), contactList
                        )
                        // Persist to SharedPreferences for when app is closed
                        editor.putStringSet(
                            pkg.toString(), contactList.toSet()
                        )
                    }
                    editor.apply()
                    result.success(null)
                }
                "setGlobalEnabled" -> {
                    val enabled = call.arguments as Boolean
                    WhitelistChecker.setGlobalEnabled(enabled)
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("global_enabled", enabled).apply()
                    result.success(null)
                }
                "setAppEnabled" -> {
                    val args = call.arguments as Map<*, *>
                    val pkg = args["pkg"] as String
                    val enabled = args["enabled"] as Boolean
                    WhitelistChecker.setAppEnabled(pkg, enabled)
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("${pkg}_enabled", enabled).apply()
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

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CONTACT_PICK_CODE) {
            if (resultCode == RESULT_OK && data != null) {
                val cursor = contentResolver.query(
                    data.data!!,
                    arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME),
                    null, null, null
                )
                cursor?.use {
                    if (it.moveToFirst()) {
                        pendingContactResult?.success(it.getString(0))
                    } else {
                        pendingContactResult?.success(null)
                    }
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