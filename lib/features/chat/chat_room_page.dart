import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_controller.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String otherUid;
  final String otherName;

  const ChatRoomPage({
    super.key,
    required this.roomId,
    required this.otherUid,
    required this.otherName,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  late final ChatController controller;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    controller = Get.find<ChatController>();
    controller.enterChatRoom(widget.roomId);
  }

  @override
  void dispose() {
    controller.leaveChatRoom();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE4),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deepBrown),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.otherName,
          style: const TextStyle(
            color: AppColors.deepBrown,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          // Hidden test bot button
          Obx(() => IconButton(
            icon: Icon(
              Icons.smart_toy_outlined,
              color: controller.isBotRunning.value
                  ? AppColors.latte
                  : AppColors.taupe,
              size: 22,
            ),
            tooltip: '테스트 봇',
            onPressed: () {
              if (controller.isBotRunning.value) {
                controller.stopTestBot();
                Get.snackbar('🤖 봇 중지', '테스트 봇이 멈췄습니다.',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: AppColors.white,
                    colorText: AppColors.deepBrown);
              } else {
                controller.runTestBot(widget.roomId, widget.otherUid);
                Get.snackbar('🤖 봇 시작', '10초마다 메시지를 보냅니다 (총 6회)',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: AppColors.white,
                    colorText: AppColors.deepBrown);
              }
            },
          )),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.latte),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Message List (StreamBuilder via Obx) ───
            Expanded(
              child: Obx(() {
                if (controller.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: AppColors.sand),
                        const SizedBox(height: 12),
                        Text(
                          "${widget.otherName}님과의 대화를 시작해보세요! 🐾",
                          style: TextStyle(
                            color: AppColors.taupe,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: controller.scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: controller.messages.length,
                  itemBuilder: (context, index) {
                    final msg = controller.messages[index];
                    final data = msg.data() as Map<String, dynamic>;
                    final isMe = data['senderUid'] != widget.otherUid;
                    
                    // Parse timestamp
                    final Timestamp? ts = data['createdAt'] as Timestamp?;
                    final DateTime? sentTime = ts?.toDate();
                    
                    // Read receipt
                    final bool isRead = data['isRead'] ?? false;

                    // Check if we should show date divider
                    bool showDate = false;
                    if (index < controller.messages.length - 1) {
                      final nextMsg = controller.messages[index + 1];
                      final nextData = nextMsg.data() as Map<String, dynamic>;
                      final Timestamp? nextTs = nextData['createdAt'] as Timestamp?;
                      if (sentTime != null && nextTs != null) {
                        final nextTime = nextTs.toDate();
                        showDate = sentTime.day != nextTime.day ||
                            sentTime.month != nextTime.month ||
                            sentTime.year != nextTime.year;
                      }
                    } else {
                      showDate = true; // First message (bottom of reversed list)
                    }

                    return Column(
                      children: [
                        if (showDate && sentTime != null)
                          _buildDateDivider(sentTime),
                        _buildMessageBubble(
                          text: data['text'] ?? '',
                          isMe: isMe,
                          sentTime: sentTime,
                          isRead: isRead,
                        ),
                      ],
                    );
                  },
                );
              }),
            ),

            // ─── Input Area ───
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ────────────────── Date Divider ──────────────────
  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = '오늘';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = '어제';
    } else {
      label = DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.sand.withOpacity(0.5), thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.taupe,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.sand.withOpacity(0.5), thickness: 0.5)),
        ],
      ),
    );
  }

  // ────────────────── Message Bubble ──────────────────
  Widget _buildMessageBubble({
    required String text,
    required bool isMe,
    DateTime? sentTime,
    required bool isRead,
  }) {
    final timeText = sentTime != null
        ? DateFormat('a h:mm', 'ko').format(sentTime)
        : '';

    // Read receipt + time widget
    final metaWidget = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Unread "1" indicator (only for MY messages that haven't been read)
        if (isMe && !isRead)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            child: const Text(
              '1',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE6A23C),
              ),
            ),
          ),
        // Time
        Text(
          timeText,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.taupe,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) ...[
            metaWidget,
            const SizedBox(width: 4),
          ],
          
          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF5D4037) : AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mocha.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? AppColors.white : AppColors.deepBrown,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),

          if (!isMe) ...[
            const SizedBox(width: 4),
            metaWidget,
          ],
        ],
      ),
    );
  }

  // ────────────────── Input Area ──────────────────
  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          // + Button
          GestureDetector(
            onTap: _showMediaPicker,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0EB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add, color: Color(0xFF5D4037), size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Text Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3EF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  hintStyle: TextStyle(
                    color: AppColors.taupe,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button (Paw icon)
          GestureDetector(
            onTap: _handleSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF5D4037),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.pets, color: AppColors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────── Send Handler ──────────────────
  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    controller.sendMessage(widget.roomId, text);
    _textController.clear();
    _focusNode.requestFocus(); // Keep keyboard open
  }

  // ────────────────── Media Picker Bottom Sheet ──────────────────
  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Camera option
              _buildMediaOption(
                icon: Icons.camera_alt_outlined,
                label: '카메라로 촬영하기',
                emoji: '📷',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Connect camera
                  Get.snackbar(
                    '준비 중',
                    '카메라 기능은 곧 준비됩니다 📷',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: AppColors.white,
                    colorText: AppColors.deepBrown,
                  );
                },
              ),
              const SizedBox(height: 12),

              // Gallery option
              _buildMediaOption(
                icon: Icons.photo_library_outlined,
                label: '갤러리에서 사진 선택',
                emoji: '🖼️',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Connect gallery picker
                  Get.snackbar(
                    '준비 중',
                    '갤러리 기능은 곧 준비됩니다 🖼️',
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: AppColors.white,
                    colorText: AppColors.deepBrown,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required String emoji,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7F3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.deepBrown,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: AppColors.taupe, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
