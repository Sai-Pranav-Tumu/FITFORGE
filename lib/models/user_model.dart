class UserModel {
  final String id;
  final String email;
  final String name;
  final String gender;
  final int age;
  final String occupation;
  final String sittingHours;
  final String fitnessGoal;
  final int workoutDays;
  final double weight;
  final double height;
  final String avatarKey;
  final String preferredUnits;
  final String dietaryPreference;
  final String trainingLevel;
  final String workoutLocation;
  final String availableEquipment;
  final int sessionDurationMinutes;
  final String targetMuscleFocus;
  final String jointSensitivity;
  final int streak;
  final bool onboardingComplete;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.gender = '',
    this.age = 25,
    this.occupation = '',
    this.sittingHours = '',
    this.fitnessGoal = '',
    this.workoutDays = 3,
    this.weight = 0.0,
    this.height = 170.0,
    this.avatarKey = 'person',
    this.preferredUnits = 'metric',
    this.dietaryPreference = 'any',
    this.trainingLevel = 'Beginner',
    this.workoutLocation = 'Home',
    this.availableEquipment = 'Bodyweight',
    this.sessionDurationMinutes = 30,
    this.targetMuscleFocus = 'Full Body',
    this.jointSensitivity = 'None',
    this.streak = 0,
    this.onboardingComplete = false,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? gender,
    int? age,
    String? occupation,
    String? sittingHours,
    String? fitnessGoal,
    int? workoutDays,
    double? weight,
    double? height,
    String? avatarKey,
    String? preferredUnits,
    String? dietaryPreference,
    String? trainingLevel,
    String? workoutLocation,
    String? availableEquipment,
    int? sessionDurationMinutes,
    String? targetMuscleFocus,
    String? jointSensitivity,
    int? streak,
    bool? onboardingComplete,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      occupation: occupation ?? this.occupation,
      sittingHours: sittingHours ?? this.sittingHours,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      workoutDays: workoutDays ?? this.workoutDays,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      avatarKey: avatarKey ?? this.avatarKey,
      preferredUnits: preferredUnits ?? this.preferredUnits,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      trainingLevel: trainingLevel ?? this.trainingLevel,
      workoutLocation: workoutLocation ?? this.workoutLocation,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      targetMuscleFocus: targetMuscleFocus ?? this.targetMuscleFocus,
      jointSensitivity: jointSensitivity ?? this.jointSensitivity,
      streak: streak ?? this.streak,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? '',
      age: json['age'] ?? 25,
      occupation: json['occupation'] ?? '',
      sittingHours: json['sittingHours'] ?? '',
      fitnessGoal: json['fitnessGoal'] ?? '',
      workoutDays: json['workoutDays'] ?? 3,
      weight: (json['weight'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 170.0).toDouble(),
      avatarKey: json['avatarKey'] ?? 'person',
      preferredUnits: json['preferredUnits'] ?? 'metric',
      dietaryPreference: json['dietaryPreference'] ?? 'any',
      trainingLevel: json['trainingLevel'] ?? 'Beginner',
      workoutLocation: json['workoutLocation'] ?? 'Home',
      availableEquipment: json['availableEquipment'] ?? 'Bodyweight',
      sessionDurationMinutes: json['sessionDurationMinutes'] ?? 30,
      targetMuscleFocus: json['targetMuscleFocus'] ?? 'Full Body',
      jointSensitivity: json['jointSensitivity'] ?? 'None',
      streak: json['streak'] ?? 0,
      onboardingComplete: json['onboardingComplete'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'gender': gender,
      'age': age,
      'occupation': occupation,
      'sittingHours': sittingHours,
      'fitnessGoal': fitnessGoal,
      'workoutDays': workoutDays,
      'weight': weight,
      'height': height,
      'avatarKey': avatarKey,
      'preferredUnits': preferredUnits,
      'dietaryPreference': dietaryPreference,
      'trainingLevel': trainingLevel,
      'workoutLocation': workoutLocation,
      'availableEquipment': availableEquipment,
      'sessionDurationMinutes': sessionDurationMinutes,
      'targetMuscleFocus': targetMuscleFocus,
      'jointSensitivity': jointSensitivity,
      'streak': streak,
      'onboardingComplete': onboardingComplete,
    };
  }
}
