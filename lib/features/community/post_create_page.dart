import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import 'post_create_controller.dart';
import 'community_constants.dart';
import 'widgets/pet_report_form.dart';
import '../profile/profile_controller.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  bool _showDateTimeFields = false;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PostCreateController());
    if (!Get.isRegistered<ProfileController>()) {
      Get.put(ProfileController());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final hasContent = controller.titleController.text.trim().isNotEmpty ||
            controller.contentController.text.trim().isNotEmpty ||
            controller.selectedImages.isNotEmpty;
        if (!hasContent) {
          Navigator.of(context).pop();
          return;
        }
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('나가시겠어요?',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
            content: const Text('작성 중인 글이 저장되지 않습니다. 나가시겠어요?',
                style: TextStyle(color: AppColors.mocha)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('이어서 작성',
                    style: TextStyle(color: AppColors.taupe, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('나가기',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          title: const Text('글쓰기', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            Obx(() {
              return TextButton(
                onPressed: controller.isLoading.value ? null : () => controller.submitPost(),
                child: controller.isLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepBrown),
                      )
                    : const Text('등록', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold, fontSize: 16)),
              );
            }),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selectors
              Obx(() {
                final mainCat = controller.selectedMainCategory.value;
                final subTags = CommunityConstants.getSubTagsForCategory(mainCat).where((t) => t != '전체').toList();
                
                if (subTags.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('태그 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mocha)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: subTags.map((tag) {
                          final isSelected = controller.selectedSubCategory.value == tag || 
                                           (controller.selectedSubCategory.value == '전체' && tag == subTags.first);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () => controller.selectedSubCategory.value = tag,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.deepBrown : AppColors.sand.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? AppColors.deepBrown : AppColors.sand,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.white : AppColors.deepBrown,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }),
              const SizedBox(height: 24),

              // Title
              TextField(
                controller: controller.titleController,
                decoration: const InputDecoration(
                  hintText: '제목을 입력하세요',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
              ),
              const SizedBox(height: 16),

              // Dynamic Meetup Form Phase
              // Dynamic Form Phase (Meetup or Pet Report)
              Obx(() {
                final mainCat = controller.selectedMainCategory.value;
                final subCat = controller.selectedSubCategory.value;

                if (mainCat == '모임') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 날짜/시간 토글 버튼
                      if (!_showDateTimeFields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => setState(() => _showDateTimeFields = true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.sand.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.sand),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 18, color: AppColors.deepBrown),
                                  SizedBox(width: 6),
                                  Text('날짜·시간 추가하기',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.deepBrown)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // 날짜/시간 필드 (토글 시 표시)
                      if (_showDateTimeFields)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMeetupField(
                              icon: Icons.calendar_today_outlined,
                              title: '날짜',
                              child: InkWell(
                                onTap: () => controller.selectMeetupDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.sand.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Obx(() => Text(
                                        controller.selectedMeetupDate.value != null
                                            ? DateFormat('yyyy.MM.dd').format(controller.selectedMeetupDate.value!)
                                            : '날짜 선택',
                                        style: TextStyle(
                                          color: controller.selectedMeetupDate.value != null ? AppColors.deepBrown : AppColors.taupe,
                                          fontSize: 14,
                                        ),
                                      )),
                                      const Spacer(),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.taupe),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMeetupField(
                              icon: Icons.access_time_outlined,
                              title: '시간',
                              child: InkWell(
                                onTap: () => controller.selectMeetupTime(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.sand.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Obx(() => Text(
                                        controller.selectedMeetupDate.value != null
                                            ? DateFormat('a h:mm', 'ko_KR').format(controller.selectedMeetupDate.value!)
                                            : '시간 선택',
                                        style: TextStyle(
                                          color: controller.selectedMeetupDate.value != null ? AppColors.deepBrown : AppColors.taupe,
                                          fontSize: 14,
                                        ),
                                      )),
                                      const Spacer(),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.taupe),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMeetupField(
                              icon: Icons.location_on_outlined,
                              title: '장소',
                              child: InkWell(
                                onTap: () => controller.pickLocation(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.sand.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Obx(() => Text(
                                          controller.selectedMeetingPlace.value ?? '장소 선택',
                                          style: TextStyle(
                                            color: controller.selectedMeetingPlace.value != null ? AppColors.deepBrown : AppColors.taupe,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.taupe),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMeetupField(
                              icon: Icons.people_outline,
                              title: '모집 인원',
                              child: InkWell(
                                onTap: () => controller.selectMeetupCapacity(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.sand.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Obx(() => Text(
                                        controller.selectedMeetupCapacity.value != null
                                            ? '${controller.selectedMeetupCapacity.value}명'
                                            : '인원 선택',
                                        style: TextStyle(
                                          color: controller.selectedMeetupCapacity.value != null ? AppColors.deepBrown : AppColors.taupe,
                                          fontSize: 14,
                                        ),
                                      )),
                                      const Spacer(),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.taupe),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.sand, thickness: 1),
                      const SizedBox(height: 16),
                    ],
                  );
                } else if (mainCat == '신고' && ['실종', '임시보호'].contains(subCat)) {
                  return Column(
                    children: [
                      PetReportForm(
                        isMissing: subCat == '실종',
                        nameController: controller.petNameController,
                        breedController: controller.petBreedController,
                        ageController: controller.petAgeController,
                        featureController: controller.petFeatureController,
                        healthController: controller.petHealthController,
                        selectedGender: controller.selectedPetGender,
                        isNeutered: controller.isNeutered,
                        incidentLocations: controller.incidentLocations,
                        selectedDate: controller.selectedIncidentDate,
                        onSelectDate: (ctx) => controller.selectIncidentDate(ctx),
                        onAddLocation: () => controller.addIncidentLocation(),
                        onRemoveLocation: (idx) => controller.removeIncidentLocation(idx),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.sand, thickness: 1),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),

              // Content
              TextField(
                controller: controller.contentController,
                maxLines: 10,
                minLines: 5,
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요.\n반려견과의 소중한 이야기를 들려주세요.',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: const TextStyle(fontSize: 16, color: AppColors.mocha),
              ),
              const SizedBox(height: 24),

              // Image Picker Button & List
              Row(
                children: [
                  Obx(() {
                    final isFull = controller.selectedImages.length >= 5;
                    return GestureDetector(
                      onTap: isFull ? null : controller.pickImages,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isFull ? AppColors.sand.withOpacity(0.5) : AppColors.sand,
                          borderRadius: BorderRadius.circular(12),
                          border: isFull ? Border.all(color: AppColors.sand) : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: isFull ? AppColors.taupe.withOpacity(0.5) : AppColors.taupe),
                            const SizedBox(height: 4),
                            Text('${controller.selectedImages.length}/5', 
                              style: TextStyle(
                                color: isFull ? AppColors.taupe.withOpacity(0.5) : AppColors.taupe, 
                                fontSize: 12,
                                fontWeight: isFull ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 80,
                      child: Obx(() => ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.selectedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    controller.selectedImages[index],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => controller.removeImage(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black54,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetupField({required IconData icon, required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.taupe),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mocha)),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/*
// ==========================================
// --- Legacy UI Code (For reference)
// ==========================================
import 'dart:io';
// ... previous implementation without meetup form
*/
