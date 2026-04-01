
class DogProfile {
  final String dogId;
  final String dogName;
  final int birthYear;
  final int? birthMonth;
  final int? birthDay;
  final String dogBreed;
  final String dogGender; // 'Male', 'Female'
  final bool isNeutered;
  final String profileImageUrl;
  final String? bio; // 한줄 소개
  final double? weight; // 몸무게 (kg)

  DogProfile({
    required this.dogId,
    required this.dogName,
    required this.birthYear,
    this.birthMonth,
    this.birthDay,
    this.dogBreed = '',
    this.dogGender = 'Male',
    this.isNeutered = false,
    this.profileImageUrl = '',
    this.bio,
    this.weight,
  });

  factory DogProfile.fromMap(String id, Map<String, dynamic> data) {
    return DogProfile(
      dogId: id,
      dogName: data['dogName'] ?? 'Dog',
      birthYear: data['birthYear'] ?? 2020,
      birthMonth: data['birthMonth'],
      birthDay: data['birthDay'],
      dogBreed: data['dogBreed'] ?? '',
      dogGender: data['dogGender'] ?? 'Male',
      isNeutered: data['isNeutered'] ?? false,
      profileImageUrl: data['profileImageUrl'] ?? '',
      bio: data['bio'],
      weight: (data['weight'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dogName': dogName,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'birthDay': birthDay,
      'dogBreed': dogBreed,
      'dogGender': dogGender,
      'isNeutered': isNeutered,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'weight': weight,
    };
  }

  // Age calculation helper
  String get ageString {
    final now = DateTime.now();
    final bMonth = birthMonth;
    final bDay = birthDay;

    if (bMonth == null) {
      return '${now.year - birthYear}살';
    }

    int totalMonths = (now.year * 12 + now.month) - (birthYear * 12 + bMonth);
    if (bDay != null && now.day < bDay) totalMonths--;
    if (totalMonths < 0) return '미래에서 왔나요?';

    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;

    if (years == 0) return '$months개월';
    if (months == 0) return '$years살';
    return '$years살 $months개월';
  }

  DogProfile copyWith({
    String? dogId,
    String? dogName,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    String? dogBreed,
    String? dogGender,
    bool? isNeutered,
    String? profileImageUrl,
    String? bio,
    double? weight,
  }) {
    return DogProfile(
      dogId: dogId ?? this.dogId,
      dogName: dogName ?? this.dogName,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      dogBreed: dogBreed ?? this.dogBreed,
      dogGender: dogGender ?? this.dogGender,
      isNeutered: isNeutered ?? this.isNeutered,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      weight: weight ?? this.weight,
    );
  }
}
