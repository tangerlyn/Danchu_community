import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import '../../widgets/paw_loading_indicator.dart';
import '../../widgets/image_gallery_page.dart';
import '../../widgets/simple_video_controls.dart';
import '../community/chat_user_profile_page.dart';
import 'direct_chat_controller.dart';
import '../../widgets/walk_picker_sheet.dart';
import '../../widgets/walk_map_widgets.dart';
class DirectChatPage extends StatefulWidget {
  final String chatId;
  final String friendUid;
  final String friendNickname;
  final String friendProfileImageUrl;

  const DirectChatPage({
    super.key,
    required this.chatId,
    required this.friendUid,
    required this.friendNickname,
    required this.friendProfileImageUrl,
  });

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  late final DirectChatController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      DirectChatController(
        chatId: widget.chatId,
        friendUid: widget.friendUid,
        friendNickname: widget.friendNickname,
        friendProfileImageUrl: widget.friendProfileImageUrl,
      ),
      tag: widget.chatId,
    );
  }

  @override
  void dispose() {
    Get.delete<DirectChatController>(tag: widget.chatId);
    super.dispose();
  }

  // ── 이미지 그리드 ──
  Widget _buildImageGrid(List<String> urls) {
    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => Get.to(() => ImageGalleryPage(imageUrls: urls, initialIndex: 0)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(imageUrl: urls[0], width: 180, fit: BoxFit.cover),
        ),
      );
    }
    List<List<int>> rows;
    if (urls.length == 2) rows = [[0, 1]];
    else if (urls.length == 3) rows = [[0, 1, 2]];
    else if (urls.length == 4) rows = [[0, 1], [2, 3]];
    else rows = [[0, 1, 2], [3, 4]];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.asMap().entries.map((rowEntry) {
          final rowIndex = rowEntry.key;
          final row = rowEntry.value;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: row.asMap().entries.map((colEntry) {
              final colIndex = colEntry.key;
              final imgIndex = colEntry.value;
              const double imgHeight = 75.0;
              final double imgWidth = row.length == 3 ? 75.0 : row.length == 2 ? 113.0 : 75.0;
              return GestureDetector(
                onTap: () => Get.to(() => ImageGalleryPage(imageUrls: urls, initialIndex: imgIndex)),
                child: Container(
                  margin: EdgeInsets.only(
                    right: colIndex < row.length - 1 ? 2 : 0,
                    bottom: rowIndex < rows.length - 1 ? 2 : 0,
                  ),
                  child: CachedNetworkImage(imageUrl: urls[imgIndex], width: imgWidth, height: imgHeight, fit: BoxFit.cover),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  void _openVideoPlayer(String videoUrl) {
    Get.to(() => _DirectFullScreenVideoPage(videoUrl: videoUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F5F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: GestureDetector(
          onTap: () => Get.to(() => ChatUserProfilePage(uid: widget.friendUid)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.sand,
                backgroundImage: widget.friendProfileImageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(widget.friendProfileImageUrl)
                    : null,
                child: widget.friendProfileImageUrl.isEmpty
                    ? ClipOval(child: Image.asset('assets/icon/app_icon3.png', fit: BoxFit.cover))
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                widget.friendNickname,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBrown,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                final msgs = controller.messages;
                final uploadingMsgs = controller.uploadingMessages;

                if (controller.isLoadingMessages.value) {
                  return const Center(child: PawLoadingIndicator());
                }

                if (msgs.isEmpty && uploadingMsgs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.taupe.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          '${widget.friendNickname}님과 대화를 시작해보세요!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.taupe, height: 1.5, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final totalCount = msgs.length + uploadingMsgs.length;

                return ListView.builder(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: totalCount,
                  itemBuilder: (context, index) {
                    // 업로딩 메시지
                    if (index >= msgs.length) {
                      return _buildUploadingBubble(uploadingMsgs[index - msgs.length]);
                    }

                    final msg = msgs[index];
                    final isMine = msg.senderUid == controller.myUid;

                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMsg = msgs[index - 1];
                      if (prevMsg.createdAt.year != msg.createdAt.year ||
                          prevMsg.createdAt.month != msg.createdAt.month ||
                          prevMsg.createdAt.day != msg.createdAt.day) {
                        showDateSeparator = true;
                      }
                    }

                    bool showProfileAndName = true;
                    if (index > 0 && !showDateSeparator) {
                      final prevMsg = msgs[index - 1];
                      if (prevMsg.senderUid == msg.senderUid) showProfileAndName = false;
                    }

                    return Column(
                      children: [
                        if (showDateSeparator) _buildDateSeparator(msg.createdAt),
                        _buildMessageBubble(
                          msg: msg,
                          isMine: isMine,
                          showProfileAndName: showProfileAndName,
                        ),
                      ],
                    );
                  },
                );
              }),
            ),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.sand)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(date),
              style: const TextStyle(fontSize: 12, color: AppColors.taupe, fontWeight: FontWeight.w500),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.sand)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required ChatMessage msg,
    required bool isMine,
    required bool showProfileAndName,
  }) {
    final timeWidget = Text(
      DateFormat('a h:mm', 'ko_KR').format(msg.createdAt),
      style: const TextStyle(fontSize: 10, color: AppColors.taupe),
    );

    // 내가 보낸 메시지 중 상대방이 아직 안 읽은 것 → "1" 표시
    final bool friendHasRead = msg.readBy.contains(widget.friendUid);
    final unreadWidget = (isMine && !friendHasRead)
        ? const Text(
            '1',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.deepBrown,
              fontWeight: FontWeight.bold,
            ),
          )
        : const SizedBox.shrink();

    final metaWidget = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        unreadWidget,
        timeWidget,
      ],
    );

    final bool isMediaOnly = (msg.imageUrls.isNotEmpty || msg.imageUrl != null || msg.videoUrl != null) &&
        (msg.message.isEmpty || msg.message == '사진을 보냈습니다.' || msg.message == '동영상을 보냈습니다.');

    Widget bubbleContent;
    if (msg.type == 'walk') {
      bubbleContent = _buildWalkBubble(msg, isMine);
    } else {
      bubbleContent = Container(
        padding: isMediaOnly ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: isMediaOnly ? null : BoxDecoration(
          color: isMine ? AppColors.sand : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 동영상
            if (msg.videoUrl != null && msg.videoUrl!.isNotEmpty)
              GestureDetector(
                onTap: () => _openVideoPlayer(msg.videoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 200, height: 200,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (msg.videoThumbnailUrl != null)
                          CachedNetworkImage(imageUrl: msg.videoThumbnailUrl!, fit: BoxFit.cover)
                        else
                          Container(color: Colors.black),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 이미지 그리드
            if (msg.imageUrls.isNotEmpty)
              _buildImageGrid(msg.imageUrls)
            else if (msg.imageUrl != null)
              GestureDetector(
                onTap: () => Get.to(() => ImageGalleryPage(imageUrls: [msg.imageUrl!], initialIndex: 0)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: msg.imageUrl!, width: 200, fit: BoxFit.cover),
                ),
              ),
            // 텍스트
            if (msg.message.isNotEmpty &&
                msg.message != '사진을 보냈습니다.' &&
                msg.message != '동영상을 보냈습니다.' &&
                msg.imageUrl == null &&
                msg.imageUrls.isEmpty &&
                msg.videoUrl == null)
              Text(
                msg.message,
                style: const TextStyle(fontSize: 14, color: AppColors.deepBrown, height: 1.4),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: showProfileAndName ? 8 : 2, bottom: 2),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            if (showProfileAndName)
              GestureDetector(
                onTap: () => Get.to(() => ChatUserProfilePage(uid: msg.senderUid)),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.sand,
                  backgroundImage: widget.friendProfileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(widget.friendProfileImageUrl)
                      : null,
                  child: widget.friendProfileImageUrl.isEmpty
                      ? ClipOval(child: Image.asset('assets/icon/app_icon3.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                      : null,
                ),
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isMine) ...[metaWidget, const SizedBox(width: 6)],
                    Flexible(child: bubbleContent),
                    if (!isMine) ...[const SizedBox(width: 6), metaWidget],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkBubble(ChatMessage msg, bool isMine) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        child: Stack(
          children: [
            WalkMapThumbnail(msg: msg),
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  debugPrint('🗺️ overlay tap: routePoints=${msg.walkRoutePoints?.length}');
                  final points = msg.walkRoutePoints;
                  if (points != null && points.isNotEmpty) {
                    Get.to(() => WalkRouteViewPage(msg: msg));
                  } else {
                    Get.snackbar('알림', '루트 데이터가 없습니다.');
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadingBubble(dynamic msg) {
    Widget mediaWidget;
    if (msg.isVideo) {
      mediaWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 200, height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (msg.localThumbnailPath != null)
                Image.file(File(msg.localThumbnailPath!), fit: BoxFit.cover)
              else
                Container(color: Colors.black54),
              Container(color: Colors.black.withOpacity(0.3)),
              const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))),
            ],
          ),
        ),
      );
    } else if (msg.localImagePaths.isNotEmpty) {
      mediaWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.file(File(msg.localImagePaths[0]), width: 113, height: 75, fit: BoxFit.cover),
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
              ),
            ),
          ],
        ),
      );
    } else if (msg.localImagePath != null) {
      mediaWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.file(File(msg.localImagePath!), width: 180, fit: BoxFit.cover),
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
              ),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('전송 중...', style: TextStyle(fontSize: 10, color: AppColors.taupe)),
          const SizedBox(width: 6),
          mediaWidget,
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 28, height: 28,
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.taupe),
                onPressed: () => _showMediaActionSheet(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller.messageTextController,
                onChanged: (value) => controller.messageText.value = value,
                style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => controller.sendMessage(),
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: const TextStyle(color: AppColors.taupe, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() => Container(
              decoration: BoxDecoration(
                color: controller.messageText.value.trim().isEmpty ? AppColors.sand : AppColors.deepBrown,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: controller.isSubmitting.value
                    ? const SizedBox(width: 20, height: 20, child: PawLoadingIndicator(size: 20))
                    : const Icon(Icons.send_rounded, color: AppColors.white, size: 20),
                onPressed: (controller.isSubmitting.value || controller.messageText.value.trim().isEmpty)
                    ? null
                    : controller.sendMessage,
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showMediaActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () { Navigator.of(ctx).pop(); controller.pickAndSendImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 사진 선택'),
              onTap: () { Navigator.of(ctx).pop(); controller.pickAndSendImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('앨범에서 동영상 선택'),
              onTap: () { Navigator.of(ctx).pop(); controller.pickAndSendVideo(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: const Text('산책 기록 공유'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final selectedWalk = await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const WalkPickerSheet(),
                );
                if (selectedWalk != null) {
                  controller.sendWalkRecord(selectedWalk);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 전체화면 동영상 ──
class _DirectFullScreenVideoPage extends StatefulWidget {
  final String videoUrl;
  const _DirectFullScreenVideoPage({required this.videoUrl});

  @override
  State<_DirectFullScreenVideoPage> createState() => _DirectFullScreenVideoPageState();
}

class _DirectFullScreenVideoPageState extends State<_DirectFullScreenVideoPage> {
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
            ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: Chewie(controller: _chewieController!))
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
