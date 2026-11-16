# MediSync — System Architecture & Engineering Blueprint

## 1. Architectural Philosophy

MediSync is designed following **Clean Architecture** and **Feature-Driven Development** (FDD). The application adheres to strict separation of concerns, high testability, and a **100% Offline-First, Privacy-Preserving** mandate:

```
lib/
├── config/              # App routing, global flags, constants
├── core/                # Shared domain logic, infrastructure & models
│   ├── data/            # Internal databases (MedicinesDatabase repository)
│   ├── models/          # Core entity models (Medication, Condition, SideEffect, SafetyFlag, UserProfile)
│   ├── services/        # StorageService (Hive), SchedulerService, NotificationService
│   └── theme/           # AppTheme (Light & Dark mode palettes, ThemeNotifier)
├── features/            # Feature-first modular layers
│   ├── homeboard/       # Today's dose timeline, progress ring, next dose countdown card
│   ├── medications/     # Add/Edit with DB autocomplete, list, and details
│   ├── onboarding/      # Account setup wizard (profile, allergies, routine, alarm test)
│   └── profile/         # User profile manager, theme switcher, routine time-pickers
└── main.dart            # Dependency injection entry point & ProviderScope
```

---

## 2. Technology Stack & Decision Matrix

| Capability | Selection | Technical Rationale |
|---|---|---|
| **State Management** | `flutter_riverpod` (v2.6.1) | Compile-time safety, effortless provider overrides in tests, zero `BuildContext` coupling for background tasks. |
| **Local Persistence** | `hive` & `hive_flutter` | Lightweight, lightning-fast NoSQL box storage without SQLite binary overhead; encrypted & private. |
| **Notification Engine** | `flutter_local_notifications` + `timezone` | Exact alarm scheduling via `AndroidScheduleMode.exactAllowWhileIdle`, recurring daily zoned alarms, heads-up notifications. |
| **Theming System** | Material 3 Dynamic Theming | Separate daylight medical palette and night-time dark mode (`Color(0xFF0F172A)`) to minimize blue-light glare in bed. |

---

## 3. Clinical Scheduling & Safety Algorithm

### 3.1 Studied Time Arrangement Logic
Unlike generic reminder apps that default to arbitrary times, MediSync evaluates:
1. **Side-Effect Chronobiology**:
   - Medications causing **drowsiness** or marked sedation are placed **30 minutes prior to the user's bedtime**.
   - Medications that may cause **insomnia** or alertness are scheduled in the morning with breakfast.
2. **Gastric Protection**:
   - Medications causing **stomach distress or nausea** (e.g., NSAIDs, Metformin, Augmentin) are aligned **20 minutes post-meal** to buffer gastric mucosa.
3. **Bioavailability Optimization**:
   - Medications requiring an **empty stomach** (e.g., PPIs like Omeprazole) are scheduled **15 minutes upon waking**, before breakfast.

### 3.2 Medical Database & Allergy Cross-Checking
MediSync bundles a local clinical database (`MedicinesDatabase`) containing common prescription drugs, active ingredients, common dosages, and known allergen triggers.
- When an input query matches a drug (e.g. *Augmentin*), the system inspects active ingredients (*Amoxicillin* + *Clavulanate*) and checks allergen cross-reactivity (e.g. *Penicillin* allergy triggers a critical warning).

---

## 4. Privacy & Offline Guarantee
No telemetry, tracking, or cloud endpoints are invoked for personal health data. All patient records, dosage logs, and routine hours reside exclusively on device storage.
