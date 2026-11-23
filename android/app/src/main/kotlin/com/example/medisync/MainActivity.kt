package com.example.medisync

import android.app.KeyguardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.CalendarContract
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.medisync/device_integration"
    private var pendingGalleryResult: MethodChannel.Result? = null
    private val PICK_IMAGE_REQUEST = 2002

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val fromWidget = intent.getBooleanExtra("from_lockscreen_widget", false)
        val isAction = intent.action == "com.example.medisync.OPEN_EMERGENCY_QUICK" ||
                       intent.action == "com.example.medisync.OPEN_EMERGENCY_CARD"
        if (fromWidget || isAction) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, CHANNEL).invokeMethod("onEmergencyCardRequested", null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            val result = pendingGalleryResult
            pendingGalleryResult = null
            if (resultCode == RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    val inputStream = contentResolver.openInputStream(uri)
                    val pfpDir = File(context.filesDir, "profile_pictures")
                    if (!pfpDir.exists()) pfpDir.mkdirs()
                    val targetFile = File(pfpDir, "custom_avatar_${System.currentTimeMillis()}.jpg")
                    val outputStream = FileOutputStream(targetFile)
                    inputStream?.copyTo(outputStream)
                    inputStream?.close()
                    outputStream.close()
                    result?.success(targetFile.absolutePath)
                } catch (e: Exception) {
                    result?.error("COPY_FAILED", e.message, null)
                }
            } else {
                result?.success(null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openCalendar" -> {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW).setData(Uri.parse("content://com.android.calendar/time/"))
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_CALENDAR)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("CALENDAR_ERROR", e2.message, null)
                        }
                    }
                }
                "insertCalendarEvent" -> {
                    try {
                        val title = call.argument<String>("title") ?: "Medication Reminder"
                        val description = call.argument<String>("description") ?: "MediSync Dose"
                        val beginTime = call.argument<Long>("beginTime") ?: System.currentTimeMillis()

                        val intent = Intent(Intent.ACTION_INSERT)
                            .setData(CalendarContract.Events.CONTENT_URI)
                            .putExtra(CalendarContract.Events.TITLE, title)
                            .putExtra(CalendarContract.Events.DESCRIPTION, description)
                            .putExtra(CalendarContract.Events.EVENT_LOCATION, "MediSync Local")
                            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginTime)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSERT_ERROR", e.message, null)
                    }
                }
                "syncCalendarEvents" -> {
                    try {
                        val eventsList = call.argument<List<Map<String, Any>>>("events") ?: emptyList()
                        val hasWrite = checkSelfPermission(android.Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED
                        val hasRead = checkSelfPermission(android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED
                        if (!hasWrite || !hasRead) {
                            requestPermissions(arrayOf(
                                android.Manifest.permission.WRITE_CALENDAR,
                                android.Manifest.permission.READ_CALENDAR
                            ), 101)
                            result.success(mapOf("success" to false, "reason" to "PERMISSION_REQUESTED", "count" to 0))
                            return@setMethodCallHandler
                        }

                        var calId: Long? = null
                        try {
                            val calCursor = contentResolver.query(
                                CalendarContract.Calendars.CONTENT_URI,
                                arrayOf(
                                    CalendarContract.Calendars._ID,
                                    CalendarContract.Calendars.IS_PRIMARY,
                                    CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL
                                ),
                                null,
                                null,
                                null
                            )
                            calCursor?.use {
                                val idIdx = it.getColumnIndex(CalendarContract.Calendars._ID)
                                val primIdx = it.getColumnIndex(CalendarContract.Calendars.IS_PRIMARY)
                                val accessIdx = it.getColumnIndex(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL)
                                while (it.moveToNext()) {
                                    if (idIdx >= 0) {
                                        val id = it.getLong(idIdx)
                                        val isPrimary = primIdx >= 0 && it.getInt(primIdx) == 1
                                        val access = if (accessIdx >= 0) it.getInt(accessIdx) else 0
                                        if (access >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR || access == 0) {
                                            if (calId == null || isPrimary) {
                                                calId = id
                                                if (isPrimary) break
                                            }
                                        }
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("MediSync", "Error querying calendars: ${e.message}")
                        }

                        if (calId == null) {
                            try {
                                val fallbackCursor = contentResolver.query(
                                    CalendarContract.Calendars.CONTENT_URI,
                                    arrayOf(CalendarContract.Calendars._ID),
                                    null, null, null
                                )
                                fallbackCursor?.use {
                                    if (it.moveToFirst()) {
                                        calId = it.getLong(0)
                                    }
                                }
                            } catch (e: Exception) {
                                android.util.Log.e("MediSync", "Error in fallback calendar query: ${e.message}")
                            }
                        }

                        val targetCalId = calId ?: 1L
                        var insertedCount = 0
                        val tz = TimeZone.getDefault().id

                        // Clear previously synced MediSync events to cleanly remove discontinued or updated medications
                        try {
                            contentResolver.delete(
                                CalendarContract.Events.CONTENT_URI,
                                "${CalendarContract.Events.EVENT_LOCATION} = ?",
                                arrayOf("MediSync Local")
                            )
                        } catch (e: Exception) {
                            android.util.Log.e("MediSync", "Error clearing existing calendar events: ${e.message}")
                        }

                        for (event in eventsList) {
                            val title = (event["title"] as? String) ?: "Medication Reminder"
                            val desc = (event["description"] as? String) ?: "MediSync Dose"
                            val beginTime = (event["beginTime"] as? Number)?.toLong() ?: System.currentTimeMillis()
                            val endTime = (event["endTime"] as? Number)?.toLong() ?: (beginTime + 15 * 60 * 1000L)
                            val rrule = event["rrule"] as? String

                            val values = ContentValues().apply {
                                put(CalendarContract.Events.CALENDAR_ID, targetCalId)
                                put(CalendarContract.Events.TITLE, title)
                                put(CalendarContract.Events.DESCRIPTION, desc)
                                put(CalendarContract.Events.DTSTART, beginTime)
                                put(CalendarContract.Events.DTEND, endTime)
                                put(CalendarContract.Events.EVENT_TIMEZONE, tz)
                                put(CalendarContract.Events.EVENT_LOCATION, "MediSync Local")
                                put(CalendarContract.Events.STATUS, CalendarContract.Events.STATUS_CONFIRMED)
                                put(CalendarContract.Events.HAS_ALARM, 1)
                                if (!rrule.isNullOrEmpty()) {
                                    put(CalendarContract.Events.RRULE, rrule)
                                }
                            }

                            try {
                                val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
                                if (uri != null) {
                                    insertedCount++
                                    val eventId = uri.lastPathSegment?.toLongOrNull()
                                    if (eventId != null) {
                                        val remValues = ContentValues().apply {
                                            put(CalendarContract.Reminders.EVENT_ID, eventId)
                                            put(CalendarContract.Reminders.MINUTES, 10)
                                            put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
                                        }
                                        contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, remValues)
                                    }
                                }
                            } catch (e: Exception) {
                                android.util.Log.e("MediSync", "Failed inserting event $title: ${e.message}")
                            }
                        }

                        result.success(mapOf("success" to true, "count" to insertedCount))
                    } catch (e: Exception) {
                        result.error("SYNC_ERROR", e.message, null)
                    }
                }
                "removeCalendarEventsForMedication" -> {
                    try {
                        val medicationName = call.argument<String>("medicationName") ?: ""
                        val hasWrite = checkSelfPermission(android.Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED
                        if (!hasWrite) {
                            result.success(0)
                            return@setMethodCallHandler
                        }
                        val deleted = if (medicationName.isNotEmpty()) {
                            contentResolver.delete(
                                CalendarContract.Events.CONTENT_URI,
                                "${CalendarContract.Events.EVENT_LOCATION} = ? AND ${CalendarContract.Events.TITLE} LIKE ?",
                                arrayOf("MediSync Local", "%$medicationName%")
                            )
                        } else {
                            contentResolver.delete(
                                CalendarContract.Events.CONTENT_URI,
                                "${CalendarContract.Events.EVENT_LOCATION} = ?",
                                arrayOf("MediSync Local")
                            )
                        }
                        result.success(deleted)
                    } catch (e: Exception) {
                        result.success(0)
                    }
                }
                "openHealthApp" -> {
                    val packages = listOf(
                        "com.samsung.android.app.shealth",      // Samsung Health
                        "com.google.android.apps.healthdata",   // Health Connect
                        "com.google.android.apps.fitness"       // Google Fit
                    )
                    var launched = false
                    for (pkg in packages) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(launchIntent)
                            launched = true
                            break
                        }
                    }
                    if (launched) {
                        result.success(true)
                    } else {
                        try {
                            val storeIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.samsung.android.app.shealth"))
                            storeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(storeIntent)
                            result.success(false)
                        } catch (e: Exception) {
                            result.error("HEALTH_NOT_FOUND", "No supported Health app found on this device", null)
                        }
                    }
                }
                "checkHealthAppStatus" -> {
                    val packages = listOf(
                        "com.samsung.android.app.shealth",
                        "com.google.android.apps.healthdata",
                        "com.google.android.apps.fitness"
                    )
                    var foundName = "None"
                    for (pkg in packages) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            foundName = when (pkg) {
                                "com.samsung.android.app.shealth" -> "Samsung Health"
                                "com.google.android.apps.healthdata" -> "Health Connect"
                                else -> "Google Fit"
                            }
                            break
                        }
                    }
                    result.success(foundName)
                }
                "openBrowserUrl" -> {
                    try {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("INVALID_URL", "URL cannot be null", null)
                        }
                    } catch (e: Exception) {
                        result.error("BROWSER_ERROR", e.message, null)
                    }
                }
                "shareReport" -> {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        val title = call.argument<String>("title") ?: "MediSync Continuity Report"
                        val mimeType = call.argument<String>("mimeType") ?: "text/plain"
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_SUBJECT, title)
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        val chooser = Intent.createChooser(intent, "Share Continuity Report")
                        chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "sharePdfReport" -> {
                    try {
                        val title = call.argument<String>("title") ?: "MediSync Continuity Report"
                        val filename = call.argument<String>("filename") ?: "MediSync_Continuity_Report_${System.currentTimeMillis()}.pdf"
                        val patientName = call.argument<String>("patientName") ?: "Patient"
                        val content = call.argument<String>("content") ?: ""

                        val cacheDir = File(context.cacheDir, "reports")
                        if (!cacheDir.exists()) cacheDir.mkdirs()
                        val pdfFile = File(cacheDir, filename)

                        generatePdfDocument(pdfFile, title, patientName, content)

                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            pdfFile
                        )
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra(Intent.EXTRA_SUBJECT, title)
                            putExtra(Intent.EXTRA_TEXT, "$title\nVerified Patient Continuity Record for $patientName")
                            clipData = android.content.ClipData.newRawUri("report", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(shareIntent, "Share Continuity Report (PDF)")
                        chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(chooser)
                        result.success(pdfFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("PDF_SHARE_FAILED", e.message, null)
                    }
                }
                "shareFileReport" -> {
                    try {
                        val title = call.argument<String>("title") ?: "MediSync Continuity Report"
                        val filename = call.argument<String>("filename") ?: "MediSync_Continuity_Report_${System.currentTimeMillis()}.txt"
                        val content = call.argument<String>("content") ?: ""
                        val mimeType = call.argument<String>("mimeType") ?: "text/plain"

                        val cacheDir = File(context.cacheDir, "reports")
                        if (!cacheDir.exists()) cacheDir.mkdirs()
                        val reportFile = File(cacheDir, filename)
                        reportFile.writeText(content, Charsets.UTF_8)

                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            reportFile
                        )
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = mimeType
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra(Intent.EXTRA_SUBJECT, title)
                            putExtra(Intent.EXTRA_TEXT, "$title\nVerified Patient Continuity Record")
                            clipData = android.content.ClipData.newRawUri("report", uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooser = Intent.createChooser(shareIntent, "Share Continuity Report ($filename)")
                        chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(chooser)
                        result.success(reportFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("FILE_SHARE_FAILED", e.message, null)
                    }
                }
                "saveFileReport" -> {
                    try {
                        val filename = call.argument<String>("filename") ?: "MediSync_Continuity_Report_${System.currentTimeMillis()}.txt"
                        val content = call.argument<String>("content") ?: ""
                        val mimeType = call.argument<String>("mimeType") ?: "text/plain"

                        val docsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
                        val medisyncDir = File(docsDir, "MediSync")
                        if (!medisyncDir.exists()) medisyncDir.mkdirs()
                        val reportFile = File(medisyncDir, filename)
                        reportFile.writeText(content, Charsets.UTF_8)

                        MediaScannerConnection.scanFile(context, arrayOf(reportFile.absolutePath), arrayOf(mimeType), null)
                        result.success(reportFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("FILE_SAVE_FAILED", e.message, null)
                    }
                }
                "savePdfReport" -> {
                    try {
                        val title = call.argument<String>("title") ?: "MediSync Continuity Report"
                        val filename = call.argument<String>("filename") ?: "MediSync_Continuity_Report_${System.currentTimeMillis()}.pdf"
                        val patientName = call.argument<String>("patientName") ?: "Patient"
                        val content = call.argument<String>("content") ?: ""

                        val docsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
                        val medisyncDir = File(docsDir, "MediSync")
                        if (!medisyncDir.exists()) medisyncDir.mkdirs()
                        val pdfFile = File(medisyncDir, filename)

                        generatePdfDocument(pdfFile, title, patientName, content)
                        MediaScannerConnection.scanFile(context, arrayOf(pdfFile.absolutePath), arrayOf("application/pdf"), null)
                        result.success(pdfFile.absolutePath)
                    } catch (e: Exception) {
                        result.error("PDF_SAVE_FAILED", e.message, null)
                    }
                }
                "shareEmergencyCardJpg" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val title = call.argument<String>("title") ?: "MediSync Emergency Health Card"
                        val filename = call.argument<String>("filename") ?: "medisync_emergency_card.jpg"
                        if (bytes != null && bytes.isNotEmpty()) {
                            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            if (bitmap != null) {
                                val cacheDir = File(context.cacheDir, "emergency_cards")
                                if (!cacheDir.exists()) cacheDir.mkdirs()
                                val file = File(cacheDir, filename)
                                val fos = FileOutputStream(file)
                                // Composite on pure white background to prevent JPEG transparent corner black-artifact chipping
                                val rgbBitmap = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
                                val canvas = Canvas(rgbBitmap)
                                canvas.drawColor(Color.WHITE)
                                canvas.drawBitmap(bitmap, 0f, 0f, null)
                                rgbBitmap.compress(Bitmap.CompressFormat.JPEG, 95, fos)
                                fos.flush()
                                fos.close()
                                rgbBitmap.recycle()
                                bitmap.recycle()

                                val uri = FileProvider.getUriForFile(
                                    context,
                                    "${context.packageName}.fileprovider",
                                    file
                                )
                                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "image/jpeg"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    putExtra(Intent.EXTRA_SUBJECT, title)
                                    putExtra(Intent.EXTRA_TEXT, "$title\nVerified Offline Clinical Card")
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                val chooser = Intent.createChooser(shareIntent, "Share Emergency Health Card (JPG)")
                                chooser.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(chooser)
                                result.success(true)
                            } else {
                                result.error("DECODE_FAILED", "Failed to decode bitmap from bytes", null)
                            }
                        } else {
                            result.error("EMPTY_BYTES", "Image bytes were null or empty", null)
                        }
                    } catch (e: Exception) {
                        result.error("SHARE_JPG_ERROR", e.message, null)
                    }
                }
                "saveEmergencyCardJpg" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val filename = call.argument<String>("filename") ?: "medisync_emergency_card_${System.currentTimeMillis()}.jpg"
                        if (bytes != null && bytes.isNotEmpty()) {
                            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                            if (bitmap != null) {
                                val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                                val medisyncDir = File(picturesDir, "MediSync")
                                if (!medisyncDir.exists()) medisyncDir.mkdirs()
                                val file = File(medisyncDir, filename)
                                val fos = FileOutputStream(file)
                                // Composite on pure white background to prevent JPEG transparent corner black-artifact chipping
                                val rgbBitmap = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
                                val canvas = Canvas(rgbBitmap)
                                canvas.drawColor(Color.WHITE)
                                canvas.drawBitmap(bitmap, 0f, 0f, null)
                                rgbBitmap.compress(Bitmap.CompressFormat.JPEG, 95, fos)
                                fos.flush()
                                fos.close()
                                rgbBitmap.recycle()
                                bitmap.recycle()

                                MediaScannerConnection.scanFile(context, arrayOf(file.absolutePath), arrayOf("image/jpeg"), null)
                                result.success(file.absolutePath)
                            } else {
                                result.error("DECODE_FAILED", "Failed to decode bitmap from bytes", null)
                            }
                        } else {
                            result.error("EMPTY_BYTES", "Image bytes were null or empty", null)
                        }
                    } catch (e: Exception) {
                        result.error("SAVE_JPG_ERROR", e.message, null)
                    }
                }
                "getCalendarEvents" -> {
                    try {
                        if (checkSelfPermission(android.Manifest.permission.READ_CALENDAR) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            val projection = arrayOf(
                                CalendarContract.Events.TITLE,
                                CalendarContract.Events.DTSTART,
                                CalendarContract.Events.DTEND,
                                CalendarContract.Events.DESCRIPTION,
                                CalendarContract.Events.EVENT_LOCATION
                            )
                            val startTime = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
                            val endTime = System.currentTimeMillis() + 48 * 60 * 60 * 1000L
                            val selection = "(${CalendarContract.Events.DTSTART} >= ?) AND (${CalendarContract.Events.DTSTART} <= ?)"
                            val selectionArgs = arrayOf(startTime.toString(), endTime.toString())
                            val cursor = contentResolver.query(
                                CalendarContract.Events.CONTENT_URI,
                                projection,
                                selection,
                                selectionArgs,
                                "${CalendarContract.Events.DTSTART} ASC"
                            )
                            val events = mutableListOf<Map<String, Any?>>()
                            cursor?.use {
                                val titleIdx = it.getColumnIndex(CalendarContract.Events.TITLE)
                                val startIdx = it.getColumnIndex(CalendarContract.Events.DTSTART)
                                val endIdx = it.getColumnIndex(CalendarContract.Events.DTEND)
                                val descIdx = it.getColumnIndex(CalendarContract.Events.DESCRIPTION)
                                val locIdx = it.getColumnIndex(CalendarContract.Events.EVENT_LOCATION)
                                while (it.moveToNext()) {
                                    events.add(mapOf(
                                        "title" to (if (titleIdx >= 0) it.getString(titleIdx) else null),
                                        "dtStart" to (if (startIdx >= 0) it.getLong(startIdx) else null),
                                        "dtEnd" to (if (endIdx >= 0) it.getLong(endIdx) else null),
                                        "description" to (if (descIdx >= 0) it.getString(descIdx) else null),
                                        "location" to (if (locIdx >= 0) it.getString(locIdx) else null)
                                    ))
                                }
                            }
                            result.success(events)
                        } else {
                            result.success(emptyList<Map<String, Any?>>())
                        }
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, Any?>>())
                    }
                }
                "getTimeZone" -> {
                    try {
                        result.success(TimeZone.getDefault().id)
                    } catch (e: Exception) {
                        result.success("UTC")
                    }
                }
                "getInitialLockscreenAction" -> {
                    val fromWidget = intent?.getBooleanExtra("from_lockscreen_widget", false) ?: false
                    val isAction = intent?.action == "com.example.medisync.OPEN_EMERGENCY_QUICK" ||
                                   intent?.action == "com.example.medisync.OPEN_EMERGENCY_CARD"
                    if (fromWidget || isAction) {
                        val view = intent?.getStringExtra("lockscreen_view") ?: "dual"
                        result.success(view)
                    } else {
                        result.success(null)
                    }
                }
                "updateWidgetData" -> {
                    try {
                        val name = call.argument<String>("patientName") ?: "MediSync Patient"
                        val blood = call.argument<String>("bloodType") ?: "Unknown"
                        val nextDose = call.argument<String>("nextDose") ?: "Tap to view medical ID"
                        val view = call.argument<String>("defaultView") ?: "dual"
                        val healthId = call.argument<String>("healthId") ?: "Not Provided"
                        val demographics = call.argument<String>("demographics") ?: ""
                        val allergies = call.argument<String>("allergies") ?: ""
                        val conditions = call.argument<String>("conditions") ?: ""
                        val medications = call.argument<String>("medications") ?: ""
                        val organDonor = call.argument<String>("organDonor") ?: "NO"
                        val pastSurgeries = call.argument<String>("pastSurgeries") ?: ""
                        val medicalHistory = call.argument<String>("medicalHistory") ?: ""
                        val discontinuedMeds = call.argument<String>("discontinuedMeds") ?: ""
                        val address = call.argument<String>("address") ?: ""
                        val emergencyContactName = call.argument<String>("emergencyContactName") ?: ""
                        val emergencyContactPhone = call.argument<String>("emergencyContactPhone") ?: ""
                        val emergencyContactRelation = call.argument<String>("emergencyContactRelation") ?: ""

                        val prefs = getSharedPreferences(MediSyncWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString(MediSyncWidgetProvider.KEY_PATIENT_NAME, name)
                            .putString(MediSyncWidgetProvider.KEY_BLOOD_TYPE, blood)
                            .putString(MediSyncWidgetProvider.KEY_NEXT_DOSE, nextDose)
                            .putString(MediSyncWidgetProvider.KEY_DEFAULT_VIEW, view)
                            .putString("health_id", healthId)
                            .putString("demographics", demographics)
                            .putString("allergies", allergies)
                            .putString("conditions", conditions)
                            .putString("medications", medications)
                            .putString("organ_donor", organDonor)
                            .putString("past_surgeries", pastSurgeries)
                            .putString("medical_history", medicalHistory)
                            .putString("discontinued_meds", discontinuedMeds)
                            .putString("address", address)
                            .putString("emergency_contact_name", emergencyContactName)
                            .putString("emergency_contact_phone", emergencyContactPhone)
                            .putString("emergency_contact_relation", emergencyContactRelation)
                            .apply()

                        MediSyncWidgetProvider.updateAllWidgets(this)
                        MediSyncEmergencyButtonWidgetProvider.updateAllWidgets(this)
                        MediSyncTileService.requestTileUpdate(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WIDGET_UPDATE_FAILED", e.message, null)
                    }
                }
                "saveEmergencyCardImage" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes != null) {
                            val file = java.io.File(filesDir, "emergency_card.png")
                            file.writeBytes(bytes)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("SAVE_IMAGE_FAILED", e.message, null)
                    }
                }
                "pickGalleryImage" -> {
                    try {
                        pendingGalleryResult = result
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(intent, PICK_IMAGE_REQUEST)
                    } catch (e: Exception) {
                        pendingGalleryResult = null
                        result.error("PICKER_ERROR", e.message, null)
                    }
                }
                "openEmergencySettings" -> {
                    val possibleIntents = listOf(
                        Intent("android.intent.action.EDIT_EMERGENCY_INFO"),
                        Intent("com.android.settings.action.EMERGENCY_SETTINGS"),
                        Intent(android.provider.Settings.ACTION_SECURITY_SETTINGS)
                    )
                    var opened = false
                    for (tryIntent in possibleIntents) {
                        try {
                            tryIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(tryIntent)
                            opened = true
                            break
                        } catch (_: Exception) {}
                    }
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun generatePdfDocument(pdfFile: File, title: String, patientName: String, content: String) {
        val pdfDocument = PdfDocument()
        val pageWidth = 595
        val pageHeight = 842
        var pageNumber = 1

        var pageInfo = PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create()
        var page = pdfDocument.startPage(pageInfo)
        var canvas = page.canvas

        fun sanitizePdfText(input: String): String {
            return input.replace(Regex("[\\p{So}\\p{Cn}\\uD83C-\\uDBFF\\uDC00-\\uDFFF]+"), "")
                .replace(Regex("[\uFE00-\uFE0F]"), "")
                .trim()
        }

        val textPaint = Paint().apply {
            color = Color.parseColor("#0F172A")
            textSize = 9.5f
            isAntiAlias = true
        }
        val boldPaint = Paint().apply {
            color = Color.parseColor("#0F172A")
            textSize = 9.5f
            isFakeBoldText = true
            isAntiAlias = true
        }
        val headerTitlePaint = Paint().apply {
            color = Color.WHITE
            textSize = 13.5f
            isFakeBoldText = true
            isAntiAlias = true
        }
        val sectionPaint = Paint().apply {
            color = Color.parseColor("#0D9488")
            textSize = 11f
            isFakeBoldText = true
            isAntiAlias = true
        }
        val alertPaint = Paint().apply {
            color = Color.parseColor("#BE123C")
            textSize = 9.5f
            isFakeBoldText = true
            isAntiAlias = true
        }
        val mutedPaint = Paint().apply {
            color = Color.parseColor("#64748B")
            textSize = 8.5f
            isAntiAlias = true
        }
        val bgHeaderPaint = Paint().apply {
            color = Color.parseColor("#0D9488")
        }
        val dividerPaint = Paint().apply {
            color = Color.parseColor("#CBD5E1")
            strokeWidth = 1f
        }

        fun drawPageHeader(c: Canvas, pNum: Int) {
            c.drawRect(36f, 32f, 559f, 74f, bgHeaderPaint)
            c.drawText("MEDISYNC CLINICAL CONTINUITY RECORD", 48f, 52f, headerTitlePaint)
            val subPaint = Paint().apply {
                color = Color.parseColor("#CCFBF1")
                textSize = 8.5f
                isAntiAlias = true
            }
            val dateStr = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US).format(Date())
            c.drawText("Patient: ${patientName.uppercase()}   •   Generated: $dateStr   •   100% Offline Verified", 48f, 66f, subPaint)

            c.drawLine(36f, 802f, 559f, 802f, dividerPaint)
            c.drawText("MediSync Offline Health Record   •   Confidential Medical File", 36f, 816f, mutedPaint)
            c.drawText("Page $pNum", 520f, 816f, mutedPaint)
        }

        drawPageHeader(canvas, pageNumber)
        var curY = 96f

        val lines = content.split("\n")
        for (line in lines) {
            val rawTrimmed = line.trim()
            val trimmed = sanitizePdfText(rawTrimmed)

            if (curY > 770f) {
                pdfDocument.finishPage(page)
                pageNumber++
                pageInfo = PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create()
                page = pdfDocument.startPage(pageInfo)
                canvas = page.canvas
                drawPageHeader(canvas, pageNumber)
                curY = 96f
            }

            if (trimmed.isEmpty()) {
                curY += 7f
                continue
            }

            // Section Dividers / Headers
            if (trimmed.startsWith("# ") || trimmed.startsWith("===") || trimmed.startsWith("+---")) {
                if (trimmed.startsWith("+---")) continue
                val headerText = trimmed.replace(Regex("^[#=+\\s]+"), "").replace(Regex("[=+\\s]+$"), "").trim()
                if (headerText.isNotEmpty()) {
                    curY += 6f
                    canvas.drawText(headerText, 36f, curY, sectionPaint)
                    canvas.drawLine(36f, curY + 3f, 559f, curY + 3f, dividerPaint)
                    curY += 15f
                }
                continue
            }

            if (trimmed.startsWith("## ") || trimmed.startsWith("### ")) {
                val subText = trimmed.replace(Regex("^#+\\s*"), "").trim()
                curY += 5f
                canvas.drawText(subText, 36f, curY, boldPaint)
                curY += 13f
                continue
            }

            // Alert lines (Allergies, Warnings, Contraindications)
            if (trimmed.contains("ALLERGY", ignoreCase = true) || trimmed.contains("CRITICAL", ignoreCase = true) || trimmed.contains("[!")) {
                val alertClean = trimmed.replace(">", "").replace("[!IMPORTANT]", "").replace("[!WARNING]", "").trim()
                canvas.drawText(alertClean, 40f, curY, alertPaint)
                curY += 13f
                continue
            }

            // Tables / Pipe rows
            if (trimmed.startsWith("|") && trimmed.endsWith("|")) {
                if (trimmed.contains("---")) continue
                val cells = trimmed.split("|").filter { it.isNotBlank() }.map { sanitizePdfText(it.trim().replace("**", "")) }
                val colWidth = (520f / cells.size.coerceAtLeast(1))
                val isHeader = trimmed.contains("Medication") || trimmed.contains("Clinical Tier")
                for (idx in cells.indices) {
                    val cellX = 38f + idx * colWidth
                    val cellText = if (cells[idx].length > 25) cells[idx].substring(0, 23) + ".." else cells[idx]
                    canvas.drawText(cellText, cellX, curY, if (isHeader) boldPaint else textPaint)
                }
                canvas.drawLine(36f, curY + 3f, 559f, curY + 3f, dividerPaint)
                curY += 14f
                continue
            }

            // Bullet items
            if (trimmed.startsWith("•") || trimmed.startsWith("*") || trimmed.startsWith("-")) {
                val bulletText = trimmed.replace(Regex("^[•*\\-]\\s*"), "").replace("**", "")
                canvas.drawText("•", 40f, curY, boldPaint)
                canvas.drawText(bulletText, 50f, curY, textPaint)
                curY += 13f
                continue
            }

            // Standard body lines
            val cleanLine = trimmed.replace(">", "").replace("**", "").replace("`", "")
            canvas.drawText(cleanLine, 36f, curY, textPaint)
            curY += 13f
        }

        // Clinician Attestation Sign-off
        if (curY > 700f) {
            pdfDocument.finishPage(page)
            pageNumber++
            pageInfo = PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create()
            page = pdfDocument.startPage(pageInfo)
            canvas = page.canvas
            drawPageHeader(canvas, pageNumber)
            curY = 120f
        }

        curY += 24f
        canvas.drawLine(36f, curY + 28f, 250f, curY + 28f, textPaint)
        canvas.drawText("Attending Clinician Signature", 36f, curY + 40f, mutedPaint)
        canvas.drawLine(340f, curY + 28f, 555f, curY + 28f, textPaint)
        canvas.drawText("Verification Date (DD/MM/YYYY)", 340f, curY + 40f, mutedPaint)

        pdfDocument.finishPage(page)

        val fos = FileOutputStream(pdfFile)
        pdfDocument.writeTo(fos)
        fos.flush()
        fos.close()
        pdfDocument.close()
    }
}
