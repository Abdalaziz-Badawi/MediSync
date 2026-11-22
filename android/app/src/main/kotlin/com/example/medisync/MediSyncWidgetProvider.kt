package com.example.medisync

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class MediSyncWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val PREFS_NAME = "MediSyncWidgetPrefs"
        const val KEY_PATIENT_NAME = "patient_name"
        const val KEY_BLOOD_TYPE = "blood_type"
        const val KEY_NEXT_DOSE = "next_dose"
        const val KEY_DEFAULT_VIEW = "default_view"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val patientName = prefs.getString(KEY_PATIENT_NAME, "MediSync Patient") ?: "MediSync Patient"
            val bloodType = prefs.getString(KEY_BLOOD_TYPE, "Unknown") ?: "Unknown"
            val nextDose = prefs.getString(KEY_NEXT_DOSE, "Tap to view medical ID") ?: "Tap to view medical ID"
            val defaultView = prefs.getString(KEY_DEFAULT_VIEW, "dual") ?: "dual"

            val views = RemoteViews(context.packageName, R.layout.widget_lockscreen_emergency)
            views.setTextViewText(R.id.widget_patient_name, patientName)
            views.setTextViewText(R.id.widget_blood_type, "BLOOD: $bloodType")

            // Intent to launch EmergencyCardActivity on top of the lockscreen with ZERO PIN
            val intent = Intent(context, EmergencyCardActivity::class.java).apply {
                action = "com.example.medisync.OPEN_EMERGENCY_QUICK"
                putExtra("from_lockscreen_widget", true)
                putExtra("lockscreen_view", defaultView)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, MediSyncWidgetProvider::class.java))
            for (id in ids) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }
}
