import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/app_colors.dart';
import '../../../data/repositories/review_repository_impl.dart';
import '../../../domain/entities/place_entity.dart';
import '../../../domain/repositories/review_repository.dart';
import '../controllers/place_detail_controller.dart';
import 'review_list_widget.dart';
import 'review_write_sheet.dart';

/// Bottom panel showing details of a selected place.
class PlaceDetailPanel extends StatefulWidget {
  final PlaceEntity place;
  final VoidCallback onClose;

  const PlaceDetailPanel({super.key, required this.place, required this.onClose});

  @override
  State<PlaceDetailPanel> createState() => _PlaceDetailPanelState();
}

class _PlaceDetailPanelState extends State<PlaceDetailPanel> {
  late final PlaceDetailController controller;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      PlaceDetailController(
        repository: Get.find<ReviewRepositoryImpl>(),
        place: widget.place,
      ),
      tag: widget.place.id, // Ensure unique controller instance per place
    );
  }

  @override
  void dispose() {
    Get.delete<PlaceDetailController>(tag: widget.place.id);
    super.dispose();
  }

  void _showWriteReviewSheet({String? reviewId, int initialRating = 0, String initialContent = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReviewWriteSheet(
        initialRating: initialRating,
        initialContent: initialContent,
        onSubmit: (rating, content) {
          if (reviewId != null) {
            return controller.updateReview(reviewId, rating, content);
          } else {
            return controller.submitReview(rating, content);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutQuad,
      transform: Matrix4.translationValues(0, _dragOffset, 0),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: AppColors.mocha.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar with drag gesture
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) {
                setState(() {
                  _isDragging = true;
                });
              },
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! > 0) { // Only allow dragging down
                  setState(() {
                    _dragOffset += details.primaryDelta!;
                  });
                }
              },
              onVerticalDragEnd: (details) {
                setState(() => _isDragging = false);
                if (_dragOffset > 80 || details.primaryVelocity! > 300) {
                  // Animate out completely then close
                  setState(() {
                    _dragOffset = MediaQuery.of(context).size.height;
                  });
                  Future.delayed(const Duration(milliseconds: 250), () {
                    if (mounted) widget.onClose();
                  });
                } else {
                  // Snap back
                  setState(() => _dragOffset = 0.0);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // Scrollable Content area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.sand.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.place, color: AppColors.deepBrown, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(
                                widget.place.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.place.category.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                                  child: Text(
                                    widget.place.category,
                                    style: const TextStyle(fontSize: 13, color: AppColors.taupe),
                                  ),
                                ),
                              // Rating & Reviews Summary
                              Obx(() {
                                if (controller.isLoading.value) return const SizedBox();
                                return Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      controller.averageRating.value.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${controller.reviewCount.value})',
                                      style: const TextStyle(fontSize: 13, color: AppColors.taupe),
                                    ),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                      Obx(() => IconButton(
                        icon: Icon(
                          controller.isBookmarked.value ? Icons.bookmark : Icons.bookmark_border,
                          color: controller.isBookmarked.value ? AppColors.deepBrown : AppColors.latte,
                        ),
                        onPressed: controller.toggleBookmark,
                      )),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.latte),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Distance
                  if (widget.place.distance > 0)
                    _infoRow(Icons.straighten, '현재 위치에서 ${widget.place.distanceLabel}'),

                  // Info rows
                  if (widget.place.roadAddress.isNotEmpty)
                    _infoRow(Icons.location_on_outlined, widget.place.roadAddress),
                  if (widget.place.address.isNotEmpty && widget.place.address != widget.place.roadAddress)
                    _infoRow(Icons.map_outlined, widget.place.address),
                  if (widget.place.telephone.isNotEmpty)
                    _infoRow(Icons.phone_outlined, widget.place.telephone),
                    
                  const Divider(height: 32, color: AppColors.sand),
                  
                  // Reviews Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('후기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
                      TextButton.icon(
                        onPressed: _showWriteReviewSheet,
                        icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.mocha),
                        label: const Text('후기 작성하기', style: TextStyle(fontSize: 13, color: AppColors.mocha, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: AppColors.sand.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Review List Body
                  Obx(() {
                    if (controller.isLoading.value) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.latte),
                          ),
                        ),
                      );
                    }
                    return ReviewListWidget(
                      reviews: controller.reviews.toList(),
                      onEdit: (review) {
                        _showWriteReviewSheet(
                          reviewId: review.id,
                          initialRating: review.rating,
                          initialContent: review.content,
                        );
                      },
                      onDelete: (review) async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.white,
                            title: const Text('후기 삭제'),
                            content: const Text('이 후기를 삭제하시겠습니까?\n삭제된 후기는 복구할 수 없습니다.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          controller.deleteReview(review.id);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.taupe),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.latte),
            ),
          ),
        ],
      ),
    );
  }
}
