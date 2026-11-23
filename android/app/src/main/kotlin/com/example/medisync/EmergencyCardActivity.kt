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
        val organDonor = prefs.getString("organ_donor", "NO") ?: "NO"
        val pastSurgeries = prefs.getString("past_surgeries", "") ?: ""
        val medicalHistory = prefs.getString("medical_history", "") ?: ""
        val discontinuedMeds = prefs.getString("discontinued_meds", "") ?: ""

        findViewById<TextView>(R.id.tv_patient_name)?.text = patientName.uppercase()
        findViewById<TextView>(R.id.tv_blood_type)?.text = bloodType
        findViewById<TextView>(R.id.tv_demographics)?.text = demographics.uppercase()
        findViewById<TextView>(R.id.tv_health_id)?.text = healthId

        // Organ Donor Hero Badge
        val isDonor = organDonor.equals("YES", ignoreCase = true)
        val tvOrganDonor = findViewById<TextView>(R.id.tv_organ_donor)
        val tvDonorSubtitle = findViewById<TextView>(R.id.tv_donor_subtitle)
        tvOrganDonor?.text = if (isDonor) "YES" else "NO"
        tvOrganDonor?.setTextColor(if (isDonor) 0xFF059669.toInt() else 0xFF475569.toInt())
        tvDonorSubtitle?.text = if (isDonor) "REGISTERED DONOR" else "NOT REGISTERED"
        tvDonorSubtitle?.setTextColor(if (isDonor) 0xFF047857.toInt() else 0xFF94A3B8.toInt())

        // Priority 1: Allergies & Contraindications (High-Alert Warning)
        val tvAllergies = findViewById<TextView>(R.id.tv_allergies)
        val tvAllergiesWarning = findViewById<TextView>(R.id.tv_allergies_warning)
        val hasAllergies = !(allergies.isBlank() || allergies.contains("No known", ignoreCase = true))
        if (hasAllergies) {
            tvAllergies?.text = allergies
            tvAllergiesWarning?.visibility = View.VISIBLE
        } else {
            tvAllergies?.text = "NO KNOWN DRUG ALLERGIES (NKDA)"
            tvAllergiesWarning?.visibility = View.GONE
        }

        // Priority 2: Clinical Conditions, Surgeries & History
        val layoutClinical = findViewById<View>(R.id.layout_clinical_section)
        val layoutConditions = findViewById<View>(R.id.layout_conditions_section)
        val tvConditions = findViewById<TextView>(R.id.tv_conditions)
        val layoutSurgeries = findViewById<View>(R.id.layout_surgeries_section)
        val tvSurgeries = findViewById<TextView>(R.id.tv_surgeries)
        val layoutHistory = findViewById<View>(R.id.layout_history_section)
        val tvHistory = findViewById<TextView>(R.id.tv_history)

        val hasConditions = !(conditions.isBlank() || conditions.contains("No chronic", ignoreCase = true) || conditions.equals("None", ignoreCase = true))
        val hasSurgeries = !(pastSurgeries.isBlank() || pastSurgeries.contains("None recorded", ignoreCase = true))
        val hasHistory = !(medicalHistory.isBlank() || medicalHistory.contains("None recorded", ignoreCase = true))

        if (hasConditions || hasSurgeries || hasHistory) {
            layoutClinical?.visibility = View.VISIBLE

            if (hasConditions) {
                layoutConditions?.visibility = View.VISIBLE
                tvConditions?.text = conditions
            } else {
                layoutConditions?.visibility = View.GONE
            }

            if (hasSurgeries) {
                layoutSurgeries?.visibility = View.VISIBLE
                tvSurgeries?.text = pastSurgeries
            } else {
                layoutSurgeries?.visibility = View.GONE
            }

            if (hasHistory) {
                layoutHistory?.visibility = View.VISIBLE
                tvHistory?.text = medicalHistory
            } else {
                layoutHistory?.visibility = View.GONE
            }
        } else {
            // Keep container showing default if all empty
            layoutClinical?.visibility = View.VISIBLE
            layoutConditions?.visibility = View.VISIBLE
            tvConditions?.text = "No chronic conditions or past surgical history recorded."
            layoutSurgeries?.visibility = View.GONE
            layoutHistory?.visibility = View.GONE
        }

        // Priority 3: Medications
        val tvMedications = findViewById<TextView>(R.id.tv_medications)
        tvMedications?.text = medications

        // Priority 4: Discontinued High-Risk Medications
        val tvDiscontinued = findViewById<TextView>(R.id.tv_discontinued)
        val layoutDiscontinued = findViewById<View>(R.id.layout_discontinued_section)
        if (discontinuedMeds.isBlank()) {
            layoutDiscontinued?.visibility = View.GONE
        } else {
            layoutDiscontinued?.visibility = View.VISIBLE
            tvDiscontinued?.text = discontinuedMeds
        }

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
