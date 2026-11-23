# MediSync

[![Version](https://img.shields.io/badge/version-1.8.15--gold-teal.svg)](pubspec.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/platform-Android-green.svg)](android)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg)](https://flutter.dev)
[![Architecture: Clean%20Feature--First](https://img.shields.io/badge/architecture-Clean%20Feature--First-purple.svg)](ARCHITECTURE.md)
[![Privacy: 100%20Offline](https://img.shields.io/badge/privacy-100%25%20Offline-success.svg)](INSTALLATION_GUIDE.md)

### 📥 Direct APK Download
Ready-to-install Android release package for immediate sideloading:
👉 **[Download MediSync v1.8.15 Release APK (medisync-v1.8.15-release.apk)](https://github.com/Abdalaziz-Badawi/MediSync/releases/download/v1.8.15/medisync-v1.8.15-release.apk)**

All historical and current releases are available on the [GitHub Releases Page](https://github.com/Abdalaziz-Badawi/MediSync/releases).

---

**MediSync** is an offline-first, clinical-grade medication management and emergency medical identity platform designed for patients, chronic care individuals, and first-responders. It combines intelligent routine-based scheduling, adverse drug-allergy conflict detection, multi-dose timing safeguards, and zero-PIN lock screen emergency access—with **100% on-device local storage and zero cloud telemetry**.

---

## 🌟 Core Clinical & System Capabilities (v1.8.11 Production Gold)

### 1. 🛡️ 100% On-Device Confidentiality & Zero Telemetry
- **Hardware-Isolated Storage:** All prescription schedules, intake timestamps, clinical conditions, blood groups, and demographic records are stored solely in local encrypted Hive databases on the device.
- **Zero Network Leaks:** No remote analytics, no cloud tracking, and no external servers. 
- **Privacy-Preserving Monograph Lookups:** External monograph queries search *only* the generic drug name with zero patient identifiers attached.

### 2. 🚨 Zero-PIN Emergency Medical ID & Lock Screen Triage
- **Squarish High-Res Vector Card:** Renders a 300 DPI (1000x1050) squarish emergency medical card featuring blood group transfusion vitals, organ donor status, active prescriptions, allergies, and emergency contacts.
- **Persistent Keyguard Notification:** Displays real-time vitals, blood type, and next dose countdown on the lock screen with a 1-tap emergency view button.
- **Lock Screen Bypass Overlay (`EmergencyCardActivity`):** Launches directly over the lock screen without requiring PIN or fingerprint entry (`FLAG_SHOW_WHEN_LOCKED` and `FLAG_TURN_SCREEN_ON`).
- **Samsung Quick Settings Shade Tile (`MediSyncTileService`):** Pull-down notification shade tile allows any bystander or paramedic to view medical ID instantly.
- **Samsung One UI & Android AppWidgets:** Dual widget support (`home|lockAndAod`) compatible with standard home screens and Samsung **Good Lock (LockStar)**.

### 3. ⏱️ Clinical Timing Safeguards & Early/Late Dose Evaluation
- **Early Dose Reminder:** Prompted if taking medication more than 45 minutes early, displaying the exact time remaining and asking to confirm or wait.
- **Delayed Intake Logging:** Evaluates delayed intake, distinguishing between doses taken just now versus previously taken and logged retroactively.
- **Conflicting Window Alerts:** Detects when a delayed dose encroaches on the subsequent scheduled dose window, preventing hazardous double-dosing.
- **As-Needed (PRN) Settled State:** Once taken, as-needed medications are visually settled and greyed-out to prevent unintentional overmedication.
- **PRN Repeat Dose Safety Warning:** Tapping a settled PRN card prompts an alert detailing the previous dose timestamp, spacing rules (4-6h), and verifying persistent symptoms before logging additional doses.
- **Daily Safe Limits:** Strict daily dosage caps prevent exceeding maximum 24-hour limits.
- **Evening Review Banner:** Prompts an end-of-day check (after 17:00) for unlogged PRN medicines to record symptom-free days.

### 4. 📄 Multi-Format Clinical Continuity Record Sharing
- Export comprehensive patient history in verified file formats:
  - 🖨️ **Printable PDF (.pdf):** Multi-page clinical document with hospital-grade headers, tabular medication lists, and attending clinician sign-off line.
  - 📋 **Markdown (.md):** File attachment for digital health vaults, Notion, or Obsidian.
  - 📝 **Plain Text (.txt):** Clean universal text document attachment for clinic sharing.
  - 📋 **Copy Text:** Quick clipboard copy for instant pasting.
- FileProvider integration ensures seamless sharing via WhatsApp, Gmail, Drive, or Bluetooth.

### 5. ⚠️ Drug-Drug Interaction & Red Flag Allergy Engine
- **Debounced Allergy Screening:** 3-character threshold with 350ms debounce prevents premature 1-letter false alarms while accurately flagging true allergen conflicts (e.g., Penicillin, Sulfa, Aspirin).
- **Drug-Drug Interaction Matrix:** Proactively screens dangerous pairs (e.g., NSAID + Anticoagulant hemorrhage risk, Fluoroquinolone + multivalent cation chelation spacing).
- **Dietary & Food Restrictions:** Prompts critical food advisories (e.g., empty stomach requirements, avoiding grapefruit with statins, milk separation with tetracyclines).

### 6. 📅 Native Phone Calendar Synchronization
- Injects recurring dose reminders directly into Google Calendar or Samsung Calendar (`CalendarContract.Events`) with complete dosage instructions, physician notes, and native alarms.
- Discontinuing or updating a medication automatically purges and resynchronizes associated calendar events cleanly.

### 7. 🔥 Duolingo-Inspired Adherence Streak Gamification
- **Live Fire Counter:** Flaming fire streak celebrating daily medication compliance.
- **7-Day Flame Trail:** Visual weekly indicator (Mon–Sun) tracking adherence consistency.
- **Rest Day & PRN Shields:** Automatically shields streaks on days when no scheduled medications were due.
- **5 Milestone Trophies:** 3-Day Spark, 7-Day Habit Builder, 14-Day Routine Master, 30-Day Health Champion, and 100-Day Centurion Legend.

### 8. 🎨 10 Clinical Theme Palettes & Dynamic Typography
- 10 healthcare color palettes (Emerald, Sapphire, Indigo, Titanium, etc.) with soft ambient glow and elevation shadows.
- Dynamic font scaling (0.85x – 1.30x) with zero layout overflow on narrow viewports (down to 320px).

---

## 🏛️ Project Directory Structure

```
lib/
├── core/
│   ├── data/                 # Clinical monographs database (60+ drug monographs)
│   ├── models/               # Medication, UserProfile, ClinicalCondition, SafetyFlag, NecessityLevel
│   ├── services/             # StorageService (Hive), SchedulerService, StreakService, DeviceIntegrationService
│   ├── theme/                # AppTheme (10 clinical palettes, soft shadows, font scaling)
│   └── widgets/              # Common UI widgets (emergency cards, status badges, chips)
├── features/
│   ├── navigation/           # MainNavigationPage (bottom navigation tab host)
│   ├── today/                # Today schedule, timeline cards, PRN settled view, next dose countdown
│   ├── medications/          # Medication CRUD, discontinuation archive, allergy/DDI warnings
│   ├── onboarding/           # First-run clinical routine setup wizard
│   ├── profile/              # Daily routine schedule, Emergency ID, Samsung Health, calendar sync, About
│   ├── records/              # Clinical continuity export (PDF, MD, TXT), interactive calendar
│   └── splash/               # Medical pulse brand logo animation
└── main.dart                 # Application entry point, Hive initialization & deep links
```

---

## 📱 Installation & Deployment

See the complete [Installation Guide](INSTALLATION_GUIDE.md) for step-by-step instructions:
- Sideloading the signed release APK (`build/app/outputs/flutter-apk/app-release.apk`)
- Deploying via ADB: `adb install -r -d build/app/outputs/flutter-apk/app-release.apk`
- Setting up the Samsung Quick Settings Tile & Good Lock (LockStar) widgets.

---

## 🗺️ Future Roadmap & Technical Backlog

See the comprehensive **[Engineering Roadmap & Technical TODO Specification](TODO.md)** for detailed implementation breakdowns, difficulty scores, and time estimates for future milestones:
- **TODO-01:** Factory Reset & "Burn / Wipe" Data Function (Total User Sovereignty)
- **TODO-02:** Multi-Language Support (Arabic RTL, English, Spanish, French, Hindi)
- **TODO-03:** Lock Screen Glance & Under-Clock Live Widgets
- **TODO-04:** Edge Panel & Dynamic Quick Settings Tile Service
- **TODO-05:** UI/UX Visual Polish & OLED True-Black Theme ("Improving Your Eye")
- **TODO-06:** Exhaustive QA/QC Pipeline (Doze Mode, Timezone Shifts, Drug Fuzzing)

---

## 🛠️ Verification & Test Suite

```powershell
# Run Dart static analysis (0 warnings, 0 errors)
flutter analyze --no-pub

# Run complete automated test suite (65 passing unit and widget tests)
flutter test --no-pub

# Build production release APK
flutter build apk --release --no-pub
```

---

## 👨‍💻 Author & Contact

**Abdalaziz Adil Badawi Mohamed**  
- ✉️ Email: [abdalaziz.02@proton.me](mailto:abdalaziz.02@proton.me)  
- 🐙 GitHub: [@Abdalaziz-Badawi](https://github.com/Abdalaziz-Badawi)  
- 📦 Repository: [MediSync](https://github.com/Abdalaziz-Badawi/MediSync)  

---

## 📜 License & Attributions

Copyright © 2026 **Abdalaziz Adil Badawi Mohamed**. All rights reserved.  
Licensed under the **MIT License**.
