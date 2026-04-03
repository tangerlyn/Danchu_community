import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/app_colors.dart';

class InquiryWritePage extends StatefulWidget {
  const InquiryWritePage({super.key});

  @override
  State<InquiryWritePage> createState() => _InquiryWritePageState();
}

class _InquiryWritePageState extends State<InquiryWritePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      Get.snackbar('잠깐!', '제목을 입력해주세요 🐾', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_contentController.text.trim().isEmpty) {
      Get.snackbar('잠깐!', '내용을 입력해주세요 🐾', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('로그인이 필요합니다.');

      await FirebaseFirestore.instance.collection('inquiries').add({
        'uid': uid,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'answer': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isAnswered': false,
      });

      Get.back(result: true);
      Get.snackbar(
        '문의 완료 🐾',
        '문의가 접수되었습니다. 답변을 기다려주세요!',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      debugPrint('⚠️ Error submitting inquiry: $e');
      Get.snackbar('잠깐!', '문의 접수에 실패했어요 🐾', snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _isSubmitting = false);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '문의하기',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(
              '제출',
              style: TextStyle(
                color: _isSubmitting ? AppColors.taupe : AppColors.deepBrown,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            const Text('제목', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.deepBrown)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 15, color: AppColors.deepBrown),
              decoration: InputDecoration(
                hintText: '문의 제목을 입력해주세요',
                hintStyle: TextStyle(color: AppColors.taupe, fontSize: 14),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // 내용
            const Text('내용', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.deepBrown)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 8,
              style: const TextStyle(fontSize: 15, color: AppColors.deepBrown),
              decoration: InputDecoration(
                hintText: '문의 내용을 자세히 입력해주세요',
                hintStyle: TextStyle(color: AppColors.taupe, fontSize: 14),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '※ 답변은 앱 내 문의 내역에서 확인하실 수 있습니다.',
              style: TextStyle(fontSize: 12, color: AppColors.taupe),
            ),
          ],
        ),
      ),
    );
  }
}
