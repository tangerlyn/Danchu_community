import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';

class NotificationListPage extends StatelessWidget {
  const NotificationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deepBrown),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "알림",
          style: TextStyle(
            color: AppColors.deepBrown, 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: 1, // Dummy item for now
        itemBuilder: (context, index) {
          // Dummy data for "New MungCard Request"
          return _buildNotificationItem(
            context,
            title: "새로운 멍카 교환 요청",
            content: "'초코'님의 멍카 교환 요청이 도착했습니다!",
            time: "방금 전",
            isRead: false,
            onTap: () {
               // Navigation to detail or action sheet
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context, {
    required String title,
    required String content,
    required String time,
    required bool isRead,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isRead ? AppColors.white : const Color(0xFFFFF8F6), // Slight tint for unread
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFEBE9), 
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, color: AppColors.deepBrown, size: 20),
              ),
              const SizedBox(width: 16),
              
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            color: AppColors.deepBrown,
                          ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.taupe,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.latte,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
