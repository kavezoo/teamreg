package com.example.teamreg

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val saved = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.theme", null)
        applyNightMode(saved)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setNightMode") {
                    applyNightMode(call.arguments as? String)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun applyNightMode(theme: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }
        val mode = when (theme) {
            "light" -> UiModeManager.MODE_NIGHT_NO
            "dark" -> UiModeManager.MODE_NIGHT_YES
            else -> return
        }
        getSystemService(UiModeManager::class.java)?.setApplicationNightMode(mode)
    }

    companion object {
        private const val CHANNEL = "hu.vzsfoto.teamreg/theme"
    }
}
