import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/community_post.dart';
import 'widgets/post_card_widget.dart';
import 'post_detail_page.dart';

class MyPostsPage extends StatelessWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        title: const Text('내가 쓴 게시글', style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
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
                  .collection('community_posts')
                  .where('authorUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.deepBrown));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('작성한 게시글이 없습니다.', style: TextStyle(color: AppColors.taupe, fontSize: 16)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final post = CommunityPost.fromJson(doc.data() as Map<String, dynamic>, doc.id);
                    
                    return GestureDetector(
                      onTap: () => Get.to(() => PostDetailPage(post: post)),
                      child: PostCardWidget(
                        post: post,
                        isGlobalView: true,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
