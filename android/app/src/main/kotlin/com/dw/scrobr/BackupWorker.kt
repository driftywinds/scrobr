package com.dw.scrobr

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class BackupWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {
    override fun doWork(): Result {
        val context = applicationContext
        return try {
            val backupUri = prefs(context).getString("flutter.scrobr_backup_uri", null)
                ?: throw IllegalStateException("No backup folder selected")
            val bytes = download(context)
            val file = write(context, backupUri, bytes)
            prune(context, backupUri)
            prefs(context).edit()
                .putString("flutter.scrobr_backup_last", file.name ?: "Backup saved")
                .remove("flutter.scrobr_backup_last_error")
                .commit()
            Result.success()
        } catch (e: Exception) {
            prefs(context).edit()
                .putString(
                    "flutter.scrobr_backup_last_error",
                    (e.message ?: e.javaClass.simpleName).take(300),
                )
                .commit()
            Result.failure()
        } finally {
            BackupScheduler.scheduleNext(context, append = true)
        }
    }

    private fun download(context: Context): ByteArray {
        val prefs = prefs(context)
        val server = prefs.getString("flutter.scrobr_server", null)
            ?.trim()?.trimEnd('/')
            ?: throw IllegalStateException("Server is not configured")
        val token = prefs.getString("flutter.scrob_token", null)
            ?: throw IllegalStateException("Sign in again to renew backups")
        val base = if (server.endsWith("/api/proxy")) server else "$server/api/proxy"
        val connection = (URL("$base/admin/backup").openConnection() as HttpURLConnection)
            .apply {
                requestMethod = "GET"
                connectTimeout = 30_000
                readTimeout = 120_000
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("X-Api-Key", "scrob-native-client")
                setRequestProperty("Accept", "application/octet-stream")
            }
        try {
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IOException("Backup request failed (HTTP $code)")
            }
            return connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }

    private fun write(context: Context, treeUri: String, bytes: ByteArray): DocumentFile {
        val root = DocumentFile.fromTreeUri(context, Uri.parse(treeUri))
            ?: throw IllegalStateException("Backup folder is unavailable")
        val stamp = SimpleDateFormat("yyyyMMdd-HHmm", Locale.US).format(Date())
        val file = root.createFile(
            "application/octet-stream",
            "scrobr-backup-$stamp.bak",
        ) ?: throw IllegalStateException("Could not create backup file")
        val output = context.contentResolver.openOutputStream(file.uri)
            ?: throw IllegalStateException("Could not open backup file")
        output.use { it.write(bytes) }
        return file
    }

    private fun prune(context: Context, treeUri: String) {
        val root = DocumentFile.fromTreeUri(context, Uri.parse(treeUri)) ?: return
        val keep = prefs(context)
            .getLong("flutter.scrobr_backup_keep", 7L)
            .toInt()
            .coerceIn(1, 100)
        val backups = root.listFiles()
            .filter { it.isFile && (it.name ?: "").startsWith("scrobr-backup-") }
            .sortedByDescending { it.lastModified() }
        backups.drop(keep).forEach { it.delete() }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
}
