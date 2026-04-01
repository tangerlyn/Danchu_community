import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_colors.dart';
import '../controllers/home_controller.dart';

/// "현 지도에서 검색" button — appears at the top center
/// when the user drags the map (onCameraMove).
class SearchInMapButton extends GetView<HomeController> {
  const SearchInMapButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.showSearchInMapButton.value ||
          controller.selectedPlace.value != null) {
        return const SizedBox.shrink();
      }

      return Center(
        child: GestureDetector(
          onTap: controller.onSearchInMapArea,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mocha.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 16, color: AppColors.deepBrown),
                SizedBox(width: 6),
                Text(
                  '현 지도에서 검색',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepBrown,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
