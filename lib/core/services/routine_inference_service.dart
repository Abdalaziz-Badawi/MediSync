import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

class TimeWindow {
  final int startMinutes; // Minutes from 00:00 (0..1439)
  final int endMinutes;
  final String label;
  final bool isDrivingOrTransit;

  const TimeWindow({
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
    this.isDrivingOrTransit = false,
  });

  String get startTimeFormatted => _formatMinutes(startMinutes);
  String get endTimeFormatted => _formatMinutes(endMinutes);

  bool overlaps(int timeMinutes, {int bufferMinutes = 0}) {
    final start = startMinutes - bufferMinutes;
    final end = endMinutes + bufferMinutes;
    return timeMinutes >= start && timeMinutes <= end;
  }

  static String _formatMinutes(int mins) {
    final h = (mins ~/ 60) % 24;
    final m = mins % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class InferredRoutine {
  final String wakeTime;
  final String sleepTime;
  final String breakfastTime;
  final String lunchTime;
  final String dinnerTime;
  final List<TimeWindow> transitWindows;
  final List<TimeWindow> busyWindows;
  final String source;
  final List<String> inferenceNotes;

  const InferredRoutine({
    required this.wakeTime,
    required this.sleepTime,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    this.transitWindows = const [],
    this.busyWindows = const [],
    required this.source,
    this.inferenceNotes = const [],
  });

  bool isDuringTransit(int timeMinutes, {int bufferMinutes = 15}) {
    for (final tw in transitWindows) {
      if (tw.overlaps(timeMinutes, bufferMinutes: bufferMinutes)) {
        return true;
      }
    }
    return false;
  }
}

final routineInferenceServiceProvider = Provider<RoutineInferenceEngine>((ref) {
  return RoutineInferenceEngine();
});

class RoutineInferenceEngine {
  /// Infers patient daily routine from calendar events or profile baseline.
  InferredRoutine inferRoutine({
    required UserProfile profile,
    List<Map<String, dynamic>> calendarEvents = const [],
  }) {
    if (calendarEvents.isEmpty) {
      return _buildProfileBaseline(profile);
    }

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final transitList = <TimeWindow>[];
      final busyList = <TimeWindow>[];
      final notes = <String>[];

      int? earliestEventStartMins;
      int? latestEventEndMins;
      int? detectedLunchMins;
      int? detectedDinnerMins;

      for (final event in calendarEvents) {
        final startMillis = event['dtStart'] as int?;
        final endMillis = event['dtEnd'] as int?;
        final title = ((event['title'] as String?) ?? '').toLowerCase();
        final desc = ((event['description'] as String?) ?? '').toLowerCase();
        final loc = ((event['location'] as String?) ?? '').toLowerCase();

        if (startMillis == null) continue;
        final startDt = DateTime.fromMillisecondsSinceEpoch(startMillis);
        final endDt = endMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(endMillis)
            : startDt.add(const Duration(minutes: 60));

        // Skip all-day events (>= 20 hours)
        if (endDt.difference(startDt).inHours >= 20) continue;

        // Check if event is relevant for today / active window
        if (startDt.isBefore(todayStart.subtract(const Duration(hours: 4))) ||
            startDt.isAfter(todayEnd.add(const Duration(hours: 4)))) {
          continue;
        }

        final startMins = startDt.hour * 60 + startDt.minute;
        final endMins = endDt.hour * 60 + endDt.minute;

        // Update earliest and latest bounds
        if (startMins >= 300) { // After 5:00 AM
          if (earliestEventStartMins == null || startMins < earliestEventStartMins) {
            earliestEventStartMins = startMins;
          }
        }
        if (latestEventEndMins == null || endMins > latestEventEndMins) {
          latestEventEndMins = endMins;
        }

        final combinedText = '$title $desc $loc';

        // Detect Driving / Transportation
        final isTransit = _isTransitRelated(combinedText);
        if (isTransit) {
          transitList.add(TimeWindow(
            startMinutes: startMins,
            endMinutes: endMins,
            label: event['title'] ?? 'Commute / Transit',
            isDrivingOrTransit: true,
          ));
        } else {
          busyList.add(TimeWindow(
            startMinutes: startMins,
            endMinutes: endMins,
            label: event['title'] ?? 'Scheduled Commitment',
            isDrivingOrTransit: false,
          ));
        }

        // Detect Meals
        if (combinedText.contains('lunch') || combinedText.contains('brunch')) {
          detectedLunchMins = startMins;
        } else if (combinedText.contains('dinner') || combinedText.contains('supper')) {
          detectedDinnerMins = startMins;
        }
      }

      // Infer Wake Time
      String wakeTime = profile.wakeTime;
      if (earliestEventStartMins != null) {
        // Person typically wakes 75-90 minutes before earliest morning event
        final inferredWakeMins = (earliestEventStartMins - 75).clamp(300, 600); // 5:00 AM to 10:00 AM
        wakeTime = _formatMinutes(inferredWakeMins);
        notes.add('Inferred wake time ($wakeTime) from early calendar event at ${_formatMinutes(earliestEventStartMins)}.');
      }

      // Infer Sleep Time
      String sleepTime = profile.sleepTime;
      if (latestEventEndMins != null && latestEventEndMins >= 1140) { // After 7:00 PM
        // Person typically winds down and sleeps 75-90 mins after latest evening event
        final inferredSleepMins = (latestEventEndMins + 75).clamp(1260, 1439); // 9:00 PM to 11:59 PM
        sleepTime = _formatMinutes(inferredSleepMins);
        notes.add('Inferred sleep time ($sleepTime) accommodating evening schedule ending at ${_formatMinutes(latestEventEndMins)}.');
      }

      // Infer Meals
      String breakfastTime = profile.breakfastTime;
      final wakeMins = _parseMinutes(wakeTime);
      final breakfastMins = (wakeMins + 45).clamp(360, 630);
      breakfastTime = _formatMinutes(breakfastMins);

      String lunchTime = detectedLunchMins != null
          ? _formatMinutes(detectedLunchMins)
          : profile.lunchTime;
      String dinnerTime = detectedDinnerMins != null
          ? _formatMinutes(detectedDinnerMins)
          : profile.dinnerTime;

      if (transitList.isNotEmpty) {
        notes.add('${transitList.length} transit/driving window(s) detected: sedating doses will avoid these intervals.');
      }

      return InferredRoutine(
        wakeTime: wakeTime,
        sleepTime: sleepTime,
        breakfastTime: breakfastTime,
        lunchTime: lunchTime,
        dinnerTime: dinnerTime,
        transitWindows: transitList,
        busyWindows: busyList,
        source: 'Calendar & Event Adaptive Inference',
        inferenceNotes: notes,
      );
    } catch (_) {
      return _buildProfileBaseline(profile);
    }
  }

  InferredRoutine _buildProfileBaseline(UserProfile profile) {
    final wakeMins = _parseMinutes(profile.wakeTime);

    // Heuristic standard transit intervals: morning commute & evening commute
    final morningTransitStart = wakeMins + 45;
    final morningTransitEnd = wakeMins + 90;

    final eveningTransitStart = 1050; // 17:30
    final eveningTransitEnd = 1110;   // 18:30

    final transitWindows = [
      TimeWindow(
        startMinutes: morningTransitStart,
        endMinutes: morningTransitEnd,
        label: 'Estimated Morning Commute',
        isDrivingOrTransit: true,
      ),
      TimeWindow(
        startMinutes: eveningTransitStart,
        endMinutes: eveningTransitEnd,
        label: 'Estimated Evening Commute',
        isDrivingOrTransit: true,
      ),
    ];

    return InferredRoutine(
      wakeTime: profile.wakeTime,
      sleepTime: profile.sleepTime,
      breakfastTime: profile.breakfastTime,
      lunchTime: profile.lunchTime,
      dinnerTime: profile.dinnerTime,
      transitWindows: transitWindows,
      busyWindows: const [],
      source: 'User Profile Baseline Routine',
      inferenceNotes: [
        'Routine configured from User Profile (Wake: ${profile.wakeTime}, Bedtime: ${profile.sleepTime}).',
        'Standard transit caution windows applied (morning & evening rush).',
      ],
    );
  }

  bool _isTransitRelated(String text) {
    const transitKeywords = [
      'drive',
      'driving',
      'commute',
      'traffic',
      'transit',
      'train',
      'flight',
      'metro',
      'travel',
      'bus',
      'car',
      'airport',
      'subway',
      'ride',
    ];
    for (final kw in transitKeywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  static int _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  static String _formatMinutes(int totalMins) {
    final normalized = (totalMins % 1440 + 1440) % 1440;
    final h = normalized ~/ 60;
    final m = normalized % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
