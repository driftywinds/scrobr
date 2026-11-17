package com.dw.scrobr

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Fetches the server calendar once a day, caches it locally, and posts one
 * notification for entries releasing today. No server-side notification
 * support is required.
 */
class CalendarNotificationWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {
    override fun doWork(): Result {
        val context = applicationContext
        val prefs = prefs(context)
        if (!prefs.getBoolean(CalendarNotificationScheduler.ENABLED_KEY, false)) {
            return Result.success()
        }

        return try {
            val body = fetch(context) ?: prefs.getString(CACHE_KEY, null)
            if (body.isNullOrBlank()) throw IOException("Calendar is unavailable")
            if (body != prefs.getString(CACHE_KEY, null)) {
                prefs.edit()
                    .putString(CACHE_KEY, body)
                    .putLong(CACHE_AT_KEY, System.currentTimeMillis())
                    .apply()
            }
            notifyToday(context, body)
            prefs.edit().remove(LAST_ERROR_KEY).commit()
            Result.success()
        } catch (e: Exception) {
            prefs.edit()
                .putString(
                    LAST_ERROR_KEY,
                    (e.message ?: e.javaClass.simpleName).take(300),
                )
                .commit()
            Result.failure()
        } finally {
            CalendarNotificationScheduler.scheduleNext(context, append = true)
        }
    }

    private fun fetch(context: Context): String? {
        val prefs = prefs(context)
        val server = prefs.getString("flutter.scrobr_server", null)
            ?.trim()?.trimEnd('/')
            ?: return null
        val token = prefs.getString("flutter.scrob_token", null) ?: return null
        val base = if (server.endsWith("/api/proxy")) server else "$server/api/proxy"
        val connection = (URL("$base/calendar?days=7").openConnection() as HttpURLConnection)
            .apply {
                requestMethod = "GET"
                connectTimeout = 30_000
                readTimeout = 30_000
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("X-Api-Key", "scrob-native-client")
                setRequestProperty("Accept", "application/json")
            }
        try {
            if (connection.responseCode !in 200..299) return null
            return connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun notifyToday(context: Context, body: String) {
        val prefs = prefs(context)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val previousDay = prefs.getString(NOTIFIED_DAY_KEY, null)
        val seen = if (previousDay == today) {
            prefs.getString(NOTIFIED_KEYS_KEY, "")
                .orEmpty()
                .split("\n")
                .filter { it.isNotBlank() }
                .toSet()
        } else {
            emptySet()
        }

        val entries = JSONObject(body)
            .optJSONObject("calendar")
            ?.optJSONArray("entries")
            ?: return
        val fresh = mutableListOf<Pair<String, String>>()
        for (i in 0 until entries.length()) {
            val entry = entries.optJSONObject(i) ?: continue
            val airDate = entry.optString("air_date").take(10)
            if (airDate != today) continue
            val mediaType = entry.optString("media_type")
            val season = entry.optInt("season_number", -1)
            val episode = entry.optInt("episode_number", -1)
            val showTitle = entry.optString("show_title")
            val mediaTitle = entry.optString("title")
            val episodeName = entry.optString("episode_name")
            val title = if (mediaType == "movie") mediaTitle else showTitle
            if (title.isBlank()) continue
            val key = if (mediaType == "movie") {
                "movie:$title:$airDate"
            } else {
                "$title:$season:$episode:$airDate"
            }
            if (key in seen) continue
            val label = if (mediaType == "movie") {
                title
            } else {
                buildString {
                    append(title)
                    if (season >= 0 && episode >= 0) {
                        append(" S")
                        append(season.toString().padStart(2, '0'))
                        append("E")
                        append(episode.toString().padStart(2, '0'))
                    }
                    if (episodeName.isNotBlank()) {
                        append(" · ")
                        append(episodeName)
                    }
                }
            }
            fresh.add(key to label)
        }

        if (fresh.isEmpty()) return
        if (CalendarNotifier.post(context, fresh.map { it.second })) {
            prefs.edit()
                .putString(NOTIFIED_DAY_KEY, today)
                .putString(
                    NOTIFIED_KEYS_KEY,
                    (seen + fresh.map { it.first }).joinToString("\n"),
                )
                .apply()
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    companion object {
        private const val CACHE_KEY = "flutter.scrobr_calendar_cache"
        private const val CACHE_AT_KEY = "flutter.scrobr_calendar_cache_at"
        private const val NOTIFIED_DAY_KEY = "flutter.scrobr_calendar_notified_day"
        private const val NOTIFIED_KEYS_KEY = "flutter.scrobr_calendar_notified_keys"
        private const val LAST_ERROR_KEY = "flutter.scrobr_calendar_last_error"
    }
}
