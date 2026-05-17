package com.example.notification_filter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        var methodChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "notifications"
        )
        methodChannel?.setMethodCallHandler { _, result ->
            result.success(null)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        methodChannel = null
    }
}