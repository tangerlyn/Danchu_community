import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:pawprint_app/core/app_colors.dart';
import '../../core/utils/date_picker_utils.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../domain/entities/community_post.dart';
import '../auth/login_page.dart';
import 'community_constants.dart';
import 'post_detail_page.dart';
import 'location_pick_page.dart';
import 'community_controller.dart';
import 'mixins/pet_report_mixin.dart';

class PostCreateController extends GetxController with PetReportMixin {
  final CommunityRepositoryImpl _communityRepository = CommunityRepositoryImpl();
  final ProfileRepository _profileRepository = ProfileRepository();
  final ImagePicker _picker = ImagePicker();

  var isLoading = false.obs;
  
  // Form State
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  // Meetup specific fields (Phase 3: Geographic)
  var selectedMeetupDate = Rxn<DateTime>();
  var selectedMeetingPlace = Rxn<String>();
  var selectedMeetingLat = Rxn<double>();
  var selectedMeetingLng = Rxn<double>();
  
  // Legacy text field (now used for manual override or display)
  final meetupLocationController = TextEditingController(); 
  final meetupCapacityController = TextEditingController();

  var selectedMeetupCapacity = Rxn<int>();

  var selectedMainCategory = '자유'.obs;
  var selectedSubCategory = '전체'.obs;

  var selectedImages = <File>[].obs;
  
  List<Map<String, double>>? _passedRoutePoints;
  String? _passedWalkSummary;

  UserProfile? _currentUserProfile;

  // Pet Report specific fields are provided by PetReportMixin:
  // petNameController, petBreedController, petAgeController,
  // petFeatureController, petHealthController,
  // selectedPetGender, isNeutered, incidentLocations, selectedIncidentDate

  @override
  void onInit() {
    super.onInit();
    _fetchUserProfile();
    
    // Check for predefined categories (e.g. from Walk Summary sharing)
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['mainCategory'] != null) {
        selectedMainCategory.value = args['mainCategory'] as String;
      }
      if (args['subCategory'] != null) {
        selectedSubCategory.value = args['subCategory'] as String;
      }
      if (args['routePoints'] != null) {
        _passedRoutePoints = args['routePoints'] as List<Map<String, double>>;
      }
      if (args['walkSummary'] != null) {
        _passedWalkSummary = args['walkSummary'] as String;
      }
    }

    // Listen to main category changes to reset subcategory
    ever(selectedMainCategory, (String mainCat) {
      final subTags = CommunityConstants.getSubTagsForCategory(mainCat).where((t) => t != '전체').toList();
      selectedSubCategory.value = subTags.isNotEmpty ? subTags.first : '전체';
      resetPetFields(); // from PetReportMixin
    });

    // Listen to sub category changes (within '신고')
    ever(selectedSubCategory, (_) => resetPetFields()); // from PetReportMixin
  }


  @override
  void onClose() {
    titleController.dispose();
    contentController.dispose();
    meetupLocationController.dispose();
    meetupCapacityController.dispose();
    disposePetFields(); // from PetReportMixin
    super.onClose();
  }

  Future<void> _fetchUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _currentUserProfile = await _profileRepository.getUserProfile(uid);
    }
  }

  // --- Sighting Location Management ---
  Future<void> addIncidentLocation() async {
    if (selectedSubCategory.value == '임시보호') return;

    final result = await Get.to(() => const LocationPickPage());
    if (result != null && result is Map<String, dynamic>) {
      final name = result['title'] as String;
      final lat = result['lat'] as double;
      final lng = result['lng'] as double;
      
      incidentLocations.add(IncidentLocation(name: name, latitude: lat, longitude: lng));
      incidentLocations.refresh();
    }
  }

  void removeIncidentLocation(int index) {
    incidentLocations.removeAt(index);
    incidentLocations.refresh();
  }

  Future<void> selectIncidentDate(BuildContext context) async {
    final now = DateTime.now();
    await DatePickerUtils.showDateSheet(
      context: context,
      title: '발생 날짜 선택',
      initialDate: selectedIncidentDate.value ?? now,
      maxDate: now,
      onSelect: (date) {
        selectedIncidentDate.value = date;
      },
    );
  }

  // --- Location Picking (Phase 3) ---
  Future<void> pickLocation() async {
    final result = await Get.to(() => const LocationPickPage());
    if (result != null && result is Map<String, dynamic>) {
      selectedMeetingPlace.value = result['title'];
      selectedMeetingLat.value = result['lat'];
      selectedMeetingLng.value = result['lng'];
      
      // Also update text controller for display
      meetupLocationController.text = result['title'];
    }
  }

  Future<void> pickImages() async {
    final remaining = 5 - selectedImages.length;
    if (remaining <= 0) {
      Get.snackbar('알림', '사진은 최대 5개까지 첨부할 수 있습니다.');
      return;
    }

    try {
      final List<XFile> images = await _picker.pickMultiImage(limit: remaining);
      if (images.isNotEmpty) {
        selectedImages.addAll(images.map((x) => File(x.path)));
      }
    } catch (e) {
      debugPrint('⚠️ Error picking images: $e');
      Get.snackbar('잠깐!', '사진을 불러오는 중 문제가 발생했어요. 다시 시도해주세요 🐾');
    }
  }

  void reorderImages(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final File image = selectedImages.removeAt(oldIndex);
    selectedImages.insert(newIndex, image);
  }

  void removeImage(int index) {
    selectedImages.removeAt(index);
  }


  Future<void> selectMeetupDate(BuildContext context) async {
    await DatePickerUtils.showDateSheet(
      context: context,
      title: '날짜 선택',
      initialDate: selectedMeetupDate.value ?? DateTime.now(),
      onSelect: (date) {
        DateTime initial = selectedMeetupDate.value ?? DateTime.now();
        selectedMeetupDate.value = DateTime(
          date.year, date.month, date.day,
          initial.hour, initial.minute,
        );
      },
    );
  }

  Future<void> _showDateSheet({
    required BuildContext context,
    required String title,
    required DateTime initialDate,
    DateTime? maxDate,
    required Function(DateTime) onSelect,
  }) => DatePickerUtils.showDateSheet(
    context: context,
    title: title,
    initialDate: initialDate,
    maxDate: maxDate,
    onSelect: onSelect,
  );

  Future<void> selectMeetupTime(BuildContext context) async {
    final initial = selectedMeetupDate.value ?? DateTime.now();
    await DatePickerUtils.showTimeSheet(
      context: context,
      initialDateTime: initial,
      onSelect: (hour24, minute) {
        selectedMeetupDate.value = DateTime(
          initial.year, initial.month, initial.day,
          hour24, minute,
        );
      },
    );
  }

  Future<void> selectMeetupCapacity(BuildContext context) async {
    await DatePickerUtils.showCapacitySheet(
      context: context,
      initialCapacity: selectedMeetupCapacity.value ?? 1,
      onSelect: (capacity) {
        selectedMeetupCapacity.value = capacity;
        meetupCapacityController.text = capacity.toString();
      },
    );
  }

  Widget _amPmButton(String label, bool isSelected, VoidCallback onTap) =>
      DatePickerUtils.buildAmPmButton(label: label, isSelected: isSelected, onTap: onTap);

  Future<void> submitPost() async {
    if (titleController.text.trim().isEmpty) {
      Get.snackbar('알림', '제목을 입력해주세요.');
      return;
    }
    if (contentController.text.trim().isEmpty) {
      Get.snackbar('알림', '내용을 입력해주세요.');
      return;
    }
    
    // Meetup Validation (date/time is optional now)
    if (selectedMainCategory.value == '모임') {
      if (meetupLocationController.text.trim().isEmpty) {
        Get.snackbar('알림', '모임 장소를 선택해주세요.');
        return;
      }
      if (meetupCapacityController.text.trim().isEmpty || int.tryParse(meetupCapacityController.text.trim()) == null) {
        Get.snackbar('알림', '올바른 모집 인원(숫자)을 입력해주세요.');
        return;
      }
    }

    // Pet Report Validation
    if (selectedMainCategory.value == '신고') {
       if (['실종', '임시보호'].contains(selectedSubCategory.value)) {
          if (petNameController.text.trim().isEmpty) {
             Get.snackbar('알림', '이름을 입력해주세요.');
             return;
          }
          if (selectedSubCategory.value == '실종' && incidentLocations.isEmpty) {
             Get.snackbar('알림', '목격 장소를 추가해주세요.');
             return;
          }
       }
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Get.defaultDialog(
        title: "로그인 필요",
        middleText: "게시글을 작성하려면 로그인이 필요합니다.",
        textConfirm: "로그인",
        textCancel: "취소",
        confirmTextColor: Colors.white,
        buttonColor: const Color(0xFF3A200B),
        onConfirm: () {
          Get.back();
          Get.offAll(() => const LoginPage());
        },
      );
      return;
    }

    isLoading.value = true;
    try {
      final String nickname = _currentUserProfile?.nickname ?? 'Unknown';

      // Capture geographic data if not '자유'
      double? lat, lng;
      Map<String, dynamic>? position;
      
      // For reports, we set the primary position to the first sighting location if available (Only for '실종')
      if (selectedMainCategory.value == '신고' && selectedSubCategory.value == '실종' && incidentLocations.isNotEmpty) {
          lat = incidentLocations.first.latitude;
          lng = incidentLocations.first.longitude;
          position = GeoFirePoint(GeoPoint(lat, lng)).data;
      } else {
        // Capture position for all other categories including '자유'
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          lat = pos.latitude;
          lng = pos.longitude;
          position = GeoFirePoint(GeoPoint(lat, lng)).data;
        } catch (e) {
          print('⚠️ Failed to get current position: $e');
        }
      }

      // Prepare petInfo
      Map<String, dynamic>? petInfo;
      if (selectedMainCategory.value == '신고' && ['실종', '임시보호'].contains(selectedSubCategory.value)) {
         petInfo = {
            'name': petNameController.text.trim(),
            'breed': petBreedController.text.trim(),
            'age': petAgeController.text.trim(),
            'gender': selectedPetGender.value,
            'features': petFeatureController.text.trim(),
            if (selectedSubCategory.value == '임시보호') ...{
               'health': petHealthController.text.trim(),
               'isNeutered': isNeutered.value,
            },
            if (selectedIncidentDate.value != null)
               'incidentDate': Timestamp.fromDate(selectedIncidentDate.value!),
         };
      }

      final post = CommunityPost(
        id: _communityRepository.getNewDocId(),
        title: titleController.text.trim(),
        content: contentController.text.trim(),
        authorUid: uid,
        authorNickname: nickname,
        authorProfileImageUrl: _currentUserProfile?.profileImageUrl,
        mainCategory: selectedMainCategory.value,
        subCategoryTag: selectedSubCategory.value,
        imageUrls: [],
        likeCount: 0,
        commentCount: 0,
        likedBy: [],
        createdAt: DateTime.now(),
        // Pet Report fields
        petInfo: petInfo,
        incidentLocations: selectedSubCategory.value == '실종' ? incidentLocations.toList() : null,
        isMissing: selectedSubCategory.value == '실종',
        // Meetup fields
        meetupDate: selectedMainCategory.value == '모임' ? selectedMeetupDate.value : null,
        meetupLocation: selectedMainCategory.value == '모임' ? meetupLocationController.text.trim() : null,
        meetupCapacity: selectedMainCategory.value == '모임' ? int.tryParse(meetupCapacityController.text.trim()) : null,
        currentParticipantCount: selectedMainCategory.value == '모임' ? 1 : 0,
        // Phase 3: Geographic
        lat: lat,
        lng: lng,
        position: position,
        meetingPlace: selectedMainCategory.value == '모임' ? selectedMeetingPlace.value : null,
        meetingLat: selectedMainCategory.value == '모임' ? selectedMeetingLat.value : null,
        meetingLng: selectedMainCategory.value == '모임' ? selectedMeetingLng.value : null,
        routePoints: _passedRoutePoints,
        walkSummary: _passedWalkSummary,
      );

      final uploadedUrls = await _communityRepository.createPost(post, selectedImages);
      final postWithImages = post.copyWith(imageUrls: uploadedUrls);
      
      if (post.mainCategory == '모임') {
        if (Get.isRegistered<CommunityController>()) {
          Get.find<CommunityController>().refreshMyMeetupPostIds();
        }
      }
      
      Get.off(() => PostDetailPage(post: postWithImages, fromCreate: true));
    } catch (e, stack) {
      debugPrint('⚠️ Error submitting post: $e\n$stack');
      Get.snackbar('잠깐!', '글 등록에 실패했어요. 잠시 후 다시 시도해주세요 🐾');
    } finally {
      isLoading.value = false;
    }
  }
}

/*
// ==========================================
// --- Legacy Controller Code (For reference)
// ==========================================
import 'dart:io';
// ... previous implementation without meetup logic and checking '전체' instead of '인기'
*/
