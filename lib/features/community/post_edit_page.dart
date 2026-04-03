import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/community_post.dart';
import 'post_edit_controller.dart';
import 'widgets/pet_report_form.dart';

class PostEditPage extends StatelessWidget {
  final CommunityPost post;

  const PostEditPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PostEditController(post: post), tag: post.id);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text('수정하기', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          Obx(() => TextButton(
            onPressed: controller.isSubmitting.value ? null : () => controller.submitEdit(),
            child: controller.isSubmitting.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepBrown),
                  )
                : const Text('저장', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold, fontSize: 16)),
          )),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              // Pet Report Form (Optional)
              if (['실종', '임시보호'].contains(post.subCategoryTag)) ...[
                PetReportForm(
                  isMissing: post.subCategoryTag == '실종',
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

              // Content
              TextField(
                controller: controller.contentController,
                maxLines: 10,
                minLines: 5,
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요.',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: const TextStyle(fontSize: 16, color: AppColors.mocha),
              ),
              const SizedBox(height: 24),

              // Image Selection Section
              const Text('사진 (최대 5장)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mocha)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Obx(() {
                    final total = controller.totalImageCount;
                    final isFull = total >= 5;
                    return GestureDetector(
                      onTap: isFull ? null : controller.pickImages,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isFull ? AppColors.sand.withOpacity(0.5) : AppColors.sand,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: isFull ? AppColors.taupe.withOpacity(0.5) : AppColors.taupe),
                            const SizedBox(height: 4),
                            Text('$total/5',
                              style: TextStyle(
                                color: isFull ? AppColors.taupe.withOpacity(0.5) : AppColors.taupe,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
                      child: Obx(() => ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: controller.combinedImages.length,
                        onReorder: controller.reorderImages,
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              final scale = 1.0 + (animation.value * 0.08);
                              return Transform.scale(
                                scale: scale,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  shadowColor: Colors.black38,
                                  child: child,
                                ),
                              );
                            },
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final item = controller.combinedImages[index];
                          final String key = item is String ? item : (item as File).path;
                          return Padding(
                            key: ValueKey(key),
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: item is String
                                      ? CachedNetworkImage(
                                          imageUrl: item,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: AppColors.sand),
                                          errorWidget: (context, url, error) => const Icon(Icons.error),
                                        )
                                      : Image.file(
                                          item as File,
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
}
