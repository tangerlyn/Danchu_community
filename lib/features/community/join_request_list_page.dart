import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import 'join_request_list_controller.dart';
import '../../../domain/entities/join_request.dart';
import '../../widgets/paw_loading_indicator.dart';

class JoinRequestListPage extends StatelessWidget {
  final String postId;

  const JoinRequestListPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(JoinRequestListController(postId: postId), tag: postId);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text('참가 신청 관리',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown, fontSize: 18)),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: PawLoadingIndicator());
        }

        final pendingRequests = controller.requests.where((r) => r.status == 'pending').toList();

        if (pendingRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: AppColors.taupe.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text('새로운 참가 신청이 없습니다.',
                    style: TextStyle(color: AppColors.taupe, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: pendingRequests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final request = pendingRequests[index];
            return _buildRequestCard(context, controller, request);
          },
        );
      }),
    );
  }

  Widget _buildRequestCard(BuildContext context, JoinRequestListController controller, JoinRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.sand,
                backgroundImage: (request.profileImageUrl != null && request.profileImageUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(request.profileImageUrl!)
                    : null,
                child: (request.profileImageUrl == null || request.profileImageUrl!.isEmpty)
                    ? ClipOval(child: Image.asset('assets/icon/app_icon3.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.nickname,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown, fontSize: 16)),
                    Text(DateFormat('yyyy.MM.dd HH:mm').format(request.createdAt),
                        style: const TextStyle(color: AppColors.taupe, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sand.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              request.message,
              style: const TextStyle(color: AppColors.deepBrown, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.rejectRequest(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('거절', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => controller.acceptRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBrown,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('승인', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
