package com.example.teamreg

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Ugyanabban az alkalmazásban fut. Belépés után figyeli az új flash üzeneteket,
 * és értesítést ad, amíg a kijelentkezés le nem állítja.
 */
class MessageWatchService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var running = false
    private var loopStarted = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            clearCreds()
            stopWatch()
            return START_NOT_STICKY
        }
        val access = intent?.getStringExtra(EXTRA_ACCESS)
        val refresh = intent?.getStringExtra(EXTRA_REFRESH)
        val base = intent?.getStringExtra(EXTRA_BASE)
        if (!access.isNullOrBlank() && !refresh.isNullOrBlank() && !base.isNullOrBlank()) {
            saveCreds(access, refresh, base.trimEnd('/'))
        }
        val creds = creds()
        if (creds == null) {
            stopWatch()
            return START_NOT_STICKY
        }
        if (!promote()) {
            stopWatch()
            return START_NOT_STICKY
        }
        running = true
        if (!loopStarted) {
            loopStarted = true
            schedule()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun schedule() {
        if (!running) {
            return
        }
        worker.execute {
            try {
                poll()
            } catch (error: Exception) {
                Log.e(TAG, "Az üzenetfigyelés nem ért el a szervert", error)
            }
            handler.postDelayed({
                if (running) {
                    schedule()
                }
            }, INTERVAL_MS)
        }
    }

    private fun poll() {
        val creds = creds() ?: return
        var access = creds.access
        var response = getJson("${creds.base}/flashes.json", access)
        if (response.code == 401) {
            val refreshed = refresh(creds) ?: return
            access = refreshed
            response = getJson("${creds.base}/flashes.json", access)
        }
        if (response.code !in 200..299) {
            return
        }
        val flashes = JSONObject(response.body).optJSONArray("flashes") ?: return
        val seen = prefs().getStringSet(KEY_NOTIFIED, emptySet())?.toMutableSet() ?: mutableSetOf()
        val manager = getSystemService(NotificationManager::class.java)
        for (index in 0 until flashes.length()) {
            val flash = flashes.optJSONObject(index) ?: continue
            if (!flash.isNull("seen")) {
                continue
            }
            val id = flash.optString("id")
            if (id.isBlank() || seen.contains(id)) {
                continue
            }
            notify(manager, flash, id)
            seen.add(id)
        }
        if (seen.size > 200) {
            val trimmed = seen.toList().takeLast(200).toMutableSet()
            prefs().edit().putStringSet(KEY_NOTIFIED, trimmed).apply()
        } else {
            prefs().edit().putStringSet(KEY_NOTIFIED, seen).apply()
        }
    }

    private fun notify(manager: NotificationManager, flash: JSONObject, id: String) {
        val subject = flash.optString("subject").ifBlank { "Új üzenet" }
        val body = flash.optString("body")
        val target = flash.optString("target").ifBlank { "message" }
        val targetId = if (flash.isNull("target_id")) "" else flash.optString("target_id")
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_FLASH_ID, id)
            putExtra(EXTRA_SUBJECT, subject)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_TARGET, target)
            putExtra(EXTRA_TARGET_ID, targetId)
        }
        val request = id.hashCode() and 0x7fffffff
        val pending = PendingIntent.getActivity(
            this,
            request,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_MESSAGES)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(subject)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        val noticeId = if (request == ONGOING_ID) request + 1 else request
        manager.notify(noticeId, notification)
    }

    private fun refresh(creds: Creds): String? {
        val connection = (URL("${creds.base}/auth/refresh.json").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15000
            readTimeout = 15000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("Accept", "application/json")
        }
        val payload = JSONObject().put("refresh_token", creds.refresh).toString()
        connection.outputStream.use { it.write(payload.toByteArray(Charsets.UTF_8)) }
        val code = connection.responseCode
        val text = read(connection)
        connection.disconnect()
        if (code !in 200..299) {
            return null
        }
        val data = JSONObject(text).optJSONObject("data") ?: return null
        val access = data.optString("access_token")
        val refresh = data.optString("refresh_token")
        if (access.isBlank() || refresh.isBlank()) {
            return null
        }
        saveCreds(access, refresh, creds.base)
        return access
    }

    private fun getJson(url: String, access: String): HttpResult {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 15000
            readTimeout = 15000
            setRequestProperty("Authorization", "Bearer $access")
            setRequestProperty("Accept", "application/json")
        }
        val code = connection.responseCode
        val text = read(connection)
        connection.disconnect()
        return HttpResult(code, text)
    }

    private fun read(connection: HttpURLConnection): String {
        val stream = if (connection.responseCode >= 400) connection.errorStream else connection.inputStream
        return stream?.bufferedReader()?.use { it.readText() } ?: ""
    }

    private fun promote(): Boolean {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val watch = NotificationChannel(
                CHANNEL_WATCH,
                "Üzenetfigyelés",
                NotificationManager.IMPORTANCE_LOW,
            )
            watch.description = "Az alkalmazás figyeli az új telefonos üzeneteket."
            val messages = NotificationChannel(
                CHANNEL_MESSAGES,
                "Telefonos üzenetek",
                NotificationManager.IMPORTANCE_HIGH,
            )
            manager.createNotificationChannel(watch)
            manager.createNotificationChannel(messages)
        }
        val ongoing = NotificationCompat.Builder(this, CHANNEL_WATCH)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle("Ibafai Pipaklub")
            .setContentText("Az üzenetek figyelése fut.")
            .setOngoing(true)
            .build()
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(ONGOING_ID, ongoing, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(ONGOING_ID, ongoing)
            }
            true
        } catch (error: Exception) {
            Log.e(TAG, "A figyelés nem indult el", error)
            false
        }
    }

    private fun stopWatch() {
        running = false
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
        stopSelf()
    }

    private fun creds(): Creds? {
        val store = prefs()
        val access = store.getString(KEY_ACCESS, null)
        val refresh = store.getString(KEY_REFRESH, null)
        val base = store.getString(KEY_BASE, null)
        if (access.isNullOrBlank() || refresh.isNullOrBlank() || base.isNullOrBlank()) {
            return null
        }
        return Creds(access, refresh, base)
    }

    private fun saveCreds(access: String, refresh: String, base: String) {
        prefs().edit()
            .putString(KEY_ACCESS, access)
            .putString(KEY_REFRESH, refresh)
            .putString(KEY_BASE, base)
            .apply()
    }

    private fun clearCreds() {
        prefs().edit().clear().apply()
    }

    private fun prefs() = getSharedPreferences(PREFS, MODE_PRIVATE)

    private data class Creds(val access: String, val refresh: String, val base: String)

    private data class HttpResult(val code: Int, val body: String)

    companion object {
        private const val TAG = "MessageWatch"
        private const val PREFS = "teamreg_message_watch"
        private const val KEY_ACCESS = "access"
        private const val KEY_REFRESH = "refresh"
        private const val KEY_BASE = "base"
        private const val KEY_NOTIFIED = "notified"
        private const val CHANNEL_WATCH = "teamreg_watch"
        private const val CHANNEL_MESSAGES = "teamreg_messages"
        private const val ONGOING_ID = 41001
        private const val INTERVAL_MS = 45_000L
        const val ACTION_STOP = "hu.vzsfoto.teamreg.STOP_WATCH"
        const val EXTRA_ACCESS = "accessToken"
        const val EXTRA_REFRESH = "refreshToken"
        const val EXTRA_BASE = "baseUrl"
        const val EXTRA_FLASH_ID = "flash_id"
        const val EXTRA_SUBJECT = "flash_subject"
        const val EXTRA_BODY = "flash_body"
        const val EXTRA_TARGET = "flash_target"
        const val EXTRA_TARGET_ID = "flash_target_id"

        fun start(context: Context, access: String, refresh: String, base: String) {
            val intent = Intent(context, MessageWatchService::class.java).apply {
                putExtra(EXTRA_ACCESS, access)
                putExtra(EXTRA_REFRESH, refresh)
                putExtra(EXTRA_BASE, base)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, MessageWatchService::class.java).setAction(ACTION_STOP)
            context.startService(intent)
        }
    }
}
