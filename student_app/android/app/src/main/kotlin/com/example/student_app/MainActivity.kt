package com.example.student_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "student_app/downloads"
        ).setMethodCallHandler { call, result ->
            if (call.method != "copyFileToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val sourcePath = call.argument<String>("sourcePath")
            val fileName = call.argument<String>("fileName")
            val mimeType = call.argument<String>("mimeType")

            if (
                sourcePath.isNullOrBlank() ||
                fileName.isNullOrBlank() ||
                mimeType.isNullOrBlank()
            ) {
                result.error("INVALID_ARGS", "Missing export file data.", null)
                return@setMethodCallHandler
            }

            try {
                val savedPath = copyFileToDownloads(sourcePath, fileName, mimeType)
                result.success(savedPath)
            } catch (error: Exception) {
                result.error("SAVE_FAILED", error.message, null)
            }
        }
    }

    @Throws(IOException::class)
    private fun copyFileToDownloads(
        sourcePath: String,
        fileName: String,
        mimeType: String,
    ): String {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw IOException("Temporary export file not found.")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val itemUri = resolver.insert(collection, values)
                ?: throw IOException("Could not create a Downloads entry.")

            FileInputStream(sourceFile).use { input ->
                resolver.openOutputStream(itemUri)?.use { output ->
                    input.copyTo(output)
                    output.flush()
                } ?: throw IOException("Could not open Downloads output stream.")
            }

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)

            return "Download/$fileName"
        }

        val downloadsDirectory = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!downloadsDirectory.exists() && !downloadsDirectory.mkdirs()) {
            throw IOException("Could not open the Downloads folder.")
        }

        val file = File(downloadsDirectory, fileName)
        FileInputStream(sourceFile).use { input ->
            file.outputStream().use { output ->
                input.copyTo(output)
                output.flush()
            }
        }
        return file.absolutePath
    }
}
