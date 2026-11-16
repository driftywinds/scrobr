package com.dw.scrobr

import android.content.Context
import androidx.work.Configuration
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Owns the single backup chain. WorkManager is initialized here, on demand,
 * rather than through the global startup provider.
 */
object BackupScheduler {
    private const val PREFS = "FlutterSharedPreferences"
    private const val WORK_NAME = "scrobr_backup_chain"

    private fun workManager(context: Context): WorkManager {
        if (!WorkManager.isInitialized()) {
            WorkManager.initialize(
                context,
                Configuration.Builder().build(),
            )
        }
        return WorkManager.getInstance(context)
    }

    fun scheduleNext(context: Context, append: Boolean) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val frequency = prefs.getString("flutter.scrobr_backup_frequency", "off") ?: "off"
        if (frequency == "off" || frequency.isEmpty()) {
            workManager(context).cancelUniqueWork(WORK_NAME)
            return
        }

        val hour = prefs.getLong("flutter.scrobr_backup_hour", 3L).toInt()
        val minute = prefs.getLong("flutter.scrobr_backup_minute", 0L).toInt()
        val delay = nextRunDelayMillis(frequency, hour, minute)
        val request = OneTimeWorkRequestBuilder<BackupWorker>()
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .addTag(WORK_NAME)
            .build()

        workManager(context).enqueueUniqueWork(
            WORK_NAME,
            if (append) ExistingWorkPolicy.APPEND_OR_REPLACE else ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    fun runNow(context: Context) {
        val request = OneTimeWorkRequestBuilder<BackupWorker>()
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .addTag(WORK_NAME)
            .build()
        workManager(context).enqueueUniqueWork(
            WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    private fun nextRunDelayMillis(frequency: String, hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!next.after(now)) {
            when (frequency) {
                "weekly" -> next.add(Calendar.DAY_OF_YEAR, 7)
                "monthly" -> next.add(Calendar.MONTH, 1)
                else -> next.add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        return (next.timeInMillis - System.currentTimeMillis()).coerceAtLeast(0L)
    }
}
