# MediSync

[![Version](https://img.shields.io/badge/version-1.6.0-teal.svg)](pubspec.yaml)
[![License: Personal Use](https://img.shields.io/badge/license-Personal%20Use-blue.svg)](LICENSE)
[![Platform: Android](https://img.shields.io/badge/platform-Android-green.svg)](android)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg)](https://flutter.dev)
[![Architecture: Clean%20Feature--First](https://img.shields.io/badge/architecture-Clean%20Feature--First-purple.svg)](ARCHITECTURE.md)

**MediSync** is a clinical-grade, privacy-first personal medication management assistant designed to help patients safely track prescriptions, synchronize schedules with native device calendars, prevent adverse drug-allergy interactions, and gamify daily adherence streaks—with **100% on-device local storage and zero cloud tracking**.

---

## 🌟 Key Features (v1.6.0)

### 1. 🛡️ 100% On-Device Privacy Architecture
- **Zero Cloud Telemetry:** All prescriptions, dosages, intake timestamps, and health profiles are stored exclusively on your physical device hardware in encrypted Hive databases.
- **Privacy-Preserving Lookups:** External monograph queries search *only* generic medication names with zero personal identifiers.

### 2. 📅 Calendar-Style Medication Discontinuation vs. Full Purge
- **Discontinue from Today Forward (Recommended):** Like ending a recurring calendar event series, halts all future scheduled doses and alarms starting today while preserving 100% of historical intake logs, adherence rates, and doctor continuity records. Displays a `[Discontinued on DD MMM YYYY]` badge with a **Resume Schedule** action.
- **Delete Entire Medication & History:** Purges the medication and permanently deletes all historical records from local storage.

### 3. 🔥 Duolingo-Inspired Adherence Streak Gamification
- **Live Streak Tracking:** Active flaming fire counter 🔥 celebrating continuous medication adherence.
- **7-Day Flame Trail:** Visual weekly indicator (Mon–Sun) showing completed doses and rest days.
- **PRN / Rest Day Shields:** Automatically shields your streak on days when no regular scheduled medications were due.
- **5 Adherence Milestone Trophies:**
  - 🥉 **3-Day Spark:** Consistent first steps.
  - 🥈 **7-Day Habit Builder:** One full week of unbroken consistency.
  - 🥇 **14-Day Routine Master:** Two consecutive weeks of therapeutic plasma equilibrium.
  - 🏆 **30-Day Health Champion:** Full month of proactive adherence.
  - 👑 **100-Day Centurion Legend:** Complete medication mastery.

### 4. 📲 Native Phone Calendar Synchronization
- Injects recurring calendar reminder events (`CalendarContract.Events` and `Reminders`) into Google Calendar or Samsung Calendar at exact scheduled dose times with dosage, dietary rules, and pre/post conditions.
- Standard RFC 5545 iCalendar (`.ics`) export available offline.

### 5. 🔒 Strict Date-Locking & Greying on Dose Timeline
- Prevents logging future doses ahead of time.
- Future and past dates are visually dimmed (`Opacity: 0.62`) and display `[🔒 Locked • Scheduled]` / `[🔒 Locked • History]` badges.
- Tapping locked dose items shows an informative toast explaining that historical records are view-only and future doses cannot be recorded ahead of time.

### 6. 🚩 Prominent Red Flag Allergy Conflict Detection
- Dynamic clinical cross-checking against the patient's documented allergy profile (`UserProfile.allergies`).
- Displays high-visibility `🚩 RED FLAG: ALLERGY TRIGGER DETECTED` banners across Medication Cards, Dose Timeline Cards, Countdown Hero Card, and Details Page.
- Debounced (350ms) input with a 3-character threshold prevents premature single-letter false alarms while typing.

### 7. 📄 Multi-Format Clinical Continuity Report Export
- Export comprehensive patient intake and adherence records in **6 distinct formats**:
  - 📝 **Plain Text (.txt)**
  - 📋 **Markdown (.md)**
  - 🌐 **Web HTML (.html)**
  - 🏷️ **Standard XML (.xml)** (HL7 / EHR interoperability)
  - 📑 **Microsoft Word (.doc)**
  - 🖨️ **Printable PDF Layout** (`@page { size: A4 }`)
- One-tap clipboard copy and native Android share sheet (`ACTION_SEND`) to share directly with doctors or family via email, Drive, or messaging.

### 8. 🎨 10 Clinical Theme Palettes & Ambient Glow
- Soothing healthcare visual design with faint ambient AppBar glow shadow (`Size.fromHeight(74)`).
- **10 Curated Palettes:**
  - Emerald & Teal
  - Ocean & Cyan
  - Royal Indigo
  - Amethyst & Lilac
  - Sunset Coral
  - Rose & Ruby
  - Midnight Sapphire
  - Forest & Sage
  - Crimson & Amber
  - Nordic Titanium

### 9. 🚀 Animated Splash Screen
- Concentric ripple rings and animated medical pulse cross logo.

---

## 🏛️ Project Architecture

```
lib/
├── core/
│   ├── data/                 # Medical templates database (60+ clinical monographs)
│   ├── models/               # Medication, UserProfile, SafetyFlag, SideEffect, Condition
│   ├── services/             # StorageService (Hive), SchedulerService, RoutineInferenceService, StreakService, DeviceIntegrationService
│   ├── theme/                # AppTheme (10 palettes, soft & elevated shadow hierarchy)
│   └── widgets/              # Reusable healthcare feedback and UI components
├── features/
│   ├── homeboard/            # Today schedule, NextDoseCountdownCard, Duolingo AdherenceStreakCard, Dose Timeline
│   ├── medications/          # CRUD, calendar-style discontinuation, debounced allergy checks, search & filters
│   ├── onboarding/           # First-run clinical routine wizard
│   ├── profile/              # Routine setup, Health app sync, Developer About card, Terms, Privacy Policy
│   ├── records/              # Multi-format report export, calendar month viewer, adherence analytics
│   └── splash/               # Medical pulse cross logo animation
└── main.dart                 # Application entry point & Hive initialization
```

---

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK `^3.12.2` or later
- Android SDK 26+ (Tested on Samsung Galaxy S25 FE `SM-S731B` Android 14/15)

### Running Locally
```bash
git clone https://github.com/Abdalaziz-Badawi/MediSync.git
cd MediSync
flutter pub get
flutter run
```

### Running Tests
```bash
flutter test
```

---

## 👨‍💻 Developer & Authorship

- **Lead Software Engineer & Product Architect:** [Abdalaziz Adil Badawi Mohamed](https://github.com/Abdalaziz-Badawi)
- **Repository:** [https://github.com/Abdalaziz-Badawi/MediSync](https://github.com/Abdalaziz-Badawi/MediSync)
- **Email:** `Abdalaziz.02@proton.me`

---

## ⚖️ Legal & Medical Disclaimer

1. **Assistive Scheduling Tool:** MediSync is designed solely as an assistive scheduling and adherence tracking companion.
2. **Not Medical Advice:** MediSync does not provide clinical diagnosis, medical treatment prescriptions, or definitive pharmacology consultations. Always consult your licensed physician or pharmacist for medical decisions.
3. **On-Device Autonomy:** All records remain stored solely on your physical device hardware under your exclusive control.
