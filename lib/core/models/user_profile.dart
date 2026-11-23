class UserProfile {
  final String name;
  final String avatarId;
  final DateTime? dateOfBirth;
  final int? _explicitAge;
  final String? gender;
  final String? healthId;
  final String? bloodType;
  final double? weightKg;
  final double? heightCm;
  final String? profileImagePath;
  final String lockscreenDefaultView; // 'card', 'medications', 'dual'
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> pastSurgeries;
  final List<String> medicalHistory;
  final bool isOrganDonor;
  final String wakeTime;      // "HH:mm" e.g. "07:00"
  final String sleepTime;     // "HH:mm" e.g. "23:00"
  final String breakfastTime; // "HH:mm" e.g. "08:30"
  final String lunchTime;     // "HH:mm" e.g. "13:30"
  final String dinnerTime;    // "HH:mm" e.g. "20:00"
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;
  final bool useHealthApp;

  static const List<String> standardBloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  const UserProfile({
    this.name = 'User',
    this.avatarId = 'avatar_wellness',
    this.dateOfBirth,
    int? age,
    this.gender,
    this.healthId,
    this.bloodType,
    this.weightKg,
    this.heightCm,
    this.profileImagePath,
    this.lockscreenDefaultView = 'dual',
    this.allergies = const [],
    this.chronicConditions = const [],
    this.pastSurgeries = const [],
    this.medicalHistory = const [],
    this.isOrganDonor = false,
    this.wakeTime = '07:00',
    this.sleepTime = '23:00',
    this.breakfastTime = '08:30',
    this.lunchTime = '13:30',
    this.dinnerTime = '20:00',
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
    this.useHealthApp = false,
  }) : _explicitAge = age;

  /// Dynamic clinical age derived strictly from date of birth,
  /// falling back to explicit age if legacy profile has no DoB set.
  int? get age {
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int calculated = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        calculated--;
      }
      return calculated >= 0 ? calculated : 0;
    }
    return _explicitAge;
  }

  /// Dynamic clinical BMI calculation
  double? get bmi {
    if (weightKg != null && heightCm != null && heightCm! > 0) {
      final heightM = heightCm! / 100.0;
      return double.parse((weightKg! / (heightM * heightM)).toStringAsFixed(1));
    }
    return null;
  }

  String get bmiCategory {
    final val = bmi;
    if (val == null) return 'Unrecorded';
    if (val < 18.5) return 'Underweight';
    if (val < 25.0) return 'Normal';
    if (val < 30.0) return 'Overweight';
    return 'Obese';
  }

  UserProfile copyWith({
    String? name,
    String? avatarId,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? healthId,
    String? bloodType,
    double? weightKg,
    double? heightCm,
    String? profileImagePath,
    String? lockscreenDefaultView,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? pastSurgeries,
    List<String>? medicalHistory,
    bool? isOrganDonor,
    String? wakeTime,
    String? sleepTime,
    String? breakfastTime,
    String? lunchTime,
    String? dinnerTime,
    String? address,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    bool? useHealthApp,
  }) {
    return UserProfile(
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? (dateOfBirth != null ? null : this.age),
      gender: gender ?? this.gender,
      healthId: healthId ?? this.healthId,
      bloodType: bloodType ?? this.bloodType,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      lockscreenDefaultView: lockscreenDefaultView ?? this.lockscreenDefaultView,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      pastSurgeries: pastSurgeries ?? this.pastSurgeries,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      isOrganDonor: isOrganDonor ?? this.isOrganDonor,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      breakfastTime: breakfastTime ?? this.breakfastTime,
      lunchTime: lunchTime ?? this.lunchTime,
      dinnerTime: dinnerTime ?? this.dinnerTime,
      address: address ?? this.address,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      useHealthApp: useHealthApp ?? this.useHealthApp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatarId': avatarId,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'age': age,
      'gender': gender,
      'healthId': healthId,
      'bloodType': bloodType,
      'weightKg': weightKg,
      'heightCm': heightCm,
      'profileImagePath': profileImagePath,
      'lockscreenDefaultView': lockscreenDefaultView,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'pastSurgeries': pastSurgeries,
      'medicalHistory': medicalHistory,
      'isOrganDonor': isOrganDonor,
      'wakeTime': wakeTime,
      'sleepTime': sleepTime,
      'breakfastTime': breakfastTime,
      'lunchTime': lunchTime,
      'dinnerTime': dinnerTime,
      'address': address,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelation': emergencyContactRelation,
      'useHealthApp': useHealthApp,
    };
  }

  factory UserProfile.fromJson(Map<dynamic, dynamic> json) {
    DateTime? parsedDob;
    if (json['dateOfBirth'] != null) {
      parsedDob = DateTime.tryParse(json['dateOfBirth'].toString());
    }

    return UserProfile(
      name: json['name'] as String? ?? 'User',
      avatarId: json['avatarId'] as String? ?? 'avatar_wellness',
      dateOfBirth: parsedDob,
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      healthId: json['healthId'] as String?,
      bloodType: json['bloodType'] as String?,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      profileImagePath: json['profileImagePath'] as String?,
      lockscreenDefaultView: json['lockscreenDefaultView'] as String? ?? 'dual',
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      chronicConditions: (json['chronicConditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      pastSurgeries: (json['pastSurgeries'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      medicalHistory: (json['medicalHistory'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isOrganDonor: json['isOrganDonor'] as bool? ?? false,
      wakeTime: json['wakeTime'] as String? ?? '07:00',
      sleepTime: json['sleepTime'] as String? ?? '23:00',
      breakfastTime: json['breakfastTime'] as String? ?? '08:30',
      lunchTime: json['lunchTime'] as String? ?? '13:30',
      dinnerTime: json['dinnerTime'] as String? ?? '20:00',
      address: json['address'] as String?,
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
      emergencyContactRelation: json['emergencyContactRelation'] as String?,
      useHealthApp: json['useHealthApp'] as bool? ?? false,
    );
  }
}
