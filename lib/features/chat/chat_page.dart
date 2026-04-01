import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_controller.dart';
import 'chat_room_page.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChatController());

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      appBar: AppBar(
        title: const Text(
          '채팅',
          style: TextStyle(
            color: AppColors.deepBrown,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: false,
      ),
      body: Obx(() {
        if (controller.myRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 56, color: AppColors.sand),
                const SizedBox(height: 16),
                Text(
                  '아직 채팅이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.taupe,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '친구 목록에서 채팅을 시작해보세요! 🐾',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.taupe,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: controller.myRooms.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 76,
            color: AppColors.sand,
          ),
          itemBuilder: (context, index) {
            final room = controller.myRooms[index];
            final data = room.data() as Map<String, dynamic>;
            final members = data['members'] as List;
            final otherUid = controller.getOtherUid(members);
            final profile = controller.userProfiles[otherUid];
            
            final lastMsg = data['lastMessage'] as String? ?? '';
            final Timestamp? lastTs = data['lastMessageTime'] as Timestamp?;
            final lastTime = lastTs?.toDate();
            final otherName = profile?.dogName ?? '알 수 없는 사용자';
            
            // Format time
            String timeLabel = '';
            if (lastTime != null) {
              final now = DateTime.now();
              if (lastTime.year == now.year &&
                  lastTime.month == now.month &&
                  lastTime.day == now.day) {
                timeLabel = DateFormat('a h:mm', 'ko').format(lastTime);
              } else if (lastTime.year == now.year &&
                  lastTime.month == now.month &&
                  lastTime.day == now.day - 1) {
                timeLabel = '어제';
              } else {
                timeLabel = DateFormat('M/d').format(lastTime);
              }
            }
            
            return Material(
              color: AppColors.white,
              child: InkWell(
                onTap: () {
                  Get.to(() => ChatRoomPage(
                    roomId: room.id,
                    otherUid: otherUid,
                    otherName: otherName,
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFEDE0D4),
                        backgroundImage: profile?.profileImageUrl != null &&
                                profile!.profileImageUrl.isNotEmpty
                            ? CachedNetworkImageProvider(profile.profileImageUrl)
                            : null,
                        child: (profile?.profileImageUrl == null ||
                                profile!.profileImageUrl.isEmpty)
                            ? const Icon(Icons.pets,
                                color: Color(0xFF8D6E63), size: 24)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      
                      // Name + Last message
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              otherName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.deepBrown,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastMsg.isNotEmpty ? lastMsg : '새로운 대화를 시작하세요',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: lastMsg.isNotEmpty
                                    ? AppColors.latte
                                    : AppColors.taupe,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Time label
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.taupe,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
