package com.example.medisync

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class EmergencyCardActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Essential: Allow Activity to display over Android & Samsung Keyguard without PIN entry
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        setContentView(R.layout.activity_emergency_card)

        // Dismiss when tapping outside the centered card (on the dark dimming area)
        findViewById<View>(R.id.emergency_overlay_root)?.setOnClickListener {
            finish()
        }
        findViewById<View>(R.id.emergency_card_container)?.setOnClickListener {
            // Consume click so tapping on card itself does not dismiss
        }

        findViewById<View>(R.id.btn_close)?.setOnClickListener {
            finish()
        }

        // Read verified patient data from SharedPreferences
        val prefs = getSharedPreferences(MediSyncWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        val patientName = prefs.getString(MediSyncWidgetProvider.KEY_PATIENT_NAME, "MediSync Patient") ?: "MediSync Patient"
        val bloodType = prefs.getString(MediSyncWidgetProvider.KEY_BLOOD_TYPE, "Unknown") ?: "Unknown"
        val healthId = prefs.getString("health_id", "Not Provided") ?: "Not Provided"
        val demographics = prefs.getString("demographics", "Age: Not recorded • Gender: Not recorded") ?: "Age: Not recorded • Gender: Not recorded"
        val allergies = prefs.getString("allergies", "No known drug or environmental allergies recorded.") ?: "No known drug or environmental allergies recorded."
        val conditions = prefs.getString("conditions", "No chronic conditions or organ risks recorded.") ?: "No chronic conditions or organ risks recorded."
        val medications = prefs.getString("medications", "No active regular medications recorded.") ?: "No active regular medications recorded."

        findViewById<TextView>(R.id.tv_patient_name)?.text = patientName.uppercase()
        findViewById<TextView>(R.id.tv_blood_type)?.text = "BLOOD: $bloodType"
        findViewById<TextView>(R.id.tv_demographics)?.text = demographics.uppercase()
        findViewById<TextView>(R.id.tv_health_id)?.text = "ID: $healthId"

        // Allergies
        val tvAllergies = findViewById<TextView>(R.id.tv_allergies)
        tvAllergies?.text = if (allergies.isBlank() || allergies.contains("No known", ignoreCase = true)) {
            "NO KNOWN DRUG ALLERGIES (NKDA)"
        } else {
            allergies
        }

        // Conditions
        val tvConditions = findViewById<TextView>(R.id.tv_conditions)
        val layoutConditions = findViewById<View>(R.id.layout_conditions_section)
        if (conditions.isBlank() || conditions.contains("No chronic", ignoreCase = true) || conditions.equals("None", ignoreCase = true)) {
            layoutConditions?.visibility = View.GONE
        } else {
            layoutConditions?.visibility = View.VISIBLE
            tvConditions?.text = conditions
        }

        // Medications
        val tvMedications = findViewById<TextView>(R.id.tv_medications)
        tvMedications?.text = medications

        // Emergency Call
        findViewById<Button>(R.id.btn_call_emergency)?.setOnClickListener {
            try {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:112")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(dialIntent)
            } catch (_: Exception) {}
        }
    }
}
