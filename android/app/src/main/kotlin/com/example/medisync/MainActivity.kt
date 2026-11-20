package com.example.medisync

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Environment
import android.provider.CalendarContract
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.medisync/device_integration"

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
                else -> result.notImplemented()
            }
        }
    }
}
