package com.example.medisync

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class EmergencyCardActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure activity displays over Android / Samsung Keyguard without PIN entry
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        setContentView(R.layout.activity_emergency_card)

        val prefs = getSharedPreferences(MediSyncWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        val patientName = prefs.getString(MediSyncWidgetProvider.KEY_PATIENT_NAME, "MediSync Patient") ?: "MediSync Patient"
        val bloodType = prefs.getString(MediSyncWidgetProvider.KEY_BLOOD_TYPE, "Unknown") ?: "Unknown"
        val healthId = prefs.getString("health_id", "Not Provided") ?: "Not Provided"
        val demographics = prefs.getString("demographics", "Age: Not recorded • Gender: Not recorded") ?: "Age: Not recorded • Gender: Not recorded"
        val allergies = prefs.getString("allergies", "No known drug or environmental allergies recorded.") ?: "No known drug or environmental allergies recorded."
        val conditions = prefs.getString("conditions", "No chronic conditions or organ risks recorded.") ?: "No chronic conditions or organ risks recorded."
        val medications = prefs.getString("medications", "No active regular medications recorded.") ?: "No active regular medications recorded."

        findViewById<TextView>(R.id.tv_patient_name)?.text = patientName
        findViewById<TextView>(R.id.tv_blood_type)?.text = "BLOOD: $bloodType"
        findViewById<TextView>(R.id.tv_demographics)?.text = demographics
        findViewById<TextView>(R.id.tv_health_id)?.text = healthId
        findViewById<TextView>(R.id.tv_allergies)?.text = allergies
        findViewById<TextView>(R.id.tv_conditions)?.text = conditions
        findViewById<TextView>(R.id.tv_medications)?.text = medications

        findViewById<Button>(R.id.btn_close)?.setOnClickListener {
            finish()
        }

        findViewById<Button>(R.id.btn_call_emergency)?.setOnClickListener {
            try {
                val dialIntent = Intent(Intent.ACTION_DIAL).apply {
                    data = Uri.parse("tel:112")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(dialIntent)
            } catch (_: Exception) {}
        }

        findViewById<Button>(R.id.btn_open_app)?.setOnClickListener {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val km = getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
                km?.requestDismissKeyguard(this, null)
            }
            val mainIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(mainIntent)
            finish()
        }
    }
}
