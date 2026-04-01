import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';

class InquiryDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const InquiryDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isAnswered = data['isAnswered'] == true;
    final answer = data['answer'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '문의 상세',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 + 배지
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAnswered ? AppColors.deepBrown : AppColors.sand.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAnswered ? '답변 완료' : '답변 대기',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAnswered ? AppColors.white : AppColors.taupe,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data['title'] ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.deepBrown,
                letterSpacing: -0.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            // 작성자 + 날짜
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.sand,
                  child: Icon(Icons.person, size: 18, color: AppColors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  '나',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mocha),
                ),
                const SizedBox(width: 8),
                const Text('·', style: TextStyle(color: AppColors.taupe)),
                const SizedBox(width: 8),
                if (createdAt != null)
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.taupe),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.sand, thickness: 1),
            const SizedBox(height: 20),

            // 문의 내용
            Text(
              data['content'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.deepBrown,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 32),

            // 답변 섹션
            const Divider(color: AppColors.sand, thickness: 1),
            const SizedBox(height: 16),
            if (isAnswered && answer != null && answer.isNotEmpty) ...[
              // 답변 헤더
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.deepBrown,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.pets, size: 16, color: AppColors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '단추 팀',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBrown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.sand.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sand),
                ),
                child: Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.deepBrown,
                    height: 1.7,
                  ),
                ),
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty, size: 36, color: AppColors.taupe.withOpacity(0.4)),
                      const SizedBox(height: 8),
                      const Text(
                        '아직 답변이 달리지 않았습니다.\n순서대로 답변 드리겠습니다 🐾',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.taupe, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
