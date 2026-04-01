import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

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
          '공지사항',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBrown),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.deepBrown),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 48, color: AppColors.taupe.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    '아직 공지사항이 없습니다.',
                    style: TextStyle(color: AppColors.taupe, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? '';
              final content = data['content'] as String? ?? '';
              final createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate();
              final isPinned = data['isPinned'] == true;

              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(vertical: 8),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                title: Row(
                  children: [
                    if (isPinned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.deepBrown,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '필독',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepBrown,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: createdAt != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('yyyy.MM.dd').format(createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.taupe),
                        ),
                      )
                    : null,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.sand.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.mocha,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
