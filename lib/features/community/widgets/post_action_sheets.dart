import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/community_post.dart';
import '../post_detail_controller.dart';
import '../post_edit_page.dart';

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
