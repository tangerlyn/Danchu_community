import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../widgets/simple_video_controls.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../core/app_colors.dart';

import '../main_screen.dart';
import '../../domain/entities/community_post.dart';
import 'community_constants.dart';
import 'community_controller.dart';
import 'post_detail_controller.dart';
import 'widgets/comment_item.dart';
import '../../core/utils/paw_marker_utils.dart';
import 'widgets/post_action_sheets.dart';
import 'meetup_chat_page.dart';
import '../../widgets/paw_loading_indicator.dart';
import '../../widgets/image_gallery_page.dart';

class PostDetailPage extends StatefulWidget {
  final CommunityPost post;
  final bool fromCreate;

  const PostDetailPage({super.key, required this.post, this.fromCreate = false});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late CommunityPost _post;
  late final PostDetailController controller;
  final ScrollController _scrollController = ScrollController();
  int _currentImageIndex = 0;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    controller = Get.put(PostDetailController(post: _post), tag: _post.id);

    // 키보드 올라올 때 자동 스크롤
    controller.commentFocusNode.addListener(() {
      if (controller.commentFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // 동영상 초기화
    if (_post.videoUrl != null && _post.videoUrl!.isNotEmpty) {
      _initVideoPlayer();
    }
  }

  Future<void> _initVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(_post.videoUrl!));
      await _videoController!.initialize();
      _videoController!.setLooping(false);   // 1회만 재생
      _videoController!.play();
      _videoController!.setVolume(0);
      
      // 재생 완료 시 setState 호출해서 ▶ 아이콘 표시
      _videoController!.addListener(_onVideoStatusChanged);
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('⚠️ Video player init error: $e');
    }
  }

  void _onVideoStatusChanged() {
    if (_videoController == null) return;
    // 재생 끝났을 때 UI 갱신 (▶ 아이콘 표시)
    if (!_videoController!.value.isPlaying && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoStatusChanged);
    _videoController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () {
            if (widget.fromCreate) {
              final displayCategory = _post.mainCategory == '장소' ? '자유' : _post.mainCategory;
              final mainCategoryIndex = CommunityConstants.mainCategories.indexOf(displayCategory);
              final subCategory = _post.subCategoryTag;

              Get.offAll(() => MainScreen(initialIndex: 2));

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Get.isRegistered<CommunityController>()) {
                  final communityController = Get.find<CommunityController>();
                  if (mainCategoryIndex != -1) {
                    communityController.changeMainCategory(mainCategoryIndex);
                  }
                  communityController.changeSubCategory(subCategory);
                }
              });
            } else {
              Get.back();
            }
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.deepBrown),
            onPressed: () => showPostMenu(
              context, 
              controller, 
              onEditComplete: (updatedPost) {
                setState(() {
                  _post = updatedPost;
                });
                controller.updatePostData(updatedPost);
              }
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_post.videoUrl != null || _post.imageUrls.isNotEmpty)
                      _buildMediaSlider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Tag
                          Builder(
                            builder: (context) {
                              final displayMainCategory = _post.mainCategory == '장소' ? '자유' : _post.mainCategory;
                              if (displayMainCategory == '자유') {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.sand.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      displayMainCategory == '전체' ? _post.subCategoryTag : '$displayMainCategory > ${_post.subCategoryTag}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.deepBrown, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ]
                              );
                            }
                          ),
                          
                          // Title
                          Obx(() => Text(
                            controller.postTitle.value,
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold, 
                              color: AppColors.deepBrown,
                              letterSpacing: -0.5,
                              height: 1.3,
                            ),
                          )),
                          const SizedBox(height: 16),
                          
                          // Author Info Row
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.sand,
                                child: ClipOval(
                                  child: (_post.authorProfileImageUrl != null && _post.authorProfileImageUrl!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: _post.authorProfileImageUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorWidget: (context, url, error) => Image.asset(
                                            'assets/icon/app_icon3.png',
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/icon/app_icon3.png',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Obx(() => Text(
                                '${_post.authorNickname}${controller.isDeletedAuthor.value ? ' (X)' : ''}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mocha),
                              )),
                              const SizedBox(width: 8),
                              const Text('·', style: TextStyle(color: AppColors.taupe)),
                              const SizedBox(width: 8),
                              Obx(() => Row(
                                children: [
                                  Text(
                                    DateFormat('yyyy.MM.dd HH:mm').format(controller.createdAt.value),
                                    style: const TextStyle(fontSize: 12, color: AppColors.taupe),
                                  ),
                                  if (controller.isEdited.value)
                                    const Text(
                                      ' · 수정됨',
                                      style: TextStyle(fontSize: 12, color: AppColors.taupe),
                                    ),
                                ],
                              )),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppColors.sand, thickness: 1),
                          const SizedBox(height: 20),

                          if (_post.mainCategory == '모임')
                            Obx(() {
                              final hasLocation = controller.meetupLocation.value != null && controller.meetupLocation.value!.isNotEmpty;
                              final hasCapacity = controller.meetupCapacity.value != null;
                              final hasDate = controller.meetupDate.value != null;

                              if (hasLocation || hasCapacity || hasDate) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.sand.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.sand),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (hasDate) ...[
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 16, color: AppColors.deepBrown),
                                            const SizedBox(width: 8),
                                            Text(DateFormat('M월 d일(E) a h:mm', 'ko_KR').format(controller.meetupDate.value!), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: AppColors.deepBrown),
                                          const SizedBox(width: 8),
                                          Text(controller.meetupLocation.value ?? '장소 미정', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.people, size: 16, color: AppColors.deepBrown),
                                          const SizedBox(width: 8),
                                          Text('${controller.currentParticipantCount.value}/${controller.meetupCapacity.value ?? '?'}명 모집', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 44,
                                        child: Obx(() {
                                          final isParticipating = controller.currentUserUid != null && controller.meetupParticipants.contains(controller.currentUserUid!);
                                          final isFull = controller.meetupCapacity.value != null && controller.currentParticipantCount.value >= controller.meetupCapacity.value!;
                                          
                                          if (isParticipating) {
                                            return ElevatedButton.icon(
                                              onPressed: () => _enterChatRoom(controller),
                                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                              label: const Text('채팅방 입장', style: TextStyle(fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.deepBrown,
                                                foregroundColor: AppColors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            );
                                          } else if (isFull) {
                                            return ElevatedButton(
                                              onPressed: null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.sand,
                                                foregroundColor: AppColors.taupe,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              child: const Text('모집 마감', style: TextStyle(fontWeight: FontWeight.bold)),
                                            );
                                          } else {
                                            return Obx(() {
                                              final status = controller.myJoinRequestStatus.value;
                                              final isApproval = controller.joinType.value == 'approval';
                                              
                                              String buttonText = isApproval ? '참가 신청하기' : '참가하기';
                                              bool isEnabled = true;
                                              
                                              if (isApproval) {
                                                if (status == 'pending') {
                                                  buttonText = '신청 완료';
                                                  isEnabled = false;
                                                } else if (status == 'rejected') {
                                                  buttonText = '신청 거절됨';
                                                  isEnabled = false;
                                                }
                                              }
                                              
                                              return ElevatedButton(
                                                onPressed: isEnabled ? () {
                                                  if (isApproval) {
                                                    _showJoinRequestDialog(controller);
                                                  } else {
                                                    _showJoinConfirmDialog(controller);
                                                  }
                                                } : null,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isEnabled ? AppColors.deepBrown : AppColors.sand,
                                                  foregroundColor: isEnabled ? AppColors.white : AppColors.taupe,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                              );
                                            });
                                          }
                                        }),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),

                          if (_post.walkSummary != null && _post.walkSummary!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.sand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.sand.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                _post.walkSummary!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.deepBrown,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          if (_post.routePoints != null && _post.routePoints!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Container(
                                height: MediaQuery.of(context).size.width * 0.85,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.mocha.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Builder(
                                    builder: (context) {
                                      final points = _post.routePoints!.map((p) => NLatLng(p['lat']!, p['lng']!)).toList();
                                      final bounds = points.isNotEmpty ? NLatLngBounds.from(points) : null;
                                      
                                      if (bounds == null) return const SizedBox.shrink();

                                      final centerLat = (bounds.southWest.latitude + bounds.northEast.latitude) / 2;
                                      final centerLng = (bounds.southWest.longitude + bounds.northEast.longitude) / 2;
                                      final initialPosition = NCameraPosition(target: NLatLng(centerLat, centerLng), zoom: 14);

                                      return NaverMap(
                                        options: NaverMapViewOptions(
                                          customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
                                          initialCameraPosition: initialPosition,
                                          liteModeEnable: true,
                                          logoClickEnable: false,
                                          scrollGesturesEnable: false,
                                          zoomGesturesEnable: false,
                                        ),
                                        onMapReady: (NaverMapController mapController) async {
                                          if (points.length >= 2) {
                                            final bounds = NLatLngBounds.from(points);
                                            mapController.updateCamera(
                                              NCameraUpdate.fitBounds(
                                                bounds,
                                                padding: const EdgeInsets.all(100),
                                              ),
                                            );

                                            await Future.delayed(const Duration(milliseconds: 800));
                                            if (!context.mounted) return;
                                            await PawMarkerUtils.placePawMarkers(
                                              context: context,
                                              controller: mapController,
                                              pathPoints: points,
                                            );
                                          }
                                        },
                                      );
                                    }
                                  ),
                                ),
                              ),
                            ),

                          Obx(() => Text(
                            controller.postContent.value,
                            style: const TextStyle(
                              fontSize: 16, 
                              color: AppColors.deepBrown, 
                              height: 1.7,
                              letterSpacing: 0.1,
                            ),
                          )),

                          if (_post.subCategoryTag == '실종' || _post.subCategoryTag == '임시보호') ...[
                            Obx(() => controller.petInfo.value != null
                              ? PetInfoSection(petInfo: controller.petInfo.value)
                              : const SizedBox.shrink()
                            ),
                            Obx(() => controller.incidentLocations.isNotEmpty
                              ? IncidentLocationsSection(locations: controller.incidentLocations.toList())
                              : const SizedBox.shrink()
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Interactions
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.sand, width: 0.5),
                                bottom: BorderSide(color: AppColors.sand, width: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Obx(() => _buildInteractionItem(
                                  icon: controller.isLiked.value ? Icons.favorite : Icons.favorite_border,
                                  count: controller.likeCount.value,
                                  isActive: controller.isLiked.value,
                                  activeColor: Colors.redAccent,
                                  onTap: controller.toggleLike,
                                )),
                                const SizedBox(width: 20),
                                Obx(() => _buildInteractionItem(
                                  icon: Icons.chat_bubble_outline,
                                  count: controller.commentCount.value,
                                  isActive: false,
                                  onTap: () => controller.commentFocusNode.requestFocus(),
                                )),
                                const SizedBox(width: 20),
                                Obx(() => _buildInteractionItem(
                                  icon: Icons.visibility_outlined,
                                  count: controller.viewCount.value,
                                  isActive: false,
                                )),
                              ],
                            ),
                          ),
                          
                          // Comments Header
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 16),
                            child: Row(
                              children: [
                                const Text('댓글', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
                                const SizedBox(width: 6),
                                Obx(() => Text('${controller.commentCount.value}', 
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.taupe)
                                )),
                              ],
                            ),
                          ),

                          // Comments List
                          Obx(() {
                            final _ = controller.editingCommentId.value;
                            if (controller.comments.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.taupe.withOpacity(0.3)),
                                      const SizedBox(height: 12),
                                      const Text('아직 작성된 댓글이 없습니다.\n첫 번째 소중한 댓글을 남겨보세요!', 
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.taupe, height: 1.5, fontSize: 14)
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: controller.comments.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final comment = controller.comments[index];
                                return CommentItem(
                                  comment: comment, 
                                  controller: controller, 
                                  isMyComment: controller.isMyComment(comment)
                                );
                              },
                            );
                          }),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Comment Input
            Obx(() {
              if (controller.editingCommentId.value != null || controller.editingReplyId.value != null) {
                return const SizedBox.shrink();
              }
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Obx(() {
                    if (controller.replyingToNickname.value == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.sand.withOpacity(0.3),
                      child: Row(
                        children: [
                          const Icon(Icons.reply, size: 16, color: AppColors.deepBrown),
                          const SizedBox(width: 8),
                          Text('${controller.replyingToNickname.value}에게 답글 작성 중',
                            style: const TextStyle(fontSize: 13, color: AppColors.deepBrown, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          GestureDetector(
                            onTap: controller.cancelReply,
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close, size: 18, color: AppColors.taupe),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller.commentTextController,
                              focusNode: controller.commentFocusNode,
                              onChanged: (value) => controller.commentText.value = value,
                              style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
                              maxLines: 5,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: '댓글을 입력하세요...',
                                hintStyle: const TextStyle(color: AppColors.taupe, fontSize: 14),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Obx(() => Container(
                            decoration: BoxDecoration(
                              color: controller.commentText.value.trim().isEmpty 
                                ? AppColors.sand 
                                : AppColors.deepBrown,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: controller.isSubmittingComment.value
                                ? const SizedBox(width: 20, height: 20, child: PawLoadingIndicator(size: 20))
                                : const Icon(Icons.send_rounded, color: AppColors.white, size: 20),
                              onPressed: (controller.isSubmittingComment.value || controller.commentText.value.trim().isEmpty) 
                                ? null 
                                : controller.submitComment,
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSlider() {
    final hasVideo = _post.videoUrl != null && _post.videoUrl!.isNotEmpty;
    final totalCount = (hasVideo ? 1 : 0) + _post.imageUrls.length;

    if (totalCount == 0) return const SizedBox.shrink();

    // 동영상만 있고 이미지 없는 경우
    if (hasVideo && _post.imageUrls.isEmpty) {
      return _buildVideoWidget();
    }

    // 이미지만 있는 경우 (기존 로직)
    if (!hasVideo) {
      return _buildImageSlider();
    }

    // 동영상 + 이미지 혼합
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width,
          child: PageView.builder(
            itemCount: totalCount,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
              if (hasVideo) {
                if (index == 0) {
                  // 동영상 끝났으면 처음부터 재생
                  if (_videoController!.value.position >= _videoController!.value.duration) {
                    _videoController!.seekTo(Duration.zero);
                  }
                  _videoController!.play();
                } else {
                  _videoController?.pause();
                }
              }
            },
            itemBuilder: (context, index) {
              // 첫 번째 페이지 = 동영상
              if (index == 0 && hasVideo) {
                return _buildVideoWidget();
              }
              // 나머지 = 이미지 (인덱스 보정)
              final imageIndex = hasVideo ? index - 1 : index;
              return GestureDetector(
                onTap: () => Get.to(() => ImageGalleryPage(
                  imageUrls: _post.imageUrls,
                  initialIndex: imageIndex,
                )),
                child: CachedNetworkImage(
                  imageUrl: _post.imageUrls[imageIndex],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.sand,
                    child: const Center(child: PawLoadingIndicator(size: 32)),
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/icon/app_icon3.png',
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        // 페이지 카운터 (우측 상단)
        if (totalCount > 1)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentImageIndex + 1}/$totalCount',
                style: const TextStyle(
                  color: AppColors.deepBrown,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // 페이지 인디케이터 (하단 점)
        if (totalCount > 1)
          Positioned(
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalCount,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? AppColors.white
                        : AppColors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoWidget() {
    // 아직 초기화 안 됐으면 썸네일 + 로딩
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return GestureDetector(
        onTap: () => _openFullScreenVideo(),
        child: Container(
          height: MediaQuery.of(context).size.width,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_post.videoThumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: _post.videoThumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        if (_videoController!.value.position >= _videoController!.value.duration && 
            !_videoController!.value.isPlaying) {
          // 재생 끝난 상태에서 탭 → 처음부터 다시 재생
          _videoController!.seekTo(Duration.zero);
          _videoController!.play();
        } else {
          // 재생 중이거나 일시정지 중 → 전체화면
          _openFullScreenVideo();
        }
      },
      child: Container(
        height: size,
        width: size,
        color: Colors.black,
        child: Stack(
          children: [
            // 동영상 (정사각형 크롭)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
            // 가운데 재생/일시정지 아이콘
            Positioned.fill(
              child: Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _videoController!,
                  builder: (context, value, child) {
                    if (!value.isPlaying) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            // 하단 흰색 progress bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _videoController!,
                builder: (context, value, child) {
                  final duration = value.duration.inMilliseconds;
                  final position = value.position.inMilliseconds;
                  final progress = duration > 0 ? position / duration : 0.0;
                  
                  return Container(
                    height: 3,
                    color: Colors.white.withOpacity(0.3),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        height: 3,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenVideo() async {
    _videoController?.pause();
    
    await Get.to(() => _FullScreenVideoPage(videoUrl: _post.videoUrl!));
    
    // 전체화면에서 돌아오면 슬라이더 동영상 다시 재생 (음소거)
    if (_currentImageIndex == 0 && _videoController != null) {
      _videoController!.setVolume(0);
      _videoController!.play();
    }
  }

  Widget _buildImageSlider() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.width,
          child: PageView.builder(
            itemCount: _post.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Get.to(() => ImageGalleryPage(
                  imageUrls: _post.imageUrls,
                  initialIndex: index,
                )),
                child: CachedNetworkImage(
                  imageUrl: _post.imageUrls[index],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.sand,
                    child: const Center(child: PawLoadingIndicator(size: 32)),
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/icon/app_icon3.png',
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        if (_post.imageUrls.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${_post.imageUrls.length}',
                style: const TextStyle(
                  color: AppColors.deepBrown,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (_post.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _post.imageUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? AppColors.white
                        : AppColors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInteractionItem({
    required IconData icon, 
    required int count, 
    required bool isActive, 
    Color? activeColor,
    VoidCallback? onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? (activeColor ?? AppColors.deepBrown) : AppColors.taupe,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              color: isActive ? (activeColor ?? AppColors.deepBrown) : AppColors.taupe,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerWidget(String text, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showJoinConfirmDialog(PostDetailController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('모임 참가',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
        content: const Text('채팅방에 입장하시겠습니까?',
            style: TextStyle(color: AppColors.mocha)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.taupe, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await controller.toggleMeetupParticipation();
              _enterChatRoom(controller);
            },
            child: const Text('확인',
                style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _enterChatRoom(PostDetailController controller) {
    Get.to(() => MeetupChatPage(
      postId: _post.id,
      postTitle: controller.postTitle.value,
    ));
  }

  void _showJoinRequestDialog(PostDetailController controller) {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('참가 신청',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('단장에게 보낼 메시지를 입력하세요',
                style: TextStyle(color: AppColors.mocha, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '예: 안녕하세요! 꼭 참여하고 싶습니다.',
                hintStyle: const TextStyle(color: AppColors.taupe, fontSize: 13),
                filled: true,
                fillColor: AppColors.sand.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.sand),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.deepBrown),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.taupe, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              final message = messageController.text.trim();
              if (message.isEmpty) {
                Get.snackbar('알림', '메시지를 입력해주세요.');
                return;
              }
              Navigator.of(ctx).pop();
              await controller.submitJoinRequest(message);
            },
            child: const Text('신청하기',
                style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class PetInfoSection extends StatelessWidget {
  final Map<String, dynamic>? petInfo;
  const PetInfoSection({super.key, this.petInfo});

  @override
  Widget build(BuildContext context) {
    if (petInfo == null) return const SizedBox.shrink();

    final name = petInfo!['name'] ?? '정보 없음';
    final breed = petInfo!['breed'] ?? '정보 없음';
    final age = petInfo!['age'] ?? '정보 없음';
    final gender = petInfo!['gender'] ?? '정보 없음';
    final features = petInfo!['features'] ?? '정보 없음';
    final health = petInfo!['health'];
    final isNeutered = petInfo!['isNeutered'];
    final incidentDate = petInfo!['incidentDate'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pets, color: AppColors.deepBrown, size: 20),
              SizedBox(width: 8),
              Text('반려견 정보', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown)
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('이름', name),
          _buildInfoRow('견종', breed),
          _buildInfoRow('나이', age),
          _buildInfoRow('성별', gender),
          _buildInfoRow('특징', features),
          if (health != null) _buildInfoRow('건강 상태', health),
          if (isNeutered != null) _buildInfoRow('중성화 여부', isNeutered ? '완료' : '미완료'),
          if (incidentDate != null) 
            _buildInfoRow('날짜', DateFormat('yyyy년 M월 d일').format((incidentDate as Timestamp).toDate())),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.taupe, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.deepBrown, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class IncidentLocationsSection extends StatefulWidget {
  final List<IncidentLocation> locations;
  const IncidentLocationsSection({super.key, required this.locations});

  @override
  State<IncidentLocationsSection> createState() => _IncidentLocationsSectionState();
}

class _IncidentLocationsSectionState extends State<IncidentLocationsSection> {
  NaverMapController? _mapController;

  @override
  void didUpdateWidget(IncidentLocationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations != widget.locations) {
      _refreshMarkers();
    }
  }

  Future<void> _refreshMarkers() async {
    if (_mapController == null) return;
    await _mapController!.clearOverlays();
    final points = widget.locations.map((loc) => NLatLng(loc.latitude, loc.longitude)).toList();
    if (points.isEmpty) return;

    for (int i = 0; i < points.length; i++) {
      final markerIcon = await NOverlayImage.fromWidget(
        widget: _buildMarker(i + 1),
        size: const Size(40, 40),
        context: context,
      );
      _mapController!.addOverlay(NMarker(
        id: "incident_loc_$i",
        position: points[i],
        icon: markerIcon,
      ));
    }
    
    if (points.length >= 2) {
      final bounds = NLatLngBounds.from(points);
      _mapController!.updateCamera(NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(50)));
    } else if (points.isNotEmpty) {
      _mapController!.updateCamera(NCameraUpdate.withParams(target: points.first, zoom: 14));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: AppColors.deepBrown, size: 20),
              SizedBox(width: 8),
              Text('목격/보호 장소', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown)
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.locations.asMap().entries.map((entry) {
            final loc = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.sand.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(loc.name, style: const TextStyle(fontSize: 14, color: AppColors.deepBrown)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sand),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NaverMap(
                options: NaverMapViewOptions(
                  customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
                  initialCameraPosition: NCameraPosition(
                    target: widget.locations.isNotEmpty 
                        ? NLatLng(widget.locations.first.latitude, widget.locations.first.longitude)
                        : const NLatLng(37.5665, 126.9780), 
                    zoom: 14,
                  ),
                  liteModeEnable: true,
                  logoClickEnable: false,
                ),
                onMapReady: (mapController) {
                  _mapController = mapController;
                  _refreshMarkers();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(int index) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.deepBrown,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text('$index', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPage({required this.videoUrl});

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _controller,
          autoPlay: true,
          looping: false,
          showControls: true,
          showOptions: false,
          allowPlaybackSpeedChanging: false,
          hideControlsTimer: const Duration(seconds: 3),
          customControls: const SimpleVideoControls(),
          aspectRatio: _controller.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.white,
            handleColor: Colors.white,
            backgroundColor: Colors.white24,
            bufferedColor: Colors.white38,
          ),
          errorBuilder: (context, errorMessage) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.white, size: 42),
                  SizedBox(height: 8),
                  Text('동영상을 불러올 수 없습니다',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            );
          },
        );
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: Center(
        child: _chewieController != null
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
