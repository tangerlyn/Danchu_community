import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/entities/place_entity.dart';
import '../../../domain/entities/place_review.dart';
import '../../../domain/repositories/review_repository.dart';
import '../../../data/repositories/profile_repository.dart';

class PlaceDetailController extends GetxController {
  final ReviewRepository repository;
  final PlaceEntity place;
  final ProfileRepository _profileRepository = ProfileRepository();

  PlaceDetailController({required this.repository, required this.place});

  final reviews = <PlaceReview>[].obs;
  final averageRating = 0.0.obs;
  final reviewCount = 0.obs;
  final isLoading = true.obs;
  final isBookmarked = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadData();
    _checkBookmarkStatus();
  }

  Future<void> _checkBookmarkStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final addr = place.roadAddress.isNotEmpty ? place.roadAddress : place.address;
      final placeId = '${place.title}_$addr'.replaceAll(RegExp(r'[^\w]'), '_');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookmarked_places')
          .doc(placeId)
          .get();
      isBookmarked.value = doc.exists;
    } catch (e) {
      debugPrint('Error checking bookmark status: $e');
    }
  }

  Future<void> toggleBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return;
    }

    final uid = user.uid;
    final addr = place.roadAddress.isNotEmpty ? place.roadAddress : place.address;
    final placeId = '${place.title}_$addr'.replaceAll(RegExp(r'[^\w]'), '_');
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('bookmarked_places')
        .doc(placeId);

    try {
      // 저장 전 중복 체크
      final existing = await docRef.get();

      if (existing.exists) {
        // 이미 저장됨 → 삭제 (토글)
        await existing.reference.delete();
        isBookmarked.value = false;
        Get.snackbar('관심 장소', '관심 장소에서 삭제되었습니다');
      } else {
        // 없으면 저장
        await docRef.set({
          'placeId': placeId,
          'placeName': place.title,
          'category': place.category,
          'address': place.roadAddress.isNotEmpty ? place.roadAddress : place.address,
          'lat': place.latitude,
          'lng': place.longitude,
          'savedAt': FieldValue.serverTimestamp(),
        });
        isBookmarked.value = true;
        Get.snackbar('관심 장소', '관심 장소로 저장되었습니다 🔖');
      }
    } catch (e) {
      debugPrint('⚠️ Error toggling bookmark: $e');
      Get.snackbar('잠깐!', '관심 장소 저장에 실패했어요 🐾');
    }
  }

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      final ratingInfo = await repository.getPlaceRatingInfo(place.id);
      averageRating.value = ratingInfo.$1;
      reviewCount.value = ratingInfo.$2;

      final fetchedReviews = await repository.getReviews(place.id);
      reviews.assignAll(fetchedReviews);
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submitReview(int rating, String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return false;
    }

    try {
      final submitPlaceId = place.id;
      debugPrint('📝 Submitting review for Place ID: $submitPlaceId');
      
      final profile = await _profileRepository.getUserProfile(user.uid);
      final nickname = profile?.nickname ?? user.displayName ?? '익명';
      
      await repository.addReview(
        placeId: submitPlaceId,
        authorUid: user.uid,
        authorNickname: nickname,
        rating: rating,
        content: content,
      );
      
      // Refresh silently after adding to avoid flashing the loading spinner
      // Short delay ensures Firestore serverTimestamp() is properly synced locally
      await Future.delayed(const Duration(milliseconds: 600));
      
      final fetchPlaceId = place.id;
      debugPrint('🔄 Re-fetching reviews for Place ID: $fetchPlaceId');
      
      final ratingInfo = await repository.getPlaceRatingInfo(fetchPlaceId);
      averageRating.value = ratingInfo.$1;
      reviewCount.value = ratingInfo.$2;

      final fetchedReviews = await repository.getReviews(fetchPlaceId);
      reviews.assignAll(fetchedReviews);
      
      debugPrint('✅ Fetched ${fetchedReviews.length} reviews post-submission.');

      
      return true;
    } catch (e) {
      debugPrint('⚠️ Error adding review: $e');
      Get.snackbar('잠깐!', '후기 등록에 실패했어요 🐾');
      return false;
    }
  }

  Future<bool> updateReview(String reviewId, int rating, String content) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return false;
    }

    try {
      debugPrint('📝 Updating review ID: $reviewId');
      
      await repository.updateReview(
        reviewId: reviewId,
        rating: rating,
        content: content,
      );
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      final ratingInfo = await repository.getPlaceRatingInfo(place.id);
      averageRating.value = ratingInfo.$1;
      reviewCount.value = ratingInfo.$2;

      final fetchedReviews = await repository.getReviews(place.id);
      reviews.assignAll(fetchedReviews);
      
      return true;
    } catch (e) {
      debugPrint('⚠️ Error updating review: $e');
      Get.snackbar('잠깐!', '후기 수정에 실패했어요 🐾');
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    try {
      debugPrint('🗑️ Deleting review ID: $reviewId');
      
      await repository.deleteReview(reviewId);
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      final ratingInfo = await repository.getPlaceRatingInfo(place.id);
      averageRating.value = ratingInfo.$1;
      reviewCount.value = ratingInfo.$2;

      final fetchedReviews = await repository.getReviews(place.id);
      reviews.assignAll(fetchedReviews);
      
      return true;
    } catch (e) {
      debugPrint('⚠️ Error deleting review: $e');
      Get.snackbar('잠깐!', '후기 삭제에 실패했어요 🐾');
      return false;
    }
  }
}
