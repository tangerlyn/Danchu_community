import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_colors.dart';

class CustomCenterToast {
  static void show(String message) {
    if (Get.isDialogOpen ?? false) return;

    Get.dialog(
      _ToastWidget(message: message),
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      useSafeArea: false,
    );

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.deepBrown.withOpacity(0.75),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none, // Remove Material text underline
            ),
          ),
        ),
      ),
    );
  }
}
