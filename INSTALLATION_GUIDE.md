# MediSync v1.8.15 — Installation & Deployment Guide

Welcome to the definitive deployment and installation guide for **MediSync** (Production Release `v1.8.15+34`).

### 📥 1-Click Direct Download
👉 **[Download MediSync v1.8.15 Release APK (medisync-v1.8.15-release.apk)](https://github.com/Abdalaziz-Badawi/MediSync/releases/download/v1.8.15/medisync-v1.8.15-release.apk)**

---

## 📱 System Requirements

- **Operating System:** Android 8.0 (Oreo / API Level 26) or higher. Fully optimized for Android 14 and Android 15 / Samsung One UI 6.1 & One UI 7.0.
- **Hardware Target Tested:** Samsung Galaxy S25 FE (Exynos 2400e / Snapdragon 8 Gen 3 series), Google Pixel 7/8/9, and standard Android devices.
- **Storage:** Minimum 50 MB free space.
- **Network:** Zero internet connectivity required. 100% offline-first.

---

## 🚀 Installation Methods

### Method 1: Sideloading the Release APK Directly on Your Phone (Recommended)

1. **Download the APK:**
   - Tap the download link above or download from the [GitHub Releases](https://github.com/Abdalaziz-Badawi/MediSync/releases).
   - Alternatively, locate the compiled APK in your workspace:
     `build/app/outputs/flutter-apk/medisync-v1.8.15-release.apk` (or `app-release.apk`).
2. **Install the APK:**
   - Open your browser's downloaded files or tap the APK in **My Files** / **Files**.
   - If prompted with *"Install unknown apps"*, toggle **Allow from this source**.
   - Tap **Install** (or **Update** if updating).
   - Tap **Open** to launch MediSync.

---

### Method 2: Fast Deployment via ADB (Android Debug Bridge)

If your device is connected to your PC with USB Debugging enabled:

1. **Verify device connection:**
   ```powershell
   adb devices
   ```
   *(Ensure your device appears with the `device` status).*

2. **Install or update the release APK:**
   ```powershell
   adb install -r -d build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Launch the application:**
   ```powershell
   adb shell am start -n com.example.medisync/.MainActivity
   ```

---

## 🛡️ Samsung One UI Lock Screen & First-Responder Integration

MediSync is engineered with three zero-PIN emergency access vectors to ensure paramedics and ER physicians can access vital medical ID information even when the phone is locked.

### 1. Zero-PIN Persistent Keyguard Notification
- When enabled in the app, MediSync posts a persistent, high-priority notification to your lock screen.
- **Lockscreen View:** Displays patient blood group, critical allergy warnings, and next dose countdown.
- **1-Tap Triage:** Tapping the notification immediately displays the full-screen Emergency Medical ID over the lock screen without requiring PIN or fingerprint entry (`FLAG_SHOW_WHEN_LOCKED`).

### 2. Samsung Quick Settings Shade Tile
1. Swipe down twice from the top of your phone screen to expand the full **Quick Settings Shade**.
2. Tap the **Edit** (pencil or three-dots menu) button, then tap **Edit Tiles**.
3. Locate **MediSync Emergency ID** under Available Tiles.
4. Drag it into your active top tiles and tap **Done**.
5. **Emergency Usage:** Anyone can pull down the shade on your lock screen and tap this tile to instantly display your Emergency Health Card without unlocking the device.

### 3. Placing MediSync Widgets on Samsung One UI Lock Screen (Good Lock / LockStar)
- **Why Good Lock?** Samsung One UI 6.1 / One UI 7 restricts the default "under-the-clock" lock screen widget slot strictly to Samsung's first-party apps (Samsung Health, Clock, Calendar, Weather).
- **Official Solution:** Samsung provides **Good Lock** on the **Galaxy Store**:
  1. Open the **Galaxy Store** on your Samsung phone.
  2. Search for and install **Good Lock**.
  3. Inside Good Lock, open the **Make Up** tab and install the **LockStar** module.
  4. Enable LockStar, tap **Edit Lock Screen**, tap **Add Widget**, and choose **MediSync Emergency ID** or **MediSync Quick Launch**.
  5. Position the widget anywhere on your lock screen or Always On Display (AOD) and tap **Save**.

### 4. Home Screen AppWidgets
1. Long-press any empty space on your home screen and tap **Widgets**.
2. Scroll to **MediSync**.
3. Choose either:
   - **Emergency ID & Dose Status** (2x1 widget with live countdown and blood group).
   - **MediSync Quick Launch** (1x1 red cross button for instant emergency triage).
4. Drag the widget to your desired home screen location.

---

## ⚙️ Initial Configuration & Daily Routine Setup

1. **First-Run Setup Wizard:**
   - Set your name, Date of Birth (DoB), Blood Group, and emergency contact.
   - Enter your personal daily schedule:
     - 🌅 Wake Up Time (e.g., `07:30`)
     - 🍳 Breakfast Time (e.g., `08:30`)
     - 🥗 Lunch Time (e.g., `13:00`)
     - 🍲 Dinner Time (e.g., `19:30`)
     - 🌙 Sleep Time (e.g., `23:00`)
2. **Add Your Prescriptions:**
   - Tap the floating `+` button on the Medications screen.
   - Search the 60+ clinical drug monographs (e.g., *Panadol, Amoxicillin, Atorvastatin, Lisinopril, Metformin*).
   - Specify dosage, frequency, food restrictions, and necessity tier (Life-Critical, Essential, Maintenance, Symptom Relief).
   - Automatic debounced allergy checking cross-references the drug name against your documented allergy profile.
3. **Synchronize with Phone Calendar (Optional):**
   - On the Profile screen, tap **Sync Medications to Calendar**.
   - MediSync writes recurring dose reminders directly into Google Calendar or Samsung Calendar (`CalendarContract.Events`) with detailed dosage instructions and alarms.

---

## 📄 Clinical Continuity Record Export

To export your complete medication history and adherence record for your physician:
1. Navigate to the **Records** tab.
2. Tap **Export Clinical Record**.
3. Choose your desired format:
   - **Printable PDF (.pdf):** Verified multi-page clinical document with formal header, tabular schedule, and physician sign-off line.
   - **Markdown (.md):** File attachment for digital health vaults, Notion, or Obsidian.
   - **Plain Text (.txt):** Universal text file attachment for SMS, WhatsApp, or email.
   - **Copy Text:** Instant clipboard copy.
4. Tap **Share** to launch the Android share sheet and transmit directly to your doctor, clinic, or cloud backup.

---

## 🔧 Building from Source

To compile and verify MediSync from source:

```powershell
# 1. Clone repository
git clone https://github.com/Abdalaziz-Badawi/MediSync.git
cd MediSync

# 2. Run static analysis (must report zero issues)
flutter analyze --no-pub

# 3. Run all unit and widget tests (65 tests)
flutter test --no-pub

# 4. Build release APK
flutter build apk --release --no-pub

# 5. Output binary location
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔒 Security & Privacy Guarantee

- **100% Offline-First:** MediSync includes zero remote API calls, zero analytics SDKs, and zero cloud synchronization servers.
- **Local Hive Storage:** All patient data, dosage logs, and allergy profiles are stored strictly within sandboxed application storage on the local device hardware.
- **User Ownership:** Exporting or deleting data is 100% manual and under the patient's exclusive control.
