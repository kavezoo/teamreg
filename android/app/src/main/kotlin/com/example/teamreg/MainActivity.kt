package com.example.teamreg

import android.Manifest
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingOpen: HashMap<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        val saved = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.theme", null)
        applyNightMode(saved)
        pendingOpen = readOpen(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingOpen = readOpen(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THEME_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setNightMode") {
                    applyNightMode(call.arguments as? String)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MESSAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startWatch" -> {
                        val args = call.arguments as? Map<*, *>
                        val access = args?.get("accessToken") as? String
                        val refresh = args?.get("refreshToken") as? String
                        val base = args?.get("baseUrl") as? String
                        if (access.isNullOrBlank() || refresh.isNullOrBlank() || base.isNullOrBlank()) {
                            result.error("missing", "Hiányzik a belépés.", null)
                        } else {
                            askNotifications()
                            MessageWatchService.start(this, access, refresh, base)
                            result.success(null)
                        }
                    }
                    "stopWatch" -> {
                        MessageWatchService.stop(this)
                        result.success(null)
                    }
                    "takeOpen" -> {
                        val open = pendingOpen
                        pendingOpen = null
                        intent?.removeExtra(MessageWatchService.EXTRA_FLASH_ID)
                        result.success(open)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun askNotifications() {
        if (Build.VERSION.SDK_INT < 33) {
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            return
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4101)
    }

    private fun readOpen(source: Intent?): HashMap<String, String>? {
        val id = source?.getStringExtra(MessageWatchService.EXTRA_FLASH_ID) ?: return null
        if (id.isBlank()) {
            return null
        }
        return hashMapOf(
            "id" to id,
            "subject" to (source.getStringExtra(MessageWatchService.EXTRA_SUBJECT) ?: ""),
            "body" to (source.getStringExtra(MessageWatchService.EXTRA_BODY) ?: ""),
            "target" to (source.getStringExtra(MessageWatchService.EXTRA_TARGET) ?: "message"),
            "targetId" to (source.getStringExtra(MessageWatchService.EXTRA_TARGET_ID) ?: ""),
        )
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
        private const val THEME_CHANNEL = "hu.vzsfoto.teamreg/theme"
        private const val MESSAGE_CHANNEL = "hu.vzsfoto.teamreg/messages"
    }
}
