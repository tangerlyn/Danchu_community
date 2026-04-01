import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_colors.dart';
import '../controllers/home_controller.dart';

/// Horizontal scrollable category chips using ListView.builder.
class CategoryChipsWidget extends GetView<HomeController> {
  final Function(String)? onCategorySelected;
  
  const CategoryChipsWidget({super.key, this.onCategorySelected});


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Obx(() {
        final selected = controller.selectedCategory.value;
        return ListView.builder(
          clipBehavior: Clip.none,
          scrollDirection: Axis.horizontal,
          itemCount: HomeController.categories.length + 1, // +1 for Bookmark chip
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            // Bookmark chip at first position
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('관심장소'),
                  selected: false,
                  backgroundColor: AppColors.sand.withOpacity(0.3),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepBrown,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.sand),
                  ),
                  showCheckmark: false,
                  onSelected: (_) => controller.showBookmarkedPlaces(),
                ),
              );
            }

            final cat = HomeController.categories[index - 1]; // Offset index
            final isSelected = cat == selected;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: AppColors.deepBrown,
                backgroundColor: AppColors.sand.withOpacity(0.3),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.white : AppColors.deepBrown,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors.sand),
                ),
                showCheckmark: false,
                onSelected: (_) {
                  controller.onCategoryTapped(cat);
                  onCategorySelected?.call(cat);
                },
              ),
            );
          },
        );
      }),
    );
  }
}
