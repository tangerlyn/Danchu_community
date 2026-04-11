import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../domain/entities/community_post.dart';

/// 제보(실종/임시보호) 게시글에 공통으로 필요한 펫 정보 필드 모음.
///
/// 사용 방법:
/// ```dart
/// class PostCreateController extends GetxController with PetReportMixin {
///   @override
///   void onClose() {
///     disposePetFields(); // ← 반드시 super.onClose() 전에 호출
///     super.onClose();
///   }
/// }
/// ```
///
/// ⚠️ onInit/onClose를 mixin에서 오버라이드하지 않습니다.
///    GetxController 생명주기와 충돌을 방지하기 위해
///    각 컨트롤러의 onClose()에서 disposePetFields()를 직접 호출해주세요.
mixin PetReportMixin on GetxController {
  // TextEditingControllers
  final petNameController = TextEditingController();
  final petBreedController = TextEditingController();
  final petAgeController = TextEditingController();
  final petFeatureController = TextEditingController(); // 색상/외형 특징 or 성격(임시보호)
  final petHealthController = TextEditingController();  // 건강 상태(임시보호)

  // Rx fields
  late final selectedPetGender = '선택 안함'.obs;
  late final isNeutered = false.obs;
  late final incidentLocations = <IncidentLocation>[].obs;
  late final selectedIncidentDate = Rxn<DateTime>();

  /// 카테고리가 바뀔 때 펫 필드를 초기화합니다.
  void resetPetFields() {
    petNameController.clear();
    petBreedController.clear();
    petAgeController.clear();
    petFeatureController.clear();
    petHealthController.clear();
    selectedPetGender.value = '선택 안함';
    isNeutered.value = false;
    incidentLocations.clear();
    selectedIncidentDate.value = null;
  }

  /// 기존 petInfo 데이터로 필드를 초기화합니다. (수정 화면에서 사용)
  void initPetFieldsFromData(Map<String, dynamic> petInfo, {List<IncidentLocation>? locations, dynamic incidentDateTimestamp}) {
    petNameController.text = petInfo['name'] ?? '';
    petBreedController.text = petInfo['breed'] ?? '';
    petAgeController.text = petInfo['age'] ?? '';
    petFeatureController.text = petInfo['features'] ?? '';
    petHealthController.text = petInfo['health'] ?? '';
    selectedPetGender.value = petInfo['gender'] ?? '선택 안함';
    isNeutered.value = petInfo['isNeutered'] ?? false;
    if (incidentDateTimestamp != null) {
      selectedIncidentDate.value = incidentDateTimestamp.toDate();
    }
    if (locations != null) {
      incidentLocations.assignAll(locations);
    }
  }

  /// onClose()에서 반드시 호출해야 합니다.
  void disposePetFields() {
    petNameController.dispose();
    petBreedController.dispose();
    petAgeController.dispose();
    petFeatureController.dispose();
    petHealthController.dispose();
  }
}
