import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/app_colors.dart';
import '../../../domain/entities/place_entity.dart';
import '../controllers/home_controller.dart';

class UnifiedSearchPanel extends StatelessWidget {
  final HomeController controller;
  final bool hasInput;
  final bool showDropdown;

  const UnifiedSearchPanel({
    super.key,
    required this.controller,
    required this.hasInput,
    required this.showDropdown,
  });

  @override
  Widget build(BuildContext context) {
    if (hasInput && showDropdown) {
      return _buildAutocompleteList(context);
    }
    return _buildRecentSearches(context);
  }

  Widget _buildAutocompleteList(BuildContext context) {
    return Obx(() {
      if (controller.isSearching.value) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (controller.searchSuggestions.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '연관된 검색어가 없습니다',
            style: TextStyle(color: AppColors.taupe, fontSize: 14),
          ),
        );
      }

      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          itemCount: controller.searchSuggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
          itemBuilder: (context, index) {
            final place = controller.searchSuggestions[index];
            return AutocompleteResultTile(
              place: place,
              onTap: () {
                controller.searchController.text = place.title;
                controller.searchFocusNode.unfocus();
                controller.showDropdown.value = false;
                controller.isSearchFocused.value = false;
                controller.currentSearchQuery.value = place.title; // ← 추가
                // ✅ nearbyPlaces에 선택한 장소 추가 → 패널 닫아도 마커 유지
                controller.nearbyPlaces.value = [place];
                controller.searchResults.value = [place];
                controller.onPlaceTapped(place);
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildRecentSearches(BuildContext context) {
    return Obx(() {
      final history = controller.searchHistory;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '최근 검색어',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown,
                  ),
                ),
                if (history.isNotEmpty)
                  GestureDetector(
                    onTap: controller.clearAllHistory,
                    child: const Text(
                      '전체 삭제',
                      style: TextStyle(fontSize: 13, color: AppColors.taupe),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    '최근 검색 기록이 없습니다.',
                    style: TextStyle(fontSize: 14, color: AppColors.taupe),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.sand),
                  itemBuilder: (context, index) {
                    final query = history[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.history, color: AppColors.taupe.withOpacity(0.6), size: 20),
                      title: Text(
                        query,
                        style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close, size: 16, color: AppColors.taupe.withOpacity(0.6)),
                        onPressed: () => controller.removeHistory(query),
                      ),
                      onTap: () {
                        controller.searchController.text = query;
                        controller.onSearchSubmitted(query);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}

class AutocompleteResultTile extends StatelessWidget {
  final PlaceEntity place;
  final VoidCallback onTap;

  const AutocompleteResultTile({super.key, required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.sand.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.place, color: AppColors.deepBrown, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    place.roadAddress.isNotEmpty ? place.roadAddress : place.address,
                    style: TextStyle(fontSize: 12, color: AppColors.latte),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (place.distance > 0)
              Text(
                place.distanceLabel,
                style: TextStyle(fontSize: 12, color: AppColors.taupe),
              ),
          ],
        ),
      ),
    );
  }
}
