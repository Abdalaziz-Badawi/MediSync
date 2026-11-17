# Changelog & Development Record

All notable developments, architectural transitions, clinical safety features, and engineering decisions for **MediSync** are recorded herein in clear, accessible detail.

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
