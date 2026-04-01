import 'package:cloud_firestore/cloud_firestore.dart';
import 'dog_profile.dart';

class UserProfile {
  final String uid;
  final String nickname;
  final String intro;
  // Keep legacy single-dog fields for backward compat
  final String dogName;
  final int birthYear;
  final int? birthMonth;
  final int? birthDay;
  final String dogBreed;
  final String dogGender;
  final bool isNeutered;
  final double? weight;
  final String profileImageUrl;
  final DateTime? createdAt;
  // Multi-dog support
  final List<DogProfile> dogs;

  UserProfile({
    required this.uid,
    required this.nickname,
    this.intro = '',
    this.dogName = '',
    this.birthYear = 2024,
    this.birthMonth,
    this.birthDay,
    this.dogBreed = '',
    this.dogGender = 'Male',
    this.isNeutered = false,
    this.weight,
    this.profileImageUrl = '',
    this.createdAt,
    this.dogs = const [],
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return UserProfile(
          uid: doc.id,
          nickname: 'Unknown',
          dogName: 'Dog',
          birthYear: 2020,
      );
    }
    
    return UserProfile(
      uid: doc.id,
      nickname: data['nickname'] ?? 'User',
      intro: data['intro'] ?? '',
      dogName: data['dogName'] ?? 'Dog',
      birthYear: data['birthYear'] ?? 2020,
      birthMonth: data['birthMonth'],
      birthDay: data['birthDay'],
      dogBreed: data['dogBreed'] ?? '',
      dogGender: data['dogGender'] ?? 'Male',
      isNeutered: data['isNeutered'] ?? false,
      weight: (data['weight'] as num?)?.toDouble(),
      profileImageUrl: data['profileImageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      // dogs will be populated separately after fetching subcollection
    );
  }

  /// Create a copy with dogs list populated
  UserProfile withDogs(List<DogProfile> dogsList) {
    return UserProfile(
      uid: uid,
      nickname: nickname,
      intro: intro,
      dogName: dogName,
      birthYear: birthYear,
      birthMonth: birthMonth,
      birthDay: birthDay,
      dogBreed: dogBreed,
      dogGender: dogGender,
      isNeutered: isNeutered,
      weight: weight,
      profileImageUrl: profileImageUrl,
      createdAt: createdAt,
      dogs: dogsList,
    );
  }

  /// Auto-migrate: if no dogs in subcollection, create one from legacy fields
  List<DogProfile> get effectiveDogs {
    if (dogs.isNotEmpty) return dogs;
    // Fallback: use legacy single-dog fields
    if (dogName.isNotEmpty && dogName != 'Dog') {
      return [
        DogProfile(
          dogId: 'legacy_0',
          dogName: dogName,
          birthYear: birthYear,
          birthMonth: birthMonth,
          birthDay: birthDay,
          dogBreed: dogBreed,
          dogGender: dogGender,
          isNeutered: isNeutered,
          weight: weight,
          profileImageUrl: profileImageUrl,
        ),
      ];
    }
    return [];
  }

  UserProfile copyWith({
    String? uid,
    String? nickname,
    String? intro,
    String? dogName,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    String? dogBreed,
    String? dogGender,
    bool? isNeutered,
    double? weight,
    String? profileImageUrl,
    DateTime? createdAt,
    List<DogProfile>? dogs,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      intro: intro ?? this.intro,
      dogName: dogName ?? this.dogName,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      dogBreed: dogBreed ?? this.dogBreed,
      dogGender: dogGender ?? this.dogGender,
      isNeutered: isNeutered ?? this.isNeutered,
      weight: weight ?? this.weight,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      dogs: dogs ?? this.dogs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'intro': intro,
      'dogName': dogName,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'birthDay': birthDay,
      'dogBreed': dogBreed,
      'dogGender': dogGender,
      'isNeutered': isNeutered,
      'weight': weight,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
