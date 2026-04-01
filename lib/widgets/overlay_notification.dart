import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';

/// Slide-down overlay notification for foreground FCM messages.
class OverlayNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Show an in-app overlay notification that slides down from the top.
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any existing overlay first
    dismiss();

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => _OverlayNotificationWidget(
        title: title,
        body: body,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _OverlayNotificationWidget extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _OverlayNotificationWidget({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_OverlayNotificationWidget> createState() =>
      _OverlayNotificationWidgetState();
}

class _OverlayNotificationWidgetState
    extends State<_OverlayNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                widget.onDismiss();
              }
            },
            child: Container(
              margin: EdgeInsets.only(
                top: topPadding + 8,
                left: 12,
                right: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mocha.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: AppColors.mocha.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Paw icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pets,
                      color: Color(0xFFE65100),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E2723),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.latte,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Close/dismiss indicator
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.taupe,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
