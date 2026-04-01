import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/app_colors.dart';
import '../../core/utils/date_picker_utils.dart';
import '../../domain/entities/community_post.dart';
import '../../data/repositories/community_repository_impl.dart';
import 'location_pick_page.dart';
import 'mixins/pet_report_mixin.dart';

class PostEditController extends GetxController with PetReportMixin {
  final CommunityRepositoryImpl _repository = CommunityRepositoryImpl();
  final CommunityPost post;

  final titleController = TextEditingController();
  final contentController = TextEditingController();

  // Pet Report specific fields are provided by PetReportMixin:
  // petNameController, petBreedController, petAgeController,
  // petFeatureController, petHealthController,
  // selectedPetGender, isNeutered, incidentLocations, selectedIncidentDate

  final ImagePicker _picker = ImagePicker();
  var existingImageUrls = <String>[].obs; // 기존 이미지 URL
  var newImages = <File>[].obs; // 새로 추가한 이미지
  var isSubmitting = false.obs;

  PostEditController({required this.post});

  @override
  void onInit() {
    super.onInit();
    titleController.text = post.title;
    existingImageUrls.assignAll(post.imageUrls);
    contentController.text = post.content;

    // Initialize pet info using mixin helper
    if (post.petInfo != null) {
      initPetFieldsFromData(
        post.petInfo!,
        locations: post.incidentLocations,
        incidentDateTimestamp: post.petInfo!['incidentDate'],
      );
    } else if (post.incidentLocations != null) {
      incidentLocations.assignAll(post.incidentLocations!);
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    contentController.dispose();
    disposePetFields(); // from PetReportMixin
    super.onClose();
  }

  // --- Methods for PetReportForm ---

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


  Future<void> addIncidentLocation() async {
    if (post.subCategoryTag == '임시보호') return; // Not used for '임시보호'

    final result = await Get.to(() => const LocationPickPage());
    if (result != null && result is Map<String, dynamic>) {
      final name = result['title'] as String?;
      final lat = result['lat'] as double?;
      final lng = result['lng'] as double?;

      if (name == null || lat == null || lng == null) return;

      final newLocation = IncidentLocation(
        name: name,
        latitude: lat,
        longitude: lng,
      );

      incidentLocations.add(newLocation);
      incidentLocations.refresh();
    }
  }

  void removeIncidentLocation(int index) {
    incidentLocations.removeAt(index);
    incidentLocations.refresh();
  }

  Future<void> pickImages() async {
    final remaining = 5 - existingImageUrls.length - newImages.length;
    if (remaining <= 0) {
      Get.snackbar('알림', '사진은 최대 5개까지 첨부할 수 있습니다.');
      return;
    }
    try {
      final List<XFile> images = await _picker.pickMultiImage(limit: remaining);
      if (images.isNotEmpty) {
        newImages.addAll(images.map((x) => File(x.path)));
      }
    } catch (e) {
      Get.snackbar('오류', '이미지를 불러오는 중 문제가 발생했습니다.');
    }
  }

  void removeExistingImage(int index) {
    existingImageUrls.removeAt(index);
  }

  void removeNewImage(int index) {
    newImages.removeAt(index);
  }

  int get totalImageCount => existingImageUrls.length + newImages.length;

  Future<void> submitEdit() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      Get.snackbar('알림', '제목과 내용을 모두 입력해주세요.');
      return;
    }

    isSubmitting.value = true;
    try {
      // 새 이미지 업로드
      final List<String> newUploadedUrls = [];
      for (final imageFile in newImages) {
        try {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${post.authorUid}.jpg';
          final ref = FirebaseStorage.instance
              .ref()
              .child('community_images')
              .child(fileName);
          await ref.putFile(imageFile);
          final url = await ref.getDownloadURL();
          newUploadedUrls.add(url);
        } catch (e) {
          debugPrint('⚠️ Image upload failed: $e');
        }
      }

      // 최종 이미지 URL 목록 (기존 유지된 것 + 새로 업로드된 것)
      final finalImageUrls = [...existingImageUrls, ...newUploadedUrls];

      Map<String, dynamic>? petInfo;
      if (['실종', '임시보호'].contains(post.subCategoryTag)) {
        petInfo = {
          'name': petNameController.text.trim(),
          'breed': petBreedController.text.trim(),
          'age': petAgeController.text.trim(),
          'gender': selectedPetGender.value,
          'features': petFeatureController.text.trim(),
          'health': petHealthController.text.trim(),
          'isNeutered': isNeutered.value,
          'incidentDate': selectedIncidentDate.value != null ? Timestamp.fromDate(selectedIncidentDate.value!) : null,
        };
      }

      await _repository.updatePost(
        post.id, 
        title, 
        content,
        petInfo: petInfo,
        incidentLocations: post.subCategoryTag == '실종' ? incidentLocations : null,
        imageUrls: finalImageUrls, // ← 추가
      );
      
      final updatedPost = post.copyWith(
        title: title,
        content: content,
        imageUrls: finalImageUrls, // ← 추가
        petInfo: petInfo,
        incidentLocations: post.subCategoryTag == '실종' ? incidentLocations.toList() : null,
        isEdited: true,
        updatedAt: DateTime.now(),
      );
      
      Get.back(result: updatedPost); 
    } catch (e) {
      Get.snackbar('오류', '게시글 수정 중 오류가 발생했습니다: $e');
    } finally {
      isSubmitting.value = false;
    }
  }
}
