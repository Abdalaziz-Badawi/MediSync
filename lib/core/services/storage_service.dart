import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/medication.dart';
import '../models/user_profile.dart';
import 'device_integration_service.dart';
import 'notification_service.dart';

const String kSettingsBoxName = 'settings_box';
const String kMedicationsBoxName = 'medications_box';
const String kProfileKey = 'user_profile';
const String kSetupCompletedKey = 'setup_completed';

class StorageService {
  late Box _settingsBox;
  late Box _medicationsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(kSettingsBoxName);
    _medicationsBox = await Hive.openBox(kMedicationsBoxName);
  }

  bool isSetupCompleted() {
    return _settingsBox.get(kSetupCompletedKey, defaultValue: false) as bool;
  }

  Future<void> setSetupCompleted(bool val) async {
    await _settingsBox.put(kSetupCompletedKey, val);
  }

  // User Profile
  UserProfile getUserProfile() {
    final raw = _settingsBox.get(kProfileKey);
    if (raw == null) {
      return const UserProfile(
        name: 'My Health Profile',
        allergies: ['Penicillin'], // Demo default that can be edited
        chronicConditions: [],
        wakeTime: '07:30',
        sleepTime: '23:00',
        breakfastTime: '08:30',
        lunchTime: '13:30',
        dinnerTime: '20:00',
      );
    }
    try {
      final map = jsonDecode(raw as String);
      return UserProfile.fromJson(map as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _settingsBox.put(kProfileKey, jsonEncode(profile.toJson()));
  }

  // Medications
  List<Medication> getMedications() {
    final list = <Medication>[];
    for (final key in _medicationsBox.keys) {
      final raw = _medicationsBox.get(key);
      if (raw != null) {
        try {
          final map = jsonDecode(raw as String);
          list.add(Medication.fromJson(map as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    return list;
  }

  Medication? getMedication(String id) {
    final raw = _medicationsBox.get(id);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw as String);
      return Medication.fromJson(map as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMedication(Medication medication) async {
    await _medicationsBox.put(medication.id, jsonEncode(medication.toJson()));
  }

  Future<void> deleteMedication(String id) async {
    await _medicationsBox.delete(id);
  }

  Future<void> discontinueMedication(
    String id, {
    DateTime? date,
    String? reason,
  }) async {
    final med = getMedication(id);
    if (med != null) {
      final updated = med.copyWith(
        discontinuedDate: date ?? DateTime.now(),
        discontinuationReason: reason ?? 'Discontinued by patient',
      );
      await saveMedication(updated);
    }
  }

  Future<void> resumeMedication(String id) async {
    final med = getMedication(id);
    if (med != null) {
      final updated = Medication(
        id: med.id,
        name: med.name,
        dosage: med.dosage,
        form: med.form,
        timesPerDay: med.timesPerDay,
        scheduledTimes: med.scheduledTimes,
        durationDays: med.durationDays,
        startDate: med.startDate,
        preConditions: med.preConditions,
        postConditions: med.postConditions,
        sideEffects: med.sideEffects,
        refillsRemaining: med.refillsRemaining,
        refillAlertThreshold: med.refillAlertThreshold,
        doctorNotes: med.doctorNotes,
        isVerified: med.isVerified,
        safetyFlags: med.safetyFlags,
        daysOfWeek: med.daysOfWeek,
        scheduleFrequency: med.scheduleFrequency,
        intervalDays: med.intervalDays,
        monthlyDays: med.monthlyDays,
        foodRestrictions: med.foodRestrictions,
        inactiveExcipients: med.inactiveExcipients,
        mealCondition: med.mealCondition,
        discontinuedDate: null,
        discontinuationReason: null,
        doseLog: med.doseLog,
      );
      await saveMedication(updated);
    }
  }

  // Does not auto-inject phantom medications. Remains clean on fresh startup.
  Future<void> seedInitialDataIfEmpty() async {
    // Left clean to prevent unwanted sample medications from appearing out of nowhere
  }
}

// Global Storage Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized in main');
});

// Profile Notifier
class ProfileNotifier extends StateNotifier<UserProfile> {
  final StorageService _storage;

  ProfileNotifier(this._storage) : super(_storage.getUserProfile());

  Future<void> updateProfile(UserProfile newProfile) async {
    state = newProfile;
    await _storage.saveUserProfile(newProfile);
  }
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ProfileNotifier(storage);
});

// Medications Notifier
class MedicationsNotifier extends StateNotifier<List<Medication>> {
  final StorageService _storage;
  final NotificationService? _notifications;

  MedicationsNotifier(this._storage, [this._notifications])
      : super(_storage.getMedications());

  Future<void> addOrUpdate(Medication med) async {
    await _storage.saveMedication(med);
    state = _storage.getMedications();
    final notifs = _notifications;
    if (notifs != null) {
      if (med.isDiscontinued) {
        await notifs.cancelMedicationReminders(med);
      } else {
        await notifs.scheduleMedicationReminders(med);
      }
    }
  }

  Future<void> remove(String id) async {
    final med = state.cast<Medication?>().firstWhere(
          (m) => m?.id == id,
          orElse: () => null,
        );
    await _storage.deleteMedication(id);
    state = _storage.getMedications();
    final notifs = _notifications;
    if (notifs != null && med != null) {
      await notifs.cancelMedicationReminders(med);
    }
    if (med != null) {
      try {
        await DeviceIntegrationService().removeCalendarEventsForMedication(med.name);
      } catch (_) {}
    }
  }

  Future<void> discontinue(String id, {DateTime? date, String? reason}) async {
    final med = state.cast<Medication?>().firstWhere(
          (m) => m?.id == id,
          orElse: () => null,
        );
    await _storage.discontinueMedication(id, date: date, reason: reason);
    state = _storage.getMedications();
    final notifs = _notifications;
    if (notifs != null && med != null) {
      await notifs.cancelMedicationReminders(med);
    }
    if (med != null) {
      try {
        await DeviceIntegrationService().removeCalendarEventsForMedication(med.name);
      } catch (_) {}
    }
  }

  Future<void> resume(String id) async {
    await _storage.resumeMedication(id);
    state = _storage.getMedications();
    final resumedMed = state.cast<Medication?>().firstWhere(
          (m) => m?.id == id,
          orElse: () => null,
        );
    final notifs = _notifications;
    if (notifs != null && resumedMed != null) {
      await notifs.scheduleMedicationReminders(resumedMed);
    }
  }

  Future<void> setDoseStatus(
    String medId,
    DateTime date,
    String time,
    DoseStatus status,
  ) async {
    final med = state.firstWhere((m) => m.id == medId);
    final dateKey =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final updatedMap = Map<String, List<String>>.from(med.doseLog);
    final entries = List<String>.from(updatedMap[dateKey] ?? []);

    // Remove any existing entry for this time slot
    entries.removeWhere((e) => e == time || e.startsWith('$time:'));

    switch (status) {
      case DoseStatus.pending:
        // Removed
        break;
      case DoseStatus.taken:
        entries.add('$time:taken');
        break;
      case DoseStatus.takenEarly:
        entries.add('$time:takenEarly');
        break;
      case DoseStatus.delayed:
        entries.add('$time:delayed');
        break;
      case DoseStatus.missed:
        entries.add('$time:missed');
        break;
      case DoseStatus.notNeeded:
        entries.add('$time:notNeeded');
        break;
    }

    if (entries.isEmpty) {
      updatedMap.remove(dateKey);
    } else {
      updatedMap[dateKey] = entries;
    }

    final updatedMed = med.copyWith(doseLog: updatedMap);
    await _storage.saveMedication(updatedMed);
    state = _storage.getMedications();
  }

  Future<void> toggleDoseTaken(String medId, DateTime date, String time) async {
    final med = state.firstWhere((m) => m.id == medId);
    final isTaken = med.isDoseTaken(date, time);
    await setDoseStatus(
      medId,
      date,
      time,
      isTaken ? DoseStatus.pending : DoseStatus.taken,
    );
  }
}

final medicationsNotifierProvider =
    StateNotifierProvider<MedicationsNotifier, List<Medication>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  NotificationService? notifications;
  try {
    notifications = ref.watch(notificationServiceProvider);
  } catch (_) {}
  return MedicationsNotifier(storage, notifications);
});
