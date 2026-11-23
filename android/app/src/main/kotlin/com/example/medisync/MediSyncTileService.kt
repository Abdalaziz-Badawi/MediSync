package com.example.medisync

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Android & Samsung One UI Quick Settings Tile for MediSync.
 * Appears in the pull-down notification shade / quick settings panel.
 * 
 * Features:
 * 1. Displays real-time Next Dose or Patient Blood Type directly on the tile subtitle.
 * 2. Tapping the tile immediately launches EmergencyCardActivity over the lock screen / keyguard
 *    with ZERO PIN entry required.
 */
class MediSyncTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    override fun onClick() {
        super.onClick()
        try {
            val intent = Intent(this, EmergencyCardActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Android 14+ / Android 15 (One UI 7) requires PendingIntent for startActivityAndCollapse
                val pendingIntent = PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                startActivityAndCollapse(pendingIntent)
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("MediSyncTileService", "Failed to launch EmergencyCardActivity from QS Tile: ${e.message}")
        }
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        try {
            val prefs = getSharedPreferences(MediSyncWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
            val patientName = prefs.getString(MediSyncWidgetProvider.KEY_PATIENT_NAME, "Patient") ?: "Patient"
            val bloodType = prefs.getString(MediSyncWidgetProvider.KEY_BLOOD_TYPE, "Unknown") ?: "Unknown"
            val nextDose = prefs.getString(MediSyncWidgetProvider.KEY_NEXT_DOSE, "") ?: ""

            tile.state = Tile.STATE_ACTIVE
            tile.label = "MediSync"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                if (nextDose.isNotBlank() &&
                    !nextDose.contains("All doses taken", ignoreCase = true) &&
                    !nextDose.contains("No active", ignoreCase = true)
                ) {
                    tile.subtitle = nextDose
                } else {
                    tile.subtitle = "$bloodType • $patientName"
                }
            }

            tile.icon = Icon.createWithResource(this, R.drawable.ic_qs_medisync)
            tile.updateTile()
        } catch (e: Exception) {
            android.util.Log.e("MediSyncTileService", "Error updating QS tile state: ${e.message}")
        }
    }

    companion object {
        /**
         * Requests the system to refresh the MediSync Quick Settings Tile.
         */
        fun requestTileUpdate(context: Context) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    requestListeningState(
                        context.applicationContext,
                        ComponentName(context.applicationContext, MediSyncTileService::class.java)
                    )
                }
            } catch (e: Exception) {
                android.util.Log.w("MediSyncTileService", "Notice: QS Tile update request deferred: ${e.message}")
            }
        }
    }
}
