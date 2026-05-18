package com.example.notification_filter

import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        var methodChannel: MethodChannel? = null
        private const val CONTACT_PICK_CODE = 1001
    }

    private var pendingContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Notifications channel — Flutter receives notifications here
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "notifications"
        )
        methodChannel?.setMethodCallHandler { _, result ->
            result.success(null)
        }

        // Whitelist sync channel — Flutter pushes whitelist to Kotlin
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "whitelist_sync"
        ).setMethodCallHandler { call, result ->
            if (call.method == "sync") {
                val args = call.arguments as Map<*, *>
                for ((pkg, contacts) in args) {
                    WhitelistChecker.updateWhitelist(
                        pkg.toString(),
                        (contacts as List<*>).map { it.toString() }
                    )
                }
                result.success(null)
            }
        }

        // Contacts picker channel
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