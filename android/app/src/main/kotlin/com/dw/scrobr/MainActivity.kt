package com.dw.scrobr

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.dw.scrobr/backup"
    private val pickRequest = 4711
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> pickDirectory(result)
                    "directoryName" -> {
                        val uri = call.argument<String>("uri")
                        val name = uri?.let {
                            DocumentFile.fromTreeUri(this, Uri.parse(it))?.name
                        }
                        result.success(name)
                    }
                    "schedule" -> {
                        BackupScheduler.scheduleNext(this, append = false)
                        result.success(null)
                    }
                    "backupNow" -> {
                        BackupScheduler.runNow(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "Folder picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, pickRequest)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val result = pendingPick
        pendingPick = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return
        }
        val uri = data.data!!
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            result?.success(uri.toString())
        } catch (e: SecurityException) {
            result?.error("permission", "Folder does not support persistent access", null)
        }
    }
}
