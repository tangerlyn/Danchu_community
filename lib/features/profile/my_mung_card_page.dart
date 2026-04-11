import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import 'profile_controller.dart';
import 'widgets/mung_card_widget.dart';
import '../community/community_constants.dart';

class MyMungCardPage extends StatelessWidget {
  const MyMungCardPage({super.key});

  ProfileController get controller => Get.isRegistered<ProfileController>()
      ? Get.find<ProfileController>()
      : Get.put(ProfileController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deepBrown),
          onPressed: () {
            controller.isLoading.value = false;
            if (controller.isEditing.value) {
              controller.isEditing.value = false;
            }
            controller.fetchProfile();
            Get.back();
          },
        ),
        title: const Text(
          "내 단추 카드",
          style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Obx(() {
            if (controller.isEditing.value) {
              return _buildEditForm(context);
            } else if (controller.userProfile.value == null) {
              return const Center(child: Text("프로필 정보가 없습니다."));
            } else {
              return _buildCarouselView(context);
            }
          }),
          // Loading overlay
          Obx(() => controller.isLoading.value
              ? Container(
                  color: AppColors.mocha.withOpacity(0.12),
                  child: const Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  // ─── Carousel View ───
  Widget _buildCarouselView(BuildContext context) {
    controller.currentDogIndex.value = 0;
    final pageController = PageController(viewportFraction: 0.85);

    // Sync pageController with controller index
    pageController.addListener(() {
      final page = pageController.page?.round() ?? 0;
      if (page != controller.currentDogIndex.value) {
        controller.currentDogIndex.value = page;
      }
    });

    return Column(
      children: [
        const SizedBox(height: 20),

        // ─── PageView Carousel ───
        Expanded(
          child: Obx(() {
            final dogs = controller.dogs;
            final targetPage = controller.currentDogIndex.value;
            final itemCount = dogs.length + 1; // +1 for "add" card

            // Sync PageView position after list changes (e.g. deletion)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (pageController.hasClients &&
                  pageController.page?.round() != targetPage) {
                pageController.jumpToPage(targetPage);
              }
            });

            return Stack(
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: itemCount,
                  onPageChanged: (index) {
                    controller.currentDogIndex.value = index;
                  },
                  itemBuilder: (context, index) {
                    if (index == dogs.length) {
                      // ─── Add Dog Card ───
                      return _buildAddDogCard();
                    }
                    // ─── Dog Card ───
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: MungCardWidget(
                            dog: dogs[index],
                            profile: controller.userProfile.value,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // ─── Left Arrow ───
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Obx(() {
                      if (controller.currentDogIndex.value <= 0) {
                        return const SizedBox.shrink();
                      }
                      return _buildArrowButton(
                        icon: Icons.chevron_left,
                        onTap: () {
                          pageController.animateToPage(
                            controller.currentDogIndex.value - 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      );
                    }),
                  ),
                ),

                // ─── Right Arrow ───
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Obx(() {
                      if (controller.currentDogIndex.value >= controller.dogs.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return _buildArrowButton(
                        icon: Icons.chevron_right,
                        onTap: () {
                          pageController.animateToPage(
                            controller.currentDogIndex.value + 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      );
                    }),
                  ),
                ),
              ],
            );
          }),
        ),

        // ─── Dot Indicator ───
        Obx(() {
          final dogs = controller.dogs;
          final totalDots = dogs.length + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalDots, (index) {
                final isActive = controller.currentDogIndex.value == index;
                final isAddCard = index == dogs.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isAddCard
                        ? (isActive ? AppColors.taupe : AppColors.sand)
                        : (isActive ? const Color(0xFF5D4037) : const Color(0xFFD7CCC8)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          );
        }),

        // ─── Action Buttons ───
        Obx(() {
          final dogs = controller.dogs;
          final idx = controller.currentDogIndex.value;
          if (idx >= dogs.length) return const SizedBox(height: 20); // On add card

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              children: [
                // Edit Button
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        controller.startEditDog(idx);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("수정하기"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                // Delete Button (only if more than 1 dog)
                if (dogs.length > 1) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: OutlinedButton(
                      onPressed: () => _showDeleteConfirm(idx),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: AppColors.sand),
                      ),
                      child: Icon(Icons.delete_outline, color: AppColors.latte, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildArrowButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.mocha.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF5D4037), size: 22),
      ),
    );
  }

  Widget _buildAddDogCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: GestureDetector(
        onTap: () => controller.startAddDog(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.sand,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.sand.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 32, color: AppColors.taupe),
                ),
                const SizedBox(height: 16),
                Text(
                  "새 단카 추가",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.latte,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "강아지를 더 등록해보세요!",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.taupe,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(int index) {
    final dog = controller.dogs[index];
    Get.defaultDialog(
      title: "단카 삭제",
      middleText: "${dog.dogName}의 단카를 삭제하시겠습니까?",
      textConfirm: "삭제",
      textCancel: "취소",
      confirmTextColor: AppColors.white,
      buttonColor: AppColors.deepBrown,
      onConfirm: () {
        Get.back();
        controller.deleteDog(index);
      },
    );
  }

  // ─── Edit Form ───
  Widget _buildEditForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Picker
          Center(
            child: GestureDetector(
              onTap: controller.pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Obx(() {
                    if (controller.pickedImage.value != null) {
                      return CircleAvatar(radius: 60, backgroundImage: FileImage(controller.pickedImage.value!));
                    }
                    // 편집 중인 강아지 이미지만 확인 (보호자 프로필 이미지 fallback 제거)
                    final idx = controller.currentDogIndex.value;
                    if (idx < controller.dogs.length) {
                      final url = controller.dogs[idx].profileImageUrl;
                      if (url.isNotEmpty) {
                        return CircleAvatar(radius: 60, backgroundImage: CachedNetworkImageProvider(url));
                      }
                    }
                    // 이미지 없으면 빈 아이콘 (보호자 프로필 이미지 사용 안 함)
                    return const CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.taupe,
                      child: Icon(Icons.add_a_photo, size: 40, color: AppColors.white),
                    );
                  }),
                  Container(
                    decoration: const BoxDecoration(color: Color(0xFF5D4037), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.camera_alt, color: AppColors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Dog Name
          const Text("강아지 이름", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Obx(() {
            final nameLen = controller.dogNameLength.value;
            return TextField(
              controller: controller.dogNameController,
              maxLength: 10,
              onChanged: (val) {
                controller.dogNameLength.value = val.length;
              },
              decoration: _inputDecoration("이름을 입력해주세요").copyWith(
                counterText: '$nameLen/10',
                counterStyle: const TextStyle(fontSize: 12, color: AppColors.taupe),
              ),
            );
          }),
          const SizedBox(height: 20),

          // Weight (Added)
          const Text("몸무게 (kg)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: controller.dogWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: _inputDecoration("예: 5.4"),
          ),
          const SizedBox(height: 20),

          // Breed
          const Text("견종", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showBreedSearchSheet(),
            child: AbsorbPointer(
              child: TextField(
                controller: controller.dogBreedController,
                decoration: InputDecoration(
                  hintText: "견종을 선택해주세요",
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.taupe),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Gender
          const Text("성별", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Obx(() => Row(
            children: [
              _genderChip('Male', '수컷 ♂', AppColors.deepBrown),
              const SizedBox(width: 12),
              _genderChip('Female', '암컷 ♀', AppColors.latte),
            ],
          )),
          const SizedBox(height: 20),

          // Bio
          const Text("한줄 소개", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Stack(
            children: [
              TextField(
                controller: controller.dogBioController,
                maxLines: 5,
                maxLength: 100,
                onChanged: (v) {
                  final lines = v.split('\n');
                  if (lines.length > 5) {
                    final limited = lines.take(5).join('\n');
                    controller.dogBioController.text = limited;
                    controller.dogBioController.selection = TextSelection.collapsed(
                      offset: limited.length,
                    );
                  }
                  controller.dogBioLength.value = controller.dogBioController.text.length;
                },
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: _inputDecoration("강아지를 한 단계 더 소개해주세요! (예: 겁이 많아요, 간식을 좋아해요)").copyWith(
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 8,
                child: Obx(() => Text(
                  "${controller.dogBioLength.value}/100",
                  style: const TextStyle(fontSize: 11, color: AppColors.taupe),
                )),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Birthday
          const Text("생일 ", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Obx(() => DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: controller.birthYear.value,
                  decoration: _inputDecoration("년"),
                  items: List.generate(DateTime.now().year - 2000 + 1, (index) {
                    final year = DateTime.now().year - index;
                    return DropdownMenuItem(value: year, child: Text("$year"));
                  }),
                  onChanged: (v) { if (v != null) controller.setBirthYear(v); },
                )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(() => DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: controller.birthMonth.value,
                  decoration: _inputDecoration("월"),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("선택")),
                    ...List.generate(12, (i) => i + 1).map((m) =>
                        DropdownMenuItem(value: m, child: Text("$m"))),
                  ],
                  onChanged: controller.setBirthMonth,
                )),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(() => DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: controller.birthDay.value,
                  decoration: _inputDecoration("일"),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("선택")),
                    ...List.generate(31, (i) => i + 1).map((d) =>
                        DropdownMenuItem(value: d, child: Text("$d"))),
                  ],
                  onChanged: controller.setBirthDay,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(() => Text(
            "나이: ${controller.dogAgeString}",
            style: const TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold, fontSize: 15),
          )),

          const SizedBox(height: 20),

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    controller.isEditing.value = false;
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("취소", style: TextStyle(color: AppColors.taupe)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => controller.saveDog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("저장하기", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderChip(String value, String label, Color color) {
    final isSelected = controller.dogGender.value == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.dogGender.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.sand,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.latte,
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.white,
    );
  }

  void _showBreedSearchSheet() {
    List<String> filteredBreeds = List.from(CommunityConstants.dogBreeds);
    Timer? debounce;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(16),
            height: Get.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const Text(
                  '견종 검색',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: '견종을 입력하세요 (예: 말티즈)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 250), () {
                      setModalState(() {
                        final query = value.trim().toLowerCase();
                        if (query.isNotEmpty) {
                          filteredBreeds = CommunityConstants.dogBreeds
                              .where((breed) => breed.toLowerCase().contains(query))
                              .toList();
                        } else {
                          filteredBreeds = List.from(CommunityConstants.dogBreeds);
                        }
                      });
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredBreeds.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '검색 결과가 없어요.\n아래 "기타"를 선택하실 수 있습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Center(
                                child: Text(
                                  '기타',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    decorationThickness: 1.5,
                                  ),
                                ),
                              ),
                              onTap: () {
                                controller.dogBreedController.text = '기타';
                                Get.back();
                              },
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: filteredBreeds.length,
                          itemBuilder: (context, index) {
                            final breed = filteredBreeds[index];
                            return ListTile(
                              title: Text(breed),
                              onTap: () {
                                controller.dogBreedController.text = breed;
                                Get.back();
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    ).then((_) => debounce?.cancel()); // 바텀시트 닫힐 때 타이머 정리
  }
}
