import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import 'meetup_chat_controller.dart';
import 'post_detail_page.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../core/utils/custom_center_toast.dart';
import 'chat_user_profile_page.dart';
import '../../widgets/paw_loading_indicator.dart';
import '../../widgets/image_gallery_page.dart';

class MeetupChatPage extends StatefulWidget {
  final String postId;
  final String postTitle;

  const MeetupChatPage({
    super.key,
    required this.postId,
    required this.postTitle,
  });

  @override
  State<MeetupChatPage> createState() => _MeetupChatPageState();
}

class _MeetupChatPageState extends State<MeetupChatPage> {
  late final MeetupChatController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      MeetupChatController(postId: widget.postId, postTitle: widget.postTitle),
      tag: widget.postId,
    );
  }

  // ─── Image helpers ───────────────────────────────────────────────────────────

  Widget _buildImageGrid(List<String> urls) {
    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => _openImageViewer(urls, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: urls[0],
            width: 180,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // 레이아웃 결정
    // 2장: 2열 1행
    // 3장: 3열 1행
    // 4장: 2열 2행
    // 5장: 3열 위 + 2열 아래
    List<List<int>> rows;
    if (urls.length == 2) {
      rows = [[0, 1]];
    } else if (urls.length == 3) {
      rows = [[0, 1, 2]];
    } else if (urls.length == 4) {
      rows = [[0, 1], [2, 3]];
    } else {
      rows = [[0, 1, 2], [3, 4]];
    }

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
              
              // 모든 이미지 높이 동일하게 고정
              const double imgHeight = 75.0;
              // 너비는 열 수에 따라 계산 (여백 2px 포함)
              final double imgWidth = row.length == 3 
                  ? 75.0 
                  : row.length == 2 
                      ? 113.0  // (75*3 + 2*2) / 2 = 113.5
                      : 75.0;

              return GestureDetector(
                onTap: () => _openImageViewer(urls, imgIndex),
                child: Container(
                  margin: EdgeInsets.only(
                    right: colIndex < row.length - 1 ? 2 : 0,
                    bottom: rowIndex < rows.length - 1 ? 2 : 0,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: urls[imgIndex],
                    width: imgWidth,
                    height: imgHeight,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  void _openImageViewer(List<String> urls, int initialIndex) {
    Get.to(() => ImageGalleryPage(imageUrls: urls, initialIndex: initialIndex));
  }

  // ─────────────────────────────────────────────────────────────────────────────

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
        title: Obx(() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                controller.chatRoomName.value.isNotEmpty 
                    ? controller.chatRoomName.value 
                    : widget.postTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBrown,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (controller.participantCount.value > 0) ...[
              const SizedBox(width: 4),
              Text(
                '· ${controller.participantCount.value}명',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.taupe,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        )),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.deepBrown),
            onPressed: () => _showChatMenu(context),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: Obx(() {
                final msgs = [
                  ...controller.messages,
                  ...controller.failedMessages,
                ];
                if (msgs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.taupe.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text(
                          '아직 메시지가 없습니다.\n첫 번째 메시지를 보내보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.taupe, height: 1.5, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    final isMine = msg.senderUid == controller.currentUid;
                    final isFailed = controller.failedMessages.contains(msg);
                    
                    // Check if we need a date separator
                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMsg = msgs[index - 1];
                      if (_isDifferentDay(prevMsg.createdAt, msg.createdAt)) {
                        showDateSeparator = true;
                      }
                    }

                    // Check if same sender as previous message
                    bool showProfileAndName = true;
                    if (index > 0 && !showDateSeparator) {
                      final prevMsg = msgs[index - 1];
                      if (prevMsg.senderUid == msg.senderUid) {
                        showProfileAndName = false;
                      }
                    }

                    final int unreadCount = controller.participantCount.value - msg.readBy.length;

                    return Column(
                      children: [
                        if (showDateSeparator) _buildDateSeparator(msg.createdAt),
                        _buildMessageBubble(
                          msg: msg,
                          isMine: isMine,
                          showProfileAndName: showProfileAndName,
                          isFailed: isFailed,
                          unreadCount: unreadCount > 0 ? unreadCount : 0,
                        ),
                      ],
                    );
                  },
                );
              }),
            ),
            // Bottom Input Bar
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
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
    required bool isFailed,
    required int unreadCount,
  }) {
    final timeWidget = Text(
      DateFormat('a h:mm', 'ko_KR').format(msg.createdAt),
      style: const TextStyle(fontSize: 10, color: AppColors.taupe),
    );

    final unreadWidget = unreadCount > 0
        ? Text(
            '$unreadCount',
            style: const TextStyle(fontSize: 10, color: AppColors.taupe, fontWeight: FontWeight.bold),
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

    // 이미지만 있는 메시지인지 확인
    final bool isImageOnly = (msg.imageUrls.isNotEmpty || msg.imageUrl != null) &&
        (msg.message.isEmpty || msg.message == '사진을 보냈습니다.');

    Widget bubbleContent = Container(
      padding: isImageOnly 
          ? EdgeInsets.zero  // 이미지만 있으면 패딩 없음
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: isImageOnly 
          ? null  // 이미지만 있으면 배경 없음
          : BoxDecoration(
              color: isMine ? AppColors.sand : AppColors.white,
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
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 여러 장 이미지 그리드
          if (msg.imageUrls.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: msg.message.isNotEmpty ? 8.0 : 0),
              child: _buildImageGrid(msg.imageUrls),
            )
          // 단일 이미지 (하위 호환)
          else if (msg.imageUrl != null)
            GestureDetector(
              onTap: () => _openImageViewer([msg.imageUrl!], 0),
              child: Padding(
                padding: EdgeInsets.only(bottom: msg.message.isNotEmpty ? 8.0 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: msg.imageUrl!,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          // 이미지가 있을 때 '사진을 보냈습니다.' 숨기기
          if (msg.message.isNotEmpty && 
              msg.message != '사진을 보냈습니다.' &&
              msg.imageUrl == null && 
              msg.imageUrls.isEmpty)
            Text(
              msg.message,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? AppColors.deepBrown : AppColors.deepBrown,
                height: 1.4,
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: showProfileAndName ? 8 : 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            if (showProfileAndName)
              GestureDetector(
                onTap: () => Get.to(() => ChatUserProfilePage(uid: msg.senderUid)),
                child: Obx(() {
                  final imageUrl = controller.userProfileImages[msg.senderUid];
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.sand,
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imageUrl)
                        : null,
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? const Icon(Icons.person, size: 20, color: AppColors.taupe)
                        : null,
                  );
                }),
              )
            else
              const SizedBox(width: 32),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine && showProfileAndName)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      msg.senderNickname,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mocha,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isMine) ...[
                      if (isFailed)
                        GestureDetector(
                          onTap: () => controller.resendMessage(msg),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 4, bottom: 4),
                            child: Icon(Icons.error, color: Colors.red, size: 20),
                          ),
                        ),
                      metaWidget,
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: bubbleContent),
                    if (!isMine) ...[
                      const SizedBox(width: 6),
                      metaWidget,
                      if (isFailed)
                        GestureDetector(
                          onTap: () => controller.resendMessage(msg),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 4),
                            child: Icon(Icons.error, color: Colors.red, size: 20),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.taupe),
                onPressed: () => _showImageSourceActionSheet(context),
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
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: const TextStyle(color: AppColors.taupe, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
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
                color: controller.messageText.value.trim().isEmpty
                    ? AppColors.sand
                    : AppColors.deepBrown,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: controller.isSubmitting.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: PawLoadingIndicator(size: 20),
                      )
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

  void _showChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // 게시글 보기
                ListTile(
                  leading: const Icon(Icons.article_outlined, color: AppColors.deepBrown),
                  title: const Text('게시글 보기', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final repo = CommunityRepositoryImpl();
                    final post = await repo.getPostById(widget.postId);
                    if (post != null) {
                      Get.to(() => PostDetailPage(post: post));
                    } else {
                      CustomCenterToast.show('삭제된 게시글입니다.');
                    }
                  },
                ),
                // 채팅방 사진 변경
                ListTile(
                  leading: const Icon(Icons.image_outlined, color: AppColors.deepBrown),
                  title: const Text('채팅방 사진 변경', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.changeChatRoomImage();
                  },
                ),
                // 채팅방 이름 변경
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.deepBrown),
                  title: const Text('채팅방 이름 변경', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameDialog(context);
                  },
                ),
                // 알림 켜기/끄기
                Obx(() => ListTile(
                  leading: Icon(
                    controller.isChatMuted.value ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                    color: AppColors.deepBrown,
                  ),
                  title: Text(
                    controller.isChatMuted.value ? '채팅방 알림 켜기' : '채팅방 알림 끄기',
                    style: const TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.toggleChatMute();
                  },
                )),
                // 채팅방 나가기
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: const Text('채팅방 나가기', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLeaveConfirmDialog(context);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final textController = TextEditingController(text: controller.chatRoomName.value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('채팅방 이름 변경',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppColors.deepBrown, fontSize: 14),
          decoration: InputDecoration(
            hintText: '새 채팅방 이름',
            hintStyle: const TextStyle(color: AppColors.taupe),
            filled: true,
            fillColor: const Color(0xFFF5F5F3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.taupe, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.renameChatRoom(textController.text);
            },
            child: const Text('확인',
                style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLeaveConfirmDialog(BuildContext context) {
    // Eagerly evaluate the condition so the dialog doesn't flash when the count changes during closing
    final isLastParticipant = controller.participantCount.value <= 1;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('채팅방 나가기',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
        content: Text(
          isLastParticipant
              ? '채팅방을 나가면 모임 게시글이 삭제됩니다.\n나가시겠습니까?'
              : '채팅방을 나가시겠습니까?',
          style: const TextStyle(color: AppColors.mocha, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.taupe, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              // Let the controller handle all routing when done
              controller.leaveChatRoom();
            },
            child: const Text('나가기',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.of(ctx).pop();
                controller.pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () {
                Navigator.of(ctx).pop();
                controller.pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
