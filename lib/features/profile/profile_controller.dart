import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../auth/onboarding_page.dart';
import '../main_screen.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/dog_profile.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileController extends GetxController {
  final ProfileRepository _repository = ProfileRepository();
  final ImagePicker _picker = ImagePicker();

  // State
  final Rx<UserProfile?> userProfile = Rx<UserProfile?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isEditing = false.obs;

  // Multi-dog state
  final RxList<DogProfile> dogs = <DogProfile>[].obs;
  final RxInt currentDogIndex = 0.obs;

  // Form Controllers (for owner info)
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController introController = TextEditingController();

  // Form Controllers (for current dog being edited)
  final TextEditingController dogNameController = TextEditingController();
  final TextEditingController dogBreedController = TextEditingController();
  final TextEditingController dogWeightController = TextEditingController();
  final TextEditingController dogBioController = TextEditingController();
  final RxInt dogBioLength = 0.obs;
  final RxInt dogNameLength = 0.obs;
  
  // Selection
  final RxString dogGender = 'Male'.obs;
  final RxBool isNeutered = false.obs;
  
  // Flexible Birthday State
  final RxInt birthYear = 2020.obs;
  final Rx<int?> birthMonth = Rx<int?>(null);
  final Rx<int?> birthDay = Rx<int?>(null);
  
  // Image
  final Rx<File?> pickedImage = Rx<File?>(null);

  // Track which dog is being edited (-1 = new dog)
  int _editingDogIndex = -1;

  @override
  void onInit() {
    super.onInit();
    birthYear.value = DateTime.now().year;
    fetchProfile();
  }

  // ─── Fetch ───

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      final uid = _getCurrentUid();
      final profile = await _repository.getUserProfile(uid);
      
      if (profile != null) {
        userProfile.value = profile;
        dogs.value = profile.effectiveDogs;
        _populateOwnerForm(profile);
        isEditing.value = false;
      } else {
        isEditing.value = true;
        birthYear.value = DateTime.now().year;
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to load profile: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _populateOwnerForm(UserProfile p) {
    nicknameController.text = p.nickname;
    introController.text = p.intro;
    // Populate first dog's fields for backward compat
    if (p.effectiveDogs.isNotEmpty) {
      _populateDogForm(p.effectiveDogs.first);
    }
  }

  void _populateDogForm(DogProfile dog) {
    dogNameController.text = dog.dogName;
    dogBreedController.text = dog.dogBreed;
    dogBioController.text = dog.bio ?? '';
    dogBioLength.value = dogBioController.text.length;
    dogNameLength.value = dogNameController.text.length;
    dogGender.value = dog.dogGender;
    isNeutered.value = dog.isNeutered;
    birthYear.value = dog.birthYear;
    birthMonth.value = dog.birthMonth;
    birthDay.value = dog.birthDay;
    dogWeightController.text = dog.weight?.toString() ?? '';
  }

  // ─── Dog CRUD ───

  void startEditDog(int index) {
    if (index < 0 || index >= dogs.length) return;
    _editingDogIndex = index;
    _populateDogForm(dogs[index]);
    pickedImage.value = null; // Clear image from previous edits
    isEditing.value = true;
  }

  void startAddDog() {
    _editingDogIndex = -1;
    dogNameController.clear();
    dogBreedController.clear();
    dogBioController.clear();
    dogBioLength.value = 0;
    dogNameLength.value = 0;
    dogGender.value = 'Male';
    isNeutered.value = false;
    birthYear.value = DateTime.now().year;
    birthMonth.value = null;
    birthDay.value = null;
    dogWeightController.clear();
    pickedImage.value = null;
    isEditing.value = true;
  }

  Future<void> saveDog() async {
    if (dogNameController.text.isEmpty) {
      Get.snackbar("입력 오류", "강아지 이름은 필수입니다.", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    double? weightValue;
    if (dogWeightController.text.isNotEmpty) {
      final w = double.tryParse(dogWeightController.text);
      if (w == null || w <= 0) {
        Get.snackbar("입력 오류", "몸무게를 올바른 숫자로 입력해주세요 (0보다 커야 함)", snackPosition: SnackPosition.BOTTOM);
        return;
      }
      weightValue = w;
    }

    isLoading.value = true;
    try {
      final uid = _getCurrentUid();
      
      // 1. Determine the stable dogId
      final String dogId = (_editingDogIndex >= 0) 
          ? dogs[_editingDogIndex].dogId 
          : 'dog_${DateTime.now().millisecondsSinceEpoch}';

      String imageUrl = '';
      if (_editingDogIndex >= 0 && _editingDogIndex < dogs.length) {
        imageUrl = dogs[_editingDogIndex].profileImageUrl;
      }

      // 2. Upload new image if picked (using the stable dogId)
      if (pickedImage.value != null) {
        imageUrl = await _repository.uploadDogImage(uid, dogId, pickedImage.value!);
      }

      // 3. Create DogProfile with the fixed dogId
      final dog = DogProfile(
        dogId: dogId,
        dogName: dogNameController.text,
        birthYear: birthYear.value,
        birthMonth: birthMonth.value,
        birthDay: birthDay.value,
        dogBreed: dogBreedController.text,
        dogGender: dogGender.value,
        isNeutered: false,
        profileImageUrl: imageUrl,
        bio: dogBioController.text,
        weight: weightValue,
      );

      // 4. Save to Firestore (Repository will use our dogId as doc name)
      final savedId = _repository.saveDog(uid, dog);
      final savedDog = dog.copyWith(dogId: savedId);

      // Local list update (no re-fetch needed)
      if (_editingDogIndex >= 0 && _editingDogIndex < dogs.length) {
        dogs[_editingDogIndex] = savedDog;
        currentDogIndex.value = _editingDogIndex;
      } else {
        dogs.add(savedDog);
        currentDogIndex.value = dogs.length - 1;
      }

      isEditing.value = false;
      pickedImage.value = null;

      // Fire-and-forget legacy update (first dog = main)
      if (_editingDogIndex <= 0 || dogs.length == 1) {
        _updateLegacyDogFields(uid, savedDog, imageUrl);
      }

      showCenterToast("멍카 저장 완료!");
    } catch (e) {
      Get.snackbar("오류", "저장 중 문제가 발생했습니다: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _updateLegacyDogFields(String uid, DogProfile dog, String dogImageUrl) async {
    // profileImageUrl은 건드리지 않고 강아지 관련 필드만 업데이트
    final currentProfile = userProfile.value;
    if (currentProfile == null) return;
    
    final updated = UserProfile(
      uid: uid,
      nickname: currentProfile.nickname,           // 기존 닉네임 유지
      intro: currentProfile.intro,                  // 기존 소개 유지
      profileImageUrl: currentProfile.profileImageUrl, // 보호자 프로필 이미지 유지 ← 핵심
      dogName: dog.dogName,
      birthYear: dog.birthYear,
      birthMonth: dog.birthMonth,
      birthDay: dog.birthDay,
      dogBreed: dog.dogBreed,
      dogGender: dog.dogGender,
      isNeutered: dog.isNeutered,
      weight: dog.weight,
      createdAt: currentProfile.createdAt,
    );
    await _repository.saveUserProfile(updated);
  }

  Future<void> deleteDog(int index) async {
    if (index < 0 || index >= dogs.length) return;
    if (dogs.length <= 1) {
      Get.snackbar("삭제 불가", "최소 1마리는 등록되어 있어야 합니다.", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final dog = dogs[index];
    if (dog.dogId.startsWith('legacy_')) return; // Can't delete unmigrated

    isLoading.value = true;
    try {
      _repository.deleteDog(_getCurrentUid(), dog.dogId);

      // Local list update
      dogs.removeAt(index);
      if (currentDogIndex.value >= dogs.length) {
        currentDogIndex.value = dogs.length - 1;
      }

      Get.snackbar("삭제 완료", "${dog.dogName}의 멍카가 삭제되었습니다.");
    } catch (e) {
      Get.snackbar("오류", "삭제 실패: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Legacy Save (Onboarding) ───

  Future<void> saveProfile() async {
    if (nicknameController.text.isEmpty) {
      Get.snackbar("입력 오류", "닉네임은 필수입니다.");
      return;
    }

    isLoading.value = true;
    try {
      await _saveInternal();
      
      pickedImage.value = null;
      isEditing.value = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_profile_completed', true);
      debugPrint("✅ Onboarding Complete");
      
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      if (hasSeenOnboarding) {
        Get.offAll(() => MainScreen(initialIndex: 3));
      } else {
        Get.offAll(() => const OnboardingPage());
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to save profile: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveProfileUpdate() async {
    if (nicknameController.text.isEmpty) {
       Get.snackbar("입력 오류", "닉네임은 필수입니다.", snackPosition: SnackPosition.BOTTOM);
       return;
    }

    isLoading.value = true;
    _saveInternal().then((_) {
      fetchProfile();
      isEditing.value = false;
      pickedImage.value = null;
      isLoading.value = false;
      showCenterToast("프로필 저장 완료!");
    }).catchError((e) {
       Get.snackbar("오류 발생", "저장 중 문제가 발생했습니다: $e");
       isLoading.value = false;
    });
  }

  Future<void> _saveInternal() async {
    final uid = _getCurrentUid();
    
    String profileImageUrl = userProfile.value?.profileImageUrl ?? '';
    if (pickedImage.value != null) {
      profileImageUrl = await _repository.uploadProfileImage(uid, pickedImage.value!);
      // 업로드 즉시 로컬 상태 반영 (캐시된 옛날 URL로 접근하는 것 방지)
      if (userProfile.value != null) {
        userProfile.value = userProfile.value!.copyWith(
          profileImageUrl: profileImageUrl,
        );
      }
    }

    final newProfile = UserProfile(
      uid: uid,
      nickname: nicknameController.text,
      intro: introController.text,
      profileImageUrl: profileImageUrl,
      dogName: '',
      birthYear: DateTime.now().year,
      createdAt: userProfile.value?.createdAt,
      dogs: dogs.toList(),
    );

    await _repository.saveUserProfile(newProfile);
    userProfile.value = newProfile;
  }

  Future<void> updateUserBasicInfo() async {
    if (nicknameController.text.isEmpty) {
      Get.snackbar("입력 오류", "닉네임은 필수입니다.", snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isLoading.value = true;
    try {
      final uid = _getCurrentUid();
      String imageUrl = userProfile.value?.profileImageUrl ?? '';

      if (pickedImage.value != null) {
        imageUrl = await _repository.uploadProfileImage(uid, pickedImage.value!);
      }

      await _repository.updateUserProfileBasicInfo(uid, nicknameController.text, imageUrl);
      
      // Update local state without full reload if possible, but fetchProfile is safer to keep dogs in sync
      await fetchProfile();
      
      pickedImage.value = null;
      Get.back(); // Go back from edit page
      showCenterToast("프로필 수정 완료!");
    } catch (e) {
      Get.snackbar("오류", "수정 중 문제가 발생했습니다: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Helpers ───

  String _getCurrentUid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) return user.uid;
    return "test_user_1";
  }

  void toggleEdit() {
    if (!isEditing.value && userProfile.value != null) {
      _populateOwnerForm(userProfile.value!);
      if (currentDogIndex.value < dogs.length) {
        _editingDogIndex = currentDogIndex.value;
        _populateDogForm(dogs[currentDogIndex.value]);
      }
    }
    isEditing.toggle();
  }

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        IOSUiSettings(
          title: '프로필 사진',
          cancelButtonTitle: '취소',
          doneButtonTitle: '완료',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          rotateButtonsHidden: true,
          rotateClockwiseButtonHidden: true,
          resetButtonHidden: true,
          showActivitySheetOnDone: false,
          cropStyle: CropStyle.circle,
        ),
        AndroidUiSettings(
          toolbarTitle: '프로필 사진',
          toolbarColor: const Color(0xFF3E2723),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (croppedFile != null) {
      pickedImage.value = File(croppedFile.path);
    }
  }

  void setBirthYear(int year) => birthYear.value = year;
  void setBirthMonth(int? month) => birthMonth.value = month;
  void setBirthDay(int? day) => birthDay.value = day;

  String get dogAgeString {
    final now = DateTime.now();
    final bYear = birthYear.value;
    final bMonth = birthMonth.value;
    final bDay = birthDay.value;

    if (bMonth == null) {
      return '${now.year - bYear}살';
    }

    int totalMonths = (now.year * 12 + now.month) - (bYear * 12 + bMonth);
    if (bDay != null && now.day < bDay) totalMonths--;
    if (totalMonths < 0) return '미래에서 왔나요?';

    final years = totalMonths ~/ 12;
    final months = totalMonths % 12;
    if (years == 0) return '$months개월';
    if (months == 0) return '$years살';
    return '$years살 $months개월';
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_profile_completed', true);
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    if (hasSeenOnboarding) {
      Get.offAll(() => MainScreen());
    } else {
      Get.offAll(() => const OnboardingPage());
    }
  }

  void clearAll() {
    userProfile.value = null;
    dogs.clear();
    currentDogIndex.value = 0;
    isEditing.value = false;
    
    nicknameController.clear();
    introController.clear();
    dogNameController.clear();
    dogBreedController.clear();
    dogBioController.clear();
    
    dogGender.value = 'Male';
    isNeutered.value = false;
    birthYear.value = DateTime.now().year;
    birthMonth.value = null;
    birthDay.value = null;
    
    pickedImage.value = null;
    _editingDogIndex = -1;
  }

  void showCenterToast(String message) {
    Get.dialog(
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pets,
                  size: 64,
                  color: AppColors.deepBrown,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF3E2723), // AppColors.deepBrown
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierColor: Colors.black.withOpacity(0.4),
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });
  }
}
