import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/place_entity.dart';
import '../../presentation/home/controllers/home_controller.dart';

class BookmarkedPlacesPage extends StatelessWidget {
  final bool isBottomSheet;
  const BookmarkedPlacesPage({super.key, this.isBottomSheet = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final content = user == null
        ? const Center(child: Text('로그인이 필요합니다.'))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('bookmarked_places')
                .orderBy('savedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('⚠️ Error loading bookmarked places: ${snapshot.error}');
                return const Center(child: Text('정보를 불러오지 못했어요 🐾'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.deepBrown));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('아직 저장한 장소가 없어요.', style: TextStyle(color: AppColors.taupe, fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _BookmarkCard(data: data, docId: docs[index].id, isBottomSheet: isBottomSheet);
                },
              );
            },
          );

    if (isBottomSheet) {
      return Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('관심 장소', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
          const SizedBox(height: 8),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: const Text('관심 장소', style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: content,
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isBottomSheet;

  const _BookmarkCard({required this.data, required this.docId, this.isBottomSheet = false});

  @override
  Widget build(BuildContext context) {
    final placeName = data['placeName'] ?? '장소명 없음';
    final category = data['category'] ?? '';
    final address = data['address'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToPlace(context, data),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.sand.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.place, color: AppColors.deepBrown, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placeName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.isNotEmpty)
                        Text(category, style: const TextStyle(fontSize: 12, color: AppColors.taupe)),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: const TextStyle(fontSize: 13, color: AppColors.latte),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark, color: AppColors.deepBrown, size: 24),
                  onPressed: () => _removeBookmark(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPlace(BuildContext context, Map<String, dynamic> data) {
    final place = PlaceEntity(
      id: data['placeId'] ?? docId,
      title: data['placeName'],
      address: data['address'],
      roadAddress: data['address'],
      category: data['category'],
      telephone: '',
      latitude: data['lat'],
      longitude: data['lng'],
    );

    if (Get.isRegistered<HomeController>()) {
      final homeController = Get.find<HomeController>();

      // ✅ 기존 카테고리/검색 상태 초기화
      homeController.selectedCategory.value = '';
      homeController.currentSearchQuery.value = place.title;
      homeController.searchController.text = place.title;
      homeController.nearbyPlaces.value = [place];
      homeController.searchResults.value = [place];

      homeController.onPlaceTapped(place);

      if (isBottomSheet) {
        Navigator.pop(context);
      } else {
        Get.back();
      }
    }
  }

  Future<void> _removeBookmark(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('관심 장소 삭제'),
        content: const Text('관심 장소에서 삭제하시겠습니까?'),
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookmarked_places')
          .doc(docId)
          .delete();
      Get.snackbar('관심 장소', '관심 장소에서 삭제되었습니다');
    }
  }
}
