package com.petal.petal

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

/**
 * Petal's own small native features (no plugins). Nothing leaves the phone.
 *
 * Channel "petal/files":
 * - saveToDownloads: writes a file (CSV export, backup) into Downloads.
 *   Android 10+ uses MediaStore (no permission needed); Android 8-9 opens the
 *   system "Save as" screen instead.
 * - openDocument: lets the user pick a file (a backup to restore) with the
 *   system file picker, and returns its bytes.
 *
 * Channel "petal/widget": see [PetalWidget].
 *
 * Channel "petal/device": speak (the phone's offline voice), stopSpeaking,
 * hasStepCounter, requestActivityPermission, keepScreenOn. Event channels "petal/steps"
 * and "petal/facedown": see PetalSensors.kt.
 */
class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<MethodChannel.Result, ByteArray>? = null
    private var pendingOpen: MethodChannel.Result? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var speaker: PetalSpeaker? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, FILES_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val name = call.argument<String>("name")
                    val mime = call.argument<String>("mime")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (name == null || mime == null || bytes == null) {
                        result.error("bad_args", "name, mime and bytes are required", null)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        saveWithMediaStore(name, mime, bytes, result)
                    } else {
                        saveWithPicker(name, mime, bytes, result)
                    }
                }
                "openDocument" -> openDocument(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, PetalWidget.CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    PetalWidget.saveSnapshot(this, call.arguments as Map<*, *>)
                    PetalWidget.refreshAll(this)
                    result.success(null)
                }
                "takePendingGlasses" -> {
                    result.success(PetalWidget.takePendingGlasses(this))
                    PetalWidget.refreshAll(this)
                }
                else -> result.notImplemented()
            }
        }

        val steps = StepsStream(this)
        EventChannel(messenger, "petal/steps").setStreamHandler(steps)
        EventChannel(messenger, "petal/facedown").setStreamHandler(FaceDownStream(this))
        MethodChannel(messenger, "petal/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val s = speaker ?: PetalSpeaker(applicationContext).also { speaker = it }
                    s.speak(text)
                    result.success(null)
                }
                "stopSpeaking" -> {
                    speaker?.stop()
                    result.success(null)
                }
                "hasStepCounter" -> result.success(steps.available)
                "keepScreenOn" -> {
                    // Only during the focus timer, so the face-down phone
                    // keeps Petal in front and the timer honest.
                    if (call.argument<Boolean>("on") == true) {
                        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "requestActivityPermission" -> requestActivityPermission(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        speaker?.release()
        speaker = null
        super.onDestroy()
    }

    // --- step counter permission (Android 10+) ---------------------------------

    private fun requestActivityPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), ACTIVITY_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == ACTIVITY_REQUEST) {
            pendingPermission?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
            )
            pendingPermission = null
        }
    }

    // --- saving ---------------------------------------------------------------

    private fun saveWithMediaStore(
        name: String,
        mime: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        val resolver = contentResolver
        var uri: android.net.Uri? = null
        try {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                // Hide the file from other apps until it's fully written.
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IOException("Couldn't create the file")
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IOException("Couldn't open the file")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            // A second backup on the same day is saved as "name (1).json":
            // report the name Android actually used.
            val saved = resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null } ?: name
            result.success("Downloads/$saved")
        } catch (e: Exception) {
            // Don't leave a hidden half-written file behind.
            uri?.let { runCatching { resolver.delete(it, null, null) } }
            result.error("save_failed", e.message, null)
        }
    }

    private fun saveWithPicker(
        name: String,
        mime: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        if (pendingSave != null || pendingOpen != null) {
            result.error("busy", "Another file screen is open", null)
            return
        }
        pendingSave = result to bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mime
            putExtra(Intent.EXTRA_TITLE, name)
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, SAVE_REQUEST)
    }

    // --- opening --------------------------------------------------------------

    private fun openDocument(result: MethodChannel.Result) {
        if (pendingSave != null || pendingOpen != null) {
            result.error("busy", "Another file screen is open", null)
            return
        }
        pendingOpen = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Backups are JSON, but some file apps label them differently.
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("application/json", "text/plain", "application/octet-stream"),
            )
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, OPEN_REQUEST)
    }

    @Deprecated("Needed for the system file screens")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        val uri = data?.data
        when (requestCode) {
            SAVE_REQUEST -> {
                val (result, bytes) = pendingSave ?: return
                pendingSave = null
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(null) // cancelled
                    return
                }
                try {
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                        ?: throw IOException("Couldn't open the file")
                    result.success("the folder you chose")
                } catch (e: Exception) {
                    result.error("save_failed", e.message, null)
                }
            }
            OPEN_REQUEST -> {
                val result = pendingOpen ?: return
                pendingOpen = null
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(null) // cancelled
                    return
                }
                try {
                    val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                        ?: throw IOException("Couldn't read the file")
                    if (bytes.size > MAX_OPEN_BYTES) throw IOException("That file is too big")
                    result.success(bytes)
                } catch (e: Exception) {
                    result.error("open_failed", e.message, null)
                }
            }
        }
    }

    companion object {
        private const val FILES_CHANNEL = "petal/files"
        private const val SAVE_REQUEST = 4021
        private const val OPEN_REQUEST = 4022
        private const val ACTIVITY_REQUEST = 4023

        /** A backup is a few MB at most; refuse anything absurd. */
        private const val MAX_OPEN_BYTES = 50 * 1024 * 1024
    }
}
