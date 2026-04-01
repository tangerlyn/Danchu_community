import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/community_post.dart';
import 'widgets/post_card_widget.dart';
import 'post_detail_page.dart';

class MyCommentedPostsPage extends StatelessWidget {
  const MyCommentedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: const Text('댓글 단 게시글', style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('로그인이 필요합니다.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('comments')
                  .where('authorUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('오류가 발생했습니다.\n컬렉션 그룹 색인이 필요할 수 있습니다.\n\n오류: ${snapshot.error}', textAlign: TextAlign.center),
                  ));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.deepBrown));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('댓글을 단 게시글이 없습니다.', style: TextStyle(color: AppColors.taupe, fontSize: 16)),
                  );
                }

                // Extract unique post IDs maintain order by latest comment
                final postIds = <String>[];
                final seenIds = <String>{};
                for (final doc in docs) {
                  final postRef = doc.reference.parent.parent;
                  if (postRef != null && !seenIds.contains(postRef.id)) {
                    postIds.add(postRef.id);
                    seenIds.add(postRef.id);
                  }
                }

                if (postIds.isEmpty) {
                  return const Center(
                    child: Text('댓글을 단 게시글이 없습니다.', style: TextStyle(color: AppColors.taupe, fontSize: 16)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: postIds.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final postId = postIds[index];
                    return _PostCardLoader(postId: postId);
                  },
                );
              },
            ),
    );
  }
}

class _PostCardLoader extends StatelessWidget {
  final String postId;

  const _PostCardLoader({required this.postId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('community_posts').doc(postId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();

        if (!snapshot.hasData || !snapshot.data!.exists) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const SizedBox.shrink(); // Post might be deleted
          }
          // Skeleton/Placeholder during loading
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
          );
        }

        final postData = snapshot.data!.data() as Map<String, dynamic>;
        final post = CommunityPost.fromJson(postData, postId);

        return GestureDetector(
          onTap: () => Get.to(() => PostDetailPage(post: post)),
          child: PostCardWidget(
            post: post,
            isGlobalView: true,
          ),
        );
      },
    );
  }
}
