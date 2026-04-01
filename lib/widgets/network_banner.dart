import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/app_colors.dart';
import '../core/network_controller.dart';

class NetworkBanner extends StatelessWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isConnected = Get.find<NetworkController>().isConnected.value;
      return AnimatedSlide(
        offset: isConnected ? const Offset(0, -1) : Offset.zero,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: isConnected ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 10,
              left: 16,
              right: 16,
            ),
            color: const Color(0xFF4A3728),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  '인터넷 연결을 확인해주세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
