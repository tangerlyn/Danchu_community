import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_colors.dart';
import '../controllers/home_controller.dart';

class SearchBarWidget extends GetView<HomeController> {
  final bool isFullScreen;

  const SearchBarWidget({super.key, this.isFullScreen = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller.searchController,
        builder: (context, value, child) {
          return TextField(
            controller: controller.searchController,
            focusNode: controller.searchFocusNode,
            onChanged: controller.onSearchTextChanged,
            onSubmitted: controller.onSearchSubmitted,
            decoration: InputDecoration(
              hintText: '장소 검색',
              hintStyle: const TextStyle(color: AppColors.taupe),
              prefixIcon: const Icon(Icons.search, color: AppColors.latte),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20, color: AppColors.taupe),
                      onPressed: () {
                        controller.onClearSearch();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: AppColors.deepBrown.withOpacity(0.3), width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          );
        },
      ),
    );
  }
}
