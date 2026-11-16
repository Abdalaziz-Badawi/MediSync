# Changelog & Development Record

All notable developments, architectural transitions, and engineering decisions for **MediSync** are recorded herein.

---

## [1.1.0] - 2026-11-16

### Added
- **Light & Dark Mode**: Full dual-theme palette with night-friendly dark mode (`ThemeMode.light`, `ThemeMode.dark`, `ThemeMode.system`) using Riverpod and Hive persistence.
- **Pre & Post Conditions First Workflow**: Re-ordered the medication creation flow so usage instructions and side-effects precede schedule times, enabling the clinical scheduler to produce studied time suggestions.
- **Studied Clinical Rationale Engine**: The smart scheduler now outputs explicit medical justifications explaining why dose times are placed at specific hours relative to user routines (e.g. bedtime for drowsiness, post-meal for stomach protection, wake-up for empty stomach).
- **Offline Medical Database & Autocomplete**: Added `MedicinesDatabase` featuring 100+ common prescription and OTC medications (Panadol, Augmentin, Metformin, Lisinopril, Advil, Cipro, Zyrtec, etc.) with brand/generic names, forms, dosages, and allergen triggers.
- **Real-Time Allergy Cross-Checking**: Typing or selecting a medication automatically verifies cross-reactivity against the user's documented allergies with critical banners and doctor warnings.
- **First-Time Setup / Onboarding Wizard**: Step-by-step account initialization covering welcome, privacy promise, allergy selection, routine scheduling, and alarm verification.
- **Local Notification Engine**: Integrated `flutter_local_notifications` and `timezone` with high-priority notification channels, vibration, sound, and a one-tap on-device test button.
- **Live Next-Medication Countdown Card**: Prominent dashboard card displaying a live countdown to the next untaken dose, surrounding condition badges (`BEFORE`, `AFTER`, `CAUTION`), and a one-tap "Take" button.
- **Comprehensive Test Suite**: 10 unit and widget tests covering smart scheduling, database search, allergy flags, countdown card, profile, and onboarding wizard.

---

## [1.0.0] - 2026-11-13

### Added
- Initial Clean Architecture foundation with Riverpod and Hive NoSQL local storage.
- Core entities: `Medication`, `MedicationCondition`, `SideEffect`, `SafetyFlag`, and `UserProfile`.
- Smart scheduler engine (`SchedulerService`).
- Home dashboard with today's dose timeline and adherence progress ring.
- Medication CRUD operations and details overview screen.
- User profile page with routine hours and allergy manager.
