import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../domain/entities/join_request.dart';
import '../../../data/repositories/community_repository_impl.dart';
import '../../../services/fcm_service.dart';

class JoinRequestListController extends GetxController {
  final CommunityRepositoryImpl _repository = CommunityRepositoryImpl();
  final String postId;

  var requests = <JoinRequest>[].obs;
  var isLoading = true.obs;

  JoinRequestListController({required this.postId});

  @override
  void onInit() {
    super.onInit();
    _listenRequests();
  }

  void _listenRequests() {
    _repository.getJoinRequestsStream(postId).listen((data) {
      requests.value = data;
      isLoading.value = false;
    });
  }

  Future<void> acceptRequest(JoinRequest request) async {
    try {
      await _repository.acceptJoinRequest(postId, request.id, request.uid);
      Get.snackbar('알림', '${request.nickname}님의 참가를 승인했습니다.');
      
      // Notify user
      FcmService.sendJoinResultNotification(
        targetUid: request.uid,
        postId: postId,
        isAccepted: true,
      );
    } catch (e) {
      debugPrint('⚠️ acceptRequest error: $e');
      Get.snackbar('오류', '승인 중 문제가 발생했습니다: $e');
    }
  }

  Future<void> rejectRequest(JoinRequest request) async {
    try {
      await _repository.rejectJoinRequest(postId, request.id);
      Get.snackbar('알림', '${request.nickname}님의 참가를 거절했습니다.');

      // Notify user
      FcmService.sendJoinResultNotification(
        targetUid: request.uid,
        postId: postId,
        isAccepted: false,
      );
    } catch (e) {
      debugPrint('⚠️ rejectRequest error: $e');
      Get.snackbar('오류', '거절 중 문제가 발생했습니다: $e');
    }
  }
}
