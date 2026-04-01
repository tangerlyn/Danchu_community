import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_colors.dart';
import '../../../domain/entities/place_entity.dart';
import '../../../data/repositories/review_repository_impl.dart';
import '../controllers/home_controller.dart';

/// Bottom DraggableScrollableSheet showing search results after submission.
class BottomResultsSheet extends GetView<HomeController> {
  const BottomResultsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.showBottomSheet.value) return const SizedBox.shrink();

      return DraggableScrollableSheet(
        controller: controller.sheetController,
        initialChildSize: 0.5,
        minChildSize: 0.12,
        maxChildSize: 0.5,
        snap: true,
        snapSizes: const [0.12, 0.5],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: AppColors.mocha.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, -2)),
              ],
            ),
            child: ClipRect(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.sand,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Result count
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Row(
                              children: [
                                Obx(() => Text(
                                  '검색 결과 ${controller.searchResults.length}건',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.deepBrown,
                                  ),
                                )),
                                const Spacer(),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 30),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    alignment: Alignment.centerRight,
                                  ),
                                  onPressed: () {
                                    controller.showBottomSheet.value = false;
                                    controller.hideCategories.value = false;
                                  },
                                  child: const Text('닫기', style: TextStyle(color: AppColors.taupe)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.sand),
                        ],
                      ),
                    ),
                  ),

                  // Results list
                  Expanded(
                    child: Obx(() {
                      if (controller.isSearching.value) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.deepBrown));
                      }
                      
                      if (controller.searchResults.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 64, color: AppColors.sand),
                              const SizedBox(height: 16),
                              const Text(
                                '검색 결과가 없습니다',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.latte),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '검색어를 확인하거나 지도를 이동해보세요',
                                style: TextStyle(fontSize: 14, color: AppColors.taupe),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: controller.onSearchInMapArea,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('현재 지도에서 재검색'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.white,
                                  foregroundColor: AppColors.deepBrown,
                                  elevation: 0,
                                  side: const BorderSide(color: AppColors.sand),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 30),
                        itemCount: controller.searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.sand),
                        itemBuilder: (context, index) {
                          final place = controller.searchResults[index];
                          return _ResultListTile(
                            place: place,
                            onTap: () => controller.onPlaceTapped(place),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _ResultListTile extends StatelessWidget {
  final PlaceEntity place;
  final VoidCallback onTap;

  const _ResultListTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.sand.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.place, color: AppColors.deepBrown),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.deepBrown),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.roadAddress.isNotEmpty ? place.roadAddress : place.address,
                    style: const TextStyle(fontSize: 13, color: AppColors.latte),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if (place.category.isNotEmpty)
                        Text(
                          place.category,
                          style: const TextStyle(fontSize: 11, color: AppColors.taupe),
                        ),
                      if (place.category.isNotEmpty)
                        const SizedBox(width: 8),
                      FutureBuilder<(double, int)>(
                        future: Get.find<ReviewRepositoryImpl>().getPlaceRatingInfo(place.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.$2 > 0) {
                            final rating = snapshot.data!.$1;
                            return Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (place.distance > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    place.distanceLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.latte,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.taupe),
          ],
        ),
      ),
    );
  }
}
