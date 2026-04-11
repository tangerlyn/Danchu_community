import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../auth/auth_controller.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final _firestore = FirebaseFirestore.instance;
  final Map<String, Map<String, dynamic>> _userInfoCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsersInfo();
  }

  /// 차단된 사용자들의 닉네임/프로필 정보를 Firestore에서 가져옴
  Future<void> _loadBlockedUsersInfo() async {
    if (!Get.isRegistered<AuthController>()) {
      setState(() => _isLoading = false);
      return;
    }

    final auth = Get.find<AuthController>();
    final blockedUids = auth.blockedUsers.toList();

    if (blockedUids.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Firestore의 'in' 쿼리는 최대 30개까지 한 번에 가능
      const chunkSize = 30;
      for (int i = 0; i < blockedUids.length; i += chunkSize) {
        final chunk = blockedUids.sublist(
          i,
          (i + chunkSize > blockedUids.length) ? blockedUids.length : i + chunkSize,
        );

        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          _userInfoCache[doc.id] = doc.data();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load blocked users info: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showUnblockDialog(String uid, String nickname) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '차단 해제',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown),
        ),
        content: Text(
          '$nickname님의 차단을 해제하시겠습니까?\n\n'
          '해제하면 해당 사용자의 게시글과 댓글이 다시 보입니다.',
          style: const TextStyle(color: AppColors.mocha, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소', style: TextStyle(color: AppColors.taupe)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              '해제',
              style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final auth = Get.find<AuthController>();
      await auth.unblockUser(uid, targetNickname: nickname);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '차단 사용자 관리',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.deepBrown,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.deepBrown),
            )
          : Obx(() {
              if (!Get.isRegistered<AuthController>()) {
                return const Center(child: Text('로그인이 필요합니다.'));
              }
              final auth = Get.find<AuthController>();
              final blockedUids = auth.blockedUsers.toList();

              if (blockedUids.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: AppColors.taupe.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '차단한 사용자가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.taupe,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          '게시글이나 댓글에서 사용자를 차단하면\n여기에 표시됩니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.taupe,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: blockedUids.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.sand,
                  indent: 72,
                ),
                itemBuilder: (context, index) {
                  final uid = blockedUids[index];
                  final userInfo = _userInfoCache[uid];
                  final nickname =
                      userInfo?['nickname'] as String? ?? '알 수 없는 사용자';
                  final profileUrl =
                      userInfo?['profileImageUrl'] as String?;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.sand,
                      child: ClipOval(
                        child: (profileUrl != null && profileUrl.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: profileUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorWidget: (_, __, ___) => Image.asset(
                                  'assets/icon/app_icon3.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/icon/app_icon3.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    title: Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBrown,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => _showUnblockDialog(uid, nickname),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.sand.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '차단 해제',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.deepBrown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
    );
  }
}
