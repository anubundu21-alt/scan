package com.scanella.mobile

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "scanella/quota")
            .setMethodCallHandler { call, result ->
                ScanellaQuota.handle(this, call, result)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "scanella/ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val args = call.arguments
                val bytes: ByteArray?
                val language: String?
                if (args is Map<*, *>) {
                    bytes = args["bytes"] as? ByteArray
                    language = args["language"] as? String
                } else {
                    bytes = args as? ByteArray
                    language = null
                }
                if (bytes == null) {
                    result.error("bad_image", "Could not read that image.", null)
                    return@setMethodCallHandler
                }
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    result.error("bad_image", "Could not decode that image.", null)
                    return@setMethodCallHandler
                }
                val image = InputImage.fromBitmap(bitmap, 0)
                clientFor(language)
                    .process(image)
                    .addOnSuccessListener { text ->
                        val blocks = text.textBlocks.map { block ->
                            val box = block.boundingBox
                            val w = bitmap.width.coerceAtLeast(1).toFloat()
                            val h = bitmap.height.coerceAtLeast(1).toFloat()
                            mapOf(
                                "text" to block.text,
                                "l" to ((box?.left ?: 0) / w),
                                "t" to ((box?.top ?: 0) / h),
                                "w" to ((box?.width() ?: 0) / w),
                                "h" to ((box?.height() ?: 0) / h),
                            )
                        }
                        result.success(
                            mapOf(
                                "text" to text.text,
                                "blocks" to blocks,
                            ),
                        )
                    }
                    .addOnFailureListener { error ->
                        result.error("ocr_failed", error.message, null)
                    }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "scanella/pdf")
            .setMethodCallHandler { call, result ->
                ScanellaPdf.handle(this, call, result)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "scanella/pro")
            .setMethodCallHandler { call, result ->
                ScanellaPro.handle(this, call, result)
            }
    }

    private fun clientFor(language: String?) =
        when {
            language?.startsWith("zh") == true ->
                TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            language?.startsWith("ja") == true ->
                TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build())
            language?.startsWith("ko") == true ->
                TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
            language?.startsWith("hi") == true ->
                TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build())
            else ->
                TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        }
}

/// Used-scan count that survives uninstall on this phone: prefs plus a
/// public Downloads marker, so a reinstall still sees the 100 already used.
private object ScanellaQuota {
    private const val PREFS = "scanella_quota"
    private const val KEY = "used"
    private const val FILE_NAME = "scanella_quota_v1"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readUsed" -> result.success(readUsed(context))
            "writeUsed" -> {
                val n = when (val raw = call.arguments) {
                    is Int -> raw
                    is Number -> raw.toInt()
                    else -> null
                }
                if (n == null) {
                    result.error("bad_args", "used is required", null)
                    return
                }
                writeUsed(context, n)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun readUsed(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val fromPrefs = prefs.getInt(KEY, 0)
        val fromFile = readMarker(context)
        val used = maxOf(fromPrefs, fromFile.coerceAtLeast(0))
        if (used > 0 && fromPrefs != used) {
            prefs.edit().putInt(KEY, used).apply()
        }
        if (used > 0 && fromFile != used) {
            writeMarker(context, used)
        }
        return used
    }

    private fun writeUsed(context: Context, used: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY, used)
            .apply()
        writeMarker(context, used)
    }

    private fun readMarker(context: Context): Int {
        readMediaStore(context)?.let { return it }
        return readLegacyFile()
    }

    private fun writeMarker(context: Context, used: Int) {
        if (!writeMediaStore(context, used)) {
            writeLegacyFile(used)
        }
    }

    private fun readMediaStore(context: Context): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return try {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL)
            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME}=?"
            val args = arrayOf(FILE_NAME)
            context.contentResolver.query(collection, projection, selection, args, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val id = cursor.getLong(0)
                val uri = ContentUris.withAppendedId(collection, id)
                context.contentResolver.openInputStream(uri)?.use { stream ->
                    val text = stream.bufferedReader().readText().trim()
                    text.lineSequence().firstOrNull()?.toIntOrNull()
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun writeMediaStore(context: Context, used: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return try {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL)
            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME}=?"
            val args = arrayOf(FILE_NAME)
            val existing = context.contentResolver.query(
                collection,
                projection,
                selection,
                args,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) null
                else ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
            val body = "$used\n".toByteArray()
            if (existing != null) {
                context.contentResolver.openOutputStream(existing, "wt")?.use { it.write(body) }
                return true
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, FILE_NAME)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(collection, values) ?: return false
            context.contentResolver.openOutputStream(uri)?.use { it.write(body) }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readLegacyFile(): Int {
        return try {
            val file = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                FILE_NAME,
            )
            if (!file.exists()) return 0
            file.readText().trim().lineSequence().firstOrNull()?.toIntOrNull() ?: 0
        } catch (_: Exception) {
            0
        }
    }

    private fun writeLegacyFile(used: Int) {
        try {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            File(dir, FILE_NAME).writeText("$used\n")
        } catch (_: Exception) {
        }
    }
}

/// 7-day Pro trial that survives uninstall on this phone.
private object ScanellaPro {
    private const val PREFS = "scanella_pro"
    private const val USED_KEY = "courtesy_used"
    private const val UNTIL_KEY = "courtesy_until"
    private const val FILE_NAME = "scanella_pro_courtesy_v1"

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readCourtesyTrial" -> result.success(readCourtesy(context))
            "startCourtesyTrial" -> {
                val untilMs = (call.arguments as? Map<*, *>)?.get("untilMs")
                val until = when (untilMs) {
                    is Number -> untilMs.toLong()
                    else -> null
                }
                if (until == null) {
                    result.error("bad_args", "untilMs is required", null)
                    return
                }
                writeCourtesy(context, used = true, untilMs = until)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun readCourtesy(context: Context): Map<String, Any?> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        var used = prefs.getBoolean(USED_KEY, false)
        var until = if (prefs.contains(UNTIL_KEY)) prefs.getLong(UNTIL_KEY, 0) else null
        val marker = readMarker(context)
        if (marker != null) {
            used = used || marker.first
            if (marker.second != null) {
                until = maxOf(until ?: 0L, marker.second!!)
            }
        }
        if (used) {
            prefs.edit().putBoolean(USED_KEY, true).apply()
            if (until != null && until > 0) {
                prefs.edit().putLong(UNTIL_KEY, until).apply()
                writeMarker(context, true, until)
            }
        }
        return mapOf(
            "used" to used,
            "untilMs" to until,
        )
    }

    private fun writeCourtesy(context: Context, used: Boolean, untilMs: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(USED_KEY, used)
            .putLong(UNTIL_KEY, untilMs)
            .apply()
        writeMarker(context, used, untilMs)
    }

    private fun readMarker(context: Context): Pair<Boolean, Long?>? {
        val text = readMediaStore(context) ?: readLegacyFile() ?: return null
        val lines = text.trim().lines()
        val used = lines.firstOrNull() == "1"
        val until = lines.getOrNull(1)?.toLongOrNull()
        return used to until
    }

    private fun writeMarker(context: Context, used: Boolean, untilMs: Long) {
        val body = "${if (used) 1 else 0}\n$untilMs\n"
        if (!writeMediaStore(context, body)) {
            writeLegacyFile(body)
        }
    }

    private fun readMediaStore(context: Context): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return try {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL)
            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME}=?"
            val args = arrayOf(FILE_NAME)
            context.contentResolver.query(collection, projection, selection, args, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val uri = ContentUris.withAppendedId(collection, cursor.getLong(0))
                context.contentResolver.openInputStream(uri)?.use {
                    it.bufferedReader().readText()
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun writeMediaStore(context: Context, body: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return try {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL)
            val projection = arrayOf(MediaStore.MediaColumns._ID)
            val selection = "${MediaStore.MediaColumns.DISPLAY_NAME}=?"
            val args = arrayOf(FILE_NAME)
            val existing = context.contentResolver.query(
                collection,
                projection,
                selection,
                args,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) null
                else ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
            val bytes = body.toByteArray()
            if (existing != null) {
                context.contentResolver.openOutputStream(existing, "wt")?.use { it.write(bytes) }
                return true
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, FILE_NAME)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(collection, values) ?: return false
            context.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun readLegacyFile(): String? {
        return try {
            val file = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                FILE_NAME,
            )
            if (!file.exists()) return null
            file.readText()
        } catch (_: Exception) {
            null
        }
    }

    private fun writeLegacyFile(body: String) {
        try {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            File(dir, FILE_NAME).writeText(body)
        } catch (_: Exception) {
        }
    }
}

private object ScanellaPdf {
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val bytes = bytesFrom(call.arguments)
        if (bytes == null) {
            result.error("bad_pdf", "That PDF could not be read.", null)
            return
        }
        Thread {
            try {
                val value: Any = when (call.method) {
                    "extract" -> extract(context, bytes)
                    "renderPage" -> {
                        val map = call.arguments as? Map<*, *>
                        val index = (map?.get("index") as? Number)?.toInt() ?: 0
                        val dpi = (map?.get("dpi") as? Number)?.toInt() ?: 300
                        renderPage(context, bytes, index, dpi)
                    }
                    else -> {
                        post { result.notImplemented() }
                        return@Thread
                    }
                }
                post { result.success(value) }
            } catch (_: SecurityException) {
                post {
                    result.error(
                        "encrypted",
                        "That PDF is password-protected. Unlock it first.",
                        null,
                    )
                }
            } catch (error: Exception) {
                post {
                    result.error(
                        "bad_pdf",
                        error.message ?: "That PDF could not be read.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun post(block: () -> Unit) {
        android.os.Handler(android.os.Looper.getMainLooper()).post(block)
    }

    private fun bytesFrom(arguments: Any?): ByteArray? {
        if (arguments is ByteArray) return arguments
        val map = arguments as? Map<*, *> ?: return null
        return map["bytes"] as? ByteArray
    }

    private fun openRenderer(context: Context, bytes: ByteArray): Pair<File, PdfRenderer> {
        val file = File.createTempFile("scanella_pdf_", ".pdf", context.cacheDir)
        file.writeBytes(bytes)
        val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        return file to PdfRenderer(fd)
    }

    private fun extract(context: Context, bytes: ByteArray): List<Map<String, Any>> {
        val (file, renderer) = openRenderer(context, bytes)
        try {
            val pages = mutableListOf<Map<String, Any>>()
            for (i in 0 until renderer.pageCount) {
                renderer.openPage(i).use { page ->
                    pages.add(
                        mapOf(
                            "text" to "",
                            "widthPt" to page.width.toDouble(),
                            "heightPt" to page.height.toDouble(),
                        ),
                    )
                }
            }
            return pages
        } finally {
            renderer.close()
            file.delete()
        }
    }

    private fun renderPage(
        context: Context,
        bytes: ByteArray,
        index: Int,
        dpi: Int,
    ): Map<String, Any> {
        val (file, renderer) = openRenderer(context, bytes)
        try {
            if (index < 0 || index >= renderer.pageCount) {
                throw IllegalArgumentException("That PDF could not be read.")
            }
            renderer.openPage(index).use { page ->
                val scale = (dpi.coerceAtLeast(72)) / 72f
                val width = (page.width * scale).toInt().coerceAtLeast(1)
                val height = (page.height * scale).toInt().coerceAtLeast(1)
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 92, stream)
                bitmap.recycle()
                return mapOf(
                    "jpeg" to stream.toByteArray(),
                    "width" to width,
                    "height" to height,
                )
            }
        } finally {
            renderer.close()
            file.delete()
        }
    }
}
