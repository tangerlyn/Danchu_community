import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/community_post.dart';
import '../../data/repositories/community_repository_impl.dart';
import 'post_detail_page.dart';
import 'widgets/post_card_widget.dart';

class MissingPetController extends GetxController {
  final CommunityRepositoryImpl _repository = CommunityRepositoryImpl();
  
  // '전체', 'active', 'found', 'closed'
  var selectedStatus = '전체'.obs;
  Rx<List<CommunityPost>> posts = Rx<List<CommunityPost>>([]);

  @override
  void onInit() {
    super.onInit();
    _bindStream();
  }

  void setStatus(String status) {
    if (selectedStatus.value != status) {
      selectedStatus.value = status;
      _bindStream();
    }
  }

  void _bindStream() {
    posts.bindStream(_repository.getMissingPostsStream(
      status: selectedStatus.value == '전체' ? null : selectedStatus.value,
    ));
  }
}

class MissingPetPage extends StatelessWidget {
  const MissingPetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MissingPetController());
    final statusMap = {
      '전체': '전체',
      'active': '찾고 있어요',
      'found': '찾았어요',
      'closed': '종료',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      appBar: AppBar(
        title: const Text('실종신고', style: TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.deepBrown,
        )),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F5F1),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.deepBrown),
      ),
      body: Column(
        children: [
          // Status Filter Tabs
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Obx(() {
                return Row(
                  children: statusMap.entries.map((entry) {
                    final isActive = controller.selectedStatus.value == entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => controller.setStatus(entry.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.deepBrown : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive ? AppColors.deepBrown : AppColors.taupe.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: isActive ? AppColors.white : AppColors.taupe,
                              fontSize: 14,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
            ),
          ),
          
          // List of Missing Pets
          Expanded(
            child: Obx(() {
              final posts = controller.posts.value;
              if (posts.isEmpty) {
                return const Center(
                  child: Text(
                    '해당 상태의 실종신고가 없습니다.',
                    style: TextStyle(color: AppColors.taupe, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        PostCardWidget(
                          post: post,
                          isGlobalView: false, // Already in targeted missing pet view
                        ),
                        if (index < posts.length - 1)
                          const Divider(height: 32, color: AppColors.sand),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
