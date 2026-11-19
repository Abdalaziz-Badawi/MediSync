# Changelog & Development Record

All notable developments, architectural transitions, clinical safety features, and engineering decisions for **MediSync** are recorded herein in clear, accessible detail.

---

## [1.6.0] - 2026-11-19

### Added
- **Calendar-Style Medication Discontinuation vs. Deletion Lifecycle**:
  - Implemented calendar-like discontinuation: when removing or stopping a medication, users are presented with two distinct choices:
    - *Discontinue from Today Forward (Recommended)*: Stops future scheduled doses and alarms starting today while preserving 100% of historical intake logs, taken dose entries, and adherence continuity records. Displays a `[Discontinued on DD MMM YYYY]` badge with an immediate "Resume Schedule" button.
    - *Delete Entire Medication & History*: Permanently purges the medication and all historical dose records from on-device storage.
  - Implemented across both `MedicationsListPage` and `MedicationDetailsPage`.
- **Duolingo-Inspired Adherence Streak Gamification**:
  - Added `StreakService` and `AdherenceStreakCard` on the home dashboard.
  - Features an active flaming fire counter 🔥, 7-day flame trail (Monday through Sunday), automatic PRN / rest-day shields, and 5 milestone trophies (🥉 3-Day Spark, 🥈 7-Day Habit Builder, 🥇 14-Day Routine Master, 🏆 30-Day Health Champion, 👑 100-Day Centurion Legend).
- **Native Phone Calendar Synchronization**:
  - Native Kotlin method channel in `MainActivity.kt` inserting recurring reminder events (`CalendarContract.Events` and `Reminders`) into Google Calendar or Samsung Calendar at exact scheduled dose times.
  - Added one-tap "Sync Schedule to Calendar" buttons in both the Home AppBar and Medication Details page.
- **Strict Date Locking & Visual Greying on Dose Timeline**:
  - Doses on future and past dates are visually dimmed (`Opacity: 0.62`), display `[🔒 Locked • Scheduled]` / `[🔒 Locked • History]` badges, and disable take actions with an informative lock toast.
- **Prominent Red Flagging for Allergy Triggers**:
  - Real-time cross-checking against `UserProfile.allergies` with high-visibility `🚩 RED FLAG: ALLERGY TRIGGER DETECTED` banners and glowing red borders across Medication Cards, Dose Timeline cards, Countdown Card, and Details Page.
- **Multi-Format Clinical Continuity Report Export**:
  - Export comprehensive patient intake and adherence records in 6 distinct formats: Plain Text (.txt), Markdown (.md), Web HTML (.html), Standard XML (.xml), Microsoft Word (.doc), and Printable PDF Layout (`@page { size: A4 }`).
  - Added interactive format picker bottom sheet in `RecordsPage` with instant preview, one-tap clipboard copy, and native Android share sheet (`ACTION_SEND`).
- **10 Curated Clinical Theme Palettes & Ambient Glow**:
  - Expanded `AppPalette` to 10 clinical palettes (+Midnight Sapphire, +Forest & Sage, +Crimson & Amber, +Nordic Titanium).
  - Added faint ambient glow shadow to AppBars (`Size.fromHeight(74)`).
- **Animated Splash Screen & Healthcare Logo**:
  - Redesigned `SplashScreen` with concentric ripple rings and an animated medical pulse cross logo.
- **Developer & About Section on Profile Page**:
  - Added collapsible card on `ProfilePage` introducing lead developer **Abdalaziz Adil Badawi Mohamed**, GitHub link (`https://github.com/Abdalaziz-Badawi/MediSync`), Terms of Use, Privacy Policy, and Architecture folder structure viewer.

### Fixed
- **Premature Single-Letter Allergy Warnings & Keyboard Dismissal**:
  - Enforced a minimum 3-character threshold and 350ms input debouncing in `AddEditMedicationPage`, preventing 1-letter keystrokes (e.g. "P" for Panadol) from triggering false positives and dismissing the soft keyboard.
- **Phantom Metformin Seeding**:
  - Removed auto-seeding of sample Metformin in `StorageService.seedInitialDataIfEmpty()`, ensuring fresh or cleared databases remain completely clean.
- **Modal Overflow at Scale 90%**:
  - Wrapped `_showStatusPicker` and report export modals in `SingleChildScrollView` with `isScrollControlled: true` to prevent bottom overflows on compact displays and large font scales.

---

## [1.5.0] - 2026-11-17

### Added
- **Intelligent Routine & Viable Schedule Recalculator (`AddEditMedicationPage`)**:
  - Added bottom sheet modal and quick-cycle button to explore viable alternative dose timings tailored to patient routines.
  - Automatically calculates up to 4 distinct clinical schedule proposals:
    - **Meal & Routine Synchronized**: Aligns intake with breakfast, lunch, or dinner depending on food requirements, stomach sensitivity, or empty-stomach absorption.
    - **Transit & Activity Safe**: Safeguards against administering sedating or dizziness-inducing medications during commute and driving intervals.
    - **Even Clinical Spacing**: Maintains equal pharmacological separation across waking hours.
    - **Symmetrical 12-Hour Cycle**: Standard 12-hour BID spacing (08:00 & 20:00) for twice-daily regimens.
- **Calendar & Activity Inference Engine (`RoutineInferenceEngine`)**:
  - Context-aware engine that reads device calendar events via native Android `MethodChannel` (`CalendarContract.Events`).
  - Infers patient wake times, bedtime, lunch/dinner times, and transit windows from calendar events and commute entries.
  - Falls back seamlessly to profile baseline routines when calendar access is not granted.
- **Expanded Clinical Drug Database & Allergy Taxonomy**:
  - Expanded `MedicinesDatabase` with 14 drug templates (Amlodipine, Losartan, Hydrochlorothiazide, Metoprolol, Simvastatin, Gabapentin, Sertraline, Escitalopram, Alprazolam, Prednisone, Empagliflozin, Esomeprazole, Ondansetron, Fluconazole) with comprehensive excipients, side effects, food restrictions, and conflict pairs.
  - Expanded `AllergyTaxonomyData` with 11 allergen categories (Tetracyclines, Aromatic Anticonvulsants, Local Anesthetics, Heparin, Tree Nuts, Corn Starch, Aspartame, Tartrazine, Chlorhexidine, Nickel, Photosensitivity).
- **Privacy-Preserving Verified Online Medical Monograph Link**:
  - Added dedicated clinical monograph lookup button on `MedicationDetailsPage`.
  - Opens verified medical monographs on Drugs.com / OpenFDA via native intent.
  - Strictly preserves 100% on-device privacy: only the public drug name is queried, with zero patient identifiers, logs, or personal health records transmitted.
- **Strict Date Locking on Dose Logging & Early Dose Handling**:
  - **Date Locking**: Restricted dose taking and editing to the current day. Future and past days in the daily horizontal strip are locked in read-only mode with informative date-lock banners.
  - **"Taken Early" Scenario**: Added `DoseStatus.takenEarly` to accommodate users who administer doses ahead of schedule, properly crediting adherence while preserving timeline accuracy.
  - **Countdown Card Isolation**: Next dose countdown card strictly tracks today's active doses and does not offer "Take" actions on tomorrow's medications.

---

## [1.4.0] - 2026-11-17

### Added
- **Medications List Filter & Real-Time Search**:
  - Added a real-time search field allowing users to instantly filter medications by name, dosage, or doctor notes.
  - Added horizontal filter chips for fast category narrowing: **All**, **Scheduled**, **As Needed (PRN)**, and **Safety Alerts**.
- **Medications List Multi-Criteria Sorting Engine**:
  - Added a sorting action menu with 4 distinct sorting criteria:
    - **Name (A → Z)**
    - **Name (Z → A)**
    - **Doses / Day (High → Low)**
    - **Form / Medication Type**
  - Remembers user selection and immediately re-orders the list with smooth transitions.
- **Batch Multi-Select & Safe Deletion**:
  - Added multi-selection mode accessible via the checklist icon in the AppBar or by long-pressing any medication card.
  - Added **"Select All"** (selects all visible filtered medications) and **"Select None"** quick group actions.
  - Added a dedicated batch **Delete** action with safety confirmation dialog displaying the names of selected medicines, preventing accidental loss while removing scheduled reminders and dose tracking cleanly.
- **"Today We're Done! ✓" Hero Completion Banner**:
  - When a user finishes all medication doses scheduled for today, the Next Dose hero area no longer displays tomorrow's medication as an active pending dose.
  - Displays a clean celebration card with a green checkmark indicating **"Today We're Done! ✓"** and confirms that all scheduled doses for the day have been fulfilled.
- **Tomorrow's Medications Schedule Summary**:
  - Integrated a clean summary view showing tomorrow's upcoming doses at a glance (time badges, medication names, dosages, and total count).

### Changed & Fixed
- **Conditional Visibility for "Not Needed" Dose Status**:
  - Fixed dose logging so that the **"Not Needed (As Needed / PRN)"** status option only appears if the medication's schedule frequency is configured as *As Needed* (PRN).
  - Regular scheduled medications (daily, weekly, monthly) now only display clinically appropriate intake options (*Taken On Time*, *Taken Delayed*, *Missed Window*, or *Reset to Pending*).

### Added
- **Smart Dynamic Multi-Dose Spacing Engine**:
  - When a user adjusts any scheduled dose time in the medication editor, remaining scheduled times are dynamically and automatically recalculated.
  - Spacing is distributed equally between sessions within the patient's personalized waking hours (from `wakeTime` to `sleepTime`).
  - Strict clinical guidelines are enforced for minimum separation between doses of the same medication (BID $\ge 6$h, TID $\ge 4$h, QID $\ge 3$h), rounding cleanly to 5-minute intervals.
  - Added an interactive **"Re-space Evenly"** quick action button with explanatory guidance.
- **Top Overall Continuity Dashboard (`RecordsPage`)**:
  - High-impact hero gradient card displaying aggregate patient adherence percentage.
  - Consecutive adherence streak counter (tracking unbroken daily medication adherence).
  - Four-metric continuity summary breakdown:
    - **Taken On Time**: doses administered within optimal therapeutic window.
    - **Delayed**: doses administered after scheduled window.
    - **Missed**: doses where administration window lapsed.
    - **Not Needed (PRN)**: as-needed doses where symptoms were absent.
- **Interactive Calendar Widget (`RecordsPage`)**:
  - Week-by-week calendar strip with forward/backward navigation and a "Today" quick-snap button.
  - Status indicator dots for each day:
    - 🟢 **Green**: all doses taken on time.
    - 🟡 **Amber**: delayed doses recorded.
    - 🔴 **Red**: missed doses recorded.
    - ⚪ **Grey**: not-needed / PRN doses.
  - Extendable Month View toggle for comprehensive monthly calendar navigation.
  - Selecting any date immediately refreshes and displays the detailed daily intake log below.
- **App-Wide Dynamic Theming for 6 Clinical Palettes**:
  - Selection of any palette (*Emerald Teal*, *Ocean Blue*, *Royal Indigo*, *Amethyst Violet*, *Sunset Coral*, *Rose Ruby*) dynamically recolors the entire application.
  - Theme changes instantly cascade to cards, 360° glow aura shadows, navigation bar tabs, Floating Action Buttons, chips, countdown badges, and indicators.
- **Device Health & Calendar Integration**:
  - Offline `.ics` calendar generation for local native calendar syncing.
  - Quick-launch link to Samsung Health / Health Connect.
- **On-Device Clinical Continuity Export**:
  - Call-to-action export generating unencrypted continuity reports for physician review.
  - Requires explicit on-device user consent, ensuring 100% confidentiality without cloud dependency.

### Fixed
- **Next Dose Countdown "Not Needed" Dose Resolution**:
  - Fixed a critical issue where doses marked as "Not Needed" (e.g. PRN medications when asymptomatic) were previously surfaced as overdue ("Due 4 hours ago").
  - `isDoseResolved` now recognizes `DoseStatus.notNeeded` as complete, excluding it from upcoming or overdue countdown cards.
  - Today's adherence progress bar and remaining dose counter now accurately reflect that not-needed doses require no further action.

---

## [1.2.0] - 2026-11-17

### Added
- **Floating Bottom Navigation Bar**:
  - Elevated capsule navigation bar with a 360-degree ambient glow aura matching the active palette.
  - Bottom scroll-depth cue hinting that scrollable content flows gracefully behind the bar.
- **Smart Clearance Floating Action Button (FAB)**:
  - Positioned on the Medications page with deliberate elevation clearance above the floating bottom bar.
- **Unified Master User Profile Card**:
  - Integrated Account Profile, Daily Routine, and Allergies into a cohesive collapsible card.
  - Custom Profile Picture (PFP) avatar selector with 6 distinctive icons.
  - Sneak-Peek Privacy Shield masking wake, sleep, and meal hours when in public spaces.
  - Collapsible User Settings & Preferences card featuring 145% font scale overflow protection.
- **Comprehensive Allergy Taxonomy**:
  - Expanded allergy coverage across 6 standardized categories:
    1. Drug / Medication Allergies
    2. Food Allergies
    3. Environmental Allergies
    4. Material & Contact Allergies
    5. Inactive Excipients & Additives
    6. Other / Custom Triggers
- **Interactive Swipe Actions on Dose Tiles**:
  - **Swipe Right**: instantly marks dose as Taken.
  - **Swipe Left**: opens detailed intake picker (Taken On Time, Delayed, Missed Window, Not Needed PRN).
- **Extended Scheduling Frequencies**:
  - Added support for *Monthly*, *Twice-Monthly* (1st & 15th), and *Every-X-Days* scheduling intervals.
- **Food Restriction Advisories & Drug-Drug Safety**:
  - Evidence-based food restriction warnings (e.g. grapefruit interactions, calcium chelation, empty stomach protocols).
  - Cross-referencing against clinical databases with critical alert banners.
- **Proprietary Medical Software License (`LICENSE.md`)**:
  - Public educational viewing license preserving full proprietary rights for Abdalaziz Adil Badawi Mohamed.

---

## [1.1.0] - 2026-11-16

### Added
- **Light & Dark Mode**: Full dual-theme palette with night-friendly dark mode (`ThemeMode.light`, `ThemeMode.dark`, `ThemeMode.system`) using Riverpod and Hive persistence.
- **Pre & Post Conditions First Workflow**: Re-ordered the medication creation flow so usage instructions and side-effects precede schedule times, enabling the clinical scheduler to produce studied time suggestions.
- **Studied Clinical Rationale Engine**: The smart scheduler outputs explicit medical justifications explaining why dose times are placed at specific hours relative to user routines (e.g. bedtime for drowsiness, post-meal for stomach protection, wake-up for empty stomach).
- **Offline Medical Database & Autocomplete**: Added `MedicinesDatabase` featuring 100+ common prescription and OTC medications (Panadol, Augmentin, Metformin, Lisinopril, Advil, Cipro, Zyrtec, etc.) with brand/generic names, forms, dosages, and allergen triggers.
- **Real-Time Allergy Cross-Checking**: Typing or selecting a medication automatically verifies cross-reactivity against the user's documented allergies with critical banners and doctor warnings.
- **First-Time Setup / Onboarding Wizard**: Step-by-step account initialization covering welcome, privacy promise, allergy selection, routine scheduling, and alarm verification.
- **Local Notification Engine**: Integrated `flutter_local_notifications` and `timezone` with high-priority notification channels, vibration, sound, and a one-tap on-device test button.
- **Live Next-Medication Countdown Card**: Prominent dashboard card displaying a live countdown to the next untaken dose, surrounding condition badges (`BEFORE`, `AFTER`, `CAUTION`), and a one-tap "Take" button.
- **Comprehensive Test Suite**: Unit and widget tests covering smart scheduling, database search, allergy flags, countdown card, profile, and onboarding wizard.

---

## [1.0.0] - 2026-11-13

### Added
- Initial Clean Architecture foundation with Riverpod and Hive NoSQL local storage.
- Core entities: `Medication`, `MedicationCondition`, `SideEffect`, `SafetyFlag`, and `UserProfile`.
- Smart scheduler engine (`SchedulerService`).
- Home dashboard with today's dose timeline and adherence progress ring.
- Medication CRUD operations and details overview screen.
- User profile page with routine hours and allergy manager.
