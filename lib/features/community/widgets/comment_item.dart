import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import 'package:get/get.dart';
import '../post_detail_controller.dart';
import 'post_action_sheets.dart'; 

class CommentItem extends StatelessWidget {
  final dynamic comment;
  final PostDetailController controller;
  final bool isMyComment;

  const CommentItem({
    super.key,
    required this.comment,
    required this.controller,
    required this.isMyComment,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      bool isEditing = controller.editingCommentId.value == comment.id;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEditing ? AppColors.sand.withOpacity(0.2) : const Color(0xFFF9F9F7),
          borderRadius: BorderRadius.circular(16),
          border: isEditing ? Border.all(color: AppColors.deepBrown.withOpacity(0.3)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.sand,
                  backgroundImage: (comment.authorProfileImageUrl != null && comment.authorProfileImageUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(comment.authorProfileImageUrl!)
                      : null,
                  child: (comment.authorProfileImageUrl == null || comment.authorProfileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 14, color: AppColors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Obx(() {
                  final isDeleted = controller.deletedCommentAuthors.contains(comment.authorUid);
                  final suffix = isDeleted ? '(X)' : '';
                  return Text('${comment.authorNickname}$suffix', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.mocha, fontSize: 13)
                  );
                }),
                const SizedBox(width: 6),
                const Text('·', style: TextStyle(color: AppColors.taupe)),
                const SizedBox(width: 6),
                Text(DateFormat('MM.dd HH:mm').format(comment.createdAt), 
                  style: const TextStyle(fontSize: 11, color: AppColors.taupe)
                ),
                if (comment.isEdited)
                  const Text(' · 수정됨', style: TextStyle(fontSize: 11, color: AppColors.taupe)),
                const Spacer(),
                if (!isEditing && !comment.isDeleted) ...[
                  GestureDetector(
                    onTap: () => controller.startReply(comment.id, comment.authorNickname),
                    child: const Text('댓글 달기', 
                      style: TextStyle(fontSize: 12, color: AppColors.taupe)
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => showCommentMenu(context, controller, comment, isMyComment),
                    child: const Icon(Icons.more_horiz, size: 18, color: AppColors.taupe),
                  ),
                ] else if (comment.isDeleted) ...[
                  // 삭제된 댓글이라도 답글 달기는 유지
                  GestureDetector(
                    onTap: () => controller.startReply(comment.id, comment.authorNickname),
                    child: const Text('댓글 달기', 
                      style: TextStyle(fontSize: 12, color: AppColors.taupe)
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller.inlineEditController,
                    focusNode: controller.inlineEditFocusNode,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: '댓글을 수정하세요...',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.sand),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.deepBrown),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: controller.cancelEditingComment,
                        child: const Text('취소', style: TextStyle(color: AppColors.taupe, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: controller.isSubmittingInlineEdit.value ? null : controller.submitInlineEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepBrown,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 32),
                        ),
                        child: controller.isSubmittingInlineEdit.value
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                            : const Text('완료', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  )
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: comment.isDeleted 
                  ? const Text(
                      '삭제된 댓글입니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.taupe,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Text(comment.content, 
                      style: const TextStyle(fontSize: 14, color: AppColors.deepBrown, height: 1.5)
                    ),
              ),
              
            // Nested Replies
            Obx(() {
              final replies = controller.commentReplies[comment.id];
              if (replies == null || replies.isEmpty) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: replies.map((reply) => _ReplyItem(
                    reply: reply,
                    commentId: comment.id,
                    controller: controller,
                    isMyReply: controller.isMyReply(reply),
                  )).toList(),
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

class _ReplyItem extends StatelessWidget {
  final dynamic reply;
  final String commentId;
  final PostDetailController controller;
  final bool isMyReply;

  const _ReplyItem({
    required this.reply,
    required this.commentId,
    required this.controller,
    required this.isMyReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sand.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.sand,
            backgroundImage: (reply.authorProfileImageUrl != null && reply.authorProfileImageUrl!.isNotEmpty)
                ? CachedNetworkImageProvider(reply.authorProfileImageUrl!)
                : null,
            child: (reply.authorProfileImageUrl == null || reply.authorProfileImageUrl!.isEmpty)
                ? const Icon(Icons.person, size: 10, color: AppColors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(reply.authorNickname, 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.mocha, fontSize: 12)
                    ),
                    const SizedBox(width: 6),
                    const Text('·', style: TextStyle(color: AppColors.taupe)),
                    const SizedBox(width: 6),
                    Text(DateFormat('MM.dd HH:mm').format(reply.createdAt), 
                      style: const TextStyle(fontSize: 10, color: AppColors.taupe)
                    ),
                    const Spacer(),
                    if (isMyReply)
                      InkWell(
                        onTap: () => controller.deleteReply(commentId, reply.id),
                        child: const Icon(Icons.close, size: 14, color: AppColors.taupe),
                      )
                  ],
                ),
                const SizedBox(height: 4),
                Text(reply.content, 
                  style: const TextStyle(fontSize: 13, color: AppColors.deepBrown, height: 1.4)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
