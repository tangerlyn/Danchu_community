import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../data/repositories/meetup_chat_repository.dart';
import '../../../domain/entities/community_post.dart';
import '../community_controller.dart';
import '../meetup_chat_page.dart';
import 'meetup_chat_skeleton.dart';

class MeetupChatListWidget extends StatefulWidget {
  final List<CommunityPost> meetupPosts;

  const MeetupChatListWidget({super.key, required this.meetupPosts});

  @override
  State<MeetupChatListWidget> createState() => _MeetupChatListWidgetState();
}

class _MeetupChatListWidgetState extends State<MeetupChatListWidget> {
  final MeetupChatRepository _chatRepository = MeetupChatRepository();
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache: postId -> last message
  final Map<String, ChatMessage?> _lastMessages = {};
  // Cache: postId -> participant count
  final Map<String, int> _participantCounts = {};
  // Cache: postId -> chatRoomName
  final Map<String, String> _chatRoomNames = {};
  // Cache: postId -> chatRoomImageUrl
  final Map<String, String> _chatRoomImageUrls = {};
  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];
  
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(MeetupChatListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meetupPosts != widget.meetupPosts) {
      _loadData();
    }
  }

  void _loadData() {
    // Cancel previous subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    for (final post in widget.meetupPosts) {
      // Listen to last message stream
      final sub = _chatRepository.getLastMessageStream(post.id).listen((msg) {
        if (mounted) {
          setState(() {
            _lastMessages[post.id] = msg;
          });
        }
      });
      _subscriptions.add(sub);

      // Listen to participant count
      final participantSub = _firestore
          .collection('community_posts').doc(post.id)
          .collection('participants')
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _participantCounts[post.id] = snapshot.docs.length;
          });
        }
      });
      _subscriptions.add(participantSub);

      // Listen to post document for name and image updates
      final postSub = _firestore.collection('community_posts').doc(post.id).snapshots().listen((doc) {
        if (mounted && doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          final name = data?['chatRoomName'] as String?;
          final imageUrl = data?['chatRoomImageUrl'] as String?;
          
          setState(() {
            if (name != null && name.isNotEmpty) {
              _chatRoomNames[post.id] = name;
            }
            if (imageUrl != null && imageUrl.isNotEmpty) {
              _chatRoomImageUrls[post.id] = imageUrl;
            }
          });
        }
      });
      _subscriptions.add(postSub);
    }

    setState(() {
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MeetupChatSkeleton();
    }

    if (widget.meetupPosts.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.taupe.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              const Text(
                '참가 중인 모임이 없습니다.\n모임에 참가하면 채팅방이 여기에 나타납니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.taupe, height: 1.5, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by last message time, descending
    final sortedPosts = List<CommunityPost>.from(widget.meetupPosts);
    sortedPosts.sort((a, b) {
      final aMsg = _lastMessages[a.id];
      final bMsg = _lastMessages[b.id];
      final aTime = aMsg?.createdAt ?? a.createdAt;
      final bTime = bMsg?.createdAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedPosts.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        color: AppColors.sand,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final post = sortedPosts[index];
        final lastMsg = _lastMessages[post.id];
        final participantCount = _participantCounts[post.id] ?? 0;
        final displayName = _chatRoomNames[post.id] ?? post.title;

        return Obx(() {
          final unreadCount = Get.isRegistered<CommunityController>() 
              ? (Get.find<CommunityController>().unreadCountsMap[post.id] ?? 0)
              : 0;
          final hasUnread = unreadCount > 0;

          return InkWell(
            onTap: () {
              Get.to(() => MeetupChatPage(
                postId: post.id,
                postTitle: post.title,
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Representative image or fallback icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.sand.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _buildChatRoomImage(post),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chat info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.deepBrown,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              participantCount.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.taupe,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMsg?.message ?? '메시지가 없습니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: hasUnread ? AppColors.deepBrown : AppColors.mocha,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Time + badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lastMsg != null ? _formatTime(lastMsg.createdAt) : '',
                        style: const TextStyle(fontSize: 11, color: AppColors.taupe),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return DateFormat('a h:mm', 'ko_KR').format(dateTime);
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return DateFormat('E', 'ko_KR').format(dateTime);
    } else {
      return DateFormat('M/d').format(dateTime);
    }
  }

  Widget _buildChatRoomImage(CommunityPost post) {
    final chatRoomImageUrl = _chatRoomImageUrls[post.id];
    final postFirstImageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
    final String? finalUrl = (chatRoomImageUrl != null && chatRoomImageUrl.isNotEmpty) 
        ? chatRoomImageUrl 
        : postFirstImageUrl;

    if (finalUrl != null && finalUrl.isNotEmpty) {
      return Image.network(
        finalUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.groups_outlined,
          color: AppColors.deepBrown,
          size: 24,
        ),
      );
    }

    return const Icon(
      Icons.groups_outlined,
      color: AppColors.deepBrown,
      size: 24,
    );
  }
}
