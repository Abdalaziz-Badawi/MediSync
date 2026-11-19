class UserProfile {
  final String name;
  final String avatarId;
  final int? age;
  final String? gender;
  final List<String> allergies;
  final List<String> chronicConditions;
  final String wakeTime;      // "HH:mm" e.g. "07:00"
  final String sleepTime;     // "HH:mm" e.g. "23:00"
  final String breakfastTime; // "HH:mm" e.g. "08:30"
  final String lunchTime;     // "HH:mm" e.g. "13:30"
  final String dinnerTime;    // "HH:mm" e.g. "20:00"
  final bool useHealthApp;

  const UserProfile({
    this.name = 'User',
    this.avatarId = 'avatar_wellness',
    this.age,
    this.gender,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.wakeTime = '07:00',
    this.sleepTime = '23:00',
    this.breakfastTime = '08:30',
    this.lunchTime = '13:30',
    this.dinnerTime = '20:00',
    this.useHealthApp = false,
  });

  UserProfile copyWith({
    String? name,
    String? avatarId,
    int? age,
    String? gender,
    List<String>? allergies,
    List<String>? chronicConditions,
    String? wakeTime,
    String? sleepTime,
    String? breakfastTime,
    String? lunchTime,
    String? dinnerTime,
    bool? useHealthApp,
  }) {
    return UserProfile(
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      useHealthApp: useHealthApp ?? this.useHealthApp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatarId': avatarId,
      'age': age,
      'gender': gender,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'wakeTime': wakeTime,
      'sleepTime': sleepTime,
      'breakfastTime': breakfastTime,
      'lunchTime': lunchTime,
      'dinnerTime': dinnerTime,
      'useHealthApp': useHealthApp,
    };
  }

  factory UserProfile.fromJson(Map<dynamic, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? 'User',
      avatarId: json['avatarId'] as String? ?? 'avatar_wellness',
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      chronicConditions: (json['chronicConditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      wakeTime: json['wakeTime'] as String? ?? '07:00',
      sleepTime: json['sleepTime'] as String? ?? '23:00',
      breakfastTime: json['breakfastTime'] as String? ?? '08:30',
      lunchTime: json['lunchTime'] as String? ?? '13:30',
      dinnerTime: json['dinnerTime'] as String? ?? '20:00',
      useHealthApp: json['useHealthApp'] as bool? ?? false,
    );
  }
}
