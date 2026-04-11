import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/app_colors.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  bool _commentNotif = true;
  bool _meetupNotif = true;
  bool _scheduleNotif = true;
  bool _replyNotif = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_uid == null) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('notification_settings')
          .doc('preferences')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _commentNotif = data['comment'] ?? true;
          _meetupNotif = data['meetup'] ?? true;
          _scheduleNotif = data['schedule'] ?? true;
          _replyNotif = data['reply'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('알림 설정 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    if (_uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('notification_settings')
          .doc('preferences')
          .set({key: value}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('알림 설정 저장 실패: $e');
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
          '알림 설정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.deepBrown))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem(
                      icon: Icons.chat_bubble_outline,
                      label: '댓글 알림',
                      subtitle: '내 게시글에 댓글이 달리면 알려드려요',
                      value: _commentNotif,
                      onChanged: (val) {
                        setState(() => _commentNotif = val);
                        _updateSetting('comment', val);
                      },
                    ),
                    Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
                    _buildToggleItem(
                      icon: Icons.groups_outlined,
                      label: '모임 알림',
                      subtitle: '참가 중인 모임에 새 메시지가 오면 알려드려요',
                      value: _meetupNotif,
                      onChanged: (val) {
                        setState(() => _meetupNotif = val);
                        _updateSetting('meetup', val);
                      },
                    ),
                    Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
                    _buildToggleItem(
                      icon: Icons.calendar_today_outlined,
                      label: '일정 알림',
                      subtitle: '등록한 일정 2시간 전에 알려드려요',
                      value: _scheduleNotif,
                      onChanged: (val) {
                        setState(() => _scheduleNotif = val);
                        _updateSetting('schedule', val);
                      },
                    ),
                    Divider(height: 1, color: AppColors.sand.withOpacity(0.5)),
                    _buildToggleItem(
                      icon: Icons.reply_outlined,
                      label: '답글 알림',
                      subtitle: '내 댓글에 답글이 달리면 알려드려요',
                      value: _replyNotif,
                      onChanged: (val) {
                        setState(() => _replyNotif = val);
                        _updateSetting('reply', val);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.deepBrown, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.deepBrown)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.taupe)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.deepBrown,
          ),
        ],
      ),
    );
  }
}
