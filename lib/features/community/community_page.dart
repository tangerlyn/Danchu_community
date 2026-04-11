import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import 'community_controller.dart';
import 'community_constants.dart';
import 'community_search_page.dart';
import 'my_posts_page.dart';
import 'my_commented_posts_page.dart';
import 'post_create_page.dart';
import 'widgets/hot_report_card_section.dart';
import 'widgets/post_card_widget.dart';
import 'widgets/meetup_chat_list_widget.dart';
import 'widgets/post_card_skeleton.dart';
import 'widgets/meetup_chat_skeleton.dart';
import 'my_liked_posts_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  CommunityController? _controller;

  CommunityController get controller => _controller!;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<CommunityController>()) {
      _controller = Get.find<CommunityController>();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null && Get.isRegistered<CommunityController>()) {
      _controller = Get.find<CommunityController>();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFDFCFB),
          appBar: AppBar(
            title: const Text('이야기', style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
              letterSpacing: -0.5,
            )),
            titleSpacing: 24,
            centerTitle: false,
            elevation: 0,
            backgroundColor: const Color(0xFFFDFCFB),
            toolbarHeight: 64,
            actions: [
              Obx(() {
                final isActive = controller.isNearMeActive.value;
                final color = isActive ? AppColors.deepBrown : AppColors.taupe;
                return TextButton(
                  onPressed: () => controller.toggleNearMeFilter(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '내 위치',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.location_on_outlined, color: color, size: 20),
                    ],
                  ),
                );
              }),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.deepBrown),
                onPressed: () {
                  final mainCategory = CommunityConstants.mainCategories[controller.selectedMainCategoryIndex.value];
                  Get.to(() => CommunitySearchPage(currentTab: mainCategory));
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.menu, color: AppColors.deepBrown),
                offset: const Offset(0, 36),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
                onSelected: (value) {
                  if (value == 'my_posts') {
                    Get.to(() => const MyPostsPage());
                  } else if (value == 'my_comments') {
                    Get.to(() => const MyCommentedPostsPage());
                  } else if (value == 'my_liked') {
                    Get.to(() => const MyLikedPostsPage());
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'my_posts',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, color: AppColors.deepBrown, size: 20),
                        SizedBox(width: 12),
                        Text('내가 쓴 게시글', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'my_comments',
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppColors.deepBrown, size: 20),
                        SizedBox(width: 12),
                        Text('내가 쓴 댓글', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'my_liked',
                    child: Row(
                      children: [
                        Icon(Icons.favorite_border, color: AppColors.deepBrown, size: 20),
                        SizedBox(width: 12),
                        Text('좋아요한 게시글', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() {
                    final selectedIndex = controller.selectedMainCategoryIndex.value;
                    return Container(
                      height: 56,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      alignment: Alignment.center,
                      child: Row(
                        children: List.generate(
                          CommunityConstants.mainCategories.length,
                          (index) {
                            final category = CommunityConstants.mainCategories[index];
                            final isActive = selectedIndex == index;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => controller.changeMainCategory(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  color: Colors.transparent,
                                  alignment: Alignment.center,
                                  child: Text(
                                    category == '모임' ? '단모' : category,
                                    style: TextStyle(
                                      color: isActive ? AppColors.deepBrown : AppColors.taupe,
                                      fontSize: 20,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                      decoration: isActive ? TextDecoration.underline : TextDecoration.none,
                                      decorationColor: AppColors.deepBrown,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () => controller.refreshPosts(),
            color: AppColors.deepBrown,
            backgroundColor: AppColors.white,
            child: CustomScrollView(
              controller: controller.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              // Sub-category (Chip) Filter Row
              SliverToBoxAdapter(
                child: Obx(() {
                  final mainCategory = CommunityConstants.mainCategories[controller.selectedMainCategoryIndex.value];
                  final subTags = CommunityConstants.getSubTagsForCategory(mainCategory);
                  final selectedSub = controller.selectedSubCategory.value;
                  
                  Widget divider = Divider(height: 1, thickness: 1, color: AppColors.lightSand.withOpacity(0.5));

                  // ── '모임' tab: custom 3-chip row (전체 / 내 모임 / 내 주변) ──
                  if (mainCategory == '모임') {
                    // Group A: 전체 vs 내 모임 (Mutually exclusive)
                    // Group B: 내 주변 (Independent)
                    final allActive = !controller.isMyMeetupActive.value;
                    final myActive = controller.isMyMeetupActive.value;
                    final nearActive = controller.isNearMeActive.value;

                    Widget buildMeetupChip(String label, bool isActive, VoidCallback onTap) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: onTap,
                            child: Container(
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.deepBrown : AppColors.sand.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive ? AppColors.deepBrown : AppColors.sand,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isActive ? AppColors.white : AppColors.deepBrown,
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              buildMeetupChip('전체', allActive, () {
                                if (!allActive) {
                                  controller.toggleMyMeetupFilter();
                                }
                              }),
                              buildMeetupChip('내 단추 모임', myActive, () {
                                if (!myActive) {
                                  controller.toggleMyMeetupFilter();
                                }
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        divider,
                      ],
                    );
                  }

                  // ── Other tabs: generic sub-tag chips + Near Me ──
                  if (subTags.length == 1 && subTags.first == '전체') {
                    return Column(
                      children: [
                        divider,
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            ...subTags.map((tag) {
                              final isSelected = controller.selectedSubCategory.value == tag;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: GestureDetector(
                                    onTap: () => controller.changeSubCategory(tag),
                                    child: Container(
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.deepBrown : AppColors.sand.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected ? AppColors.deepBrown : AppColors.sand,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        tag,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.white : AppColors.deepBrown,
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      divider,
                    ],
                  );
                }),
              ),

              // Hot Posts Banner - Show on Walk, Report, Free > All ('전체') tab
              SliverToBoxAdapter(
                child: Obx(() {
                  final mainCategory = CommunityConstants.mainCategories[controller.selectedMainCategoryIndex.value];
                  final subCategory = controller.selectedSubCategory.value;
                  
                  if (subCategory == '전체' && mainCategory != '모임') {
                    return HotPostsSection(mainCategory: mainCategory);
                  }
                  return const SizedBox.shrink();
                }),
              ),
              
              // Post List or Chat Room List
              Obx(() {
                final posts = controller.posts.value;
                final mainCategoryIndex = controller.selectedMainCategoryIndex.value;
                final mainCategory = CommunityConstants.mainCategories[mainCategoryIndex];

                if (controller.isPostsLoading.value) {
                  // 내 모임 탭이면 채팅방 스켈레톤, 나머지는 게시글 스켈레톤
                  if (mainCategory == '모임' && controller.isMyMeetupActive.value) {
                    return const SliverToBoxAdapter(
                      child: MeetupChatSkeleton(),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: PostCardSkeleton(),
                        ),
                        childCount: 6,
                      ),
                    ),
                  );
                }

                // 내 모임 탭: 채팅방 목록 표시
                if (mainCategory == '모임' && controller.isMyMeetupActive.value) {
                  return SliverToBoxAdapter(
                    child: MeetupChatListWidget(meetupPosts: posts),
                  );
                }

                if (posts.isEmpty) {
                  final subCategory = controller.selectedSubCategory.value;
                  final categoryName = (mainCategory == '인기' || subCategory == '전체') 
                      ? mainCategory
                      : subCategory;

                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 300,
                      child: Center(
                        child: Text(
                          '$categoryName 게시판에 아직 작성된 글이 없습니다.\n첫 번째 이야기를 들려주세요! ✍️', 
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.taupe, fontSize: 16, height: 1.5)
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = posts[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              PostCardWidget(
                                post: post,
                                isGlobalView: false, 
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                      childCount: posts.length,
                    ),
                  ),
                );
              }),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'community_write_fab',
            onPressed: () {
              controller.toggleWriteMenu();
            },
            backgroundColor: AppColors.deepBrown,
            elevation: 4,
            highlightElevation: 8,
            icon: const Icon(Icons.edit, color: AppColors.white),
            label: const Text('글쓰기', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        // Scroll To Top Button
        Obx(() {
          if (!controller.showScrollToTop.value || controller.isWriteMenuOpen.value) {
            return const SizedBox.shrink();
          }
          return Positioned(
            right: 16,
            bottom: 80, // Above Write FAB
            child: FloatingActionButton.small(
              heroTag: 'community_scroll_top',
              onPressed: () => controller.scrollToTop(),
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.deepBrown,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_up),
            ),
          );
        }),
        // Custom Popup Menu Overlay
        Obx(() {
          if (!controller.isWriteMenuOpen.value) return const SizedBox.shrink();
          
          return Positioned.fill(
            child: GestureDetector(
              onTap: () => controller.toggleWriteMenu(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withOpacity(0.05),
                child: Stack(
                  children: [
                    Positioned(
                      right: 16,
                      bottom: 80, // Above FAB (FAB height + bottom padding)
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: CommunityConstants.mainCategories
                                .where((c) => c != '인기')
                                .map((category) {
                              return InkWell(
                                onTap: () {
                                  controller.toggleWriteMenu();
                                  
                                  // Map '전체' to the first actual sub-tag
                                  String subCategory = controller.selectedSubCategory.value;
                                  if (subCategory == '전체') {
                                    final subTags = CommunityConstants.getSubTagsForCategory(category);
                                    if (subTags.length > 1) {
                                      subCategory = subTags[1]; // Index 0 is '전체'
                                    }
                                  }

                                  Get.to(() => const PostCreatePage(), arguments: {
                                    'mainCategory': category,
                                    'subCategory': subCategory,
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  child: Center(
                                    child: Text(
                                      category == '모임' ? '단모' : category,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.deepBrown,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/*
// ==========================================
// --- Legacy UI Code (For reference)
// ==========================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import 'community_controller.dart';
... (legacy community page content)
*/
