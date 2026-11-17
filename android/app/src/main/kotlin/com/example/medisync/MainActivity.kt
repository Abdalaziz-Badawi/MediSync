package com.example.medisync

import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                else -> result.notImplemented()
            }
        }
    }
}
