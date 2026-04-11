import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/community_post.dart';
import '../post_detail_controller.dart';
import '../post_edit_page.dart';
import '../../auth/auth_controller.dart';

void showPostMenu(BuildContext context, PostDetailController controller, {Function(CommunityPost)? onEditComplete}) {
  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (controller.isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.deepBrown),
                title: const Text('게시글 수정하기', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w500)),
                onTap: () async {
                  Get.back();
                  final result = await Get.to(() => PostEditPage(post: controller.post));
                  if (result != null && result is CommunityPost) {
                    controller.updatePostData(result);
                    if (onEditComplete != null) {
                      onEditComplete(result);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('게시글 삭제하기', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Get.back();
                  controller.showDeleteConfirmDialog();
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred, color: Colors.redAccent),
                title: const Text('게시글 신고하기', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Get.back();
                  controller.reportPost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: const Text('이 사용자 차단하기', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Get.back();
                  _showBlockUserDialog(
                    context: context,
                    targetUid: controller.post.authorUid,
                    targetNickname: controller.post.authorNickname,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

void showCommentMenu(BuildContext context, PostDetailController controller, dynamic comment, bool isMyComment) {
  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isMyComment) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.deepBrown),
                title: const Text('댓글 수정하기', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w500)),
                onTap: () {
                  Get.back();
                  controller.startEditingComment(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('댓글 삭제하기', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Get.back();
                  controller.deleteComment(comment.id);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred, color: Colors.redAccent),
                title: const Text('댓글 신고하기', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                onTap: () {
                  Get.back();
                  controller.reportComment(comment.id);
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 사용자 차단 확인 다이얼로그
void _showBlockUserDialog({
  required BuildContext context,
  required String targetUid,
  required String targetNickname,
}) {
  Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        '사용자 차단',
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown),
      ),
      content: Text(
        '$targetNickname님을 차단하시겠습니까?\n\n'
        '차단된 사용자의 게시글과 댓글이 더 이상 보이지 않습니다. '
        '차단은 언제든지 설정에서 해제할 수 있습니다.',
        style: const TextStyle(color: AppColors.mocha, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('취소', style: TextStyle(color: AppColors.taupe)),
        ),
        TextButton(
          onPressed: () async {
            Get.back(); // 다이얼로그 닫기
            if (Get.isRegistered<AuthController>()) {
              await Get.find<AuthController>().blockUser(
                targetUid,
                targetNickname: targetNickname,
              );
              await Future.delayed(const Duration(seconds: 2));
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: const Text(
            '차단',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
